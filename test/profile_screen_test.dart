import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booking/data/auth_repository.dart';
import 'package:booking/data/bookings_repository.dart';
import 'package:booking/screens/profile/profile_screen.dart';
import 'package:booking/shell/main_shell.dart';

import 'fixtures/fake_auth.dart';
import 'fixtures/fake_bookings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthRepository previousAuth;
  late AuthSession? previousSession;

  setUp(() {
    previousAuth = AuthRepositoryScope.instance;
    previousSession = AuthRepositoryScope.session.value;
    BookingsRepositoryScope.instance = FakeBookingsRepository();
  });

  tearDown(() {
    AuthRepositoryScope.instance = previousAuth;
    AuthRepositoryScope.session.value = previousSession;
  });

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

  testWidgets('logout cancel keeps the session and profile', (tester) async {
    final auth = FakeAuthRepository()
      ..session = const AuthSession(
        userId: 'user00000000001',
        email: 'guest@mail.com',
        displayName: 'Владислав Коваленко',
        phone: '+7 (900) 123-45-67',
        profileComplete: true,
      );
    AuthRepositoryScope.instance = auth;
    AuthRepositoryScope.session.value = auth.session;

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ProfileScreen(authRepository: auth))),
    );

    await tester.tap(find.byKey(const ValueKey<String>('profile-logout')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('profile-logout-dialog')), findsOneWidget);
    expect(find.text('Выйти из аккаунта?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('profile-logout-no')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('profile-logout-dialog')), findsNothing);
    expect(find.text('Выйти из аккаунта'), findsOneWidget);
    expect(auth.currentSession(), isNotNull);
    expect(AuthRepositoryScope.session.value, isNotNull);
    expect(find.text('Авторизация'), findsNothing);
  });

  testWidgets('logout confirm signs out and opens auth', (tester) async {
    final auth = FakeAuthRepository()
      ..session = const AuthSession(
        userId: 'user00000000001',
        email: 'guest@mail.com',
        displayName: 'Владислав Коваленко',
        phone: '+7 (900) 123-45-67',
        profileComplete: true,
      );
    AuthRepositoryScope.instance = auth;
    AuthRepositoryScope.session.value = auth.session;

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ProfileScreen(authRepository: auth))),
    );

    await tester.tap(find.byKey(const ValueKey<String>('profile-logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('profile-logout-yes')));
    await tester.pumpAndSettle();

    expect(auth.currentSession(), isNull);
    expect(AuthRepositoryScope.session.value, isNull);
    expect(find.text('Авторизация'), findsOneWidget);
    expect(find.text('Выйти из аккаунта'), findsNothing);
  });
}
