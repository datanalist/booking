import 'package:booking/data/auth_repository.dart';
import 'package:booking/data/booking.dart';
import 'package:booking/data/reviews_repository.dart';
import 'package:booking/screens/search/search_listing.dart';

StayReview fakeGuestListingReview({
  String id = 'review-1',
  String bookingId = 'b-completed',
  String authorId = 'guest',
  String listingId = 'studio-msk',
  String subjectId = 'anna',
  int rating = 5,
  String comment = 'Тихо, чисто и удобно — мой отзыв о жилье',
}) {
  return StayReview(
    id: id,
    bookingId: bookingId,
    authorId: authorId,
    listingId: listingId,
    subjectId: subjectId,
    kind: ReviewKind.listing,
    rating: rating,
    comment: comment,
  );
}

ListingReview listingReviewFromStay(
  StayReview review, {
  String author = 'Гость',
  String postedAgo = 'день назад',
}) {
  return ListingReview(
    author: author,
    postedAgo: postedAgo,
    stars: review.rating,
    text: review.comment,
  );
}

class FakeReviewsRepository implements ReviewsRepository {
  FakeReviewsRepository([List<StayReview>? items])
    : items = List<StayReview>.from(items ?? const []);

  final List<StayReview> items;
  final created = <StayReview>[];
  Object? failCreateWith;

  @override
  Future<StayReview?> fetchForBooking(String bookingId) async {
    for (final item in items) {
      if (item.bookingId == bookingId && item.kind == ReviewKind.listing) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<bool> hasGuestListingReview(String bookingId) async {
    return await fetchForBooking(bookingId) != null;
  }

  @override
  Future<List<ListingReview>> fetchForListing(String listingId) async {
    return [
      for (final item in items)
        if (item.listingId == listingId && item.kind == ReviewKind.listing)
          listingReviewFromStay(item),
    ];
  }

  @override
  Future<Map<String, List<ListingReview>>> fetchForListings(
    Iterable<String> listingIds,
  ) async {
    final ids = listingIds.toSet();
    final result = <String, List<ListingReview>>{};
    for (final item in items) {
      if (!ids.contains(item.listingId) || item.kind != ReviewKind.listing) {
        continue;
      }
      result
          .putIfAbsent(item.listingId, () => [])
          .add(listingReviewFromStay(item));
    }
    return result;
  }

  @override
  Future<StayReview> create({
    required Booking booking,
    required int rating,
    String comment = '',
  }) async {
    if (failCreateWith != null) {
      final error = failCreateWith!;
      failCreateWith = null;
      throw error;
    }
    final authorId = AuthRepositoryScope.session.value?.userId ?? '';
    if (authorId.isEmpty) {
      throw const ReviewException('Войдите, чтобы оставить отзыв');
    }
    if (rating < 1 || rating > 5) {
      throw const ReviewException('Поставьте оценку от 1 до 5');
    }
    if (await hasGuestListingReview(booking.id)) {
      throw const ReviewException('Отзыв по этой брони уже оставлен');
    }
    final review = StayReview(
      id: 'review-${created.length + 1}',
      bookingId: booking.id,
      authorId: authorId,
      listingId: booking.listingId,
      subjectId: booking.hostId,
      kind: ReviewKind.listing,
      rating: rating,
      comment: comment.trim(),
    );
    created.add(review);
    items.add(review);
    return review;
  }
}
