import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booking/screens/listing/listing_detail.dart';
import 'package:booking/screens/listing/listing_detail_screen.dart';
import 'package:booking/theme/app_theme.dart';

import 'fixtures/demo_listings.dart';

Widget _app(Widget home) {
  return MaterialApp(theme: AppTheme.light, home: home);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    expect(find.text('Другие объявления владельца'), findsOneWidget);
    expect(find.text('Частный дом в 10 км от Москвы'), findsOneWidget);
    expect(find.text('Забронировать'), findsOneWidget);
    expect(find.text('15 170 ₽'), findsOneWidget);
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

    await tester.tap(find.byTooltip('В избранное'));
    await tester.pump();

    expect(favorites, contains('studio-msk'));
    expect(find.byTooltip('Убрать из избранного'), findsOneWidget);
  });
}
