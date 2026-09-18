import 'package:pocketbase/pocketbase.dart';

import '../screens/search/search_listing.dart';
import 'auth_repository.dart';
import 'booking.dart';
import 'pocketbase_client.dart';
import 'pocketbase_filter.dart';

enum ReviewKind {
  listing('listing'),
  guest('guest');

  const ReviewKind(this.apiKey);

  final String apiKey;

  static ReviewKind fromApi(String value) {
    for (final kind in ReviewKind.values) {
      if (kind.apiKey == value) return kind;
    }
    return ReviewKind.listing;
  }
}

class StayReview {
  const StayReview({
    required this.id,
    required this.bookingId,
    required this.authorId,
    required this.listingId,
    required this.subjectId,
    required this.kind,
    required this.rating,
    this.comment = '',
  });

  final String id;
  final String bookingId;
  final String authorId;
  final String listingId;
  final String subjectId;
  final ReviewKind kind;
  final int rating;
  final String comment;
}

class ReviewException implements Exception {
  const ReviewException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class ReviewsRepository {
  Future<StayReview?> fetchForBooking(String bookingId);

  Future<bool> hasGuestListingReview(String bookingId);

  Future<List<ListingReview>> fetchForListing(String listingId);

  Future<Map<String, List<ListingReview>>> fetchForListings(
    Iterable<String> listingIds,
  );

  Future<StayReview> create({
    required Booking booking,
    required int rating,
    String comment = '',
  });
}

class ReviewsRepositoryScope {
  static ReviewsRepository instance = PocketBaseReviewsRepository();
}

class PocketBaseReviewsRepository implements ReviewsRepository {
  PocketBaseReviewsRepository({PocketBase? client}) : _client = client;

  static const collection = PbCollection.reviews;

  final PocketBase? _client;
  PocketBase get _pb => _client ?? pocketBase;

  String get _userId {
    final session = AuthRepositoryScope.session.value;
    if (session != null && session.userId.isNotEmpty) return session.userId;
    return _pb.authStore.record?.id ?? '';
  }

  @override
  Future<StayReview?> fetchForBooking(String bookingId) async {
    if (bookingId.isEmpty) return null;
    final result = await _pb
        .collection(collection)
        .getList(
          page: 1,
          perPage: 1,
          filter: pbFilter('booking = {:bookingId} && kind = "listing"', {
            'bookingId': bookingId,
          }),
        );
    if (result.items.isEmpty) return null;
    return _map(result.items.first);
  }

  @override
  Future<bool> hasGuestListingReview(String bookingId) async {
    return await fetchForBooking(bookingId) != null;
  }

  @override
  Future<List<ListingReview>> fetchForListing(String listingId) async {
    if (listingId.isEmpty) return const [];
    final records = await _pb
        .collection(collection)
        .getFullList(
          filter: pbFilter('listing = {:listingId} && kind = "listing"', {
            'listingId': listingId,
          }),
          expand: 'author',
          sort: '-created',
        );
    return [
      for (final record in records) listingReviewFromRecord(record, pb: _pb),
    ];
  }

  @override
  Future<Map<String, List<ListingReview>>> fetchForListings(
    Iterable<String> listingIds,
  ) async {
    final ids = [
      for (final id in {...listingIds})
        if (id.isNotEmpty) id,
    ];
    if (ids.isEmpty) return {};
    const chunkSize = 40;
    final byListing = <String, List<ListingReview>>{};
    for (var i = 0; i < ids.length; i += chunkSize) {
      final end = i + chunkSize > ids.length ? ids.length : i + chunkSize;
      final chunk = ids.sublist(i, end);
      final records = await _pb
          .collection(collection)
          .getFullList(
            filter: pbFilter('listing ?~ {:listingIds} && kind = "listing"', {
              'listingIds': chunk.join('|'),
            }),
            expand: 'author',
            sort: '-created',
          );
      for (final record in records) {
        final listingId = record.get<String>('listing', '');
        if (listingId.isEmpty) continue;
        byListing
            .putIfAbsent(listingId, () => [])
            .add(listingReviewFromRecord(record, pb: _pb));
      }
    }
    return byListing;
  }

  @override
  Future<StayReview> create({
    required Booking booking,
    required int rating,
    String comment = '',
  }) async {
    final authorId = _userId;
    if (authorId.isEmpty) {
      throw const ReviewException('Войдите, чтобы оставить отзыв');
    }
    if (rating < 1 || rating > 5) {
      throw const ReviewException('Поставьте оценку от 1 до 5');
    }
    try {
      final record = await _pb
          .collection(collection)
          .create(
            body: {
              'booking': booking.id,
              'author': authorId,
              'listing': booking.listingId,
              'subject': booking.hostId,
              'kind': ReviewKind.listing.apiKey,
              'rating': rating,
              'comment': comment.trim(),
            },
          );
      return _map(record);
    } on ClientException catch (error) {
      throw ReviewException(_messageFor(error));
    }
  }

  StayReview _map(RecordModel record) {
    return StayReview(
      id: record.id,
      bookingId: record.get<String>('booking', ''),
      authorId: record.get<String>('author', ''),
      listingId: record.get<String>('listing', ''),
      subjectId: record.get<String>('subject', ''),
      kind: ReviewKind.fromApi(record.get<String>('kind', '')),
      rating: reviewRatingFromRecord(record),
      comment: record.get<String>('comment', ''),
    );
  }

  String _messageFor(ClientException error) {
    final response = error.response;
    final message = response['message'];
    if (message is String && message.isNotEmpty) return message;
    return 'Не удалось сохранить отзыв';
  }
}

int reviewRatingFromRecord(RecordModel record) {
  final raw = record.data['rating'];
  final rating = raw is num ? raw.round() : int.tryParse('$raw') ?? 0;
  return rating.clamp(1, 5);
}

/// Карточка отзыва объявления: имя автора, относительная дата, оценка, текст.
ListingReview listingReviewFromRecord(
  RecordModel record, {
  DateTime? now,
  PocketBase? pb,
}) {
  final author = expandedReviewAuthor(record);
  var avatarUrl = '';
  if (author != null && pb != null) {
    final name = author.get<String>('avatar', '');
    if (name.isNotEmpty) {
      avatarUrl = pb.files.getURL(author, name).toString();
    }
  }
  return ListingReview(
    author: listingHostDisplayName(
      firstName: author?.get<String>('first_name', '') ?? '',
      lastName: author?.get<String>('last_name', '') ?? '',
      name: author?.get<String>('name', '') ?? '',
      emptyLabel: 'Гость',
    ),
    postedAgo: reviewPostedAgo(
      parseReviewCreatedAt(record.get<String>('created', '')) ??
          (now ?? DateTime.now()),
      now: now,
    ),
    stars: reviewRatingFromRecord(record),
    text: record.get<String>('comment', ''),
    avatarUrl: avatarUrl,
  );
}

RecordModel? expandedReviewAuthor(RecordModel review) {
  final raw = review.data['expand'];
  if (raw is Map) {
    final parsed = _recordFromExpandValue(raw['author']);
    if (parsed != null) return parsed;
  }
  final fromSdk = review.expand['author'];
  if (fromSdk != null && fromSdk.isNotEmpty) return fromSdk.first;
  return null;
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
