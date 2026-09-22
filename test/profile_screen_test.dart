import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booking/data/auth_repository.dart';
import 'package:booking/data/bookings_repository.dart';
import 'package:booking/data/chats_repository.dart';
import 'package:booking/data/notifications_repository.dart';
import 'package:booking/data/chat.dart';
import 'package:booking/screens/chat/chat_thread_screen.dart';
import 'package:booking/screens/profile/profile_screen.dart';
import 'package:booking/shell/main_shell.dart';

import 'fixtures/fake_auth.dart';
import 'fixtures/fake_bookings.dart';
import 'fixtures/fake_chats.dart';
import 'fixtures/fake_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthRepository previousAuth;
  late AuthSession? previousSession;
  late NotificationsRepository previousNotifications;
  late ChatsRepository previousChats;

  setUp(() {
    previousAuth = AuthRepositoryScope.instance;
    previousSession = AuthRepositoryScope.session.value;
    previousNotifications = NotificationsRepositoryScope.instance;
    previousChats = ChatsRepositoryScope.instance;
    BookingsRepositoryScope.instance = FakeBookingsRepository();
    NotificationsRepositoryScope.instance = FakeNotificationsRepository();
    NotificationsRepositoryScope.setUnread(0);
    ChatsRepositoryScope.instance = FakeChatsRepository();
    ChatsRepositoryScope.setUnread(0);
  });

  tearDown(() {
    AuthRepositoryScope.instance = previousAuth;
    AuthRepositoryScope.session.value = previousSession;
    NotificationsRepositoryScope.instance = previousNotifications;
    NotificationsRepositoryScope.setUnread(0);
    ChatsRepositoryScope.instance = previousChats;
    ChatsRepositoryScope.setUnread(0);
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
    expect(find.text('2'), findsNothing);
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

  testWidgets('delete cancel keeps the session and does not delete', (
    tester,
  ) async {
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

    await tester.tap(find.byKey(const ValueKey<String>('profile-delete-account')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('profile-delete-dialog')), findsOneWidget);
    expect(find.text('Удалить аккаунт?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('profile-delete-no')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('profile-delete-dialog')), findsNothing);
    expect(find.text('Удалить аккаунт'), findsOneWidget);
    expect(auth.deleteAccountCalls, 0);
    expect(auth.currentSession(), isNotNull);
    expect(AuthRepositoryScope.session.value, isNotNull);
    expect(find.text('Авторизация'), findsNothing);
  });

  testWidgets('delete confirm removes the account and opens auth', (
    tester,
  ) async {
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

    await tester.tap(find.byKey(const ValueKey<String>('profile-delete-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('profile-delete-yes')));
    await tester.pumpAndSettle();

    expect(auth.deleteAccountCalls, 1);
    expect(auth.currentSession(), isNull);
    expect(AuthRepositoryScope.session.value, isNull);
    expect(find.text('Авторизация'), findsOneWidget);
    expect(find.text('Удалить аккаунт'), findsNothing);
  });

  testWidgets('delete error keeps the session and shows a message', (
    tester,
  ) async {
    final auth = FakeAuthRepository()
      ..failDeleteAccount = true
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

    await tester.tap(find.byKey(const ValueKey<String>('profile-delete-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('profile-delete-yes')));
    await tester.pumpAndSettle();

    expect(auth.deleteAccountCalls, 1);
    expect(auth.currentSession(), isNotNull);
    expect(AuthRepositoryScope.session.value, isNotNull);
    expect(find.text('Авторизация'), findsNothing);
    expect(find.text('Удалить аккаунт'), findsOneWidget);
    expect(
      find.text('Не удалось удалить аккаунт. Проверьте соединение'),
      findsOneWidget,
    );
  });

  testWidgets('support menu opens one support chat without a listing', (
    tester,
  ) async {
    ChatThreadScreen.debugPollInterval = Duration.zero;
    addTearDown(() => ChatThreadScreen.debugPollInterval = null);

    final chats = FakeChatsRepository();
    ChatsRepositoryScope.instance = chats;

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProfileScreen())),
    );

    await tester.tap(find.byKey(const ValueKey<String>('profile-support')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('chat-thread')), findsOneWidget);
    expect(find.text('Поддержка'), findsOneWidget);
    expect(find.text('Объявление'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('chat-thread-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('profile-support')));
    await tester.pumpAndSettle();

    expect(
      chats.chats.where((chat) => chat.kind == ChatKind.support),
      hasLength(1),
    );
  });
}
