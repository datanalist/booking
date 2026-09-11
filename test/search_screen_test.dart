import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
