import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:booking/data/auth_repository.dart';
import 'package:booking/data/booking.dart';
import 'package:booking/data/booking_draft.dart';
import 'package:booking/screens/listing/booking_confirmation_sheet.dart';
import 'package:booking/screens/listing/guests_sheet.dart';
import 'package:booking/screens/listing/listing_detail.dart';
import 'package:booking/screens/listing/listing_detail_screen.dart';
import 'package:booking/screens/listing/listing_icons.dart';
import 'package:booking/screens/listing/stay_dates_sheet.dart';
import 'package:booking/theme/app_theme.dart';
import 'package:booking/widgets/listing_host_section.dart';

import 'fixtures/demo_listings.dart';
import 'fixtures/fake_bookings.dart';
import 'fixtures/fake_notifications.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('ru');
  });

  test('listing detail maps a PocketBase listing and host extras', () {
    final listing = kDemoListings.firstWhere((item) => item.id == 'studio-msk');
    final detail = ListingDetail.fromListing(
      listing,
      hostListings: [
        for (final item in kDemoListings)
          if (item.id != listing.id && item.hostId == listing.hostId) item,
      ],
    );

    expect(detail.address, 'Москва, ул. Невская 48');
    expect(detail.host.name, 'Анна Иваненко');
    expect(detail.amenities, containsAll(['Wifi', 'Фен', 'Посуда']));
    expect(detail.reviews, hasLength(2));
    expect(detail.hostListings.map((item) => item.id), [
      'old-town',
      'house-10km',
    ]);
  });

  test('host display name joins first and last with a space', () {
    expect(
      listingHostDisplayName(firstName: 'Ирина', lastName: 'Иванова'),
      'Ирина Иванова',
    );
    expect(
      listingHostDisplayName(name: 'Анна Иваненко'),
      'Анна Иваненко',
    );
    expect(listingHostDisplayName(), 'Хозяин');
  });

  testWidgets('ListingHostSection shows kAnna verification and years badges', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Scaffold(
          body: ListingHostSection(host: kAnna),
        ),
      ),
    );

    expect(find.text('Анна Иваненко'), findsOneWidget);
    expect(kAnna.verified, isTrue);
    expect(kAnna.years, 4);
    expect(find.text('Верификация пройдена'), findsOneWidget);
    expect(find.text('4 года сдает жилье'), findsOneWidget);
  });

  test('review labels use russian plurals', () {
    expect(reviewCountFromLabel('(13)'), 13);
    expect(reviewCountLabel(1), '(1 отзыв)');
    expect(reviewCountLabel(3), '(3 отзыва)');
    expect(reviewCountLabel(13), '(13 отзывов)');
    expect(yearsHostingLabel(1), '1 год сдает жилье');
    expect(yearsHostingLabel(4), '4 года сдает жилье');
  });

  testWidgets('listing page shows stay, host and booking bar', (tester) async {
    final favorites = <String>{};
    final listing = kDemoListings.firstWhere((item) => item.id == 'studio-msk');
    final detail = ListingDetail.fromListing(
      listing,
      hostListings: [
        for (final item in kDemoListings)
          if (item.id != listing.id && item.hostId == listing.hostId) item,
      ],
    );

    await tester.pumpWidget(
      _app(
        ListingDetailScreen(
          listing: listing,
          favorites: favorites,
          initialDetail: detail,
          onFavorite: (id) {
            if (!favorites.remove(id)) favorites.add(id);
          },
        ),
      ),
    );

    expect(find.text('Уютная студия в центре Москвы'), findsOneWidget);
    expect(find.text('Москва, ул. Невская 48'), findsOneWidget);
    expect(find.text('Квартира'), findsWidgets);
    expect(find.text('Удобства'), findsOneWidget);
    expect(find.text('Wifi'), findsOneWidget);
    expect(find.text('Антон Киривлянов'), findsOneWidget);
    expect(find.text('Анна Иваненко'), findsOneWidget);
    expect(find.text('Верификация пройдена'), findsOneWidget);
    expect(find.text('4 года сдает жилье'), findsOneWidget);
    expect(find.byKey(const ValueKey('listing-host-chat')), findsOneWidget);
    expect(find.text('Другие объявления владельца'), findsOneWidget);
    expect(find.text('Частный дом в 10 км от Москвы'), findsOneWidget);
    expect(find.text('Забронировать'), findsOneWidget);
    expect(find.text('3 034 ₽'), findsOneWidget);
    expect(find.text('Выберите даты'), findsOneWidget);
  });

  testWidgets('booking bar totals the selected stay nights', (tester) async {
    final favorites = <String>{};
    final listing = kDemoListings
        .firstWhere((item) => item.id == 'studio-msk')
        .withStay(
          checkIn: DateTime(2026, 9, 12),
          checkOut: DateTime(2026, 9, 15),
        );
    final detail = ListingDetail.fromListing(listing);

    await tester.pumpWidget(
      _app(
        ListingDetailScreen(
          listing: listing,
          favorites: favorites,
          initialDetail: detail,
          onFavorite: (id) {
            if (!favorites.remove(id)) favorites.add(id);
          },
        ),
      ),
    );

    expect(find.text('9 102 ₽'), findsOneWidget);
    expect(find.text('3 034 ₽ / ночь'), findsOneWidget);
    expect(find.text('3 ночи'), findsOneWidget);
  });

  testWidgets('reviews block keeps rating but does not invent guest cards', (
    tester,
  ) async {
    final listing = kDemoListings.firstWhere((item) => item.id == 'studio-msk');
    final detail = ListingDetail(
      listing: listing,
      address: listing.address,
      description: listing.description,
      photos: listing.photos,
      amenities: listing.amenities,
      reviews: const [],
      host: listing.host!,
      hostListings: const [],
    );

    await tester.pumpWidget(
      _app(
        ListingDetailScreen(
          listing: listing,
          favorites: <String>{},
          initialDetail: detail,
          onFavorite: (_) {},
        ),
      ),
    );

    expect(find.text('Отзывы'), findsOneWidget);
    expect(find.text('Антон Киривлянов'), findsNothing);
    expect(find.text('Ирина Куленкова'), findsNothing);
  });

  testWidgets('listing page uses figma icon boxes and leaves', (tester) async {
    final listing = kDemoListings.firstWhere((item) => item.id == 'studio-msk');
    final detail = ListingDetail.fromListing(listing);

    await tester.pumpWidget(
      _app(
        ListingDetailScreen(
          listing: listing,
          favorites: <String>{},
          initialDetail: detail,
          onFavorite: (_) {},
        ),
      ),
    );

    expect(
      tester.getSize(find.byWidget(ListingFigmaIcon.mapPin16)),
      const Size(16, 16),
    );
    expect(
      tester.getSize(find.byWidget(ListingFigmaIcon.home16)),
      const Size(16, 16),
    );
    expect(
      tester.getSize(find.byWidget(ListingFigmaIcon.star18)),
      const Size(18, 18),
    );
    expect(
      tester.getSize(find.byWidget(ListingFigmaIcon.security)),
      const Size(16, 16),
    );
    expect(
      tester.getSize(find.byWidget(ListingFigmaIcon.time)),
      const Size(16, 16),
    );

    final pin = tester.widget<ListingFigmaIcon>(
      find.byWidget(ListingFigmaIcon.mapPin16),
    );
    expect(pin.leaf, const Size.square(16));
    final headerStar = tester.widget<ListingFigmaIcon>(
      find.byWidget(ListingFigmaIcon.star18),
    );
    expect(headerStar.leaf, const Size(14.5028, 13.7499));
    final reviewStar = tester.widget<ListingFigmaIcon>(
      find.byWidget(ListingFigmaIcon.reviewStarOn).first,
    );
    expect(reviewStar.box, const Size(13, 12));
    expect(reviewStar.leaf, const Size(13.0506, 12.2396));
  });

  testWidgets('favorite on the listing page updates the shared set', (
    tester,
  ) async {
    final favorites = <String>{};
    final listing = kDemoListings.firstWhere((item) => item.id == 'studio-msk');
    final detail = ListingDetail.fromListing(
      listing,
      hostListings: [
        for (final item in kDemoListings)
          if (item.id != listing.id && item.hostId == listing.hostId) item,
      ],
    );

    await tester.pumpWidget(
      _app(
        ListingDetailScreen(
          listing: listing,
          favorites: favorites,
          initialDetail: detail,
          onFavorite: (id) {
            if (!favorites.remove(id)) favorites.add(id);
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('listing-hero-favorite')));
    await tester.pump();

    expect(favorites, contains('studio-msk'));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('listing-hero-favorite')),
        matching: find.byTooltip('Убрать из избранного'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('see-all opens the host listings screen', (tester) async {
    final favorites = <String>{};
    final listing = kDemoListings.firstWhere((item) => item.id == 'studio-msk');
    final detail = ListingDetail.fromListing(
      listing,
      hostListings: [
        for (final item in kDemoListings)
          if (item.id != listing.id && item.hostId == listing.hostId) item,
      ],
    );

    await tester.pumpWidget(
      _app(
        ListingDetailScreen(
          listing: listing,
          favorites: favorites,
          initialDetail: detail,
          onFavorite: (id) {
            if (!favorites.remove(id)) favorites.add(id);
          },
        ),
      ),
    );

    final seeAll = find.byKey(const ValueKey('listing-host-see-all'));
    await tester.scrollUntilVisible(
      seeAll,
      300,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable &&
            (widget.axisDirection == AxisDirection.down ||
                widget.axisDirection == AxisDirection.up),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(seeAll);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('host-listings')), findsOneWidget);
    expect(find.text('Объявления владельца Анна Иваненко'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('host-listings')),
        matching: find.text('Квартира в старом городе'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('host-listings')),
        matching: find.text('Частный дом в 10 км от Москвы'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('host-listings')),
        matching: find.text('Квартира в старом городе'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('listing-detail-old-town')),
      findsOneWidget,
    );
  });

  testWidgets('booking button opens stay dates instead of writing a booking', (
    tester,
  ) async {
    final bookings = FakeBookingsRepository();
    final drafts = BookingDraftStore.memory();
    final listing = kDemoListings.firstWhere((item) => item.id == 'studio-msk');
    await tester.pumpWidget(
      _app(
        ListingDetailScreen(
          listing: listing,
          favorites: <String>{},
          initialDetail: ListingDetail.fromListing(listing),
          onFavorite: (_) {},
          bookingsRepository: bookings,
          draftStore: drafts,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('listing-book-button')));
    await tester.pumpAndSettle();

    expect(find.byType(StayDatesSheet), findsOneWidget);
    expect(find.text('Даты проживания'), findsOneWidget);
    expect(find.text('Дата заезда'), findsOneWidget);
    expect(find.text('Дата выезда'), findsOneWidget);
    expect(find.text('Вернуться'), findsOneWidget);
    expect(find.text('Сохранить'), findsOneWidget);
    expect(bookings.created, isEmpty);
    expect(await drafts.load(listingId: listing.id), isNull);
  });

  testWidgets('saving stay dates keeps a local draft and skips PocketBase', (
    tester,
  ) async {
    final bookings = FakeBookingsRepository();
    final drafts = BookingDraftStore.memory();
    final listing = kDemoListings
        .firstWhere((item) => item.id == 'studio-msk')
        .withStay(
          checkIn: DateTime(2026, 9, 12),
          checkOut: DateTime(2026, 9, 15),
        );
    await tester.pumpWidget(
      _app(
        ListingDetailScreen(
          listing: listing,
          favorites: <String>{},
          initialDetail: ListingDetail.fromListing(listing),
          onFavorite: (_) {},
          bookingsRepository: bookings,
          draftStore: drafts,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('listing-book-button')));
    await tester.pumpAndSettle();
    expect(find.text('12.09.2026'), findsOneWidget);
    expect(find.text('15.09.2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stay-dates-save')));
    await tester.pumpAndSettle();

    expect(find.byType(StayDatesSheet), findsNothing);
    expect(find.byType(GuestsSheet), findsOneWidget);
    expect(find.text('Гости'), findsOneWidget);
    expect(bookings.created, isEmpty);

    await tester.tap(find.byKey(const ValueKey('guests-adults-plus')));
    await tester.tap(find.byKey(const ValueKey('guests-children-plus')));
    await tester.tap(find.byKey(const ValueKey('guests-pets-plus')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('guests-save')));
    await tester.pumpAndSettle();

    expect(find.byType(GuestsSheet), findsNothing);
    expect(find.byType(BookingConfirmationSheet), findsOneWidget);
    expect(find.text('Бронирование'), findsOneWidget);
    expect(bookings.created, isEmpty);
    final draft = await drafts.load(listingId: 'studio-msk');
    expect(draft, isNotNull);
    expect(draft!.checkIn, DateTime(2026, 9, 12));
    expect(draft.checkOut, DateTime(2026, 9, 15));
    expect(draft.adults, 2);
    expect(draft.children, 1);
    expect(draft.pets, 1);
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
    expect(find.text('3 ночи'), findsWidgets);

    Navigator.of(
      tester.element(find.byType(BookingConfirmationSheet)),
    ).pop();
    await tester.pumpAndSettle();
    expect(find.byType(BookingConfirmationSheet), findsNothing);
    expect(await drafts.load(listingId: 'studio-msk'), isNotNull);

    await tester.tap(find.byKey(const ValueKey('listing-book-button')));
    await tester.pumpAndSettle();
    expect(find.byType(StayDatesSheet), findsOneWidget);
    expect(find.byType(GuestsSheet), findsNothing);
    expect(find.text('12.09.2026'), findsOneWidget);
    expect(find.text('15.09.2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stay-dates-save')));
    await tester.pumpAndSettle();
    expect(find.byType(GuestsSheet), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('guests-adults-value')))
          .data,
      '2',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('guests-children-value')))
          .data,
      '1',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('guests-pets-value'))).data,
      '1',
    );
  });

  testWidgets('confirmation book from the listing writes and clears the draft', (
    tester,
  ) async {
    AuthRepositoryScope.session.value = const AuthSession(
      userId: 'guest-1',
      email: 'guest@test.com',
    );
    addTearDown(() => AuthRepositoryScope.session.value = null);
    final bookings = FakeBookingsRepository();
    final notifications = FakeNotificationsRepository();
    final drafts = BookingDraftStore.memory();
    Booking? created;
    final listing = kDemoListings
        .firstWhere((item) => item.id == 'studio-msk')
        .withStay(
          checkIn: DateTime(2026, 9, 12),
          checkOut: DateTime(2026, 9, 15),
        );
    await tester.pumpWidget(
      _app(
        ListingDetailScreen(
          listing: listing,
          favorites: <String>{},
          initialDetail: ListingDetail.fromListing(listing),
          onFavorite: (_) {},
          bookingsRepository: bookings,
          notificationsRepository: notifications,
          draftStore: drafts,
          onBookingCreated: (booking) => created = booking,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('listing-book-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stay-dates-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('guests-save')));
    await tester.pumpAndSettle();
    expect(find.byType(BookingConfirmationSheet), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('confirmation-book')));
    await tester.pumpAndSettle();

    expect(bookings.created, hasLength(1));
    expect(created, bookings.created.single);
    expect(created!.status, BookingStatus.pendingHost);
    expect(await drafts.load(), isNull);
    expect(find.byKey(const ValueKey('booking-request-sent-dialog')), findsOneWidget);
    expect(find.text('Запрос на бронирование отправлен'), findsOneWidget);
    expect(find.byType(BookingConfirmationSheet), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('booking-request-sent-ok')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('booking-request-sent-dialog')), findsNothing);
    expect(find.byType(BookingConfirmationSheet), findsNothing);
    expect(find.text('Выберите даты'), findsOneWidget);
  });
}
