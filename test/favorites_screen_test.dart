import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booking/data/favorites_repository.dart';
import 'package:booking/data/listings_repository.dart';
import 'package:booking/screens/favorites/favorites_screen.dart';
import 'package:booking/screens/listing/listing_detail_screen.dart';
import 'package:booking/screens/search/active_search_stay.dart';
import 'package:booking/theme/app_theme.dart';

import 'fixtures/demo_listings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ListingsRepositoryScope.instance = FakeListingsRepository();
    ActiveSearchStay.current.value = const ActiveSearchStay();
  });

  tearDown(() {
    ActiveSearchStay.current.value = const ActiveSearchStay();
    ListingsRepositoryScope.instance = PocketBaseListingsRepository();
    FavoritesRepositoryScope.instance = PocketBaseFavoritesRepository();
  });

  testWidgets('empty favorites shows the illustration copy', (tester) async {
    await tester.pumpWidget(
      _app(FavoritesScreen(repository: MemoryFavoritesRepository())),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Добавленное в избранное жилье будет отображаться здесь'),
      findsOneWidget,
    );
    expect(find.byType(FavoritesScreen), findsOneWidget);
  });

  testWidgets('saved listings render, heart removes, card opens the listing', (
    tester,
  ) async {
    final repository = MemoryFavoritesRepository(
      items: kDemoListings.take(2),
    );
    ActiveSearchStay.publish(
      checkIn: DateTime(2026, 11, 14),
      checkOut: DateTime(2026, 11, 19),
      adults: 2,
    );

    await tester.pumpWidget(_app(FavoritesScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('Уютная студия в центре Москвы'), findsOneWidget);
    expect(find.text('Квартира в старом городе'), findsOneWidget);
    expect(find.textContaining('5 ночей'), findsWidgets);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('favorite-card-studio-msk')),
        matching: find.byTooltip('Убрать из избранного'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Уютная студия в центре Москвы'), findsNothing);
    expect(find.text('Квартира в старом городе'), findsOneWidget);
    expect(find.byType(ListingDetailScreen), findsNothing);
    expect((await repository.fetchMine()).map((item) => item.id), [
      'old-town',
    ]);

    await tester.tap(find.text('Квартира в старом городе'));
    await tester.pumpAndSettle();

    expect(find.byType(ListingDetailScreen), findsOneWidget);
    expect(find.text('Москва, ул. Пятницкая 12'), findsOneWidget);
  });
}

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
