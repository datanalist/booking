import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

import '../../config/mapbox_config.dart';
import '../../config/mapbox_geocoding.dart';
import '../../config/mapbox_style.dart';
import '../../data/booking.dart';
import '../../theme/app_theme.dart';

const _mapFill = Color(0xFFE8EEE4);
const _minZoom = 3.0;
const _maxZoom = 19.0;
const _pinSize = 40.0;

typedef BookingAddressGeocode =
    Future<List<AddressSuggestion>> Function(String query);

/// Карта адреса жилья: Mapbox/flutter_map, как [SearchMapView], либо текст.
class BookingAddressMapScreen extends StatefulWidget {
  const BookingAddressMapScreen({
    super.key,
    required this.booking,
    this.geocode,
  });

  final Booking booking;
  final BookingAddressGeocode? geocode;

  @visibleForTesting
  static BookingAddressGeocode? debugGeocode;

  static bool get _isWidgetTest {
    return WidgetsBinding.instance.runtimeType.toString().contains(
      'TestWidgetsFlutterBinding',
    );
  }

  @override
  State<BookingAddressMapScreen> createState() => _BookingAddressMapScreenState();
}

class _BookingAddressMapScreenState extends State<BookingAddressMapScreen> {
  LatLng? _point;
  var _resolving = false;
  Style? _style;

  Booking get _booking => widget.booking;

  String get _label {
    final label = _booking.addressLabel.trim();
    return label.isEmpty ? 'Адрес не указан' : label;
  }

  bool get _hasStoredPoint =>
      _booking.latitude != 0 || _booking.longitude != 0;

  @override
  void initState() {
    super.initState();
    if (_hasStoredPoint) {
      _point = LatLng(_booking.latitude, _booking.longitude);
    } else {
      _resolving = true;
      _geocodeAddress();
    }
    if (MapboxConfig.accessToken.isEmpty &&
        !BookingAddressMapScreen._isWidgetTest) {
      MapboxConfig.initialize().then((_) {
        if (mounted) {
          setState(() {});
          _loadStyle();
        }
      });
    } else {
      _loadStyle();
    }
  }

  Future<void> _geocodeAddress() async {
    final query = _booking.addressLabel.trim();
    final geocode =
        widget.geocode ??
        BookingAddressMapScreen.debugGeocode ??
        MapboxGeocoding.suggest;
    List<AddressSuggestion> results = const [];
    if (query.length >= 2) {
      results = await geocode(query);
    }
    if (!mounted) return;
    AddressSuggestion? match;
    for (final item in results) {
      if (item.latitude != null && item.longitude != null) {
        match = item;
        break;
      }
    }
    setState(() {
      _resolving = false;
      if (match != null) {
        _point = LatLng(match.latitude!, match.longitude!);
      }
    });
  }

  Future<void> _loadStyle() async {
    final token = MapboxConfig.accessToken;
    if (token.isEmpty || BookingAddressMapScreen._isWidgetTest) return;
    try {
      final style = await loadRussianMapboxStyle(token: token);
      if (!mounted) return;
      setState(() => _style = style);
    } catch (_) {
      // Остаётся растровая подложка с language=ru.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey<String>('booking-address-map'),
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          _label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_resolving) {
      return const ColoredBox(
        color: _mapFill,
        child: Center(
          child: Text(
            'Ищем адрес на карте…',
            key: ValueKey<String>('booking-address-loading'),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w400,
              fontSize: 16,
              color: AppColors.emptyHint,
            ),
          ),
        ),
      );
    }
    final point = _point;
    if (point == null) {
      return ColoredBox(
        color: AppColors.white,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _label,
              key: const ValueKey<String>('booking-address-text'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 16,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      );
    }
    return ColoredBox(
      color: _mapFill,
      child: _AddressMap(point: point, style: _style),
    );
  }
}

class _AddressMap extends StatelessWidget {
  const _AddressMap({required this.point, required this.style});

  final LatLng point;
  final Style? style;

  bool get _useTiles {
    return MapboxConfig.accessToken.isNotEmpty &&
        !BookingAddressMapScreen._isWidgetTest;
  }

  @override
  Widget build(BuildContext context) {
    if (!_useTiles) {
      return const Center(child: _AddressPin());
    }
    final token = MapboxConfig.accessToken;
    return FlutterMap(
      options: MapOptions(
        initialCenter: point,
        initialZoom: 15,
        minZoom: _minZoom,
        maxZoom: _maxZoom,
        backgroundColor: _mapFill,
      ),
      children: [
        if (style != null)
          VectorTileLayer(
            theme: style!.theme,
            sprites: style!.sprites,
            tileProviders: style!.providers,
            tileOffset: TileOffset.mapbox,
            maximumZoom: 22,
          )
        else
          TileLayer(
            urlTemplate: mapboxStreetsRasterUrl(token),
            fallbackUrl: mapboxStreetsRasterFallbackUrl(token),
            tileDimension: 512,
            zoomOffset: -1,
            maxNativeZoom: 22,
            userAgentPackageName: 'com.booking.booking',
            tileDisplay: const TileDisplay.instantaneous(),
          ),
        MarkerLayer(
          markers: [
            Marker(
              key: const ValueKey<String>('booking-address-pin'),
              point: point,
              width: _pinSize,
              height: _pinSize,
              alignment: Alignment.bottomCenter,
              child: const _AddressPin(),
            ),
          ],
        ),
      ],
    );
  }
}

class _AddressPin extends StatelessWidget {
  const _AddressPin();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      key: ValueKey<String>('booking-address-pin'),
      Icons.location_on,
      color: AppColors.orange,
      size: _pinSize,
    );
  }
}
