import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:booking/data/auth_repository.dart';
import 'package:booking/data/chat.dart';
import 'package:booking/data/chats_repository.dart';
import 'package:booking/screens/chat/chat_screen.dart';
import 'package:booking/shell/main_shell.dart';
import 'package:booking/theme/app_theme.dart';

import 'fixtures/fake_chats.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatsRepository previousChats;

  setUpAll(() async {
    await initializeDateFormatting('ru');
  });

  setUp(() {
    previousChats = ChatsRepositoryScope.instance;
    ChatsRepositoryScope.setUnread(0);
    ChatScreen.debugPollInterval = Duration.zero;
    AuthRepositoryScope.session.value = const AuthSession(
      userId: 'guest-1',
      email: 'guest@test.com',
    );
  });

  tearDown(() {
    ChatsRepositoryScope.instance = previousChats;
    ChatsRepositoryScope.setUnread(0);
    ChatScreen.debugPollInterval = null;
    AuthRepositoryScope.session.value = null;
  });

  testWidgets('chats tab shows a red unread count', (tester) async {
    ChatsRepositoryScope.instance = FakeChatsRepository(
      chats: demoChatPreviews(),
    );

    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pump();

    final badge = find.byKey(const ValueKey('chats-tab-unread-badge'));
    expect(badge, findsOneWidget);
    expect(
      find.descendant(of: badge, matching: find.text('2')),
      findsOneWidget,
    );

    final box = tester.widget<Container>(badge);
    final decoration = box.decoration! as ShapeDecoration;
    expect(decoration.color, AppColors.badgeRed);
    expect(tester.getSize(badge), const Size(24, 24));

    final label = tester.widget<Text>(
      find.descendant(of: badge, matching: find.text('2')),
    );
    expect(label.style?.color, AppColors.white);
    expect(label.style?.fontSize, 12);
    expect(label.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('chats tab hides the badge without unread messages', (
    tester,
  ) async {
    ChatsRepositoryScope.instance = FakeChatsRepository(chats: const []);

    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pump();

    expect(find.byKey(const ValueKey('chats-tab-unread-badge')), findsNothing);
    expect(ChatsRepositoryScope.unreadCount.value, 0);
  });

  testWidgets('chats tab badge updates after silent list poll', (tester) async {
    ChatScreen.debugPollInterval = const Duration(milliseconds: 40);
    final repo = FakeChatsRepository(chats: demoChatPreviews());
    ChatsRepositoryScope.instance = repo;

    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.byKey(const ValueKey('chats-tab-unread-badge')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('chats-tab-unread-badge')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );

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
        unreadCount: 7,
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('chats-tab-unread-badge')),
        matching: find.text('7'),
      ),
      findsOneWidget,
    );
  });
}
