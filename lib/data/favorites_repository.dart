import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

import '../screens/search/search_listing.dart';
import 'auth_repository.dart';
import 'listings_repository.dart';
import 'pocketbase_client.dart';
import 'pocketbase_filter.dart';
import 'reviews_repository.dart';

abstract class FavoritesRepository {
  Future<List<SearchListing>> fetchMine();

  Future<void> add(String listingId);

  Future<void> remove(String listingId);
}

class FavoritesRepositoryScope {
  static FavoritesRepository instance = PocketBaseFavoritesRepository();
  static final listVersion = ValueNotifier<int>(0);

  static void notifyChanged() {
    listVersion.value++;
  }
}

class FavoriteException implements Exception {
  const FavoriteException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Сессия гостя уже в auth store. Без неё сердце остаётся локальным
/// (виджет-тесты поиска), запись в `favorites` не уходит.
bool get favoritesCanWrite {
  final session = AuthRepositoryScope.session.value;
  final fromSession = session?.userId ?? '';
  final userId = fromSession.isNotEmpty
      ? fromSession
      : pocketBase.authStore.record?.id ?? '';
  return userId.isNotEmpty && pocketBase.authStore.isValid;
}

/// Пишет пару user+listing. `false` — гость не вошёл, локальное сердце не трогаем.
Future<bool> writeFavorite({
  required FavoritesRepository repository,
  required String listingId,
  required bool removing,
}) async {
  if (!favoritesCanWrite) return false;
  if (removing) {
    await repository.remove(listingId);
  } else {
    await repository.add(listingId);
  }
  FavoritesRepositoryScope.notifyChanged();
  return true;
}

class PocketBaseFavoritesRepository implements FavoritesRepository {
  PocketBaseFavoritesRepository({
    PocketBase? client,
    ReviewsRepository? reviews,
    PocketBaseListingsRepository? listings,
  }) : _client = client,
       _reviewsOverride = reviews,
       _listingsOverride = listings;

  static const collection = PbCollection.favorites;
  static const _expand = 'listing.host';

  final PocketBase? _client;
  final ReviewsRepository? _reviewsOverride;
  final PocketBaseListingsRepository? _listingsOverride;

  PocketBase get _pb => _client ?? pocketBase;

  ReviewsRepository get _reviews =>
      _reviewsOverride ?? PocketBaseReviewsRepository(client: _pb);

  PocketBaseListingsRepository get _listings =>
      _listingsOverride ?? PocketBaseListingsRepository(client: _pb);

  String get _userId {
    final session = AuthRepositoryScope.session.value;
    if (session != null && session.userId.isNotEmpty) return session.userId;
    return _pb.authStore.record?.id ?? '';
  }

  bool get _signedIn => _userId.isNotEmpty && _pb.authStore.isValid;

  @override
  Future<List<SearchListing>> fetchMine() async {
    if (!_signedIn) return const [];
    final records = await _pb.collection(collection).getFullList(
      filter: pbFilter('user = {:userId}', {'userId': _userId}),
      expand: _expand,
      sort: '-created',
    );
    final mapped = <SearchListing>[];
    for (final record in records) {
      final listing = _expandedListing(record);
      if (listing == null) continue;
      mapped.add(_listings.mapListingRecord(listing));
    }
    if (mapped.isEmpty) return mapped;
    try {
      final live = await _reviews.fetchForListings([
        for (final item in mapped) item.id,
      ]);
      return [
        for (final item in mapped) overlayListingReviews(item, live[item.id]),
      ];
    } catch (_) {
      return mapped;
    }
  }

  @override
  Future<void> add(String listingId) async {
    final id = listingId.trim();
    if (id.isEmpty) {
      throw const FavoriteException('Не удалось сохранить жилье');
    }
    if (!_signedIn) {
      throw const FavoriteException('Войдите, чтобы сохранить жилье');
    }
    try {
      await _pb.collection(collection).create(
        body: {'user': _userId, 'listing': id},
      );
    } on ClientException catch (error) {
      if (_isDuplicate(error)) return;
      throw FavoriteException(_messageFor(error));
    }
  }

  @override
  Future<void> remove(String listingId) async {
    final id = listingId.trim();
    if (id.isEmpty) return;
    if (!_signedIn) {
      throw const FavoriteException('Войдите, чтобы сохранить жилье');
    }
    try {
      final records = await _pb.collection(collection).getFullList(
        filter: pbFilter('user = {:userId} && listing = {:listingId}', {
          'userId': _userId,
          'listingId': id,
        }),
      );
      for (final record in records) {
        await _pb.collection(collection).delete(record.id);
      }
    } on ClientException catch (error) {
      throw FavoriteException(_messageFor(error));
    }
  }

  RecordModel? _expandedListing(RecordModel favorite) {
    final fromSdk = favorite.expand['listing'];
    if (fromSdk != null && fromSdk.isNotEmpty) return fromSdk.first;
    return null;
  }

  bool _isDuplicate(ClientException error) {
    return '${error.response}'.toLowerCase().contains('validation_not_unique');
  }

  String _messageFor(ClientException error) {
    final message = error.response['message'];
    if (message is String &&
        message.isNotEmpty &&
        message != 'Failed to create record.') {
      return message;
    }
    return 'Не удалось обновить избранное';
  }
}

/// Память для виджет-тестов вкладки. В приложении не используется.
@visibleForTesting
class MemoryFavoritesRepository implements FavoritesRepository {
  MemoryFavoritesRepository({Iterable<SearchListing> items = const []}) {
    for (final item in items) {
      _items[item.id] = item;
    }
  }

  final _items = <String, SearchListing>{};

  @override
  Future<List<SearchListing>> fetchMine() async => _items.values.toList();

  @override
  Future<void> add(String listingId) async {
    final id = listingId.trim();
    if (id.isEmpty || _items.containsKey(id)) return;
    _items[id] = SearchListing(
      id: id,
      title: id,
      city: '',
      type: '',
      address: '',
      description: '',
      dates: '',
      nights: '',
      total: '',
      perNight: '',
      rating: '—',
      reviews: '(0)',
      photo: '',
      photos: const [],
      imageIndex: 0,
      latitude: 0,
      longitude: 0,
      pricePerNight: 0,
    );
  }

  @override
  Future<void> remove(String listingId) async {
    _items.remove(listingId.trim());
  }
}
