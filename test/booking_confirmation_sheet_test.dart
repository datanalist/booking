import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:booking/data/auth_repository.dart';
import 'package:booking/data/booking.dart';
import 'package:booking/data/booking_draft.dart';
import 'package:booking/screens/listing/booking_confirmation_sheet.dart';
import 'package:booking/screens/listing/listing_icons.dart';
import 'package:booking/screens/search/search_listing.dart';
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

BookingDraft _draft() {
  return BookingDraft(
    listingId: 'studio-msk',
    checkIn: DateTime(2026, 9, 12),
    checkOut: DateTime(2026, 9, 15),
    adults: 2,
    children: 1,
    pets: 1,
  );
}

SearchListing _listing() {
  return kDemoListings
      .firstWhere((item) => item.id == 'studio-msk')
      .withStay(
        checkIn: DateTime(2026, 9, 12),
        checkOut: DateTime(2026, 9, 15),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('ru');
  });

  tearDown(() {
    AuthRepositoryScope.session.value = null;
  });

  test('confirmation labels match the draft card', () {
    expect(
      confirmationDatesLabel(DateTime(2024, 11, 14), DateTime(2024, 11, 19)),
      '14.11.2024 - 19.11.2024',
    );
    expect(
      confirmationGuestsLabel(adults: 2, children: 1, pets: 0),
      '2 взрослых, 1 ребенок',
    );
    expect(
      confirmationCancelUntilLabel(DateTime(2024, 11, 14)),
      '13.11.2024 12:00',
    );
  });

  testWidgets('confirmation shows dates, guests and quoted price', (
    tester,
  ) async {
    final drafts = BookingDraftStore.memory(_draft());
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: BookingConfirmationSheet(
            listing: _listing(),
            draft: _draft(),
            draftStore: drafts,
            bookingsRepository: FakeBookingsRepository(),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('confirmation-sheet')), findsOneWidget);
    expect(find.text('Бронирование'), findsOneWidget);
    expect(find.text('Уютная студия в центре Москвы'), findsOneWidget);
    expect(find.text('Москва'), findsOneWidget);
    expect(find.text('Квартира'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('confirmation-dates')))
          .data,
      '12.09.2026 - 15.09.2026',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('confirmation-guests')))
          .data,
      '2 взрослых, 1 ребенок, 1 животное',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('confirmation-nights')))
          .data,
      '3 ночи',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('confirmation-total')))
          .data,
      '9 102 ₽',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('confirmation-prepay')))
          .data,
      '1 365 ₽',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('confirmation-remainder')))
          .data,
      '7 737 ₽',
    );
    expect(find.text('Вернуться'), findsOneWidget);
    expect(find.text('Забронировать'), findsOneWidget);
    expect(
      tester.getSize(find.byWidget(ListingFigmaIcon.star16)),
      const Size(16, 16),
    );
    expect(
      tester.getSize(find.byWidget(ListingFigmaIcon.mapPin14)),
      const Size(14, 14),
    );
    expect(
      tester.getSize(find.byWidget(ListingFigmaIcon.home14)),
      const Size(14, 14),
    );
    expect(
      tester.getSize(find.byWidget(ListingFigmaIcon.warningInfo20)),
      const Size(20, 20),
    );
    expect(
      tester.widget<ListingFigmaIcon>(find.byWidget(ListingFigmaIcon.star16)).leaf,
      const Size(13.3351, 12.6675),
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

  testWidgets('back clears the entire local draft', (tester) async {
    final drafts = BookingDraftStore.memory(_draft());
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  BookingConfirmationSheet.show(
                    context,
                    listing: _listing(),
                    draft: _draft(),
                    draftStore: drafts,
                    bookingsRepository: FakeBookingsRepository(),
                  );
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
    expect(await drafts.load(listingId: 'studio-msk'), isNotNull);

    await tester.tap(find.byKey(const ValueKey('confirmation-back')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('confirmation-sheet')), findsNothing);
    expect(await drafts.load(), isNull);
  });

  testWidgets('book writes through the repository and clears the draft', (
    tester,
  ) async {
    AuthRepositoryScope.session.value = const AuthSession(
      userId: 'guest-1',
      email: 'guest@test.com',
    );
    final drafts = BookingDraftStore.memory(_draft());
    final bookings = FakeBookingsRepository();
    Booking? created;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  BookingConfirmationSheet.show(
                    context,
                    listing: _listing(),
                    draft: _draft(),
                    draftStore: drafts,
                    bookingsRepository: bookings,
                    onBookingCreated: (booking) => created = booking,
                  );
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
    await tester.tap(find.byKey(const ValueKey('confirmation-book')));
    await tester.pumpAndSettle();

    expect(bookings.created, hasLength(1));
    expect(bookings.created.single.listingId, 'studio-msk');
    expect(bookings.created.single.checkIn, DateTime(2026, 9, 12));
    expect(bookings.created.single.checkOut, DateTime(2026, 9, 15));
    expect(bookings.created.single.adults, 2);
    expect(bookings.created.single.children, 1);
    expect(bookings.created.single.pets, 1);
    expect(bookings.created.single.status, BookingStatus.pendingHost);
    expect(created, bookings.created.single);
    expect(await drafts.load(), isNull);
    expect(find.byKey(const ValueKey('confirmation-sheet')), findsNothing);
  });

  testWidgets('book without a session keeps the draft and skips create', (
    tester,
  ) async {
    final drafts = BookingDraftStore.memory(_draft());
    final bookings = FakeBookingsRepository();
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: BookingConfirmationSheet(
            listing: _listing(),
            draft: _draft(),
            draftStore: drafts,
            bookingsRepository: bookings,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('confirmation-book')));
    await tester.pumpAndSettle();

    expect(bookings.created, isEmpty);
    expect(await drafts.load(listingId: 'studio-msk'), isNotNull);
    expect(find.text(_loginRequired), findsOneWidget);
    expect(find.byKey(const ValueKey('confirmation-sheet')), findsOneWidget);
  });
}

const _loginRequired = 'Войдите, чтобы забронировать жилье';
