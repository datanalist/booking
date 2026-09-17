import 'package:intl/intl.dart';

import 'booking.dart';

/// Копирайт Figma `1:11832` / инбокс `1:11396` после запроса брони.
abstract final class BookingRequestCopy {
  static const title = 'Запрос на бронирование отправлен';
  static const body =
      'Ожидайте подтверждение бронирования от владельца жилья в течение 12 часов';
  static const ok = 'Ок';

  static String bodyForListing(String listingTitle) {
    final title = listingTitle.trim();
    if (title.isEmpty) return body;
    return 'Ожидайте подтверждение бронирования «$title» от владельца жилья '
        'в течение 12 часов';
  }

  static InboxNotification fromBooking(Booking booking, {String id = ''}) {
    return InboxNotification(
      id: id,
      userId: booking.guestId,
      title: title,
      body: bodyForListing(booking.title),
      read: false,
      bookingId: booking.id,
      listingId: booking.listingId,
      created: DateTime.now(),
    );
  }
}

class InboxNotification {
  const InboxNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.read,
    this.bookingId = '',
    this.listingId = '',
    this.created,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final bool read;
  final String bookingId;
  final String listingId;
  final DateTime? created;
}

String notificationWhenLabel(DateTime created, {DateTime? now}) {
  final local = created.toLocal();
  final clock = (now ?? DateTime.now()).toLocal();
  final today = DateTime(clock.year, clock.month, clock.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Сегодня';
  if (diff == 1) return 'Вчера';
  return DateFormat('dd.MM.yyyy', 'ru').format(local);
}

class NotificationException implements Exception {
  const NotificationException(this.message);

  final String message;

  @override
  String toString() => message;
}
