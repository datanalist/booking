import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocketbase/pocketbase.dart';

import 'package:booking/data/booking.dart';
import 'package:booking/data/favorites_repository.dart';
import 'package:booking/data/reviews_repository.dart';
import 'package:booking/screens/search/search_listing.dart';

void main() {
  test('fetchMine without a session does not call PocketBase', () async {
    var calls = 0;
    final client = PocketBase(
      'http://pb.test',
      httpClientFactory: () => MockClient((request) async {
        calls++;
        return _jsonOk({'items': []});
      }),
    );

    final items = await PocketBaseFavoritesRepository(
      client: client,
    ).fetchMine();

    expect(items, isEmpty);
    expect(calls, 0);
  });

  test('fetchMine maps expanded listing and filters by the signed-in user', () async {
    final client = _signedInClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, contains('/api/collections/favorites/records'));
      expect(request.url.queryParameters['filter'], contains("'user-1'"));
      expect(request.url.queryParameters['expand'], 'listing.host');
      return _jsonOk({
        'page': 1,
        'perPage': 500,
        'totalItems': 1,
        'totalPages': 1,
        'items': [
          {
            'id': 'fav-1',
            'collectionId': 'favorites',
            'collectionName': 'favorites',
            'user': 'user-1',
            'listing': 'studio-msk',
            'expand': {
              'listing': {
                'id': 'studio-msk',
                'collectionId': 'listings',
                'collectionName': 'listings',
                'title': 'Уютная студия в центре Москвы',
                'city': 'Москва',
                'housing_type': 'Квартира',
                'price_night': 3034,
                'rating': 4.5,
                'reviews_count': 13,
                'status': 'published',
              },
            },
          },
        ],
      });
    });

    final items = await PocketBaseFavoritesRepository(
      client: client,
      reviews: _EmptyReviews(),
    ).fetchMine();

    expect(items, hasLength(1));
    expect(items.single.id, 'studio-msk');
    expect(items.single.title, 'Уютная студия в центре Москвы');
    expect(items.single.city, 'Москва');
    expect(items.single.pricePerNight, 3034);
  });

  test('add posts user and listing, duplicate pair is success', () async {
    var creates = 0;
    final client = _signedInClient((request) async {
      expect(request.method, 'POST');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['user'], 'user-1');
      expect(body['listing'], 'studio-msk');
      creates++;
      if (creates == 1) {
        return _jsonOk({
          'id': 'fav-1',
          'collectionId': 'favorites',
          'collectionName': 'favorites',
          'user': 'user-1',
          'listing': 'studio-msk',
        });
      }
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'message': 'Failed to create record.',
            'data': {
              'listing': {
                'code': 'validation_not_unique',
                'message': 'Value must be unique.',
              },
            },
          }),
        ),
        400,
        headers: const {'content-type': 'application/json'},
      );
    });
    final repository = PocketBaseFavoritesRepository(
      client: client,
      reviews: _EmptyReviews(),
    );

    await repository.add('studio-msk');
    await repository.add(' studio-msk ');

    expect(creates, 2);
  });

  test('remove deletes only the signed-in pair', () async {
    final deleted = <String>[];
    final client = _signedInClient((request) async {
      if (request.method == 'GET') {
        expect(
          request.url.queryParameters['filter'],
          "user = 'user-1' && listing = 'studio-msk'",
        );
        return _jsonOk({
          'page': 1,
          'perPage': 500,
          'totalItems': 1,
          'totalPages': 1,
          'items': [
            {
              'id': 'fav-1',
              'collectionId': 'favorites',
              'collectionName': 'favorites',
              'user': 'user-1',
              'listing': 'studio-msk',
            },
          ],
        });
      }
      expect(request.method, 'DELETE');
      deleted.add(request.url.path);
      return _jsonOk({});
    });

    await PocketBaseFavoritesRepository(client: client).remove('studio-msk');

    expect(deleted, ['/api/collections/favorites/records/fav-1']);
  });
}

PocketBase _signedInClient(MockClientHandler handler) {
  final client = PocketBase(
    'http://pb.test',
    httpClientFactory: () => MockClient(handler),
  );
  client.authStore.save(_token(), RecordModel.fromJson({
    'id': 'user-1',
    'collectionId': 'users',
    'collectionName': 'users',
    'email': 'guest@example.com',
  }));
  return client;
}

String _token() {
  String part(String raw) =>
      base64Url.encode(utf8.encode(raw)).replaceAll('=', '');
  final header = part('{"alg":"HS256","typ":"JWT"}');
  final payload = part('{"id":"user-1","exp":9999999999}');
  return '$header.$payload.sig';
}

http.Response _jsonOk(Object body) {
  return http.Response.bytes(
    utf8.encode(body is String ? body : jsonEncode(body)),
    200,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
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
