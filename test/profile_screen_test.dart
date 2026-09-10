import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booking/screens/profile/profile_screen.dart';
import 'package:booking/shell/main_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profile shows stub identity and menu items', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ProfileScreen()),
      ),
    );

    expect(find.text('Владислав Коваленко'), findsOneWidget);
    expect(find.text('+7 (900) 123-45-67'), findsOneWidget);
    expect(find.text('Личные данные'), findsOneWidget);
    expect(find.text('Уведомления'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Написать в поддержку'), findsOneWidget);
    expect(find.text('Выйти из аккаунта'), findsOneWidget);
    expect(find.text('Удалить аккаунт'), findsOneWidget);
    expect(find.text('Авторизация'), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
  });

  testWidgets('profile tab in shell is menu, not auth stub', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainShell(initialIndex: 4)));

    expect(find.text('Владислав Коваленко'), findsOneWidget);
    expect(find.text('Выйти из аккаунта'), findsOneWidget);
    expect(find.text('Авторизация'), findsNothing);
    expect(find.text('Профиль'), findsWidgets);
  });
}
