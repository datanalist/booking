import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:booking/data/booking.dart';
import 'package:booking/data/bookings_repository.dart';
import 'package:booking/data/listings_repository.dart';
import 'package:booking/screens/bookings/booking_cancelled_detail_screen.dart';
import 'package:booking/screens/bookings/bookings_screen.dart';
import 'package:booking/theme/app_theme.dart';

import 'fixtures/demo_listings.dart';
import 'fixtures/fake_bookings.dart';

Widget _app(Widget home) {
  return MaterialApp(
    theme: AppTheme.light,
    scrollBehavior: AppTheme.scrollBehavior,
    home: home,
  );
}

Booking _cancelled({
  String id = 'cancelled-1',
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
    status: BookingStatus.cancelled,
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

  setUpAll(() async {
    await initializeDateFormatting('ru');
  });

  testWidgets(
    'archive tap on cancelled booking opens cancelled detail without change',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      BookingsRepositoryScope.instance = FakeBookingsRepository([_cancelled()]);
      ListingsRepositoryScope.instance = FakeListingsRepository();

      await tester.pumpWidget(_app(const Scaffold(body: BookingsScreen())));
      await tester.pumpAndSettle();

      expect(find.byType(BookingCancelledDetailScreen), findsNothing);

      await tester.tap(find.text('Архив'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('booking-card-cancelled-1')));
      await tester.pumpAndSettle();

      expect(find.byType(BookingCancelledDetailScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey('booking-cancelled-detail-cancelled-1')),
        findsOneWidget,
      );
      expect(find.text('отменено'), findsOneWidget);
      expect(find.text('Изменить бронирование'), findsNothing);
      expect(find.text('Отменить бронирование'), findsNothing);
      expect(find.byKey(const ValueKey('booking-change-button')), findsNothing);
    },
  );
}
