import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

import 'package:booking/data/booking.dart';
import 'package:booking/data/listings_repository.dart';
import 'package:booking/data/reviews_repository.dart';
import 'package:booking/screens/search/search_listing.dart';

RecordModel _listingWithHost(Map<String, dynamic> host) {
  return RecordModel.fromJson({
    'id': 'studio-msk',
    'collectionId': 'listings',
    'collectionName': 'listings',
    'rating': 4.5,
    'reviews_count': 13,
    'expand': {'host': host},
  });
}

ListingHost _mapHost(RecordModel listing) {
  final expanded = expandedListingHost(listing);
  expect(expanded, isNotNull);
  return listingHostFromExpanded(
    expanded!,
    listingRating: 4.5,
    listingReviews: 13,
  );
}

SearchListing _mapListing({
  List<ListingReview>? liveReviews,
  double rating = 4.5,
  int reviewsCount = 13,
}) {
  return PocketBaseListingsRepository().mapListingRecord(
    RecordModel.fromJson({
      'id': 'studio-msk',
      'collectionId': 'listings',
      'collectionName': 'listings',
      'rating': rating,
      'reviews_count': reviewsCount,
      'price_night': 3034,
    }),
    liveReviews: liveReviews,
  );
}

void main() {
  test(
    'maps verified_host, years_hosting and host rating from expanded user',
    () {
      final host = _mapHost(
        _listingWithHost({
          'id': 'anna',
          'collectionId': 'users',
          'collectionName': 'users',
          'verified': true,
          'verified_host': true,
          'years_hosting': 4,
          'first_name': 'Анна',
          'last_name': 'Иваненко',
          'rating': 4.9,
          'reviews_count': 68,
        }),
      );

      expect(host.name, 'Анна Иваненко');
      expect(host.verified, isTrue);
      expect(host.years, 4);
      expect(host.rating, '4.9');
      expect(host.reviewCount, 68);
    },
  );

  test('does not treat email OTP verified as the host badge', () {
    final host = _mapHost(
      _listingWithHost({
        'id': 'guest-host',
        'verified': true,
        'first_name': 'Анна',
        'last_name': 'Иваненко',
      }),
    );

    expect(host.verified, isFalse);
    expect(host.years, 0);
    expect(host.rating, '4.5');
    expect(host.reviewCount, 13);
  });

  test(
    'reads verified_host from record.data when get default would miss it',
    () {
      final expanded = RecordModel({
        'id': 'anna',
        'verified_host': true,
        'years_hosting': 4,
      });

      expect(listingHostVerified(expanded), isTrue);
      expect(
        listingHostFromExpanded(
          expanded,
          listingRating: 0,
          listingReviews: 0,
        ).years,
        4,
      );
    },
  );

  test('falls back to listing denorm when host rating fields are missing', () {
    final host = _mapHost(
      _listingWithHost({
        'id': 'anna',
        'verified_host': false,
        'first_name': 'Анна',
        'name': 'Анна Иваненко',
      }),
    );

    expect(host.rating, '4.5');
    expect(host.reviewCount, 13);
    expect(host.verified, isFalse);
  });

  test('maps denorm reviews_count when no live reviews are attached', () {
    final listing = _mapListing();

    expect(listing.rating, '4.5');
    expect(listing.reviews, '(13 отзывов)');
    expect(listing.reviewCount, 13);
    expect(listing.reviewsList, isEmpty);
    expect(listingReviewTotals(denormRating: 4.5, denormCount: 13).count, 13);
  });

  test('prefers live reviews over hardcoded denorm count 13', () {
    const live = [
      ListingReview(
        author: 'Антон Киривлянов',
        postedAgo: '3 дня назад',
        stars: 5,
        text: 'Отлично',
      ),
      ListingReview(
        author: 'Мария',
        postedAgo: 'неделю назад',
        stars: 4,
        text: 'Хорошо',
      ),
    ];
    final listing = _mapListing(liveReviews: live);

    expect(listing.reviewCount, isNot(13));
    expect(listing.reviews, '(2 отзыва)');
    expect(listing.rating, '4.5');
    expect(listing.reviewsList, hasLength(2));
    expect(listing.reviewsList.first.author, 'Антон Киривлянов');

    final totals = listingReviewTotals(
      denormRating: 4.5,
      denormCount: 13,
      liveReviews: const [
        ListingReview(
          author: 'A',
          postedAgo: 'день назад',
          stars: 5,
          text: 'ok',
        ),
        ListingReview(
          author: 'B',
          postedAgo: 'день назад',
          stars: 5,
          text: 'ok',
        ),
      ],
    );
    expect(totals.count, 2);
    expect(totals.rating, 5);
    expect(totals.rating.toStringAsFixed(1), isNot('4.5'));
  });

  test('maps listing review author, stars and relative postedAgo', () {
    final review = listingReviewFromRecord(
      RecordModel.fromJson({
        'id': 'r1',
        'collectionId': 'reviews',
        'collectionName': 'reviews',
        'listing': 'studio-msk',
        'kind': 'listing',
        'rating': 5,
        'comment': 'Отлично',
        'created': '2026-09-15 12:00:00.000Z',
        'expand': {
          'author': {
            'id': 'u1',
            'collectionId': 'users',
            'collectionName': 'users',
            'first_name': 'Антон',
            'last_name': 'Киривлянов',
          },
        },
      }),
      now: DateTime.utc(2026, 9, 18, 12),
    );

    expect(review.author, 'Антон Киривлянов');
    expect(review.postedAgo, '3 дня назад');
    expect(review.stars, 5);
    expect(review.text, 'Отлично');
  });

  test('stayRangeOverlaps matches occupying booking formula', () {
    final occupiedStart = DateTime(2026, 10, 1);
    final occupiedEnd = DateTime(2026, 10, 10);

    expect(
      stayRangeOverlaps(
        occupiedStart: occupiedStart,
        occupiedEnd: occupiedEnd,
        requestedCheckIn: DateTime(2026, 10, 3),
        requestedCheckOut: DateTime(2026, 10, 6),
      ),
      isTrue,
    );
    expect(
      stayRangeOverlaps(
        occupiedStart: occupiedStart,
        occupiedEnd: occupiedEnd,
        requestedCheckIn: DateTime(2026, 10, 10),
        requestedCheckOut: DateTime(2026, 10, 12),
      ),
      isFalse,
    );
    expect(
      stayRangeOverlaps(
        occupiedStart: occupiedStart,
        occupiedEnd: occupiedEnd,
        requestedCheckIn: DateTime(2026, 9, 20),
        requestedCheckOut: DateTime(2026, 10, 1),
      ),
      isFalse,
    );
  });

  test('publishedListingsFilter binds excluded ids through pbFilter', () {
    expect(publishedListingsFilter(), 'status = "published"');
    expect(
      publishedListingsFilter(['studio-msk', "x' || id != '"]),
      "status = \"published\" && id != 'studio-msk' && "
      r"id != 'x\' || id != \''",
    );
  });

  test('stayDaySelectable disables occupying nights but keeps checkout morning', () {
    final occupied = [
      OccupiedStayRange(
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 10),
      ),
    ];

    expect(
      stayDaySelectable(
        day: DateTime(2026, 10, 3),
        checkOut: false,
        ranges: occupied,
      ),
      isFalse,
    );
    expect(
      stayDaySelectable(
        day: DateTime(2026, 10, 15),
        checkOut: false,
        ranges: occupied,
      ),
      isTrue,
    );
    expect(
      stayDaySelectable(
        day: DateTime(2026, 10, 1),
        checkOut: true,
        ranges: occupied,
      ),
      isTrue,
    );
    expect(
      stayDaySelectable(
        day: DateTime(2026, 10, 3),
        checkOut: true,
        ranges: occupied,
      ),
      isFalse,
    );
    expect(
      stayDaySelectable(
        day: DateTime(2026, 10, 10),
        checkOut: false,
        ranges: occupied,
      ),
      isTrue,
    );
    expect(
      stayConflictsWithOccupied(
        checkIn: DateTime(2026, 10, 3),
        checkOut: DateTime(2026, 10, 6),
        ranges: occupied,
      ),
      isTrue,
    );
    expect(
      stayConflictsWithOccupied(
        checkIn: DateTime(2026, 9, 20),
        checkOut: DateTime(2026, 10, 1),
        ranges: occupied,
      ),
      isFalse,
    );
  });

  test('parseOccupiedListingIds reads hook payload only', () {
    expect(parseOccupiedListingIds(null), isEmpty);
    expect(
      parseOccupiedListingIds({
        'listingIds': ['studio-msk', ' kazan-loft ', ''],
      }),
      ['studio-msk', 'kazan-loft'],
    );
  });

  test('fetchPublished without dates does not call occupied hook', () async {
    var occupiedCalls = 0;
    final client = PocketBase(
      'http://pb.test',
      httpClientFactory: () => MockClient((request) async {
        if (request.url.path.contains('occupied-listings')) {
          occupiedCalls++;
          return _jsonOk({'listingIds': ['studio-msk']});
        }
        if (request.url.path.contains('/api/collections/listings/records')) {
          expect(request.url.queryParameters['filter'], 'status = "published"');
          return _jsonOk(_listingsPayload(['kazan-loft']));
        }
        return _jsonOk({'items': []});
      }),
    );

    final listings = await PocketBaseListingsRepository(
      client: client,
      reviews: _EmptyReviews(),
    ).fetchPublished();

    expect(occupiedCalls, 0);
    expect(listings.map((item) => item.id), ['kazan-loft']);
  });

  test('fetchPublished with stay dates excludes occupied listing ids', () async {
    final client = PocketBase(
      'http://pb.test',
      httpClientFactory: () => MockClient((request) async {
        if (request.url.path.contains('occupied-listings')) {
          expect(request.url.queryParameters['checkIn'], isNotEmpty);
          expect(request.url.queryParameters['checkOut'], isNotEmpty);
          return _jsonOk({
            'listingIds': ['studio-msk'],
          });
        }
        if (request.url.path.contains('/api/collections/listings/records')) {
          expect(
            request.url.queryParameters['filter'],
            "status = \"published\" && id != 'studio-msk'",
          );
          return _jsonOk(_listingsPayload(['kazan-loft']));
        }
        return _jsonOk({'items': []});
      }),
    );

    final listings = await PocketBaseListingsRepository(
      client: client,
      reviews: _EmptyReviews(),
    ).fetchPublished(
      checkIn: DateTime(2026, 10, 1),
      checkOut: DateTime(2026, 10, 5),
    );

    expect(listings.map((item) => item.id), ['kazan-loft']);
  });

  test('parseOccupiedStayRanges reads only start/end', () {
    expect(parseOccupiedStayRanges(null), isEmpty);
    final ranges = parseOccupiedStayRanges({
      'ranges': [
        {'start': '2026-10-01', 'end': '2026-10-10'},
        {'start': '2026-10-20', 'guest': 'secret@mail.com'},
      ],
    });
    expect(ranges, hasLength(1));
    expect(ranges.single.start, DateTime(2026, 10, 1));
    expect(ranges.single.end, DateTime(2026, 10, 10));
  });

  test('fetchOccupiedDates binds listing and excludeBookingId', () async {
    final client = PocketBase(
      'http://pb.test',
      httpClientFactory: () => MockClient((request) async {
        expect(request.url.path.contains('occupied-dates'), isTrue);
        expect(request.url.queryParameters['listing'], 'studio-msk');
        expect(request.url.queryParameters['excludeBookingId'], 'booking-1');
        return _jsonOk({
          'ranges': [
            {'start': '2026-10-01', 'end': '2026-10-10'},
          ],
        });
      }),
    );

    final ranges = await PocketBaseListingsRepository(
      client: client,
    ).fetchOccupiedDates(
      listingId: 'studio-msk',
      excludeBookingId: 'booking-1',
    );

    expect(ranges, hasLength(1));
    expect(ranges.single.start, DateTime(2026, 10, 1));
    expect(ranges.single.end, DateTime(2026, 10, 10));
  });
}

class _EmptyReviews implements ReviewsRepository {
  @override
  Future<StayReview?> fetchForBooking(String bookingId) async => null;

  @override
  Future<bool> hasGuestListingReview(String bookingId) async => false;

  @override
  Future<List<ListingReview>> fetchForListing(String listingId) async =>
      const [];

  @override
  Future<Map<String, List<ListingReview>>> fetchForListings(
    Iterable<String> listingIds,
  ) async =>
      {};

  @override
  Future<StayReview> create({
    required Booking booking,
    required int rating,
    String comment = '',
  }) {
    throw UnimplementedError();
  }
}

http.Response _jsonOk(Object body) {
  return http.Response.bytes(
    utf8.encode(body is String ? body : jsonEncode(body)),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

Map<String, Object?> _listingsPayload(List<String> ids) {
  return {
    'page': 1,
    'perPage': 500,
    'totalItems': ids.length,
    'totalPages': 1,
    'items': [
      for (final id in ids)
        {
          'id': id,
          'collectionId': 'listings',
          'collectionName': 'listings',
          'title': id,
          'city': 'Kazan',
          'status': 'published',
          'price_night': 3100,
        },
    ],
  };
}
