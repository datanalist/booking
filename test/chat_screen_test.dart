import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:booking/data/auth_repository.dart';
import 'package:booking/data/chat.dart';
import 'package:booking/data/chats_repository.dart';
import 'package:booking/screens/chat/chat_screen.dart';
import 'package:booking/screens/chat/chat_thread_screen.dart';
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
    ChatScreen.debugPollInterval = Duration.zero;
    ChatThreadScreen.debugPollInterval = Duration.zero;
  });

  tearDown(() {
    ChatsRepositoryScope.instance = previous;
    AuthRepositoryScope.session.value = null;
    ChatScreen.debugPollInterval = null;
    ChatThreadScreen.debugPollInterval = null;
  });

  testWidgets('chat tab lists conversations from the repository', (
    tester,
  ) async {
    ChatsRepositoryScope.instance = FakeChatsRepository(
      chats: demoChatPreviews(),
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ChatScreen())),
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
      const MaterialApp(home: Scaffold(body: ChatScreen())),
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
      const MaterialApp(home: Scaffold(body: ChatScreen())),
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
      const MaterialApp(home: Scaffold(body: ChatScreen())),
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

  testWidgets('composer bar matches Figma 1:14230 geometry', (tester) async {
    ChatsRepositoryScope.instance = FakeChatsRepository(
      chats: demoChatPreviews(),
    );
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: ChatThreadScreen(chat: demoChatPreviews().first)),
    );
    await tester.pumpAndSettle();

    final attach = tester.getRect(find.byKey(const ValueKey('chat-attach')));
    final send = tester.getRect(find.byKey(const ValueKey('chat-send')));
    final field = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('chat-input')),
        matching: find.byType(InputDecorator),
      ),
    );
    final mic = tester.getRect(find.byKey(const ValueKey('chat-mic')));

    expect(attach.size, const Size(40, 40));
    expect(send.size, const Size(40, 40));
    expect(attach.left, 16);
    expect(send.right, 393 - 16);
    expect(field.left - attach.right, 16);
    expect(send.left - field.right, 16);
    expect(field.height, 40);
    expect(mic.size, const Size(45, 36));
    expect(field.right - mic.right, 0);
    expect(field.center.dy, attach.center.dy);
  });

  testWidgets('incoming message appears when chat preview updates', (
    tester,
  ) async {
    final repo = FakeChatsRepository(chats: demoChatPreviews());
    repo.messagesByChat['anna'] = [
      ChatMessage(
        id: 'local-1',
        chatId: 'anna',
        authorId: 'guest-1',
        text: 'Уже тут',
        created: DateTime(2024, 9, 12, 13),
      ),
    ];
    ChatsRepositoryScope.instance = repo;

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ChatScreen())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('chat-tile-anna')));
    await tester.pumpAndSettle();
    expect(find.text('Уже тут'), findsOneWidget);
    expect(find.text('Вы тут'), findsNothing);

    repo.emitIncomingViaChat(
      'anna',
      ChatMessage(
        id: 'remote-vy-tut',
        chatId: 'anna',
        authorId: 'anna',
        text: 'Вы тут',
        created: DateTime(2024, 9, 12, 13, 40),
      ),
    );
    // subscribeChat → _pollMessages; без ожидания полного poll-интервала.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Вы тут'), findsOneWidget);
  });

  testWidgets('list preview and unread refresh when chats subscription fires', (
    tester,
  ) async {
    final repo = FakeChatsRepository(chats: demoChatPreviews());
    ChatsRepositoryScope.instance = repo;
    ChatsRepositoryScope.setUnread(0);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ChatScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Добрый день, бронирование…'), findsOneWidget);
    expect(ChatsRepositoryScope.unreadCount.value, 2);

    final base = demoChatPreviews().first;
    repo.replaceChat(
      ChatPreview(
        id: base.id,
        kind: base.kind,
        guestId: base.guestId,
        hostId: base.hostId,
        counterpartyName: base.counterpartyName,
        lastMessage: '666',
        lastMessageAt: DateTime(2026, 9, 22, 16, 6),
        listingTitle: base.listingTitle,
        city: base.city,
        checkIn: base.checkIn,
        checkOut: base.checkOut,
        adults: base.adults,
        unreadCount: 5,
      ),
    );
    repo.emitChatsChanged();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('666'), findsOneWidget);
    expect(find.text('Добрый день, бронирование…'), findsNothing);
    expect(ChatsRepositoryScope.unreadCount.value, 5);
  });

  testWidgets('list polls for new previews when chats SSE stays quiet', (
    tester,
  ) async {
    ChatScreen.debugPollInterval = const Duration(milliseconds: 40);
    final repo = FakeChatsRepository(chats: demoChatPreviews());
    ChatsRepositoryScope.instance = repo;

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ChatScreen())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('Добрый день, бронирование…'), findsOneWidget);

    final base = demoChatPreviews().first;
    repo.replaceChat(
      ChatPreview(
        id: base.id,
        kind: base.kind,
        guestId: base.guestId,
        hostId: base.hostId,
        counterpartyName: base.counterpartyName,
        lastMessage: '555',
        lastMessageAt: DateTime(2026, 9, 22, 15, 47),
        listingTitle: base.listingTitle,
        city: base.city,
        checkIn: base.checkIn,
        checkOut: base.checkOut,
        adults: base.adults,
        unreadCount: 4,
      ),
    );
    // SSE молчит — только poll подхватывает превью и бейдж.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    expect(find.text('555'), findsOneWidget);
    expect(ChatsRepositoryScope.unreadCount.value, 4);
  });

  testWidgets('queued refresh applies a newer preview after a hung fetch', (
    tester,
  ) async {
    final repo = FakeChatsRepository(chats: demoChatPreviews());
    final hold = Completer<void>();
    repo.holdFetchMine = hold;
    ChatsRepositoryScope.instance = repo;

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ChatScreen())),
    );
    await tester.pump();

    final base = demoChatPreviews().first;
    repo.replaceChat(
      ChatPreview(
        id: base.id,
        kind: base.kind,
        guestId: base.guestId,
        hostId: base.hostId,
        counterpartyName: base.counterpartyName,
        lastMessage: 'yed',
        lastMessageAt: DateTime(2026, 9, 23, 18),
        listingTitle: base.listingTitle,
        city: base.city,
        checkIn: base.checkIn,
        checkOut: base.checkOut,
        adults: base.adults,
      ),
    );
    repo.emitChatsChanged();
    hold.complete();
    await tester.pump();
    await tester.pump();

    expect(find.text('yed'), findsOneWidget);
    expect(find.text('Добрый день, бронирование…'), findsNothing);
  });

  testWidgets('leaving a thread shows its latest message in the list', (
    tester,
  ) async {
    final repo = FakeChatsRepository(chats: demoChatPreviews());
    final base = demoChatPreviews().first;
    repo.replaceChat(
      ChatPreview(
        id: base.id,
        kind: base.kind,
        guestId: base.guestId,
        hostId: base.hostId,
        counterpartyName: base.counterpartyName,
        lastMessage: '0000',
        lastMessageAt: DateTime(2026, 9, 22, 22, 41),
        listingTitle: base.listingTitle,
        city: base.city,
        checkIn: base.checkIn,
        checkOut: base.checkOut,
        adults: base.adults,
      ),
    );
    repo.messagesByChat['anna'] = [
      ChatMessage(
        id: 'old',
        chatId: 'anna',
        authorId: 'anna',
        text: '0000',
        created: DateTime(2026, 9, 22, 22, 41),
      ),
      ChatMessage(
        id: 'new',
        chatId: 'anna',
        authorId: 'anna',
        text: 'yed',
        created: DateTime(2026, 9, 23, 3, 53),
      ),
    ];
    ChatsRepositoryScope.instance = repo;

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ChatScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.text('0000'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat-tile-anna')));
    await tester.pumpAndSettle();
    expect(find.text('yed'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat-thread-back')));
    await tester.pumpAndSettle();

    expect(find.text('yed'), findsOneWidget);
    expect(find.text('Добрый день, бронирование…'), findsNothing);
  });
}
