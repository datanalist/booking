import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:booking/data/auth_repository.dart';
import 'package:booking/data/chats_repository.dart';
import 'package:booking/screens/chat/chat_screen.dart';
import 'package:booking/theme/app_theme.dart';

import 'fixtures/fake_chats.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatsRepository previous;

  setUpAll(() async {
    await initializeDateFormatting('ru');
  });

  setUp(() {
    previous = ChatsRepositoryScope.instance;
    AuthRepositoryScope.session.value = const AuthSession(
      userId: 'guest-1',
      email: 'guest@test.com',
    );
  });

  tearDown(() {
    ChatsRepositoryScope.instance = previous;
    AuthRepositoryScope.session.value = null;
  });

  testWidgets('chat tab lists conversations from the repository', (
    tester,
  ) async {
    ChatsRepositoryScope.instance = FakeChatsRepository(
      chats: demoChatPreviews(),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ChatScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Анна Иваненко'), findsOneWidget);
    expect(find.text('Игнат Прокопенко'), findsOneWidget);
    expect(find.text('Ольга Филипова, Админ'), findsOneWidget);
    expect(find.text('Полина Остапович'), findsOneWidget);
    expect(find.text('13:40'), findsNWidgets(2));
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Москва'), findsNWidgets(2));
    expect(find.text('4 гостя'), findsNWidgets(2));
    expect(
      find.text('Чат с владельцем жилья появится после бронирования'),
      findsNothing,
    );
  });

  testWidgets('unread badge uses the orange accent', (tester) async {
    ChatsRepositoryScope.instance = FakeChatsRepository(
      chats: demoChatPreviews(),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ChatScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final badge = tester.widget<Text>(find.text('2'));
    expect(badge.style?.color, AppColors.white);

    final box = tester.widget<Container>(
      find.ancestor(of: find.text('2'), matching: find.byType(Container)).first,
    );
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.color, AppColors.orange);
  });

  testWidgets('empty chat tab shows booking hint', (tester) async {
    ChatsRepositoryScope.instance = FakeChatsRepository(chats: const []);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ChatScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Чат с владельцем жилья появится после бронирования'),
      findsOneWidget,
    );
    expect(find.text('Анна Иваненко'), findsNothing);
  });

  testWidgets('tapping a chat opens the thread and sends text', (tester) async {
    final repo = FakeChatsRepository(chats: demoChatPreviews());
    ChatsRepositoryScope.instance = repo;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ChatScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('chat-tile-anna')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chat-input')), findsOneWidget);
    expect(find.text('Уютная студия в центре Москвы'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('chat-input')), 'Привет');
    await tester.tap(find.byKey(const ValueKey('chat-send')));
    await tester.pumpAndSettle();

    expect(find.text('Привет'), findsOneWidget);
    expect(repo.sentTexts, ['Привет']);
  });
}
