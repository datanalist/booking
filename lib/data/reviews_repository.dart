import 'package:pocketbase/pocketbase.dart';

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
  PocketBaseReviewsRepository({this._client});

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
    final result = await _pb.collection(collection).getList(
      page: 1,
      perPage: 1,
      filter: pbFilter(
        'booking = {:bookingId} && kind = "listing"',
        {'bookingId': bookingId},
      ),
    );
    if (result.items.isEmpty) return null;
    return _map(result.items.first);
  }

  @override
  Future<bool> hasGuestListingReview(String bookingId) async {
    return await fetchForBooking(bookingId) != null;
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
    final rawRating = record.data['rating'];
    final rating = rawRating is num
        ? rawRating.round()
        : int.tryParse('$rawRating') ?? 0;
    return StayReview(
      id: record.id,
      bookingId: record.get<String>('booking', ''),
      authorId: record.get<String>('author', ''),
      listingId: record.get<String>('listing', ''),
      subjectId: record.get<String>('subject', ''),
      kind: ReviewKind.fromApi(record.get<String>('kind', '')),
      rating: rating.clamp(1, 5),
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
