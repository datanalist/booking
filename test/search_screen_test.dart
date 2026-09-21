import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booking/config/mapbox_config.dart';
import 'package:booking/config/mapbox_geocoding.dart';
import 'package:booking/config/mapbox_style.dart';
import 'package:booking/data/listings_repository.dart';
import 'package:booking/screens/listing/listing_detail_screen.dart';
import 'package:booking/screens/search/search_filters_sheet.dart';
import 'package:booking/screens/search/search_map_view.dart';
import 'package:booking/screens/search/search_query_sheet.dart';
import 'package:booking/screens/search/search_screen.dart';
import 'package:booking/theme/app_theme.dart';

import 'fixtures/demo_listings.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

Future<void> _pumpSearch(WidgetTester tester) async {
  await tester.pumpWidget(_app(const Scaffold(body: SearchScreen())));
  await tester.pump();
}

Future<void> _submitSearchCity(WidgetTester tester, String city) async {
  await tester.tap(find.byTooltip('Поиск'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('search-city-field')), city);
  await tester.pump();
  await tester.ensureVisible(find.widgetWithText(FilledButton, 'Найти'));
  await tester.tap(find.widgetWithText(FilledButton, 'Найти'));
  await tester.pumpAndSettle();
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MapboxConfig.accessToken = '';
    ListingsRepositoryScope.instance = FakeListingsRepository();
  });

  testWidgets('search listings follow the typed city', (tester) async {
    await _pumpSearch(tester);

    expect(find.text('Уютная студия в центре Москвы'), findsNothing);
    expect(find.text('Найти отель'), findsOneWidget);

    await _submitSearchCity(tester, 'Казань');

    expect(find.text('Лофт у Казанского кремля'), findsOneWidget);
    expect(find.text('1 взрослый'), findsOneWidget);
    expect(find.text('Уютная студия в центре Москвы'), findsNothing);

    await _submitSearchCity(tester, 'Владивосток');

    expect(find.text('Лофт у Казанского кремля'), findsNothing);
    expect(
      find.text(
        'Нет подходящих вариантов\nПопробуйте изменить параметры поиска',
      ),
      findsOneWidget,
    );

    await _submitSearchCity(tester, '');

    expect(find.text('Найти отель'), findsOneWidget);
    expect(
      find.text(
        'Укажите город и даты поездки, чтобы увидеть подходящие варианты',
      ),
      findsOneWidget,
    );
  });

  testWidgets('occupied listing is hidden only for overlapping stay dates', (
    tester,
  ) async {
    ListingsRepositoryScope.instance = FakeListingsRepository()
      ..occupiedStays['kazan-loft'] = [
        (DateTime(2026, 10, 1), DateTime(2026, 10, 10)),
      ];

    await _pumpSearch(tester);
    await _submitSearchCity(tester, 'Казань');
    expect(find.text('Лофт у Казанского кремля'), findsOneWidget);

    await tester.tap(find.byTooltip('Поиск'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(SearchQuerySheet))).pop(
      SearchQuery(
        city: 'Казань',
        checkIn: DateTime(2026, 10, 3),
        checkOut: DateTime(2026, 10, 6),
        adults: 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Лофт у Казанского кремля'), findsNothing);
    expect(
      find.text(
        'Нет подходящих вариантов\nПопробуйте изменить параметры поиска',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Карта'));
    await tester.pump();
    expect(find.byKey(const ValueKey('map-pin-kazan-loft')), findsNothing);
    expect(find.byKey(const ValueKey('no-matches-map-card')), findsOneWidget);

    await tester.tap(find.byTooltip('Карта'));
    await tester.pump();
    await tester.tap(find.byTooltip('Поиск'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(SearchQuerySheet))).pop(
      SearchQuery(
        city: 'Казань',
        checkIn: DateTime(2026, 10, 20),
        checkOut: DateTime(2026, 10, 25),
        adults: 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Лофт у Казанского кремля'), findsOneWidget);

    await tester.tap(find.byTooltip('Поиск'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(SearchQuerySheet))).pop(
      const SearchQuery(city: 'Казань', adults: 1),
    );
    await tester.pumpAndSettle();

    expect(find.text('Лофт у Казанского кремля'), findsOneWidget);
  });

  testWidgets('cards price the stay from the selected dates', (tester) async {
    await _pumpSearch(tester);

    await tester.tap(find.byTooltip('Поиск'));
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byType(SearchQuerySheet))).pop(
      SearchQuery(
        city: 'Москва',
        checkIn: DateTime(2026, 10, 1),
        checkOut: DateTime(2026, 10, 31),
        adults: 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('01.10.2026 – 31.10.2026'), findsOneWidget);
    // 30 ночей: 3 034 ₽ × 30 = 91 020 ₽ у московских квартир.
    expect(find.text('91 020 ₽'), findsWidgets);
    expect(find.text('3 034 ₽'), findsNothing);
    expect(find.text('1–30 октября · 30 ночей'), findsWidgets);
  });

  testWidgets('search field opens the stay query bottom sheet', (tester) async {
    await _pumpSearch(tester);

    await tester.tap(find.byTooltip('Поиск'));
    await tester.pumpAndSettle();

    expect(find.text('Снять жилье'), findsOneWidget);
    expect(find.text('Город'), findsOneWidget);
    expect(find.text('Дата заезда'), findsOneWidget);
    expect(find.text('Дата выезда'), findsOneWidget);
    expect(find.text('Количество взрослых'), findsOneWidget);
    expect(find.text('Количество детей'), findsOneWidget);
    expect(find.text('Количество животных'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('Сбросить фильтры'), findsOneWidget);
    expect(find.text('Вернуться'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Найти'), findsOneWidget);

    final findStay = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Найти'),
    );
    expect(findStay.onPressed, isNull);

    await tester.tap(find.text('Вернуться'));
    await tester.pumpAndSettle();
    expect(find.text('Снять жилье'), findsNothing);
  });

  testWidgets('search query sheet can reset and clear the current search', (
    tester,
  ) async {
    await _pumpSearch(tester);
    await _submitSearchCity(tester, 'Казань');
    expect(find.text('Лофт у Казанского кремля'), findsOneWidget);

    await tester.tap(find.byTooltip('Поиск'));
    await tester.pumpAndSettle();
    expect(find.text('Сбросить фильтры'), findsOneWidget);

    await tester.ensureVisible(find.text('Сбросить фильтры'));
    await tester.tap(find.text('Сбросить фильтры'));
    await tester.pump();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('search-city-field')))
          .controller!
          .text,
      isEmpty,
    );
    expect(find.text('1'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Найти'));
    await tester.tap(find.widgetWithText(FilledButton, 'Найти'));
    await tester.pumpAndSettle();

    expect(find.text('Лофт у Казанского кремля'), findsNothing);
    expect(find.text('Найти отель'), findsOneWidget);
  });

  testWidgets('map icon opens map search with price pins', (tester) async {
    await _pumpSearch(tester);

    await tester.tap(find.byTooltip('Карта'));
    await tester.pump();

    expect(find.text('Найти отель'), findsNothing);
    expect(find.text('3 034 ₽'), findsWidgets);
    expect(find.text('3 294 ₽'), findsOneWidget);
    expect(find.text('Частный дом в 10 км от Москвы'), findsNothing);

    final pin = find.byKey(const ValueKey('map-pin-house-10km'));
    Color pinColor() {
      final decoration =
          tester
                  .widget<AnimatedContainer>(
                    find.descendant(
                      of: pin,
                      matching: find.byType(AnimatedContainer),
                    ),
                  )
                  .decoration!
              as ShapeDecoration;
      return decoration.color!;
    }

    expect(pinColor(), AppColors.white);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(pin));
    await tester.pumpAndSettle();

    expect(pinColor(), AppColors.orange);
    expect(
      tester
          .widget<Text>(find.descendant(of: pin, matching: find.byType(Text)))
          .style
          ?.color,
      AppColors.white,
    );

    await tester.tap(pin);
    await tester.pump();

    expect(find.text('Частный дом в 10 км от Москвы'), findsOneWidget);
    expect(find.text('3 294 ₽ / ночь'), findsOneWidget);

    final selected = tester.widget<PricePin>(
      find.byKey(const ValueKey('map-pin-house-10km')),
    );
    expect(selected.active, isTrue);

    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pump();

    expect(find.text('Частный дом в 10 км от Москвы'), findsNothing);
  });

  testWidgets('tapping a list card opens the listing page', (tester) async {
    await _pumpSearch(tester);
    await _submitSearchCity(tester, 'Казань');

    await tester.tap(find.byKey(const ValueKey('listing-card-kazan-loft')));
    await tester.pumpAndSettle();

    expect(find.byType(ListingDetailScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('listing-detail-kazan-loft')),
      findsOneWidget,
    );
    expect(find.text('Казань, ул. Баумана 15'), findsOneWidget);
    expect(find.text('Забронировать'), findsOneWidget);

    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();

    expect(find.byType(ListingDetailScreen), findsNothing);
    expect(find.text('Лофт у Казанского кремля'), findsOneWidget);
  });

  testWidgets('tapping the map preview card opens the listing page', (
    tester,
  ) async {
    await _pumpSearch(tester);

    await tester.tap(find.byTooltip('Карта'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('map-pin-house-10km')));
    await tester.pump();

    expect(find.text('Частный дом в 10 км от Москвы'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('listing-card-house-10km')));
    await tester.pumpAndSettle();

    expect(find.byType(ListingDetailScreen), findsOneWidget);
    expect(find.text('Москва, деревня Дубровки 5'), findsOneWidget);
    expect(find.text('Забронировать'), findsOneWidget);
  });

  testWidgets('favorite on a list card does not open the listing page', (
    tester,
  ) async {
    await _pumpSearch(tester);
    await _submitSearchCity(tester, 'Казань');

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('listing-card-kazan-loft')),
        matching: find.byTooltip('В избранное'),
      ),
    );
    await tester.pump();

    expect(find.byType(ListingDetailScreen), findsNothing);
    expect(find.text('Забронировать'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('listing-card-kazan-loft')),
        matching: find.byTooltip('Убрать из избранного'),
      ),
      findsOneWidget,
    );
  });

  test('selected fallback pin moves above the preview card', () {
    const mapHeight = 400.0;
    const previewExtent = 320.0;
    final idle = fallbackPinTop(
      index: 2,
      selected: false,
      previewExtent: previewExtent,
      mapHeight: mapHeight,
    );
    final selected = fallbackPinTop(
      index: 2,
      selected: true,
      previewExtent: previewExtent,
      mapHeight: mapHeight,
    );

    expect(selected, lessThan(idle));
    expect(selected + 36, lessThan(mapHeight - previewExtent));
  });

  test('pinRevealCenter lifts a centered pin above the preview', () {
    final camera = MapCamera(
      crs: const Epsg3857(),
      center: const LatLng(55.75, 37.62),
      zoom: 12.2,
      rotation: 0,
      nonRotatedSize: const Size(800, 900),
    );
    final dest = pinRevealCenter(
      camera: camera,
      pin: camera.center,
      previewExtent: 320,
    );

    expect(dest, isNotNull);
    expect(dest!.latitude, lessThan(camera.center.latitude));
  });

  test('pinRevealCenter is null until the preview is measured', () {
    final camera = MapCamera(
      crs: const Epsg3857(),
      center: const LatLng(55.75, 37.62),
      zoom: 12.2,
      rotation: 0,
      nonRotatedSize: const Size(800, 900),
    );

    expect(
      pinRevealCenter(camera: camera, pin: camera.center, previewExtent: 0),
      isNull,
    );
  });

  test('pinRevealCenter stays put when the pin is already in view', () {
    final camera = MapCamera(
      crs: const Epsg3857(),
      center: const LatLng(55.75, 37.62),
      zoom: 12.2,
      rotation: 0,
      nonRotatedSize: const Size(800, 900),
    );
    const previewExtent = 320.0;
    final visibleCenter = camera.screenOffsetToLatLng(
      Offset(400, (900 - previewExtent) / 2),
    );

    expect(
      pinRevealCenter(
        camera: camera,
        pin: visibleCenter,
        previewExtent: previewExtent,
      ),
      isNull,
    );
  });

  testWidgets('tapping a map pin keeps it above the preview card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpSearch(tester);

    await tester.tap(find.byTooltip('Карта'));
    await tester.pump();

    final pin = find.byKey(const ValueKey('map-pin-house-10km'));
    final yBefore = tester.getTopLeft(pin).dy;

    await tester.tap(pin);
    await tester.pump();
    await tester.pump();

    expect(find.text('Частный дом в 10 км от Москвы'), findsOneWidget);
    expect(tester.getTopLeft(pin).dy, lessThan(yBefore));

    final card = find
        .ancestor(
          of: find.text('Частный дом в 10 км от Москвы'),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Material &&
                widget.borderRadius == BorderRadius.circular(12),
          ),
        )
        .first;
    expect(tester.getBottomLeft(pin).dy, lessThan(tester.getTopLeft(card).dy));
  });

  testWidgets(
    'tapping a pin again after closing still lifts it above the card',
    (tester) async {
      tester.view.physicalSize = const Size(800, 520);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpSearch(tester);

      await tester.tap(find.byTooltip('Карта'));
      await tester.pump();

      final pin = find.byKey(const ValueKey('map-pin-house-10km'));
      await tester.tap(pin);
      await tester.pump();
      await tester.pump();

      expect(find.text('Частный дом в 10 км от Москвы'), findsOneWidget);

      await tester.tap(find.byTooltip('Закрыть'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Частный дом в 10 км от Москвы'), findsNothing);
      final yClosed = tester.getTopLeft(pin).dy;

      await tester.tap(pin);
      await tester.pump();
      await tester.pump();

      expect(find.text('Частный дом в 10 км от Москвы'), findsOneWidget);
      expect(tester.getTopLeft(pin).dy, lessThan(yClosed));

      final card = find
          .ancestor(
            of: find.text('Частный дом в 10 км от Москвы'),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Material &&
                  widget.borderRadius == BorderRadius.circular(12),
            ),
          )
          .first;
      expect(
        tester.getBottomLeft(pin).dy,
        lessThan(tester.getTopLeft(card).dy),
      );
    },
  );

  testWidgets('filter icon opens the filters bottom sheet', (tester) async {
    await _pumpSearch(tester);

    await tester.tap(find.byTooltip('Фильтры'));
    await tester.pumpAndSettle();

    expect(find.text('Фильтры'), findsOneWidget);
    expect(find.text('Вид жилья'), findsOneWidget);
    expect(find.text('Диапазон цен'), findsOneWidget);
    expect(find.text('от 2 300 ₽'), findsOneWidget);
    expect(find.text('до 3 294 ₽'), findsOneWidget);

    final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
    expect(slider.min, 2300);
    expect(slider.max, 3294);
    expect(slider.values.start, 2300);
    expect(slider.values.end, 3294);
    expect(find.text('Удобства'), findsOneWidget);
    expect(find.text('Дополнительные характеристики'), findsOneWidget);
    expect(find.text('Сбросить фильтры'), findsOneWidget);
    expect(find.text('Вернуться'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Применить'), findsOneWidget);

    final apply = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Применить'),
    );
    expect(apply.onPressed, isNull);

    await tester.tap(find.text('Квартира'));
    await tester.pump();

    await tester.ensureVisible(find.text('Применить'));
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();

    expect(find.text('Диапазон цен'), findsNothing);
    expect(find.byKey(const ValueKey('search-chips-scroll')), findsNothing);
    expect(find.text('Квартира'), findsWidgets);
    expect(find.text('Уютная студия в центре Москвы'), findsOneWidget);
    expect(find.text('Частный дом в 10 км от Москвы'), findsNothing);
    expect(find.byKey(const ValueKey('filter-count-badge')), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('filter-count-badge')),
              matching: find.byType(Text),
            ),
          )
          .data,
      '1',
    );
  });

  testWidgets('empty filters show the no-matches illustration', (tester) async {
    await _pumpSearch(tester);

    await tester.tap(find.byTooltip('Фильтры'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отель'));
    await tester.pump();
    await tester.ensureVisible(find.text('Применить'));
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();

    expect(find.text('Уютная студия в центре Москвы'), findsNothing);
    expect(
      find.text(
        'Нет подходящих вариантов\nПопробуйте изменить параметры поиска',
      ),
      findsOneWidget,
    );
  });

  testWidgets('map with no matches shows a card over the map', (tester) async {
    await _pumpSearch(tester);

    await tester.tap(find.byTooltip('Фильтры'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отель'));
    await tester.pump();
    await tester.ensureVisible(find.text('Применить'));
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('no-matches-map-card')), findsNothing);

    await tester.tap(find.byTooltip('Карта'));
    await tester.pump();

    expect(find.byType(SearchMapView), findsOneWidget);
    expect(find.byKey(const ValueKey('no-matches-map-card')), findsOneWidget);
    expect(
      find.text(
        'Нет подходящих вариантов\nПопробуйте изменить параметры поиска',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('search-chips-scroll')), findsNothing);
    expect(find.text('Отель'), findsNothing);
  });

  testWidgets('applied filter badge counts each selected filter', (
    tester,
  ) async {
    await _pumpSearch(tester);

    expect(find.byKey(const ValueKey('filter-count-badge')), findsNothing);

    await tester.tap(find.byTooltip('Фильтры'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Квартира'));
    await tester.pump();
    await tester.ensureVisible(find.text('Wifi'));
    await tester.tap(find.text('Wifi'));
    await tester.pump();
    await tester.ensureVisible(find.text('Применить'));
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('filter-count-badge')),
              matching: find.byType(Text),
            ),
          )
          .data,
      '2',
    );
    expect(find.byKey(const ValueKey('search-chips-scroll')), findsNothing);
  });

  testWidgets('extended filters do not add chips next to search query chips', (
    tester,
  ) async {
    await _pumpSearch(tester);
    await _submitSearchCity(tester, 'Казань');

    expect(find.byKey(const ValueKey('search-chips-scroll')), findsOneWidget);
    expect(
      tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('search-chips-scroll')),
          )
          .scrollDirection,
      Axis.horizontal,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('search-chips-scroll')),
        matching: find.text('Казань'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('search-chips-scroll')),
        matching: find.text('1 взрослый'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Фильтры'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Wifi'));
    await tester.tap(find.text('Wifi'));
    await tester.pump();
    await tester.ensureVisible(find.text('Применить'));
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('search-chips-scroll')),
        matching: find.text('Wifi'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('search-chips-scroll')),
        matching: find.text('Казань'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('city field keeps typed text when keyboard insets appear', (
    tester,
  ) async {
    await _pumpSearch(tester);
    await tester.tap(find.byTooltip('Поиск'));
    await tester.pumpAndSettle();

    tester.view.viewInsets = const FakeViewPadding(bottom: 400);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();

    expect(tester.takeException(), isNull);
    await tester.enterText(
      find.byKey(const ValueKey('search-city-field')),
      'Казань',
    );
    await tester.pump();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('search-city-field')))
          .controller
          ?.text,
      'Казань',
    );
  });

  testWidgets('city field shows mapbox address suggestions', (tester) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: SearchQuerySheet(
            initial: const SearchQuery(),
            cities: const ['Москва'],
            suggestAddresses: (query) async => [
              const AddressSuggestion(
                label: 'Тверская улица, Москва, Россия',
                city: 'Москва',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('search-city-field')),
      'Твер',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Тверская улица, Москва, Россия'), findsOneWidget);
  });

  testWidgets('full address still finds listings by city', (tester) async {
    await _pumpSearch(tester);

    await _submitSearchCity(tester, 'Тверская улица, 1, Москва, Россия');

    expect(find.text('Уютная студия в центре Москвы'), findsOneWidget);
    expect(find.text('Лофт у Казанского кремля'), findsNothing);
  });

  testWidgets('date picker uses russian locale and format', (tester) async {
    await _pumpSearch(tester);

    await tester.tap(find.byTooltip('Поиск'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('search-check-in-field')));
    await tester.pumpAndSettle();

    expect(find.text('Выберите дату'), findsOneWidget);
    expect(find.text('Отмена'), findsOneWidget);
    expect(find.text('ОК'), findsOneWidget);
    expect(find.textContaining('2026'), findsWidgets);
  });

  test('search filters count each applied option including price', () {
    expect(const SearchFilters().appliedCount, 0);
    expect(const SearchFilters(housingTypes: {'Квартира'}).appliedCount, 1);
    expect(
      const SearchFilters(
        housingTypes: {'Квартира'},
        price: RangeValues(2500, 7000),
      ).appliedCount,
      2,
    );
    expect(
      const SearchFilters(
        housingTypes: {'Квартира'},
        amenities: {'Wifi', 'Телевизор'},
        extras: {'Бассейн'},
        price: RangeValues(2500, 7000),
      ).appliedCount,
      5,
    );
  });

  test('price filter bounds follow listing prices and start at extremes', () {
    final bounds = SearchFilters.boundsFromPrices([
      for (final item in kDemoListings) item.pricePerNight,
    ]);
    expect(bounds.start, 2300);
    expect(bounds.end, 3294);

    final filters = const SearchFilters().withPriceBounds(bounds);
    expect(filters.boundedMin, 2300);
    expect(filters.boundedMax, 3294);
    expect(filters.displayPrice.start, 2300);
    expect(filters.displayPrice.end, 3294);
    expect(filters.price, isNull);
    expect(filters.isActive, isFalse);
  });

  test('price bounds survive missing min/max after hot reload', () {
    const filters = SearchFilters(priceMin: null, priceMax: null);
    expect(filters.displayPrice.start, SearchFilters.fallbackPriceMin);
    expect(filters.displayPrice.end, SearchFilters.fallbackPriceMax);
  });

  test('check-in picker cannot reach the selected check-out day', () {
    final today = DateTime(2026, 9, 12);
    final checkOut = DateTime(2026, 9, 20);
    final bounds = stayDatePickerBounds(
      checkOut: false,
      today: today,
      currentCheckOut: checkOut,
    );

    expect(bounds.first, today);
    expect(bounds.last, DateTime(2026, 9, 19));
    expect(bounds.initial, today);
    expect(!bounds.last.isBefore(bounds.first), isTrue);
    expect(bounds.last.isBefore(checkOut), isTrue);
  });

  test('check-in last day stays at today if check-out is today', () {
    final today = DateTime(2026, 9, 12);
    final bounds = stayDatePickerBounds(
      checkOut: false,
      today: today,
      currentCheckOut: today,
    );

    expect(bounds.first, today);
    expect(bounds.last, today);
  });

  test('check-out picker still starts after the selected check-in', () {
    final today = DateTime(2026, 9, 12);
    final checkIn = DateTime(2026, 9, 15);
    final bounds = stayDatePickerBounds(
      checkOut: true,
      today: today,
      currentCheckIn: checkIn,
    );

    expect(bounds.first, DateTime(2026, 9, 16));
    expect(bounds.initial, DateTime(2026, 9, 16));
  });

  test('missing check-in is filled from today when check-out is later', () {
    final today = DateTime(2026, 9, 16);
    final dates = completeSearchStayDates(
      checkOut: DateTime(2026, 9, 20),
      today: today,
    );

    expect(dates.checkIn, today);
    expect(dates.checkOut, DateTime(2026, 9, 20));
  });

  test('missing check-out becomes the next day after check-in', () {
    final dates = completeSearchStayDates(
      checkIn: DateTime(2026, 9, 16),
      today: DateTime(2026, 9, 16),
    );

    expect(dates.checkIn, DateTime(2026, 9, 16));
    expect(dates.checkOut, DateTime(2026, 9, 17));
  });

  test('mapbox style json switches english labels to russian', () {
    const source = '''
{
  "layers": [
    {
      "id": "country-label",
      "layout": {
        "text-field": ["coalesce", ["get", "name_en"], ["get", "name"]],
        "text-font": ["DIN Pro Medium", "Arial Unicode MS Regular"]
      }
    }
  ]
}
''';
    final localized = localizeMapboxStyleJson(source);
    expect(localized, contains('"name_ru"'));
    expect(localized, isNot(contains('"name_en"')));
    expect(localized, contains('"name"'));

    final decoded = jsonDecode(localized) as Map<String, dynamic>;
    preferAppFonts(decoded);
    final fonts =
        (((decoded['layers'] as List).first as Map)['layout']
            as Map)['text-font'];
    expect(fonts, ['Noto Sans Regular']);
  });

  test('mapbox geocoding parses address features', () {
    const body = '''
{
  "features": [
    {
      "place_name": "Тверская улица, 1, Москва, Россия",
      "place_type": ["address"],
      "text": "1",
      "center": [37.6, 55.75],
      "context": [
        {"id": "place.1", "text": "Москва"},
        {"id": "country.1", "text": "Россия"}
      ]
    }
  ]
}
''';
    final suggestions = parseMapboxGeocodingBody(body);
    expect(suggestions, hasLength(1));
    expect(suggestions.single.label, 'Тверская улица, 1, Москва, Россия');
    expect(suggestions.single.city, 'Москва');
    expect(suggestions.single.longitude, 37.6);
    expect(suggestions.single.latitude, 55.75);
  });

  testWidgets('mapbox token is available from env.local', (tester) async {
    await MapboxConfig.initialize();
    expect(MapboxConfig.accessToken, startsWith('pk.'));
  });
}
