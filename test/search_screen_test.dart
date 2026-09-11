import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booking/config/mapbox_config.dart';
import 'package:booking/screens/search/search_map_view.dart';
import 'package:booking/screens/search/search_screen.dart';
import 'package:booking/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('search listings follow the typed city', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: SearchScreen()),
      ),
    );

    expect(find.text('Уютная студия в центре Москвы'), findsNothing);
    expect(find.text('Найти отель'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Казань');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(find.text('Лофт у Казанского кремля'), findsOneWidget);
    expect(find.text('Уютная студия в центре Москвы'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Владивосток');
    await tester.pump();

    expect(find.text('Лофт у Казанского кремля'), findsNothing);
    expect(
      find.text(
        'Нет подходящих вариантов.\nПопробуйте изменить параметры поиска',
      ),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    expect(find.text('Найти отель'), findsOneWidget);
    expect(
      find.text(
        'Укажите город и даты поездки, чтобы увидеть подходящие варианты',
      ),
      findsOneWidget,
    );
  });

  testWidgets('map icon opens map search with price pins', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: SearchScreen()),
      ),
    );

    await tester.tap(find.byTooltip('Карта'));
    await tester.pump();

    expect(find.text('Найти отель'), findsNothing);
    expect(find.text('15 170 ₽'), findsWidgets);
    expect(find.text('16 470 ₽'), findsOneWidget);
    expect(find.text('Частный дом в 10 км от Москвы'), findsNothing);

    final pin = find.byKey(const ValueKey('map-pin-house-10km'));
    Color pinColor() {
      final decoration = tester
          .widget<AnimatedContainer>(
            find.descendant(of: pin, matching: find.byType(AnimatedContainer)),
          )
          .decoration! as ShapeDecoration;
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

  testWidgets('tapping a map pin keeps it above the preview card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: SearchScreen()),
      ),
    );

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

  testWidgets('mapbox token is available from env.local', (tester) async {
    await MapboxConfig.initialize();
    expect(MapboxConfig.accessToken, startsWith('pk.'));
  });
}
