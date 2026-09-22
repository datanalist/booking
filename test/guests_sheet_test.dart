import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booking/data/booking_draft.dart';
import 'package:booking/screens/listing/guests_sheet.dart';
import 'package:booking/theme/app_theme.dart';

Widget _app(Widget home) {
  return MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('ru', 'RU'),
    home: home,
  );
}

InkWell _ink(WidgetTester tester, String key) {
  return tester.widget<InkWell>(
    find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(InkWell),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('guests sheet matches the booking chrome', (tester) async {
    await tester.pumpWidget(
      _app(
        const Scaffold(
          body: GuestsSheet(
            initialAdults: 2,
            initialChildren: 1,
            initialPets: 0,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('guests-sheet')), findsOneWidget);
    expect(find.text('Гости'), findsOneWidget);
    expect(find.text('Количество взрослых'), findsOneWidget);
    expect(find.text('12 лет и старше'), findsOneWidget);
    expect(find.text('Количество детей'), findsOneWidget);
    expect(find.text('0-11 лет'), findsOneWidget);
    expect(find.text('Количество животных'), findsOneWidget);
    expect(find.byKey(const ValueKey('guests-adults-value')), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Вернуться'), findsOneWidget);
    expect(find.text('Сохранить'), findsOneWidget);

    final icons = tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .toList();
    expect(icons, hasLength(6));
    for (final icon in icons) {
      expect(icon.width, 16);
      expect(icon.height, 16);
    }
  });

  testWidgets(
    'adults cannot go below one; children and pets can stay at zero',
    (tester) async {
      await tester.pumpWidget(_app(const Scaffold(body: GuestsSheet())));

      expect(_ink(tester, 'guests-adults-minus').onTap, isNull);
      expect(_ink(tester, 'guests-children-minus').onTap, isNull);
      expect(_ink(tester, 'guests-pets-minus').onTap, isNull);

      await tester.tap(find.byKey(const ValueKey('guests-adults-plus')));
      await tester.tap(find.byKey(const ValueKey('guests-children-plus')));
      await tester.tap(find.byKey(const ValueKey('guests-pets-plus')));
      await tester.pump();

      expect(find.byKey(const ValueKey('guests-adults-value')), findsOneWidget);
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
        tester
            .widget<Text>(find.byKey(const ValueKey('guests-pets-value')))
            .data,
        '1',
      );
      expect(_ink(tester, 'guests-adults-minus').onTap, isNotNull);
    },
  );

  testWidgets('pets stay at zero when the listing forbids them', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Scaffold(body: GuestsSheet(initialPets: 3, petsAllowed: false)),
      ),
    );

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('guests-pets-value'))).data,
      '0',
    );
    expect(_ink(tester, 'guests-pets-minus').onTap, isNull);
    expect(_ink(tester, 'guests-pets-plus').onTap, isNull);
  });

  testWidgets('save returns the selected guest counts', (tester) async {
    StayGuests? result;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await GuestsSheet.show(
                    context,
                    adults: 2,
                    children: 1,
                    pets: 0,
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
    await tester.tap(find.byKey(const ValueKey('guests-pets-plus')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('guests-save')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.adults, 2);
    expect(result!.children, 1);
    expect(result!.pets, 1);
  });

  testWidgets('back discards the sheet without a result', (tester) async {
    StayGuests? result = const StayGuests(adults: 4, children: 2, pets: 1);
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await GuestsSheet.show(
                    context,
                    adults: 2,
                    children: 1,
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
    await tester.tap(find.byKey(const ValueKey('guests-adults-plus')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('guests-back')));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byKey(const ValueKey('guests-sheet')), findsNothing);
  });
}
