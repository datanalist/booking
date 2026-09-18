import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booking/config/mapbox_config.dart';
import 'package:booking/config/mapbox_geocoding.dart';
import 'package:booking/data/booking.dart';
import 'package:booking/screens/bookings/booking_address_dialog.dart';
import 'package:booking/screens/bookings/booking_address_map_screen.dart';
import 'package:booking/theme/app_theme.dart';

Booking _booking({
  double latitude = 55.7584,
  double longitude = 37.6018,
  String address = 'Тверская улица, 1',
  String city = 'Москва',
}) {
  return Booking(
    id: 'booking-1',
    listingId: 'listing-1',
    guestId: 'guest',
    hostId: 'host',
    checkIn: DateTime(2026, 9, 12),
    checkOut: DateTime(2026, 9, 15),
    status: BookingStatus.confirmed,
    title: 'Студия',
    address: address,
    city: city,
    latitude: latitude,
    longitude: longitude,
  );
}

Widget _app(Widget home) {
  return MaterialApp(
    theme: AppTheme.light,
    home: home,
  );
}

Future<void> _openDialog(WidgetTester tester, Booking booking) async {
  await tester.pumpWidget(
    _app(
      Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => showBookingAddressDialog(context, booking),
              child: const Text('open-address'),
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('open-address'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MapboxConfig.accessToken = '';
    BookingAddressMapScreen.debugGeocode = null;
  });

  tearDown(() {
    BookingAddressMapScreen.debugGeocode = null;
  });

  testWidgets('dialog shows figma copy and test keys', (tester) async {
    await _openDialog(tester, _booking());

    expect(find.byKey(const ValueKey<String>('booking-address-dialog')), findsOneWidget);
    expect(find.text('Посмотреть адрес на картах?'), findsOneWidget);
    expect(find.text('Нет'), findsOneWidget);
    expect(find.text('Да, смотреть'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('booking-address-no')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('booking-address-yes')), findsOneWidget);
    final yesSize = tester.getSize(find.text('Да, смотреть'));
    expect(yesSize.height, inInclusiveRange(16, 22));
  });

  testWidgets('no closes the dialog without opening the map', (tester) async {
    await _openDialog(tester, _booking());

    await tester.tap(find.byKey(const ValueKey<String>('booking-address-no')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('booking-address-dialog')), findsNothing);
    expect(find.byKey(const ValueKey<String>('booking-address-map')), findsNothing);
    expect(find.text('open-address'), findsOneWidget);
  });

  testWidgets('tap outside closes the dialog', (tester) async {
    await _openDialog(tester, _booking());

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('booking-address-dialog')), findsNothing);
    expect(find.byKey(const ValueKey<String>('booking-address-map')), findsNothing);
  });

  testWidgets('yes with coordinates opens the map pin', (tester) async {
    await _openDialog(tester, _booking());

    await tester.tap(find.byKey(const ValueKey<String>('booking-address-yes')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('booking-address-dialog')), findsNothing);
    expect(find.byType(BookingAddressMapScreen), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('booking-address-map')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('booking-address-pin')), findsOneWidget);
    expect(find.text('Тверская улица, 1'), findsOneWidget);
  });

  testWidgets('yes with 0,0 and no geocode shows the address text', (
    tester,
  ) async {
    await _openDialog(
      tester,
      _booking(latitude: 0, longitude: 0, address: 'Казанский кремль'),
    );

    await tester.tap(find.byKey(const ValueKey<String>('booking-address-yes')));
    await tester.pump();
    await tester.pump();

    expect(find.byType(BookingAddressMapScreen), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('booking-address-text')), findsOneWidget);
    expect(find.text('Казанский кремль'), findsWidgets);
    expect(find.byKey(const ValueKey<String>('booking-address-pin')), findsNothing);
  });

  testWidgets('missing coordinates geocode onto a pin', (tester) async {
    BookingAddressMapScreen.debugGeocode = (query) async {
      expect(query, 'Невский проспект, 1');
      return const [
        AddressSuggestion(
          label: 'Невский проспект, 1, Санкт-Петербург',
          city: 'Санкт-Петербург',
          latitude: 59.9343,
          longitude: 30.3351,
        ),
      ];
    };

    await tester.pumpWidget(
      _app(
        BookingAddressMapScreen(
          booking: _booking(
            latitude: 0,
            longitude: 0,
            address: 'Невский проспект, 1',
            city: 'Санкт-Петербург',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('booking-address-pin')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('booking-address-text')), findsNothing);
  });
}
