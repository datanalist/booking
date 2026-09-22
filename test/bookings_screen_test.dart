import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:booking/data/booking.dart';
import 'package:booking/data/bookings_repository.dart';
import 'package:booking/screens/bookings/bookings_screen.dart';
import 'package:booking/theme/app_theme.dart';

import 'fixtures/demo_listings.dart';
import 'fixtures/fake_bookings.dart';

Widget _app(Widget home) {
  return MaterialApp(
    theme: AppTheme.light,
    scrollBehavior: AppTheme.scrollBehavior,
    home: Scaffold(body: home),
  );
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

    expect(find.text('Предстоящие'), findsOneWidget);
    expect(find.text('Архив'), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
    final illustration = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(illustration.width, 171.532);
    expect(illustration.height, 160);
    expect(tester.getSize(find.byType(SvgPicture)).width, closeTo(171.532, 0.6));
    expect(tester.getSize(find.byType(SvgPicture)).height, closeTo(160, 0.6));
    expect(
      find.text('Забронированное жилье\nбудет отображаться здесь'),
      findsOneWidget,
    );

    await tester.tap(find.text('Архив'));
    await tester.pumpAndSettle();
    expect(
      find.text('Архив бронирований\nбудет отображаться здесь'),
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
      _booking(
        id: 'b3',
        status: BookingStatus.cancelRequested,
        title: 'Дом у озера',
      ),
    ]);

    await tester.pumpWidget(_app(const BookingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Уютная студия в центре Москвы'), findsOneWidget);
    expect(find.text('ожидание подтверждения от владельца'), findsOneWidget);
    expect(find.text('Лофт у Казанского кремля'), findsNothing);
    expect(find.text('Дом у озера'), findsNothing);
    expect(find.text('запрос на отмену'), findsNothing);

    await tester.tap(find.text('Архив'));
    await tester.pumpAndSettle();
    expect(find.text('Лофт у Казанского кремля'), findsOneWidget);
    expect(find.text('Дом у озера'), findsOneWidget);
    expect(find.text('отменено'), findsNWidgets(2));
    expect(find.text('запрос на отмену'), findsNothing);
    expect(find.text('Уютная студия в центре Москвы'), findsNothing);
  });

  testWidgets(
    'change_requested upcoming chip matches pending_host',
    (tester) async {
      BookingsRepositoryScope.instance = FakeBookingsRepository([
        _booking(id: 'b1', status: BookingStatus.pendingHost),
        _booking(
          id: 'b2',
          status: BookingStatus.changeRequested,
          title: 'Отель Венеция',
        ),
      ]);

      await tester.pumpWidget(_app(const BookingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Уютная студия в центре Москвы'), findsOneWidget);
      expect(find.text('Отель Венеция'), findsOneWidget);
      expect(
        find.text('ожидание подтверждения от владельца'),
        findsNWidgets(2),
      );
    },
  );

  testWidgets(
    'after change request card shows new dates and guests not old ones',
    (tester) async {
      final repo = FakeBookingsRepository([
        _booking(
          id: 'b1',
          status: BookingStatus.confirmed,
          checkIn: DateTime(2024, 11, 14),
          checkOut: DateTime(2024, 11, 19),
          adults: 2,
        ),
      ]);
      BookingsRepositoryScope.instance = repo;

      await tester.pumpWidget(_app(const BookingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('14.11.2024 - 19.11.2024'), findsOneWidget);
      expect(find.text('2 гостя'), findsOneWidget);

      await repo.patch(
        id: 'b1',
        status: BookingStatus.changeRequested,
        requestedCheckIn: DateTime(2024, 12, 1),
        requestedCheckOut: DateTime(2024, 12, 5),
        adults: 3,
        children: 1,
        total: 12000,
        prepay: 1800,
        remainder: 10200,
        commission: 1800,
        hostAmount: 10200,
      );
      await tester.pumpAndSettle();

      expect(find.text('14.11.2024 - 19.11.2024'), findsNothing);
      expect(find.text('01.12.2024 - 05.12.2024'), findsOneWidget);
      expect(find.text('2 гостя'), findsNothing);
      expect(find.text('4 гостя'), findsOneWidget);
      expect(
        find.text('ожидание подтверждения от владельца'),
        findsOneWidget,
      );
    },
  );

  testWidgets('upcoming list does not stretch on overscroll', (tester) async {
    BookingsRepositoryScope.instance = FakeBookingsRepository([
      _booking(id: 'b1', status: BookingStatus.pendingHost),
    ]);
    await tester.pumpWidget(_app(const BookingsScreen()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ListView));
    final behavior = ScrollConfiguration.of(context);
    expect(behavior.getScrollPhysics(context), isA<ClampingScrollPhysics>());
    expect(
      behavior.buildOverscrollIndicator(
        context,
        const SizedBox.shrink(),
        const ScrollableDetails(direction: AxisDirection.down),
      ),
      isA<SizedBox>(),
    );
  });

  testWidgets(
    'after create, upcoming card chip follows the record status',
    (tester) async {
      final repo = FakeBookingsRepository();
      BookingsRepositoryScope.instance = repo;
      await tester.pumpWidget(_app(const BookingsScreen()));
      await tester.pumpAndSettle();

      expect(
        find.text('Забронированное жилье\nбудет отображаться здесь'),
        findsOneWidget,
      );

      final listing = kDemoListings.first;
      await repo.create(
        listing: listing,
        checkIn: DateTime(2026, 9, 12),
        checkOut: DateTime(2026, 9, 15),
        adults: 2,
      );
      await tester.pumpAndSettle();

      expect(find.text(listing.title), findsOneWidget);
      expect(find.text('12.09.2026 - 15.09.2026'), findsOneWidget);
      expect(find.text('2 гостя'), findsOneWidget);
      expect(
        find.text('ожидание подтверждения от владельца'),
        findsOneWidget,
      );
      expect(
        find.text('Забронированное жилье\nбудет отображаться здесь'),
        findsNothing,
      );

      final created = repo.items.single;
      expect(created.status, BookingStatus.pendingHost);
      repo.items[0] = _booking(
        id: created.id,
        status: BookingStatus.awaitingPrepayment,
        title: created.title,
        checkIn: created.checkIn,
        checkOut: created.checkOut,
        adults: created.adults,
      );
      BookingsRepositoryScope.notifyChanged();
      await tester.pumpAndSettle();

      expect(find.text(listing.title), findsOneWidget);
      expect(find.text('ожидание предоплаты'), findsOneWidget);
      expect(
        find.text('ожидание подтверждения от владельца'),
        findsNothing,
      );
    },
  );
}
