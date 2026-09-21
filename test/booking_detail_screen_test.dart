import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:booking/config/mapbox_config.dart';
import 'package:booking/data/booking.dart';
import 'package:booking/data/bookings_repository.dart';
import 'package:booking/data/listings_repository.dart';
import 'package:booking/screens/bookings/booking_address_map_screen.dart';
import 'package:booking/screens/bookings/booking_detail_screen.dart';
import 'package:booking/screens/bookings/bookings_screen.dart';
import 'package:booking/screens/listing/listing_detail.dart';
import 'package:booking/screens/search/search_map_view.dart';
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

Booking _booking({
  required String id,
  required BookingStatus status,
  String title = 'Уютная студия в центре Москвы',
  DateTime? checkIn,
  DateTime? checkOut,
  int adults = 2,
  int total = 15170,
  int prepay = 5000,
  int remainder = 10170,
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
    total: total,
    prepay: prepay,
    remainder: remainder,
    title: title,
    photo: listing.photo,
    address: listing.address,
    city: listing.city,
    hostName: listing.host?.name ?? '',
  );
}

Future<void> _openDetail(
  WidgetTester tester,
  Booking booking,
) async {
  final listing = kDemoListings.firstWhere(
    (item) => item.id == booking.listingId,
  );
  await tester.pumpWidget(
    _app(
      BookingDetailScreen(
        booking: booking,
        initialDetail: ListingDetail.fromListing(listing),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('ru');
  });

  setUp(() {
    MapboxConfig.accessToken = '';
  });

  testWidgets('tap on upcoming card opens booking detail', (tester) async {
    BookingsRepositoryScope.instance = FakeBookingsRepository([
      _booking(id: 'b1', status: BookingStatus.pendingHost),
    ]);
    ListingsRepositoryScope.instance = FakeListingsRepository();

    await tester.pumpWidget(
      _app(const Scaffold(body: BookingsScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BookingDetailScreen), findsNothing);

    await tester.tap(find.byKey(const ValueKey('booking-card-b1')));
    await tester.pumpAndSettle();

    expect(find.byType(BookingDetailScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-detail-b1')), findsOneWidget);
    expect(find.text('Изменить бронирование'), findsOneWidget);
    expect(find.text('ожидание подтверждения от владельца'), findsWidgets);
  });

  testWidgets(
    'pending_host and change_requested show owner chip and change button',
    (tester) async {
      for (final status in [
        BookingStatus.pendingHost,
        BookingStatus.changeRequested,
      ]) {
        await _openDetail(
          tester,
          _booking(id: 'pending-${status.apiKey}', status: status),
        );

        expect(
          find.text('ожидание подтверждения от владельца'),
          findsOneWidget,
        );
        expect(find.text('Изменить бронирование'), findsOneWidget);
        expect(find.text('Внести предоплату'), findsNothing);
        expect(find.text('Как попасть внутрь'), findsNothing);
        expect(find.byKey(const ValueKey('booking-prepay-button')), findsNothing);
        expect(find.byKey(const ValueKey('booking-change-button')), findsOneWidget);
      }
    },
  );

  testWidgets(
    'awaiting_prepayment shows prepay chip, amount and both footer buttons',
    (tester) async {
      await _openDetail(
        tester,
        _booking(id: 'prepay', status: BookingStatus.awaitingPrepayment),
      );

      expect(find.text('ожидание предоплаты'), findsOneWidget);
      expect(find.text('Внести предоплату'), findsOneWidget);
      expect(find.text('Изменить бронирование'), findsOneWidget);
      expect(find.text('предоплата'), findsOneWidget);
      expect(find.text('5 000 ₽'), findsWidgets);
      expect(find.text('Как попасть внутрь'), findsNothing);
      expect(find.byKey(const ValueKey('booking-prepay-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('booking-change-button')), findsOneWidget);
    },
  );

  testWidgets(
    'confirmed shows confirmed chip, access block and change button',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _openDetail(
        tester,
        _booking(id: 'confirmed', status: BookingStatus.confirmed),
      );

      expect(find.text('бронирование подтверждено'), findsOneWidget);
      expect(find.text('Изменить бронирование'), findsOneWidget);
      expect(find.text('Внести предоплату'), findsNothing);
      expect(find.byKey(const ValueKey('booking-prepay-button')), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Как попасть внутрь'),
        240,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Как попасть внутрь'), findsOneWidget);
      expect(find.textContaining('Введите код домофона 3486'), findsOneWidget);
    },
  );

  testWidgets(
    'upcoming address opens search-style map with pin and listing card',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final listing = kDemoListings.first;
      await _openDetail(
        tester,
        _booking(id: 'addr', status: BookingStatus.confirmed).copyWith(
          latitude: listing.latitude,
          longitude: listing.longitude,
        ),
      );

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('booking-address')),
        240,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const ValueKey('booking-address')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('booking-address-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('booking-address-yes')));
      await tester.pumpAndSettle();

      expect(find.byType(BookingAddressMapScreen), findsOneWidget);
      expect(find.byKey(ValueKey('map-pin-${listing.id}')), findsOneWidget);
      expect(find.byType(PricePin), findsOneWidget);
      expect(find.byKey(ValueKey('listing-card-${listing.id}')), findsOneWidget);
      expect(find.byKey(const ValueKey('booking-address-pin')), findsNothing);
    },
  );
}
