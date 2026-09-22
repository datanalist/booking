import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

import '../screens/listing/listing_detail.dart';
import '../screens/search/search_listing.dart';
import 'pocketbase_client.dart';
import 'pocketbase_filter.dart';
import 'reviews_repository.dart';

abstract class ListingsRepository {
  Future<List<SearchListing>> fetchPublished({
    DateTime? checkIn,
    DateTime? checkOut,
  });

  Future<ListingDetail> fetchDetail(SearchListing listing);

  Future<List<OccupiedStayRange>> fetchOccupiedDates({
    required String listingId,
    String? excludeBookingId,
  });
}

class ListingsRepositoryScope {
  static ListingsRepository instance = PocketBaseListingsRepository();
}

class PocketBaseListingsRepository implements ListingsRepository {
  PocketBaseListingsRepository({PocketBase? client, ReviewsRepository? reviews})
    : _client = client,
      _reviewsOverride = reviews;

  final PocketBase? _client;
  final ReviewsRepository? _reviewsOverride;
  PocketBase get _pb => _client ?? pocketBase;

  ReviewsRepository get _reviews =>
      _reviewsOverride ?? PocketBaseReviewsRepository(client: _pb);

  static const _expand = 'host';
  static const _published = 'status = "published"';
  static const occupiedListingsPath = '/api/vallome/occupied-listings';
  static const occupiedDatesPath = '/api/vallome/occupied-dates';

  @override
  Future<List<SearchListing>> fetchPublished({
    DateTime? checkIn,
    DateTime? checkOut,
  }) async {
    final excludeIds = checkIn != null &&
            checkOut != null &&
            checkOut.isAfter(checkIn)
        ? await _occupiedListingIds(checkIn, checkOut)
        : const <String>[];
    final records = await _pb
        .collection(PbCollection.listings)
        .getFullList(
          filter: publishedListingsFilter(excludeIds),
          expand: _expand,
          sort: '-created',
        );
    final mapped = await _mapRecords(records);
    if (excludeIds.isEmpty) return mapped;
    final blocked = excludeIds.toSet();
    return [for (final item in mapped) if (!blocked.contains(item.id)) item];
  }

  Future<List<String>> _occupiedListingIds(
    DateTime checkIn,
    DateTime checkOut,
  ) async {
    try {
      final raw = await _pb.send(
        occupiedListingsPath,
        query: {
          'checkIn': stayDateValue(checkIn),
          'checkOut': stayDateValue(checkOut),
        },
      );
      return parseOccupiedListingIds(raw);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<OccupiedStayRange>> fetchOccupiedDates({
    required String listingId,
    String? excludeBookingId,
  }) async {
    final id = listingId.trim();
    if (id.isEmpty) return const [];
    try {
      final query = <String, dynamic>{'listing': id};
      final exclude = excludeBookingId?.trim() ?? '';
      if (exclude.isNotEmpty) query['excludeBookingId'] = exclude;
      return parseOccupiedStayRanges(
        await _pb.send(occupiedDatesPath, query: query),
      );
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<ListingDetail> fetchDetail(SearchListing listing) async {
    RecordModel? record;
    try {
      record = await _pb
          .collection(PbCollection.listings)
          .getOne(listing.id, expand: _expand);
    } catch (_) {
      record = null;
    }

    final hostId = record == null ? listing.hostId : _hostId(record);
    final listingId = record?.id ?? listing.id;
    final hostRecords = await _hostListingRecords(hostId, listingId);
    final live = await _liveReviewsByIds([
      listingId,
      for (final item in hostRecords) item.id,
    ]);
    final mapped = record == null
        ? overlayListingReviews(listing, live?[listingId])
        : _mapListing(record, liveReviews: live?[listingId]);
    return ListingDetail.fromListing(
      mapped,
      reviews: live?[listingId] ?? mapped.reviewsList,
      hostListings: [
        for (final item in hostRecords)
          _mapListing(item, liveReviews: live?[item.id]),
      ],
    );
  }

  Future<List<RecordModel>> _hostListingRecords(
    String hostId,
    String exceptId,
  ) async {
    if (hostId.isEmpty) return const [];
    return _pb
        .collection(PbCollection.listings)
        .getFullList(
          filter: pbFilter(
            '$_published && host = {:hostId} && id != {:exceptId}',
            {'hostId': hostId, 'exceptId': exceptId},
          ),
          expand: _expand,
          sort: '-created',
        );
  }

  Future<List<SearchListing>> _mapRecords(List<RecordModel> records) async {
    final live = await _liveReviewsByIds([
      for (final record in records) record.id,
    ]);
    return [
      for (final record in records)
        _mapListing(record, liveReviews: live?[record.id]),
    ];
  }

  Future<Map<String, List<ListingReview>>?> _liveReviewsByIds(
    Iterable<String> listingIds,
  ) async {
    try {
      return await _reviews.fetchForListings(listingIds);
    } catch (_) {
      return null;
    }
  }

  /// Карточка из записи `listings`, в том числе из `favorites.expand`.
  SearchListing mapListingRecord(
    RecordModel record, {
    List<ListingReview>? liveReviews,
  }) {
    return _mapListing(record, liveReviews: liveReviews);
  }

  SearchListing _mapListing(
    RecordModel record, {
    List<ListingReview>? liveReviews,
  }) {
    final photos = _fileUrls(record, 'photos');
    final amenities = _stringList(record, 'amenities');
    final extras = _stringList(record, 'extras');
    final features = {...amenities, ...extras};
    final totals = listingReviewTotals(
      denormRating: _number(record, 'rating'),
      denormCount: _number(record, 'reviews_count').round(),
      liveReviews: liveReviews,
    );
    final ratingValue = totals.rating;
    final reviewsCount = totals.count;
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
      reviewsList: totals.items,
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

/// Occupying stay from `/api/vallome/occupied-dates`. Half-open nights
/// `[start, end)` — checkout morning can be another guest's check-in.
@immutable
class OccupiedStayRange {
  const OccupiedStayRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

DateTime stayDay(DateTime value) => DateTime(value.year, value.month, value.day);

/// Overlap used by search hide and `pb_hooks/bookings_overlap.pb.js`:
/// `check_in < requestedCheckOut && check_out > requestedCheckIn`.
bool stayRangeOverlaps({
  required DateTime occupiedStart,
  required DateTime occupiedEnd,
  required DateTime requestedCheckIn,
  required DateTime requestedCheckOut,
}) {
  return occupiedStart.isBefore(requestedCheckOut) &&
      occupiedEnd.isAfter(requestedCheckIn);
}

/// Occupying night = `[start, end)`.
bool stayNightOccupied(DateTime day, Iterable<OccupiedStayRange> ranges) {
  final d = stayDay(day);
  for (final range in ranges) {
    final start = stayDay(range.start);
    final end = stayDay(range.end);
    if (!d.isBefore(start) && d.isBefore(end)) return true;
  }
  return false;
}

/// Check-out may still pick the start morning of an occupying stay.
bool stayDaySelectable({
  required DateTime day,
  required bool checkOut,
  required Iterable<OccupiedStayRange> ranges,
}) {
  if (!stayNightOccupied(day, ranges)) return true;
  if (!checkOut) return false;
  final d = stayDay(day);
  for (final range in ranges) {
    if (stayDay(range.start) == d) return true;
  }
  return false;
}

bool stayConflictsWithOccupied({
  required DateTime checkIn,
  required DateTime checkOut,
  required Iterable<OccupiedStayRange> ranges,
}) {
  final start = stayDay(checkIn);
  final end = stayDay(checkOut);
  for (final range in ranges) {
    if (stayRangeOverlaps(
      occupiedStart: stayDay(range.start),
      occupiedEnd: stayDay(range.end),
      requestedCheckIn: start,
      requestedCheckOut: end,
    )) {
      return true;
    }
  }
  return false;
}

/// UTC date-only value for the occupied-listings hook and booking filters.
String stayDateValue(DateTime date) {
  return DateTime.utc(date.year, date.month, date.day).toIso8601String();
}

/// `status = "published"` plus `id !=` exclusions bound through [pbFilter].
@visibleForTesting
String publishedListingsFilter([List<String> excludeIds = const []]) {
  if (excludeIds.isEmpty) return 'status = "published"';
  final params = <String, Object?>{};
  final parts = <String>['status = "published"'];
  for (var i = 0; i < excludeIds.length; i++) {
    final id = excludeIds[i].trim();
    if (id.isEmpty) continue;
    params['ex$i'] = id;
    parts.add('id != {:ex$i}');
  }
  if (params.isEmpty) return 'status = "published"';
  return pbFilter(parts.join(' && '), params);
}

@visibleForTesting
List<String> parseOccupiedListingIds(Object? raw) {
  if (raw is! Map) return const [];
  final ids = raw['listingIds'] ?? raw['listing_ids'];
  if (ids is! List) return const [];
  return [
    for (final item in ids)
      if ('$item'.trim().isNotEmpty) '$item'.trim(),
  ];
}

@visibleForTesting
List<OccupiedStayRange> parseOccupiedStayRanges(Object? raw) {
  if (raw is! Map) return const [];
  final items = raw['ranges'];
  if (items is! List) return const [];
  final ranges = <OccupiedStayRange>[];
  for (final item in items) {
    if (item is! Map) continue;
    final start = _parseStayDay(item['start']);
    final end = _parseStayDay(item['end']);
    if (start == null || end == null || !end.isAfter(start)) continue;
    ranges.add(OccupiedStayRange(start: start, end: end));
  }
  return ranges;
}

DateTime? _parseStayDay(Object? raw) {
  if (raw is DateTime) return stayDay(raw);
  if (raw is String && raw.trim().isNotEmpty) {
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return null;
    return stayDay(parsed);
  }
  return null;
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

/// Live `reviews` overlay for a listing card.
///
/// Null/empty [liveReviews] keeps denorm `listings.rating` / `reviews_count`.
({double rating, int count, List<ListingReview> items}) listingReviewTotals({
  required double denormRating,
  required int denormCount,
  List<ListingReview>? liveReviews,
}) {
  if (liveReviews == null || liveReviews.isEmpty) {
    return (rating: denormRating, count: denormCount, items: const []);
  }
  var sum = 0;
  for (final item in liveReviews) {
    sum += item.stars;
  }
  return (
    rating: sum / liveReviews.length,
    count: liveReviews.length,
    items: liveReviews,
  );
}

/// Applies live listing reviews onto an already mapped card (booking fallback).
SearchListing overlayListingReviews(
  SearchListing listing,
  List<ListingReview>? liveReviews,
) {
  final totals = listingReviewTotals(
    denormRating: double.tryParse(listing.rating) ?? 0,
    denormCount: listing.reviewCount,
    liveReviews: liveReviews,
  );
  if (liveReviews == null || liveReviews.isEmpty) return listing;
  return listing.withStay(
    checkIn: listing.checkIn,
    checkOut: listing.checkOut,
    rating: totals.rating > 0 ? totals.rating.toStringAsFixed(1) : '—',
    reviews: reviewCountLabel(totals.count),
    reviewsList: totals.items,
  );
}
