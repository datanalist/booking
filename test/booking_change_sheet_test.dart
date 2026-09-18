import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:booking/data/booking.dart';
import 'package:booking/data/bookings_repository.dart';
import 'package:booking/screens/bookings/booking_change_sheet.dart';
import 'package:booking/screens/listing/guests_sheet.dart';
import 'package:booking/screens/listing/listing_icons.dart';
import 'package:booking/screens/listing/stay_dates_sheet.dart';
import 'package:booking/theme/app_theme.dart';

import 'fixtures/demo_listings.dart';
import 'fixtures/fake_bookings.dart';

Widget _app(Widget home) {
  return MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('ru', 'RU'),
    supportedLocales: const [Locale('ru', 'RU')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
  );
}

Booking _booking() {
  final listing = kDemoListings.first;
  return Booking(
    id: 'booking-1',
    listingId: listing.id,
    guestId: 'guest',
    hostId: listing.hostId,
    checkIn: DateTime(2024, 11, 14),
    checkOut: DateTime(2024, 11, 19),
    status: BookingStatus.confirmed,
    adults: 2,
    children: 1,
    pets: 0,
    total: 15170,
    prepay: 5000,
    remainder: 11170,
    title: 'Уютная студия в центре Москвы',
    photo: listing.photo,
    city: 'Москва',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookingsRepository previousRepository;

  setUpAll(() async {
    await initializeDateFormatting('ru');
  });

  setUp(() {
    previousRepository = BookingsRepositoryScope.instance;
  });

  tearDown(() {
    BookingsRepositoryScope.instance = previousRepository;
  });

  testWidgets('opens the change booking sheet', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () => showBookingChangeSheet(context, _booking()),
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('booking-change-sheet')), findsOneWidget);
    expect(find.text('Изменить бронирование'), findsOneWidget);
    expect(find.text('Уютная студия в центре Москвы'), findsOneWidget);
    expect(find.text('Москва'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('booking-change-dates'))).data,
      '14.11.2024 - 19.11.2024',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('booking-change-guests')))
          .data,
      '2 взрослых, 1 ребенок',
    );
    expect(find.text('Изменить'), findsNWidgets(2));
    expect(find.text('Вернуться'), findsOneWidget);
    expect(find.text('Отправить'), findsOneWidget);
    expect(
      tester.getSize(find.byWidget(ListingFigmaIcon.mapPin14)),
      const Size(14, 14),
    );
    expect(
      tester.getSize(find.byWidget(ListingFigmaIcon.warningInfo20)),
      const Size(20, 20),
    );
    expect(
      tester
          .widget<ListingFigmaIcon>(
            find.byWidget(ListingFigmaIcon.warningInfo20),
          )
          .leaf,
      const Size.square(20),
    );
  });

  testWidgets('send writes change_requested and shows sent dialog', (
    tester,
  ) async {
    final booking = _booking();
    final repo = FakeBookingsRepository([booking]);
    BookingsRepositoryScope.instance = repo;
    Booking? result;

    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showBookingChangeSheet(context, booking);
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('booking-change-send')));
    await tester.pumpAndSettle();

    expect(repo.items.single.status, BookingStatus.changeRequested);
    expect(repo.items.single.requestedCheckIn, isNull);
    expect(repo.items.single.requestedCheckOut, isNull);
    expect(
      find.byKey(const ValueKey('booking-change-sent-dialog')),
      findsOneWidget,
    );
    expect(
      find.text('Запрос на изменение бронирования отправлен'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Ожидайте подтверждение внесенных изменений от '
        'владельца жилья в течение 12 часов',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('booking-change-sheet')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('booking-change-sent-ok')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('booking-change-sent-dialog')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('booking-change-sheet')), findsNothing);
    expect(result?.status, BookingStatus.changeRequested);
  });

  testWidgets('change rows open stay dates and guests sheets', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () => showBookingChangeSheet(context, _booking()),
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('booking-change-edit-dates')));
    await tester.pumpAndSettle();
    expect(find.byType(StayDatesSheet), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stay-dates-back')));
    await tester.pumpAndSettle();
    expect(find.byType(StayDatesSheet), findsNothing);

    await tester.tap(find.byKey(const ValueKey('booking-change-edit-guests')));
    await tester.pumpAndSettle();
    expect(find.byType(GuestsSheet), findsOneWidget);
  });
}
