import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:booking/screens/search/search_listing.dart';

import 'fixtures/demo_listings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('ru');
  });

  test('quoteStay uses nightly rate and long-stay tiers', () {
    expect(
      quoteStay(pricePerNight: 3000, price14: 2800, price28: 2500).total,
      3000,
    );
    expect(
      quoteStay(
        pricePerNight: 3000,
        price14: 2800,
        price28: 2500,
        nights: 3,
      ).total,
      9000,
    );
    expect(
      quoteStay(
        pricePerNight: 3000,
        price14: 2800,
        price28: 2500,
        nights: 14,
      ),
      const StayQuote(nights: 14, unitPrice: 2800, total: 39200),
    );
    expect(
      quoteStay(
        pricePerNight: 3000,
        price14: 2800,
        price28: 2500,
        nights: 28,
      ),
      const StayQuote(nights: 28, unitPrice: 2500, total: 70000),
    );
  });

  test('listing stay total follows selected nights', () {
    final listing = kDemoListings.firstWhere((item) => item.id == 'studio-msk');

    expect(listing.withStay().total, '3 034 ₽');
    expect(listing.withStay().nights, isEmpty);

    final threeNights = listing.withStay(
      checkIn: DateTime(2026, 9, 12),
      checkOut: DateTime(2026, 9, 15),
    );
    expect(threeNights.stayNightCount, 3);
    expect(threeNights.total, '9 102 ₽');
    expect(threeNights.nights, '3 ночи');
    expect(threeNights.dates, '12–14 сентября');
  });

  test('stayNightsBetween counts calendar days', () {
    expect(
      stayNightsBetween(
        DateTime(2026, 9, 16, 23),
        DateTime(2026, 9, 20, 1),
      ),
      4,
    );
  });
}
