import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booking/screens/chat/chat_screen.dart';
import 'package:booking/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('chat tab lists stub conversations from the Чаты frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ChatScreen()),
      ),
    );

    expect(find.text('Анна Иваненко'), findsOneWidget);
    expect(find.text('Игнат Прокопенко'), findsOneWidget);
    expect(find.text('Ольга Филипова, Админ'), findsOneWidget);
    expect(find.text('Полина Остапович'), findsOneWidget);
    expect(find.text('13:40'), findsNWidgets(2));
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Москва'), findsNWidgets(2));
    expect(find.text('4 гостя'), findsNWidgets(2));
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.text('Чат с владельцем жилья появится после бронирования'), findsNothing);
  });

  testWidgets('unread badge uses the orange accent', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ChatScreen()),
      ),
    );

    final badge = tester.widget<Text>(find.text('2'));
    expect(badge.style?.color, AppColors.white);

    final box = tester.widget<Container>(
      find.ancestor(of: find.text('2'), matching: find.byType(Container)).first,
    );
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.color, AppColors.orange);
  });
}
