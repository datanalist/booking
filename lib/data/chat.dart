import 'package:intl/intl.dart';

enum ChatKind {
  listing('listing'),
  support('support');

  const ChatKind(this.apiKey);

  final String apiKey;

  static ChatKind fromApi(String value) {
    for (final kind in ChatKind.values) {
      if (kind.apiKey == value) return kind;
    }
    return ChatKind.listing;
  }
}

class ChatPreview {
  const ChatPreview({
    required this.id,
    required this.kind,
    required this.guestId,
    required this.hostId,
    this.staffId = '',
    this.listingId = '',
    this.bookingId = '',
    this.lastMessage = '',
    this.lastMessageAt,
    this.guestLastRead,
    this.hostLastRead,
    this.counterpartyName = '',
    this.counterpartyAvatar = '',
    this.staffName = '',
    this.staffAvatar = '',
    this.listingTitle = '',
    this.listingPhoto = '',
    this.city = '',
    this.checkIn,
    this.checkOut,
    this.adults = 0,
    this.children = 0,
    this.unreadCount = 0,
  });

  final String id;
  final ChatKind kind;
  final String guestId;
  final String hostId;
  final String staffId;
  final String listingId;
  final String bookingId;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final DateTime? guestLastRead;
  final DateTime? hostLastRead;
  final String counterpartyName;
  final String counterpartyAvatar;
  final String staffName;
  final String staffAvatar;
  final String listingTitle;
  final String listingPhoto;
  final String city;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int adults;
  final int children;
  final int unreadCount;

  bool get hasStaff => staffId.isNotEmpty;

  String titleForViewer() {
    final base = counterpartyName.trim().isEmpty
        ? (kind == ChatKind.support ? 'Поддержка' : 'Чат')
        : counterpartyName.trim();
    if (hasStaff) return '$base, Админ';
    return base;
  }

  String get datesLabel {
    if (checkIn == null || checkOut == null) return '';
    return chatStayDatesLabel(checkIn!, checkOut!);
  }

  String get guestsLabel => chatGuestsLabel(adults, children);

  String timeLabel([DateTime? now]) {
    final at = lastMessageAt;
    if (at == null) return '';
    final local = at.toLocal();
    final today = (now ?? DateTime.now()).toLocal();
    final sameDay = local.year == today.year &&
        local.month == today.month &&
        local.day == today.day;
    if (sameDay) {
      return DateFormat('HH:mm', 'ru').format(local);
    }
    return DateFormat('dd.MM.yyyy', 'ru').format(local);
  }

  ChatPreview copyWith({int? unreadCount}) {
    return ChatPreview(
      id: id,
      kind: kind,
      guestId: guestId,
      hostId: hostId,
      staffId: staffId,
      listingId: listingId,
      bookingId: bookingId,
      lastMessage: lastMessage,
      lastMessageAt: lastMessageAt,
      guestLastRead: guestLastRead,
      hostLastRead: hostLastRead,
      counterpartyName: counterpartyName,
      counterpartyAvatar: counterpartyAvatar,
      staffName: staffName,
      staffAvatar: staffAvatar,
      listingTitle: listingTitle,
      listingPhoto: listingPhoto,
      city: city,
      checkIn: checkIn,
      checkOut: checkOut,
      adults: adults,
      children: children,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.authorId,
    this.text = '',
    this.imageUrls = const [],
    this.fileUrls = const [],
    this.created,
    this.authorName = '',
    this.authorAvatar = '',
    this.authorRoleLabel = '',
  });

  final String id;
  final String chatId;
  final String authorId;
  final String text;
  final List<String> imageUrls;
  final List<String> fileUrls;
  final DateTime? created;
  final String authorName;
  final String authorAvatar;
  final String authorRoleLabel;

  String timeLabel() {
    final at = created;
    if (at == null) return '';
    return DateFormat('HH:mm', 'ru').format(at.toLocal());
  }
}

/// Compact stay line for list/thread meta (Figma `12.09.24 - 15.09.24`).
String chatStayDatesLabel(DateTime checkIn, DateTime checkOut) {
  String two(int value) => value.toString().padLeft(2, '0');
  String format(DateTime date) {
    final year = (date.year % 100).toString().padLeft(2, '0');
    return '${two(date.day)}.${two(date.month)}.$year';
  }

  return '${format(checkIn)} - ${format(checkOut)}';
}

String chatGuestsLabel(int adults, int children) {
  final count = adults + children;
  if (count <= 0) return '';
  return '$count ${_pluralGuests(count)}';
}

String chatDaySeparatorLabel(DateTime date) {
  return DateFormat('d MMMM', 'ru').format(date.toLocal());
}

String _pluralGuests(int count) {
  final n = count % 100;
  final n1 = count % 10;
  if (n >= 11 && n <= 14) return 'гостей';
  if (n1 == 1) return 'гость';
  if (n1 >= 2 && n1 <= 4) return 'гостя';
  return 'гостей';
}
