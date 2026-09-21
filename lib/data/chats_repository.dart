import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import 'auth_repository.dart';
import 'booking.dart';
import 'bookings_repository.dart';
import 'chat.dart';
import 'pocketbase_client.dart';
import 'pocketbase_filter.dart';

class ChatException implements Exception {
  const ChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class ChatsRepository {
  Future<List<ChatPreview>> fetchMine();

  Future<ChatPreview> getOrCreateForListing({
    required String listingId,
    required String hostId,
    String bookingId = '',
  });

  Future<ChatPreview> getOrCreateForBooking(Booking booking);

  Future<List<ChatMessage>> fetchMessages(String chatId);

  Future<ChatMessage> sendText({
    required String chatId,
    required String text,
  });

  Future<ChatMessage> sendImages({
    required String chatId,
    required List<File> images,
    String text = '',
  });

  Future<void> markRead(ChatPreview chat);

  Future<UnsubscribeFunc> subscribeMessages(
    String chatId,
    void Function(ChatMessage message) onCreate,
  );

  Future<UnsubscribeFunc> subscribeChats(
    void Function() onChange,
  );
}

class ChatsRepositoryScope {
  static ChatsRepository instance = PocketBaseChatsRepository();
  static final listVersion = ValueNotifier<int>(0);

  static void notifyChanged() {
    listVersion.value++;
  }
}

class PocketBaseChatsRepository implements ChatsRepository {
  PocketBaseChatsRepository({PocketBase? client}) : _client = client;

  static const chatsCollection = PbCollection.chats;
  static const messagesCollection = PbCollection.messages;
  // listing.host — актуальный владелец объявления (chat.host может устареть
  // после смены хозяина в админке).
  static const _chatExpand = 'host,guest,staff,listing,listing.host,booking';
  static const _messageExpand = 'author';

  final PocketBase? _client;
  PocketBase get _pb => _client ?? pocketBase;

  String get _userId {
    final session = AuthRepositoryScope.session.value;
    if (session != null && session.userId.isNotEmpty) return session.userId;
    return _pb.authStore.record?.id ?? '';
  }

  @override
  Future<List<ChatPreview>> fetchMine() async {
    final userId = _userId;
    if (userId.isEmpty || !_pb.authStore.isValid) return const [];
    final records = await _pb.collection(chatsCollection).getFullList(
      filter: pbFilter(
        'guest = {:userId} || host = {:userId} || staff = {:userId}',
        {'userId': userId},
      ),
      expand: _chatExpand,
      sort: '-last_message_at,-updated',
    );
    final previews = <ChatPreview>[];
    for (final record in records) {
      final preview = _mapChat(record, userId);
      previews.add(
        preview.copyWith(unreadCount: await _unreadCount(preview, userId)),
      );
    }
    return previews;
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
  Future<ChatPreview> getOrCreateForListing({
    required String listingId,
    required String hostId,
    String bookingId = '',
  }) async {
    final guestId = _userId;
    if (guestId.isEmpty) {
      throw const ChatException('Войдите, чтобы написать владельцу');
    }
    if (listingId.isEmpty) {
      throw const ChatException('Не удалось определить объявление');
    }
    if (hostId.isEmpty) {
      throw const ChatException('Не удалось определить владельца жилья');
    }

    var resolvedBookingId = bookingId.trim();
    if (resolvedBookingId.isEmpty) {
      final eligible = await BookingsRepositoryScope.instance
          .findHostChatEligible(listingId: listingId);
      resolvedBookingId = eligible?.id ?? '';
    }

    final existing = await _pb.collection(chatsCollection).getList(
      page: 1,
      perPage: 1,
      filter: pbFilter(
        'kind = "listing" && listing = {:listingId} && guest = {:guestId}',
        {'listingId': listingId, 'guestId': guestId},
      ),
      expand: _chatExpand,
    );
    if (existing.items.isNotEmpty) {
      final chat = _mapChat(existing.items.first, guestId);
      final body = <String, dynamic>{};
      // Источник правды для собеседника — текущий host объявления / брони.
      if (hostId.isNotEmpty && chat.hostId != hostId) {
        body['host'] = hostId;
      }
      if (resolvedBookingId.isNotEmpty && chat.bookingId.isEmpty) {
        body['booking'] = resolvedBookingId;
      }
      if (body.isNotEmpty) {
        try {
          final updated = await _pb.collection(chatsCollection).update(
            chat.id,
            body: body,
            expand: _chatExpand,
          );
          ChatsRepositoryScope.notifyChanged();
          return _mapChat(updated, guestId);
        } on ClientException {
          // Правила API могли запретить смену host — шапка всё равно
          // берёт имя из listing.host в _mapChat.
          return chat;
        }
      }
      return chat;
    }

    if (resolvedBookingId.isEmpty) {
      throw const ChatException(
        'Чат с владельцем откроется после бронирования этого жилья',
      );
    }

    try {
      final body = <String, dynamic>{
        'kind': ChatKind.listing.apiKey,
        'listing': listingId,
        'guest': guestId,
        'host': hostId,
        'booking': resolvedBookingId,
      };
      final record = await _pb.collection(chatsCollection).create(
        body: body,
        expand: _chatExpand,
      );
      ChatsRepositoryScope.notifyChanged();
      return _mapChat(record, guestId);
    } on ClientException catch (error) {
      // Race with unique hook: another create won — fetch again.
      final again = await _pb.collection(chatsCollection).getList(
        page: 1,
        perPage: 1,
        filter: pbFilter(
          'kind = "listing" && listing = {:listingId} && guest = {:guestId}',
          {'listingId': listingId, 'guestId': guestId},
        ),
        expand: _chatExpand,
      );
      if (again.items.isNotEmpty) {
        return _mapChat(again.items.first, guestId);
      }
      throw ChatException(_messageFor(error));
    }
  }

  @override
  Future<List<ChatMessage>> fetchMessages(String chatId) async {
    if (chatId.isEmpty) return const [];
    final records = await _pb.collection(messagesCollection).getFullList(
      filter: pbFilter('chat = {:chatId}', {'chatId': chatId}),
      expand: _messageExpand,
      sort: 'created',
    );
    final chat = await _loadChat(chatId);
    return [
      for (final record in records) _mapMessage(record, chat),
    ];
  }

  @override
  Future<ChatMessage> sendText({
    required String chatId,
    required String text,
  }) async {
    final authorId = _userId;
    if (authorId.isEmpty) {
      throw const ChatException('Войдите, чтобы отправить сообщение');
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const ChatException('Введите сообщение');
    }
    try {
      final record = await _pb.collection(messagesCollection).create(
        body: {
          'chat': chatId,
          'author': authorId,
          'text': trimmed,
        },
        expand: _messageExpand,
      );
      await _updateChatPreview(chatId, trimmed);
      await _touchLastRead(chatId, authorId);
      ChatsRepositoryScope.notifyChanged();
      final chat = await _loadChat(chatId);
      return _mapMessage(record, chat);
    } on ClientException catch (error) {
      throw ChatException(_messageFor(error));
    }
  }

  @override
  Future<ChatMessage> sendImages({
    required String chatId,
    required List<File> images,
    String text = '',
  }) async {
    final authorId = _userId;
    if (authorId.isEmpty) {
      throw const ChatException('Войдите, чтобы отправить сообщение');
    }
    if (images.isEmpty) {
      throw const ChatException('Выберите фото');
    }
    final files = <http.MultipartFile>[];
    for (var i = 0; i < images.length; i++) {
      files.add(
        http.MultipartFile.fromBytes(
          'images',
          await images[i].readAsBytes(),
          filename: 'chat-$i.jpg',
        ),
      );
    }
    try {
      final body = <String, dynamic>{
        'chat': chatId,
        'author': authorId,
      };
      final trimmed = text.trim();
      if (trimmed.isNotEmpty) body['text'] = trimmed;
      final record = await _pb.collection(messagesCollection).create(
        body: body,
        files: files,
        expand: _messageExpand,
      );
      await _updateChatPreview(
        chatId,
        trimmed.isEmpty ? 'Фото' : trimmed,
      );
      await _touchLastRead(chatId, authorId);
      ChatsRepositoryScope.notifyChanged();
      final chat = await _loadChat(chatId);
      return _mapMessage(record, chat);
    } on ClientException catch (error) {
      throw ChatException(_messageFor(error));
    }
  }

  @override
  Future<void> markRead(ChatPreview chat) async {
    final userId = _userId;
    if (userId.isEmpty || chat.id.isEmpty) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final body = <String, dynamic>{};
    if (userId == chat.guestId) {
      body['guest_last_read'] = now;
    } else if (userId == chat.hostId || userId == chat.staffId) {
      body['host_last_read'] = now;
    } else {
      return;
    }
    try {
      await _pb.collection(chatsCollection).update(chat.id, body: body);
      ChatsRepositoryScope.notifyChanged();
    } on ClientException {
      // Non-fatal: message still delivered.
    }
  }

  @override
  Future<UnsubscribeFunc> subscribeMessages(
    String chatId,
    void Function(ChatMessage message) onCreate,
  ) {
    return _pb.collection(messagesCollection).subscribe(
      '*',
      (event) async {
        if (event.action != 'create') return;
        final record = event.record;
        if (record == null) return;
        if (record.get<String>('chat', '') != chatId) return;
        try {
          final full = await _pb.collection(messagesCollection).getOne(
            record.id,
            expand: _messageExpand,
          );
          final chat = await _loadChat(chatId);
          onCreate(_mapMessage(full, chat));
        } catch (_) {
          // Ignore transient realtime failures.
        }
      },
      filter: pbFilter('chat = {:chatId}', {'chatId': chatId}),
    );
  }

  @override
  Future<UnsubscribeFunc> subscribeChats(void Function() onChange) {
    return _pb.collection(chatsCollection).subscribe('*', (event) {
      onChange();
    });
  }

  Future<ChatPreview?> _loadChat(String chatId) async {
    if (chatId.isEmpty) return null;
    try {
      final record = await _pb.collection(chatsCollection).getOne(
        chatId,
        expand: _chatExpand,
      );
      return _mapChat(record, _userId);
    } on ClientException {
      return null;
    }
  }

  Future<void> _touchLastRead(String chatId, String userId) async {
    final chat = await _loadChat(chatId);
    if (chat == null) return;
    await markRead(chat);
  }

  Future<void> _updateChatPreview(String chatId, String text) async {
    var preview = text.trim();
    if (preview.isEmpty) preview = 'Сообщение';
    if (preview.length > 120) {
      preview = '${preview.substring(0, 117)}…';
    }
    try {
      await _pb.collection(chatsCollection).update(
        chatId,
        body: {
          'last_message': preview,
          'last_message_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } on ClientException {
      // Hook on the server may already have updated the preview.
    }
  }

  Future<int> _unreadCount(ChatPreview chat, String userId) async {
    final lastRead = userId == chat.guestId
        ? chat.guestLastRead
        : chat.hostLastRead;
    final params = <String, Object?>{
      'chatId': chat.id,
      'userId': userId,
    };
    var filter = 'chat = {:chatId} && author != {:userId}';
    if (lastRead != null) {
      params['lastRead'] = lastRead.toUtc();
      filter = '$filter && created > {:lastRead}';
    }
    try {
      final result = await _pb.collection(messagesCollection).getList(
        page: 1,
        perPage: 1,
        filter: pbFilter(filter, params),
      );
      return result.totalItems;
    } on ClientException {
      return 0;
    }
  }

  ChatPreview _mapChat(RecordModel record, String viewerId) {
    final guestId = _relationId(record, 'guest');
    final staffId = _relationId(record, 'staff');
    final host = _expanded(record, 'host');
    final guest = _expanded(record, 'guest');
    final staff = _expanded(record, 'staff');
    final listing = _expanded(record, 'listing');
    final booking = _expanded(record, 'booking');
    // Актуальный владелец — из объявления; chat.host мог остаться от прежнего.
    final listingHost = listing == null ? null : _expanded(listing, 'host');
    final listingHostId = listing == null
        ? ''
        : _relationId(listing, 'host');
    final chatHostId = _relationId(record, 'host');
    final hostId =
        listingHostId.isNotEmpty ? listingHostId : chatHostId;
    // Не подставляем expand chat.host, если он уже не совпадает с listing.host.
    final RecordModel? hostRecord;
    if (listingHost != null) {
      hostRecord = listingHost;
    } else if (listingHostId.isEmpty || listingHostId == chatHostId) {
      hostRecord = host;
    } else {
      hostRecord = null;
    }

    final amGuest = viewerId == guestId;
    final counterparty = amGuest ? hostRecord : guest;

    final listingPhotos =
        listing == null ? const <String>[] : _fileUrls(listing, 'photos');

    return ChatPreview(
      id: record.id,
      kind: ChatKind.fromApi(record.get<String>('kind', '')),
      guestId: guestId,
      hostId: hostId,
      staffId: staffId,
      listingId: _relationId(record, 'listing'),
      bookingId: _relationId(record, 'booking'),
      lastMessage: record.get<String>('last_message', ''),
      lastMessageAt: _date(record, 'last_message_at'),
      guestLastRead: _date(record, 'guest_last_read'),
      hostLastRead: _date(record, 'host_last_read'),
      counterpartyName: _personName(counterparty),
      counterpartyAvatar: _avatarUrl(counterparty),
      staffName: _personName(staff),
      staffAvatar: _avatarUrl(staff),
      listingTitle: listing?.get<String>('title', '') ?? '',
      listingPhoto: listingPhotos.isEmpty ? '' : listingPhotos.first,
      city: listing?.get<String>('city', '') ?? '',
      checkIn: booking == null ? null : _date(booking, 'check_in'),
      checkOut: booking == null ? null : _date(booking, 'check_out'),
      adults: booking == null ? 0 : _number(booking, 'adults'),
      children: booking == null ? 0 : _number(booking, 'children'),
    );
  }

  ChatMessage _mapMessage(RecordModel record, ChatPreview? chat) {
    final author = _expanded(record, 'author');
    final authorId = _relationId(record, 'author');
    var role = '';
    if (chat != null) {
      if (authorId == chat.staffId) {
        role = 'админ';
      } else if (authorId == chat.hostId) {
        role = 'владелец жилья';
      } else if (authorId == chat.guestId) {
        role = 'гость';
      }
    }
    return ChatMessage(
      id: record.id,
      chatId: _relationId(record, 'chat'),
      authorId: authorId,
      text: record.get<String>('text', ''),
      imageUrls: _fileUrls(record, 'images'),
      fileUrls: _fileUrls(record, 'files'),
      created: _date(record, 'created'),
      authorName: _personName(author),
      authorAvatar: _avatarUrl(author),
      authorRoleLabel: role,
    );
  }

  RecordModel? _expanded(RecordModel record, String field) {
    final raw = record.data['expand'];
    if (raw is! Map) return null;
    final value = raw[field];
    if (value is Map<String, dynamic>) return RecordModel.fromJson(value);
    if (value is Map) {
      return RecordModel.fromJson(Map<String, dynamic>.from(value));
    }
    return null;
  }

  String _relationId(RecordModel record, String field) {
    final expanded = _expanded(record, field);
    if (expanded != null) return expanded.id;
    return record.get<String>(field, '');
  }

  String _personName(RecordModel? record) {
    if (record == null) return '';
    final first = record.get<String>('first_name', '').trim();
    final last = record.get<String>('last_name', '').trim();
    final joined = '$first $last'.trim();
    if (joined.isNotEmpty) return joined;
    final name = record.get<String>('name', '').trim();
    if (name.isNotEmpty) return name;
    return record.get<String>('email', '').trim();
  }

  String _avatarUrl(RecordModel? record) {
    if (record == null) return '';
    final name = record.get<String>('avatar', '');
    if (name.isEmpty) return '';
    return _pb.files.getURL(record, name).toString();
  }

  List<String> _fileUrls(RecordModel record, String field) {
    final raw = record.data[field];
    final names = <String>[];
    if (raw is List) {
      for (final item in raw) {
        if (item != null && '$item'.isNotEmpty) names.add('$item');
      }
    } else if (raw is String && raw.isNotEmpty) {
      names.add(raw);
    }
    return [
      for (final name in names) _pb.files.getURL(record, name).toString(),
    ];
  }

  DateTime? _date(RecordModel record, String field) {
    final raw = record.data[field];
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }

  int _number(RecordModel record, String field) {
    final raw = record.data[field];
    if (raw is num) return raw.round();
    return int.tryParse('$raw') ?? 0;
  }

  String _messageFor(ClientException error) {
    final response = error.response;
    final message = response['message'];
    if (message is String && message.isNotEmpty) return message;
    return 'Не удалось выполнить действие в чате';
  }
}
