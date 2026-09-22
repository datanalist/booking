import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:booking/data/auth_repository.dart';
import 'package:booking/data/booking.dart';
import 'package:booking/data/bookings_repository.dart';
import 'package:booking/data/listings_repository.dart';
import 'package:booking/data/reviews_repository.dart';
import 'package:booking/screens/bookings/booking_completed_detail_screen.dart';
import 'package:booking/screens/bookings/bookings_screen.dart';
import 'package:booking/screens/listing/listing_detail.dart';
import 'package:booking/theme/app_theme.dart';

import 'fixtures/demo_listings.dart';
import 'fixtures/fake_bookings.dart';
import 'fixtures/fake_reviews.dart';

Widget _app(Widget home) {
  return MaterialApp(
    theme: AppTheme.light,
    scrollBehavior: AppTheme.scrollBehavior,
    home: home,
  );
}

Booking _completed({
  String id = 'b-completed',
  String title = 'Уютная студия в центре Москвы',
}) {
  final listing = kDemoListings.first;
  return Booking(
    id: id,
    listingId: listing.id,
    guestId: 'guest',
    hostId: listing.hostId,
    checkIn: DateTime(2024, 11, 16),
    checkOut: DateTime(2024, 11, 18),
    status: BookingStatus.completed,
    adults: 2,
    total: 15170,
    prepay: 5000,
    remainder: 10170,
    title: title,
    photo: listing.photo,
    address: listing.address,
    city: listing.city,
    hostName: listing.host?.name ?? '',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReviewsRepository previousReviews;
  late ListingsRepository previousListings;
  late BookingsRepository previousBookings;

  setUpAll(() async {
    await initializeDateFormatting('ru');
  });

  setUp(() {
    previousReviews = ReviewsRepositoryScope.instance;
    previousListings = ListingsRepositoryScope.instance;
    previousBookings = BookingsRepositoryScope.instance;
    ListingsRepositoryScope.instance = FakeListingsRepository();
    AuthRepositoryScope.session.value = const AuthSession(
      userId: 'guest',
      email: 'guest@test.com',
    );
  });

  tearDown(() {
    ReviewsRepositoryScope.instance = previousReviews;
    ListingsRepositoryScope.instance = previousListings;
    BookingsRepositoryScope.instance = previousBookings;
    AuthRepositoryScope.session.value = null;
  });

  Future<void> _openDetail(
    WidgetTester tester, {
    required Booking booking,
    required FakeReviewsRepository reviews,
  }) async {
    final listing = kDemoListings.firstWhere(
      (item) => item.id == booking.listingId,
    );
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        BookingCompletedDetailScreen(
          booking: booking,
          initialDetail: ListingDetail.fromListing(listing),
          reviewsRepository: reviews,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('completed without review shows leave-review CTA from 1:12718', (
    tester,
  ) async {
    await _openDetail(
      tester,
      booking: _completed(),
      reviews: FakeReviewsRepository(),
    );

    expect(
      find.byKey(const ValueKey('booking-completed-detail-b-completed')),
      findsOneWidget,
    );
    expect(find.text('Оставить отзыв'), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-leave-review')), findsOneWidget);
    expect(find.text('Отзыв оставлен'), findsNothing);
    expect(find.byKey(const ValueKey('booking-guest-review')), findsNothing);
    expect(find.text('Как попасть внутрь'), findsOneWidget);
    expect(find.text('Пожаловаться'), findsOneWidget);
  });

  testWidgets('completed with review shows guest rating and text from 1:12946', (
    tester,
  ) async {
    const comment = 'Тихо, чисто и удобно — мой отзыв о жилье';
    await _openDetail(
      tester,
      booking: _completed(),
      reviews: FakeReviewsRepository([
        fakeGuestListingReview(
          bookingId: 'b-completed',
          comment: comment,
          rating: 5,
        ),
      ]),
    );

    expect(find.text('Оставить отзыв'), findsNothing);
    expect(find.byKey(const ValueKey('booking-leave-review')), findsNothing);
    expect(find.text('Отзыв оставлен'), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-review-left')), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-guest-review')), findsOneWidget);
    expect(find.text(comment), findsOneWidget);
    expect(find.text('Ваш отзыв'), findsOneWidget);
  });

  testWidgets('submitting review switches to left-review template', (
    tester,
  ) async {
    final reviews = FakeReviewsRepository();
    await _openDetail(
      tester,
      booking: _completed(),
      reviews: reviews,
    );

    await tester.tap(find.byKey(const ValueKey('booking-leave-review')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('booking-review-sheet')), findsOneWidget);
    expect(find.text('Оценить'), findsOneWidget);
    expect(find.text('Насколько вам понравилось проживание?'), findsOneWidget);
    expect(find.text('Пропустить'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(
        find.byKey(const ValueKey('booking-review-submit')),
      ).onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('booking-review-star-5')));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(
        find.byKey(const ValueKey('booking-review-submit')),
      ).onPressed,
      isNotNull,
    );

    await tester.enterText(
      find.byKey(const ValueKey('booking-review-text')),
      'Очень понравилось жильё',
    );
    await tester.pump();
    expect(find.text('23/500'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('booking-review-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('booking-review-sheet')), findsNothing);
    expect(find.text('Оставить отзыв'), findsNothing);
    expect(find.text('Отзыв оставлен'), findsOneWidget);
    expect(find.text('Очень понравилось жильё'), findsOneWidget);
    expect(reviews.created, hasLength(1));
    expect(reviews.created.single.rating, 5);
    expect(reviews.created.single.comment, 'Очень понравилось жильё');
  });

  testWidgets('skip closes review sheet without creating a review', (
    tester,
  ) async {
    final reviews = FakeReviewsRepository();
    await _openDetail(
      tester,
      booking: _completed(),
      reviews: reviews,
    );

    await tester.tap(find.byKey(const ValueKey('booking-leave-review')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('booking-review-skip')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('booking-review-sheet')), findsNothing);
    expect(find.text('Оставить отзыв'), findsOneWidget);
    expect(reviews.created, isEmpty);
  });

  testWidgets('tap on completed archive card opens completed detail', (
    tester,
  ) async {
    final booking = _completed(id: 'b1');
    BookingsRepositoryScope.instance = FakeBookingsRepository([booking]);
    ReviewsRepositoryScope.instance = FakeReviewsRepository();

    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(const Scaffold(body: BookingsScreen())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Архив'));
    await tester.pumpAndSettle();

    expect(find.text('Уютная студия в центре Москвы'), findsOneWidget);
    expect(find.byType(BookingCompletedDetailScreen), findsNothing);

    await tester.tap(find.byKey(const ValueKey('booking-card-b1')));
    await tester.pumpAndSettle();

    expect(find.byType(BookingCompletedDetailScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('booking-completed-detail-b1')),
      findsOneWidget,
    );
    expect(find.text('Оставить отзыв'), findsOneWidget);
  });
}
