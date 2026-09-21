import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:booking/data/listings_repository.dart';
import 'package:booking/screens/listing/stay_dates_sheet.dart';
import 'package:booking/screens/search/search_query_sheet.dart';
import 'package:booking/theme/app_theme.dart';

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

  testWidgets('stay dates sheet matches the booking chrome', (tester) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: StayDatesSheet(
            initialCheckIn: DateTime(2026, 9, 12),
            initialCheckOut: DateTime(2026, 9, 15),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('stay-dates-sheet')), findsOneWidget);
    expect(find.text('Даты проживания'), findsOneWidget);
    expect(find.text('Дата заезда'), findsOneWidget);
    expect(find.text('Дата выезда'), findsOneWidget);
    expect(find.text('12.09.2026'), findsOneWidget);
    expect(find.text('15.09.2026'), findsOneWidget);
    expect(find.text('Вернуться'), findsOneWidget);
    expect(find.text('Сохранить'), findsOneWidget);

    final icons = tester.widgetList<SvgPicture>(find.byType(SvgPicture)).toList();
    expect(icons, hasLength(2));
    for (final icon in icons) {
      expect(icon.width, 16.5);
      expect(icon.height, closeTo(18.1667, 0.001));
    }
  });

  testWidgets('save stays disabled until a stay range exists', (tester) async {
    await tester.pumpWidget(_app(const Scaffold(body: StayDatesSheet())));

    final save = tester.widget<FilledButton>(
      find.byKey(const ValueKey('stay-dates-save')),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('save returns completed stay dates', (tester) async {
    StayDates? result;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await StayDatesSheet.show(
                    context,
                    checkIn: DateTime(2026, 9, 12),
                    checkOut: DateTime(2026, 9, 15),
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
    await tester.tap(find.byKey(const ValueKey('stay-dates-save')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.checkIn, DateTime(2026, 9, 12));
    expect(result!.checkOut, DateTime(2026, 9, 15));
  });

  testWidgets('back discards the sheet without a result', (tester) async {
    StayDates? result = StayDates(
      checkIn: DateTime(2026, 1, 1),
      checkOut: DateTime(2026, 1, 2),
    );
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await StayDatesSheet.show(
                    context,
                    checkIn: DateTime(2026, 9, 12),
                    checkOut: DateTime(2026, 9, 15),
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
    await tester.tap(find.byKey(const ValueKey('stay-dates-back')));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byKey(const ValueKey('stay-dates-sheet')), findsNothing);
  });

  testWidgets('check-in field opens the russian stay date picker', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: StayDatesSheet(
            initialCheckIn: DateTime(2026, 9, 12),
            initialCheckOut: DateTime(2026, 9, 15),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('stay-dates-check-in')));
    await tester.pumpAndSettle();

    expect(find.text('Выберите дату'), findsOneWidget);
    expect(find.text('Отмена'), findsOneWidget);
    expect(find.text('ОК'), findsOneWidget);
  });

  test('stay date format matches the search filter', () {
    expect(formatSearchDate(DateTime(2024, 11, 14)), '14.11.2024');
  });

  testWidgets('occupied night is not selectable and a free day is', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        Scaffold(
          body: StayDatesSheet(
            initialCheckIn: DateTime(2026, 10, 20),
            initialCheckOut: DateTime(2026, 10, 25),
            occupiedRanges: [
              OccupiedStayRange(
                start: DateTime(2026, 10, 1),
                end: DateTime(2026, 10, 10),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('stay-dates-check-in')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ОК'));
    await tester.pumpAndSettle();
    expect(find.text('20.10.2026'), findsOneWidget);
    expect(find.text('03.10.2026'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('stay-dates-check-in')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ОК'));
    await tester.pumpAndSettle();

    expect(find.text('15.10.2026'), findsOneWidget);
    expect(find.text('20.10.2026'), findsNothing);
  });

  testWidgets('save stays disabled when the range overlaps occupied nights', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: StayDatesSheet(
            initialCheckIn: DateTime(2026, 10, 3),
            initialCheckOut: DateTime(2026, 10, 6),
            occupiedRanges: [
              OccupiedStayRange(
                start: DateTime(2026, 10, 1),
                end: DateTime(2026, 10, 10),
              ),
            ],
          ),
        ),
      ),
    );

    final save = tester.widget<FilledButton>(
      find.byKey(const ValueKey('stay-dates-save')),
    );
    expect(save.onPressed, isNull);
  });
}
