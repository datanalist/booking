import 'dart:io';

import 'package:booking/data/booking.dart';
import 'package:booking/data/chat.dart';
import 'package:booking/data/chats_repository.dart';
import 'package:pocketbase/pocketbase.dart';

class FakeChatsRepository implements ChatsRepository {
  FakeChatsRepository({List<ChatPreview>? chats})
      : chats = List.of(chats ?? const []);

  final List<ChatPreview> chats;
  final Map<String, List<ChatMessage>> messagesByChat = {};
  final sentTexts = <String>[];

  @override
  Future<List<ChatPreview>> fetchMine() async => List.of(chats);

  @override
  Future<ChatPreview> getOrCreateForListing({
    required String listingId,
    required String hostId,
    String bookingId = '',
  }) async {
    for (final chat in chats) {
      if (chat.listingId == listingId && chat.hostId == hostId) return chat;
    }
    final created = ChatPreview(
      id: 'chat-$listingId',
      kind: ChatKind.listing,
      guestId: 'guest-1',
      hostId: hostId,
      listingId: listingId,
      bookingId: bookingId,
      counterpartyName: 'Анна Иваненко',
      listingTitle: 'Уютная студия в центре Москвы',
      city: 'Москва',
      checkIn: DateTime(2024, 9, 12),
      checkOut: DateTime(2024, 9, 15),
      adults: 4,
    );
    chats.add(created);
    return created;
  }

  @override
  Future<ChatPreview> getOrCreateForBooking(Booking booking) {
    return getOrCreateForListing(
      listingId: booking.listingId,
      hostId: booking.hostId,
      bookingId: booking.id,
    );
  }

  @override
  Future<List<ChatMessage>> fetchMessages(String chatId) async {
    return List.of(messagesByChat[chatId] ?? const []);
  }

  @override
  Future<ChatMessage> sendText({
    required String chatId,
    required String text,
  }) async {
    sentTexts.add(text);
    final message = ChatMessage(
      id: 'msg-${sentTexts.length}',
      chatId: chatId,
      authorId: 'guest-1',
      text: text,
      created: DateTime.now(),
    );
    messagesByChat.putIfAbsent(chatId, () => []).add(message);
    return message;
  }

  @override
  Future<ChatMessage> sendImages({
    required String chatId,
    required List<File> images,
    String text = '',
  }) async {
    final message = ChatMessage(
      id: 'msg-img-${DateTime.now().microsecondsSinceEpoch}',
      chatId: chatId,
      authorId: 'guest-1',
      text: text,
      imageUrls: images.map((file) => file.path).toList(),
      created: DateTime.now(),
    );
    messagesByChat.putIfAbsent(chatId, () => []).add(message);
    return message;
  }

  @override
  Future<void> markRead(ChatPreview chat) async {}

  @override
  Future<UnsubscribeFunc> subscribeMessages(
    String chatId,
    void Function(ChatMessage message) onCreate,
  ) async {
    return () async {};
  }

  @override
  Future<UnsubscribeFunc> subscribeChats(void Function() onChange) async {
    return () async {};
  }
}

List<ChatPreview> demoChatPreviews() {
  final checkIn = DateTime(2024, 9, 12);
  final checkOut = DateTime(2024, 9, 15);
  final today = DateTime.now();
  return [
    ChatPreview(
      id: 'anna',
      kind: ChatKind.listing,
      guestId: 'guest-1',
      hostId: 'anna',
      counterpartyName: 'Анна Иваненко',
      lastMessage: 'Добрый день, бронирование…',
      lastMessageAt: DateTime(today.year, today.month, today.day, 13, 40),
      listingTitle: 'Уютная студия в центре Москвы',
      listingPhoto: '',
      city: 'Москва',
      checkIn: checkIn,
      checkOut: checkOut,
      adults: 4,
      unreadCount: 2,
    ),
    ChatPreview(
      id: 'ignat',
      kind: ChatKind.listing,
      guestId: 'guest-1',
      hostId: 'ignat',
      counterpartyName: 'Игнат Прокопенко',
      lastMessage: 'Добрый день, бронирование оплачено',
      lastMessageAt: DateTime(2024, 9, 15, 10),
      listingTitle: 'Лофт',
      listingPhoto: '',
      city: 'Минск',
      checkIn: checkIn,
      checkOut: checkOut,
      adults: 3,
    ),
    ChatPreview(
      id: 'admin',
      kind: ChatKind.listing,
      guestId: 'guest-1',
      hostId: 'olga',
      staffId: 'kirill',
      counterpartyName: 'Ольга Филипова',
      staffName: 'Кирилл',
      lastMessage: 'Добрый день, бронирование оплачено',
      lastMessageAt: DateTime(today.year, today.month, today.day, 13, 40),
      listingTitle: 'Студия',
      listingPhoto: '',
      city: 'Москва',
      checkIn: checkIn,
      checkOut: checkOut,
      adults: 4,
    ),
    ChatPreview(
      id: 'polina',
      kind: ChatKind.listing,
      guestId: 'guest-1',
      hostId: 'polina',
      counterpartyName: 'Полина Остапович',
      lastMessage: 'Добрый день, бронирование оплачено',
      lastMessageAt: DateTime(2024, 9, 15, 11),
      listingTitle: 'Квартира',
      listingPhoto: '',
      city: 'Минск',
      checkIn: checkIn,
      checkOut: checkOut,
      adults: 3,
    ),
  ];
}
