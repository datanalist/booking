import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

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
}
