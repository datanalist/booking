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
import '../listing/listing_detail_screen.dart';
import '../search/search_apartment_card.dart';
import '../search/search_listing.dart';
import '../search/search_map_view.dart';

const _mapFill = Color(0xFFE8EEE4);
const _minZoom = 3.0;
const _maxZoom = 19.0;
const _pinSize = 40.0;
const _meta = Color(0xFF9A9A9A);
const _priceMuted = Color(0xFF6B6B6B);

typedef BookingAddressGeocode =
    Future<List<AddressSuggestion>> Function(String query);

/// Карта адреса жилья.
///
/// Для предстоящей брони ([listing] задан) — как поиск: [SearchMapView],
/// [PricePin] и нижний preview [SearchApartmentCard].
/// Для архива ([listing] == null) — одиночный пин `Icons.location_on`.
class BookingAddressMapScreen extends StatefulWidget {
  const BookingAddressMapScreen({
    super.key,
    required this.booking,
    this.listing,
    this.geocode,
  });

  final Booking booking;

  /// Объявление брони: если задано — карта как в поиске.
  final SearchListing? listing;
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
  String? _selectedId;
  final _favorites = <String>{};

  Booking get _booking => widget.booking;

  bool get _searchStyle => widget.listing != null;

  String get _label {
    final label = _booking.addressLabel.trim();
    return label.isEmpty ? 'Адрес не указан' : label;
  }

  bool get _hasStoredPoint {
    if (_booking.latitude != 0 || _booking.longitude != 0) return true;
    final listing = widget.listing;
    if (listing == null) return false;
    return listing.latitude != 0 || listing.longitude != 0;
  }

  LatLng? get _storedPoint {
    if (_booking.latitude != 0 || _booking.longitude != 0) {
      return LatLng(_booking.latitude, _booking.longitude);
    }
    final listing = widget.listing;
    if (listing != null &&
        (listing.latitude != 0 || listing.longitude != 0)) {
      return LatLng(listing.latitude, listing.longitude);
    }
    return null;
  }

  SearchListing? get _mapListing {
    final listing = widget.listing;
    final point = _point;
    if (listing == null || point == null) return null;
    return listing.withCoordinates(point.latitude, point.longitude);
  }

  @override
  void initState() {
    super.initState();
    final stored = _storedPoint;
    if (stored != null) {
      _point = stored;
      if (_searchStyle) {
        _selectedId = widget.listing!.id;
      }
    } else {
      _resolving = true;
      _geocodeAddress();
    }
    if (!_searchStyle) {
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
        if (_searchStyle) {
          _selectedId = widget.listing!.id;
        }
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

  void _toggleFavorite(String id) {
    setState(() {
      if (!_favorites.remove(id)) _favorites.add(id);
    });
  }

  void _openListing(SearchListing listing) {
    ListingDetailScreen.open(
      context,
      listing: listing,
      favorites: _favorites,
      onFavorite: _toggleFavorite,
    );
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
    if (_searchStyle) {
      return _searchMapBody();
    }
    return ColoredBox(
      color: _mapFill,
      child: _AddressMap(point: point, style: _style),
    );
  }

  Widget _searchMapBody() {
    final listing = _mapListing!;
    final selected = _selectedId == listing.id ? listing : null;
    return SearchMapView(
      listings: [listing],
      selectedId: _selectedId,
      onSelectPin: (id) {
        setState(() => _selectedId = id);
      },
      preview: selected == null
          ? null
          : SearchApartmentCard(
              listing: selected,
              favorite: _favorites.contains(selected.id),
              meta: _meta,
              priceMuted: _priceMuted,
              compact: true,
              onOpen: () => _openListing(selected),
              onFavorite: () => _toggleFavorite(selected.id),
              onClose: () {
                setState(() => _selectedId = null);
              },
            ),
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
