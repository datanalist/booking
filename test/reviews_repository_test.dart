import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

import 'package:booking/data/reviews_repository.dart';

const _oldTown = '69onllm2f561ly3';
const _countryHouse = 'zge5vq7hppy8pd8';

Map<String, Object> _review(String id, String listingId, String comment) {
  return {
    'id': id,
    'collectionId': 'reviews',
    'collectionName': 'reviews',
    'listing': listingId,
    'kind': 'listing',
    'rating': 5,
    'comment': comment,
    'created': '2026-09-18 02:13:26.187Z',
  };
}

final _stored = [
  _review('r1', _oldTown, 'Почти супер'),
  _review('r2', _countryHouse, 'Отличное жильё'),
];

/// PocketBase `~` is SQL LIKE, not regex: `listing ~ 'a|b'` matches nothing.
bool _matches(String filter, String listingId) {
  if (filter.contains('~')) return filter.contains("'$listingId'");
  return filter.contains("listing = '$listingId'");
}

PocketBase _client(List<String> filters) {
  return PocketBase(
    'http://pb.test',
    httpClientFactory: () => MockClient((request) async {
      final filter = request.url.queryParameters['filter'] ?? '';
      filters.add(filter);
      final items = [
        for (final item in _stored)
          if (_matches(filter, '${item['listing']}')) item,
      ];
      return http.Response(
        jsonEncode({
          'page': 1,
          'perPage': 500,
          'totalItems': items.length,
          'totalPages': 1,
          'items': items,
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
}

void main() {
  test('fetchForListings returns text reviews for every host listing', () async {
    final filters = <String>[];
    final repository = PocketBaseReviewsRepository(client: _client(filters));

    final byListing = await repository.fetchForListings([
      _oldTown,
      _countryHouse,
    ]);

    expect(filters.single, contains("listing = '$_oldTown'"));
    expect(filters.single, contains("listing = '$_countryHouse'"));
    expect(filters.single, isNot(contains('~')));
    expect(byListing[_oldTown]!.single.text, 'Почти супер');
    expect(byListing[_countryHouse]!.single.text, 'Отличное жильё');
  });
}
