import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:booking/data/booking.dart';
import 'package:booking/data/bookings_repository.dart';
import 'package:booking/screens/bookings/bookings_screen.dart';
import 'package:booking/theme/app_theme.dart';

import 'fixtures/demo_listings.dart';
import 'fixtures/fake_bookings.dart';

Widget _app(Widget home) {
  return MaterialApp(theme: AppTheme.light, home: Scaffold(body: home));
}

Booking _booking({
  required String id,
  required BookingStatus status,
  String title = 'Уютная студия в центре Москвы',
  DateTime? checkIn,
  DateTime? checkOut,
  int adults = 2,
}) {
  final listing = kDemoListings.first;
  return Booking(
    id: id,
    listingId: listing.id,
    guestId: 'guest',
    hostId: listing.hostId,
    checkIn: checkIn ?? DateTime(2026, 9, 12),
    checkOut: checkOut ?? DateTime(2026, 9, 15),
    status: status,
    adults: adults,
    title: title,
    photo: listing.photo,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('ru');
  });

  testWidgets('empty bookings tab keeps current and past hints', (tester) async {
    BookingsRepositoryScope.instance = FakeBookingsRepository();
    await tester.pumpWidget(_app(const BookingsScreen()));
    await tester.pumpAndSettle();

    expect(
      find.text('Забронированное жилье будет отображаться здесь'),
      findsOneWidget,
    );

    await tester.tap(find.text('Прошлые'));
    await tester.pumpAndSettle();
    expect(
      find.text('История бронирований будет отображаться здесь'),
      findsOneWidget,
    );
  });

  testWidgets('current segment lists live bookings from the repository', (
    tester,
  ) async {
    BookingsRepositoryScope.instance = FakeBookingsRepository([
      _booking(id: 'b1', status: BookingStatus.pendingHost),
      _booking(
        id: 'b2',
        status: BookingStatus.cancelled,
        title: 'Лофт у Казанского кремля',
      ),
    ]);

    await tester.pumpWidget(_app(const BookingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Уютная студия в центре Москвы'), findsOneWidget);
    expect(find.text('ожидание подтверждения от владельца'), findsOneWidget);
    expect(find.text('Лофт у Казанского кремля'), findsNothing);

    await tester.tap(find.text('Прошлые'));
    await tester.pumpAndSettle();
    expect(find.text('Лофт у Казанского кремля'), findsOneWidget);
    expect(find.text('отменено'), findsOneWidget);
    expect(find.text('Уютная студия в центре Москвы'), findsNothing);
  });
}
