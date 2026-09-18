import 'package:pocketbase/pocketbase.dart';

import '../screens/listing/listing_detail.dart';
import '../screens/search/search_listing.dart';
import 'pocketbase_client.dart';
import 'pocketbase_filter.dart';

abstract class ListingsRepository {
  Future<List<SearchListing>> fetchPublished();

  Future<ListingDetail> fetchDetail(SearchListing listing);
}

class ListingsRepositoryScope {
  static ListingsRepository instance = PocketBaseListingsRepository();
}

class PocketBaseListingsRepository implements ListingsRepository {
  PocketBaseListingsRepository({this._client});

  final PocketBase? _client;
  PocketBase get _pb => _client ?? pocketBase;

  static const _expand = 'host';
  static const _published = 'status = "published"';

  @override
  Future<List<SearchListing>> fetchPublished() async {
    final records = await _pb.collection(PbCollection.listings).getFullList(
      filter: _published,
      expand: _expand,
      sort: '-created',
    );
    return [for (final record in records) _mapListing(record)];
  }

  @override
  Future<ListingDetail> fetchDetail(SearchListing listing) async {
    RecordModel record;
    try {
      record = await _pb.collection(PbCollection.listings).getOne(
        listing.id,
        expand: _expand,
      );
    } catch (_) {
      return ListingDetail.fromListing(
        listing,
        hostListings: await _hostListings(listing.hostId, listing.id),
      );
    }

    final mapped = _mapListing(record);
    return ListingDetail.fromListing(
      mapped,
      hostListings: await _hostListings(mapped.hostId, mapped.id),
    );
  }

  Future<List<SearchListing>> _hostListings(String hostId, String exceptId) async {
    if (hostId.isEmpty) return const [];
    final records = await _pb.collection(PbCollection.listings).getFullList(
      filter: pbFilter(
        '$_published && host = {:hostId} && id != {:exceptId}',
        {'hostId': hostId, 'exceptId': exceptId},
      ),
      expand: _expand,
      sort: '-created',
    );
    return [for (final record in records) _mapListing(record)];
  }

  SearchListing _mapListing(RecordModel record) {
    final photos = _fileUrls(record, 'photos');
    final amenities = _stringList(record, 'amenities');
    final extras = _stringList(record, 'extras');
    final features = {...amenities, ...extras};
    final ratingValue = _number(record, 'rating');
    final reviewsCount = _number(record, 'reviews_count').round();
    final priceNight = _number(record, 'price_night').round();
    final host = _mapHost(
      record,
      listingRating: ratingValue,
      listingReviews: reviewsCount,
    );
    final geo = _geo(record);

    return SearchListing(
      id: record.id,
      title: record.get<String>('title', ''),
      city: record.get<String>('city', ''),
      type: record.get<String>('housing_type', ''),
      address: record.get<String>('address', ''),
      description: stripHtml(record.get<String>('description', '')),
      dates: '',
      nights: '',
      total: formatRub(priceNight),
      perNight: '${formatRub(priceNight)} / ночь',
      rating: ratingValue > 0 ? ratingValue.toStringAsFixed(1) : '—',
      reviews: reviewCountLabel(reviewsCount),
      photo: photos.isEmpty ? '' : photos.first,
      photos: photos,
      imageIndex: 0,
      latitude: geo.$1,
      longitude: geo.$2,
      pricePerNight: priceNight,
      price14: _number(record, 'price_14').round(),
      price28: _number(record, 'price_28').round(),
      maxGuests: _number(record, 'max_guests').round(),
      petsAllowed: record.get<bool>('pets_allowed', false),
      hostId: _hostId(record),
      host: host,
      features: features,
      amenities: amenities,
      houseRules: stripHtml(record.get<String>('house_rules', '')),
      checkInTime: record.get<String>('check_in_time', ''),
      checkOutTime: record.get<String>('check_out_time', ''),
      accessInfo: stripHtml(record.get<String>('access_info', '')),
      cancellationAllowed: record.get<bool>('cancellation_allowed', false),
    ).withStay();
  }

  ListingHost? _mapHost(
    RecordModel record, {
    required double listingRating,
    required int listingReviews,
  }) {
    final expanded = expandedListingHost(record);
    if (expanded == null) return null;
    final avatarName = expanded.get<String>('avatar', '');
    final avatarUrl = avatarName.isEmpty
        ? ''
        : _pb.files.getURL(expanded, avatarName).toString();
    return listingHostFromExpanded(
      expanded,
      listingRating: listingRating,
      listingReviews: listingReviews,
      avatarUrl: avatarUrl,
    );
  }

  String _hostId(RecordModel record) {
    final expanded = expandedListingHost(record);
    if (expanded != null) return expanded.id;
    return record.get<String>('host', '');
  }

  List<String> _fileUrls(RecordModel record, String field) {
    final names = _stringList(record, field);
    return [
      for (final name in names)
        if (name.isNotEmpty) _pb.files.getURL(record, name).toString(),
    ];
  }

  List<String> _stringList(RecordModel record, String field) {
    final raw = record.data[field];
    if (raw is List) {
      return [
        for (final item in raw)
          if (item != null && '$item'.isNotEmpty) '$item',
      ];
    }
    if (raw is String && raw.isNotEmpty) return [raw];
    return const [];
  }

  double _number(RecordModel record, String field) {
    final raw = record.data[field];
    if (raw is num) return raw.toDouble();
    return double.tryParse('$raw') ?? 0;
  }

  (double, double) _geo(RecordModel record) {
    final raw = record.data['geo'];
    if (raw is Map) {
      final lat = raw['lat'] ?? raw['latitude'];
      final lon = raw['lon'] ?? raw['lng'] ?? raw['longitude'];
      return (
        lat is num ? lat.toDouble() : double.tryParse('$lat') ?? 0,
        lon is num ? lon.toDouble() : double.tryParse('$lon') ?? 0,
      );
    }
    return (0, 0);
  }
}

/// Expanded `listings.host` → `users` record, or null if the expand is missing.
RecordModel? expandedListingHost(RecordModel listing) {
  final raw = listing.data['expand'];
  if (raw is Map) {
    final parsed = _recordFromExpandValue(raw['host']);
    if (parsed != null) return parsed;
  }
  final fromSdk = listing.expand['host'];
  if (fromSdk != null && fromSdk.isNotEmpty) return fromSdk.first;
  return null;
}

/// Host card from an expanded `users` record.
///
/// `verified` is domain `verified_host` (host badge), never auth email OTP
/// `verified`. Rating/reviews prefer `users.rating` / `users.reviews_count`,
/// otherwise the listing denorm.
ListingHost listingHostFromExpanded(
  RecordModel host, {
  required double listingRating,
  required int listingReviews,
  String avatarUrl = '',
}) {
  final hostRating = _recordNumber(host, 'rating');
  final hostReviews = _recordNumber(host, 'reviews_count').round();
  final ratingValue = hostRating > 0 ? hostRating : listingRating;
  final reviewCount = hostReviews > 0 ? hostReviews : listingReviews;
  return ListingHost(
    id: host.id,
    name: listingHostDisplayName(
      firstName: host.get<String>('first_name', ''),
      lastName: host.get<String>('last_name', ''),
      name: host.get<String>('name', ''),
    ),
    rating: ratingValue > 0 ? ratingValue.toStringAsFixed(1) : '—',
    reviewCount: reviewCount,
    years: _recordNumber(host, 'years_hosting').round(),
    verified: listingHostVerified(host),
    avatarUrl: avatarUrl,
  );
}

/// `users.verified_host`. Does not fall back to system email `verified`.
bool listingHostVerified(RecordModel host) {
  if (host.data.containsKey('verified_host')) {
    return _recordBoolValue(host.data['verified_host']);
  }
  return host.get<bool>('verified_host', false);
}

RecordModel? _recordFromExpandValue(dynamic value) {
  if (value is RecordModel) return value;
  if (value is Map<String, dynamic>) return RecordModel.fromJson(value);
  if (value is Map) {
    return RecordModel.fromJson(Map<String, dynamic>.from(value));
  }
  if (value is List && value.isNotEmpty) {
    return _recordFromExpandValue(value.first);
  }
  return null;
}

double _recordNumber(RecordModel record, String field) {
  final raw = record.data.containsKey(field)
      ? record.data[field]
      : record.get<dynamic>(field);
  if (raw is num) return raw.toDouble();
  if (raw == null) return 0;
  return double.tryParse('$raw') ?? 0;
}

bool _recordBoolValue(dynamic raw) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  if (raw is String) {
    final value = raw.toLowerCase();
    return value == 'true' || value == '1';
  }
  return false;
}

String stripHtml(String html) {
  return html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
