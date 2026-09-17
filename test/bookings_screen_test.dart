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
    ]);

    await tester.pumpWidget(_app(const BookingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Уютная студия в центре Москвы'), findsOneWidget);
    expect(find.text('ожидание подтверждения от владельца'), findsOneWidget);
    expect(find.text('Лофт у Казанского кремля'), findsNothing);

    await tester.tap(find.text('Архив'));
    await tester.pumpAndSettle();
    expect(find.text('Лофт у Казанского кремля'), findsOneWidget);
    expect(find.text('отменено'), findsOneWidget);
    expect(find.text('Уютная студия в центре Москвы'), findsNothing);
  });

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
