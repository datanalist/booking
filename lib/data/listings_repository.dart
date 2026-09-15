import 'package:pocketbase/pocketbase.dart';

import '../screens/listing/listing_detail.dart';
import '../screens/search/search_listing.dart';
import 'pocketbase_client.dart';

abstract class ListingsRepository {
  Future<List<SearchListing>> fetchPublished();

  Future<ListingDetail> fetchDetail(SearchListing listing);
}

class ListingsRepositoryScope {
  static ListingsRepository instance = PocketBaseListingsRepository();
}

class PocketBaseListingsRepository implements ListingsRepository {
  PocketBaseListingsRepository({PocketBase? client}) : _pb = client ?? pocketBase;

  final PocketBase _pb;

  static const _expand = 'host';
  static const _published = 'status = "published"';

  @override
  Future<List<SearchListing>> fetchPublished() async {
    final records = await _pb.collection('listings').getFullList(
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
      record = await _pb.collection('listings').getOne(
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
    final escaped = hostId.replaceAll('"', '');
    final records = await _pb.collection('listings').getFullList(
      filter:
          '$_published && host = "$escaped" && id != "${exceptId.replaceAll('"', '')}"',
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
    final host = _mapHost(record, ratingValue, reviewsCount);
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
    ).withStay();
  }

  ListingHost? _mapHost(RecordModel record, double listingRating, int reviews) {
    final expanded = _expandedHost(record);
    if (expanded == null) return null;
    final name = expanded.get<String>('name', '');
    final avatarName = expanded.get<String>('avatar', '');
    final avatarUrl = avatarName.isEmpty
        ? ''
        : _pb.files.getURL(expanded, avatarName).toString();
    return ListingHost(
      id: expanded.id,
      name: name.isEmpty ? 'Хозяин' : name,
      rating: listingRating > 0 ? listingRating.toStringAsFixed(1) : '—',
      reviewCount: reviews,
      years: 0,
      avatarUrl: avatarUrl,
    );
  }

  String _hostId(RecordModel record) {
    final expanded = _expandedHost(record);
    if (expanded != null) return expanded.id;
    return record.get<String>('host', '');
  }

  RecordModel? _expandedHost(RecordModel record) {
    final raw = record.data['expand'];
    if (raw is! Map) return null;
    final host = raw['host'];
    if (host is Map<String, dynamic>) {
      return RecordModel.fromJson(host);
    }
    if (host is Map) {
      return RecordModel.fromJson(Map<String, dynamic>.from(host));
    }
    return null;
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
