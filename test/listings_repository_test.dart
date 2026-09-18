import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';

import 'package:booking/data/listings_repository.dart';
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

void main() {
  test('maps verified_host, years_hosting and host rating from expanded user', () {
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
  });

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

  test('reads verified_host from record.data when get default would miss it', () {
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
  });

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
}
