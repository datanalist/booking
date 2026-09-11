import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/mapbox_config.dart';
import '../../theme/app_theme.dart';
import 'search_listing.dart';

const _mapFill = Color(0xFFE8EEE4);
const _minZoom = 3.0;
const _maxZoom = 19.0;
const _scrollZoomVelocity = 0.012;
const _pinHeight = 36.0;
const _pinRevealGap = 20.0;
const _pinText = Color(0xFF1A1B1C);

/// Карта поиска на тайлах Mapbox Streets.
class SearchMapView extends StatefulWidget {
  const SearchMapView({
    super.key,
    required this.listings,
    required this.selectedId,
    required this.onSelectPin,
    this.preview,
  });

  final List<SearchListing> listings;
  final String? selectedId;
  final ValueChanged<String> onSelectPin;
  final Widget? preview;

  static bool get _isWidgetTest {
    return WidgetsBinding.instance.runtimeType.toString().contains(
      'TestWidgetsFlutterBinding',
    );
  }

  @override
  State<SearchMapView> createState() => _SearchMapViewState();
}

class _SearchMapViewState extends State<SearchMapView> {
  final _previewKey = GlobalKey();
  var _previewExtent = 0.0;

  @override
  void initState() {
    super.initState();
    if (MapboxConfig.accessToken.isEmpty && !SearchMapView._isWidgetTest) {
      MapboxConfig.initialize().then((_) {
        if (mounted) setState(() {});
      });
    }
    if (widget.preview != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measurePreview());
    }
  }

  @override
  void didUpdateWidget(covariant SearchMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.preview == null) {
      if (_previewExtent != 0) _previewExtent = 0;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _measurePreview());
  }

  void _measurePreview() {
    if (!mounted || widget.preview == null) return;
    final box = _previewKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final extent = box.size.height;
    if ((extent - _previewExtent).abs() < 1) return;
    setState(() => _previewExtent = extent);
  }

  @override
  Widget build(BuildContext context) {
    final useTiles =
        MapboxConfig.accessToken.isNotEmpty && !SearchMapView._isWidgetTest;
    final map = useTiles
        ? _MapboxTilesMap(
            listings: widget.listings,
            selectedId: widget.selectedId,
            onSelectPin: widget.onSelectPin,
            token: MapboxConfig.accessToken,
            previewExtent: _previewExtent,
          )
        : _FallbackSearchMap(
            listings: widget.listings,
            selectedId: widget.selectedId,
            onSelectPin: widget.onSelectPin,
            previewExtent: _previewExtent,
          );

    return ColoredBox(
      color: _mapFill,
      child: Stack(
        children: [
          Positioned.fill(child: map),
          if (widget.preview != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                key: _previewKey,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: widget.preview!,
              ),
            ),
        ],
      ),
    );
  }
}

class _MapboxTilesMap extends StatefulWidget {
  const _MapboxTilesMap({
    required this.listings,
    required this.selectedId,
    required this.onSelectPin,
    required this.token,
    required this.previewExtent,
  });

  final List<SearchListing> listings;
  final String? selectedId;
  final ValueChanged<String> onSelectPin;
  final String token;
  final double previewExtent;

  @override
  State<_MapboxTilesMap> createState() => _MapboxTilesMapState();
}

class _MapboxTilesMapState extends State<_MapboxTilesMap>
    with SingleTickerProviderStateMixin {
  final _controller = MapController();
  AnimationController? _revealAnimation;
  double? _pinchStartZoom;
  var _pointers = 0;
  DateTime? _downTime;
  PointerDeviceKind? _downKind;
  Offset? _lastPan;
  Duration? _lastHandledStamp;
  int? _lastHandledDevice;

  @override
  void didUpdateWidget(covariant _MapboxTilesMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final listingsChanged = !_sameListings(oldWidget.listings, widget.listings);
    if (listingsChanged) {
      final target = _cameraForListings(widget.listings);
      _controller.move(LatLng(target.latitude, target.longitude), target.zoom);
    }
    if (listingsChanged ||
        oldWidget.selectedId != widget.selectedId ||
        oldWidget.previewExtent != widget.previewExtent) {
      _scheduleRevealSelectedPin();
    }
  }

  @override
  void initState() {
    super.initState();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onGlobalPointer);
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onGlobalPointer);
    final animation = _revealAnimation;
    _revealAnimation = null;
    animation?.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onGlobalPointer(PointerEvent event) {
    if (!mounted) return;
    if (event is PointerScrollEvent) {
      final local = _localFromGlobal(event.position);
      if (local == null || !_takePointerZoom(event)) return;
      event.respond(allowPlatformDefault: false);
      _zoomByScrollDelta(local, scrollAmount(event.scrollDelta));
      return;
    }
    if (event is PointerPanZoomUpdateEvent) {
      final local = _localFromGlobal(event.position);
      if (local == null) return;
      _applyPanZoom(event, local);
    }
  }

  Offset? _localFromGlobal(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final local = box.globalToLocal(global);
    if (!box.size.contains(local)) return null;
    return local;
  }

  void _scheduleRevealSelectedPin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _revealSelectedPin();
    });
  }

  void _revealSelectedPin() {
    final listing = _listingById(widget.listings, widget.selectedId);
    if (listing == null) return;
    final MapCamera camera;
    try {
      camera = _controller.camera;
    } catch (_) {
      return;
    }
    final dest = pinRevealCenter(
      camera: camera,
      pin: LatLng(listing.latitude, listing.longitude),
      previewExtent: widget.previewExtent,
    );
    if (dest == null) return;
    _animateTo(dest);
  }

  void _animateTo(LatLng dest) {
    _revealAnimation?.dispose();
    final MapCamera camera;
    try {
      camera = _controller.camera;
    } catch (_) {
      return;
    }
    final from = camera.center;
    if ((from.latitude - dest.latitude).abs() < 1e-8 &&
        (from.longitude - dest.longitude).abs() < 1e-8) {
      return;
    }
    final animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _revealAnimation = animation;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    final lat = Tween(begin: from.latitude, end: dest.latitude);
    final lng = Tween(begin: from.longitude, end: dest.longitude);
    final zoom = camera.zoom;
    animation
      ..addListener(() {
        _controller.move(
          LatLng(lat.evaluate(curved), lng.evaluate(curved)),
          zoom,
        );
      })
      ..forward().whenComplete(() {
        if (!mounted) return;
        if (identical(_revealAnimation, animation)) {
          animation.dispose();
          _revealAnimation = null;
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    final target = _cameraForListings(widget.listings);
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerSignal: _onPointerSignal,
      onPointerPanZoomStart: (_) => _pinchStartZoom = null,
      onPointerPanZoomUpdate: _onPointerPanZoomUpdate,
      onPointerPanZoomEnd: (_) => _pinchStartZoom = null,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: (_) => _onPointerUp(),
      child: FlutterMap(
        mapController: _controller,
        options: MapOptions(
          initialCenter: LatLng(target.latitude, target.longitude),
          initialZoom: target.zoom,
          minZoom: _minZoom,
          maxZoom: _maxZoom,
          backgroundColor: _mapFill,
          onMapReady: _revealSelectedPin,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.pinchZoom |
                InteractiveFlag.doubleTapZoom |
                InteractiveFlag.doubleTapDragZoom,
            scrollWheelVelocity: _scrollZoomVelocity,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/512/{z}/{x}/{y}?access_token=${widget.token}',
            fallbackUrl:
                'https://api.mapbox.com/v4/mapbox.streets/{z}/{x}/{y}@2x.png?access_token=${widget.token}',
            tileDimension: 512,
            zoomOffset: -1,
            maxNativeZoom: 22,
            userAgentPackageName: 'com.booking.booking',
            tileDisplay: const TileDisplay.instantaneous(),
          ),
          MarkerLayer(markers: _priceMarkers()),
        ],
      ),
    );
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final scrollDy = scrollAmount(event.scrollDelta);
    if (scrollDy == 0 || !_takePointerZoom(event)) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      resolved as PointerScrollEvent;
      resolved.respond(allowPlatformDefault: false);
      _zoomByScrollDelta(
        resolved.localPosition,
        scrollAmount(resolved.scrollDelta),
      );
    });
  }

  void _onPointerPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    _applyPanZoom(event, event.localPosition);
  }

  void _applyPanZoom(PointerPanZoomUpdateEvent event, Offset local) {
    if (!_takePointerZoom(event)) return;
    if ((event.scale - 1).abs() > 0.02) {
      _pinchStartZoom ??= _safeZoom();
      if (_pinchStartZoom == null) return;
      _moveZoom(
        local,
        zoomAfterScale(startZoom: _pinchStartZoom!, scale: event.scale),
      );
      return;
    }
    _pinchStartZoom = null;
    final scrollDy = scrollAmount(event.panDelta);
    if (scrollDy == 0) return;
    _zoomByScrollDelta(local, scrollDy);
  }

  bool _takePointerZoom(PointerEvent event) {
    if (_lastHandledStamp == event.timeStamp &&
        _lastHandledDevice == event.device) {
      return false;
    }
    _lastHandledStamp = event.timeStamp;
    _lastHandledDevice = event.device;
    return true;
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers += 1;
    if (_pointers != 1) return;
    _downTime = DateTime.now();
    _downKind = event.kind;
    _lastPan = event.localPosition;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pointers != 1 || _lastPan == null) return;
    final delta = event.localPosition - _lastPan!;
    _lastPan = event.localPosition;
    if (delta.distance < 0.01) return;

    // На эмуляторе Android колесо часто приходит как короткий вертикальный
    // скачок, а не как PointerScrollEvent.
    final held = _downTime == null
        ? Duration.zero
        : DateTime.now().difference(_downTime!);
    final fromMouse =
        _downKind == PointerDeviceKind.mouse ||
        _downKind == PointerDeviceKind.trackpad ||
        event.kind == PointerDeviceKind.mouse ||
        event.kind == PointerDeviceKind.trackpad;
    final wheelLikeJump =
        delta.dy.abs() >= 12 &&
        delta.dy.abs() > delta.dx.abs() * 2 &&
        held < const Duration(milliseconds: 120);
    if ((fromMouse && held < const Duration(milliseconds: 140)) ||
        wheelLikeJump) {
      _zoomByScrollDelta(event.localPosition, delta.dy);
      return;
    }
    _panBy(delta);
  }

  void _onPointerUp([PointerUpEvent? event]) {
    _pointers = (_pointers - 1).clamp(0, 32);
    if (_pointers > 0) return;
    _downTime = null;
    _downKind = null;
    _lastPan = null;
  }

  void _panBy(Offset delta) {
    final camera = _safeCamera();
    if (camera == null) return;
    final next = camera.unprojectAtZoom(
      camera.projectAtZoom(camera.center) - delta,
    );
    _controller.move(next, camera.zoom);
  }

  MapCamera? _safeCamera() {
    try {
      final camera = _controller.camera;
      if (!camera.nonRotatedSize.isFinite || camera.nonRotatedSize.isEmpty) {
        return null;
      }
      return camera;
    } catch (_) {
      return null;
    }
  }

  double? _safeZoom() => _safeCamera()?.zoom;

  void _zoomByScrollDelta(Offset localPosition, double scrollDy) {
    final camera = _safeCamera();
    if (camera == null) return;
    _moveZoom(
      localPosition,
      (camera.zoom - scrollDy * _scrollZoomVelocity)
          .clamp(_minZoom, _maxZoom)
          .toDouble(),
    );
  }

  void _moveZoom(Offset localPosition, double newZoom) {
    final camera = _controller.camera;
    if (!camera.nonRotatedSize.isFinite || camera.nonRotatedSize.isEmpty) {
      return;
    }
    if ((newZoom - camera.zoom).abs() < 0.0001) return;
    _controller.move(camera.focusedZoomCenter(localPosition, newZoom), newZoom);
  }

  List<Marker> _priceMarkers() {
    return [
      for (final listing in widget.listings)
        Marker(
          key: ValueKey('map-pin-${listing.id}'),
          point: LatLng(listing.latitude, listing.longitude),
          width: 120,
          height: _pinHeight,
          alignment: Alignment.center,
          child: Center(
            child: PricePin(
              label: listing.total,
              active: listing.id == widget.selectedId,
              onTap: () => widget.onSelectPin(listing.id),
            ),
          ),
        ),
    ];
  }
}

class _FallbackSearchMap extends StatelessWidget {
  const _FallbackSearchMap({
    required this.listings,
    required this.selectedId,
    required this.onSelectPin,
    required this.previewExtent,
  });

  final List<SearchListing> listings;
  final String? selectedId;
  final ValueChanged<String> onSelectPin;
  final double previewExtent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            for (var i = 0; i < listings.length; i++)
              Positioned(
                left: 56 + (i % 3) * 72.0,
                top: fallbackPinTop(
                  index: i,
                  selected: listings[i].id == selectedId,
                  previewExtent: previewExtent,
                  mapHeight: constraints.maxHeight,
                ),
                child: PricePin(
                  key: ValueKey('map-pin-${listings[i].id}'),
                  label: listings[i].total,
                  active: listings[i].id == selectedId,
                  onTap: () => onSelectPin(listings[i].id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class PricePin extends StatefulWidget {
  const PricePin({
    super.key,
    required this.label,
    required this.active,
    this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  State<PricePin> createState() => _PricePinState();
}

class _PricePinState extends State<PricePin> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.active || _hovered;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: ShapeDecoration(
            color: highlighted ? AppColors.orange : AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            shadows: const [
              BoxShadow(
                color: Color(0x19000000),
                blurRadius: 32,
                offset: Offset.zero,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              height: 1.40,
              color: highlighted ? AppColors.white : _pinText,
            ),
          ),
        ),
      ),
    );
  }
}

({double latitude, double longitude, double zoom}) _cameraForListings(
  List<SearchListing> listings,
) {
  const moscow = (latitude: 55.7558, longitude: 37.6173, zoom: 12.2);
  if (listings.isEmpty) return moscow;

  final moscowListings = listings
      .where((item) => item.city == 'Москва')
      .toList();
  final focus = listings.map((item) => item.city).toSet().length == 1
      ? listings
      : (moscowListings.isNotEmpty ? moscowListings : listings);

  final latitude =
      focus.map((item) => item.latitude).reduce((a, b) => a + b) / focus.length;
  final longitude =
      focus.map((item) => item.longitude).reduce((a, b) => a + b) /
      focus.length;
  return (latitude: latitude, longitude: longitude, zoom: 12.2);
}

bool _sameListings(List<SearchListing> a, List<SearchListing> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id) return false;
  }
  return true;
}

SearchListing? _listingById(List<SearchListing> listings, String? id) {
  if (id == null) return null;
  for (final listing in listings) {
    if (listing.id == id) return listing;
  }
  return null;
}

@visibleForTesting
double scrollAmount(Offset delta) {
  if (delta.dy != 0) return delta.dy;
  return delta.dx;
}

@visibleForTesting
double zoomAfterScale({
  required double startZoom,
  required double scale,
}) {
  if (scale <= 0) return startZoom;
  return (startZoom + math.log(scale) / math.ln2)
      .clamp(_minZoom, _maxZoom)
      .toDouble();
}

@visibleForTesting
LatLng? pinRevealCenter({
  required MapCamera camera,
  required LatLng pin,
  required double previewExtent,
}) {
  if (previewExtent <= 0) return null;
  if (!camera.nonRotatedSize.isFinite || camera.nonRotatedSize.isEmpty) {
    return null;
  }

  final pinScreen = camera.latLngToScreenOffset(pin);
  final coveredTop = camera.nonRotatedSize.height - previewExtent;
  final overflow = pinScreen.dy + _pinHeight / 2 + _pinRevealGap - coveredTop;
  if (overflow <= 1) return null;

  return camera.screenOffsetToLatLng(
    camera.latLngToScreenOffset(camera.center) + Offset(0, overflow),
  );
}

@visibleForTesting
double fallbackPinTop({
  required int index,
  required bool selected,
  required double previewExtent,
  required double mapHeight,
}) {
  final base = 120 + (index ~/ 3) * 52.0 + (index % 2) * 18.0;
  if (!selected || previewExtent <= 0 || !mapHeight.isFinite) return base;

  final maxTop = mapHeight - previewExtent - _pinHeight - _pinRevealGap;
  if (base <= maxTop) return base;
  return maxTop.clamp(8.0, base);
}
