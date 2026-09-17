import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

import 'auth_repository.dart';
import 'booking.dart';
import 'inbox_notification.dart';
import 'pocketbase_client.dart';
import 'pocketbase_filter.dart';

abstract class NotificationsRepository {
  Future<List<InboxNotification>> fetchMine();

  Future<int> unreadCount();

  Future<InboxNotification> createForBooking(Booking booking);

  Future<void> markRead(String id);
}

class NotificationsRepositoryScope {
  static NotificationsRepository instance = PocketBaseNotificationsRepository();
  static final unreadCount = ValueNotifier<int>(0);

  static void setUnread(int value) {
    if (unreadCount.value == value) return;
    unreadCount.value = value;
  }
}

class PocketBaseNotificationsRepository implements NotificationsRepository {
  PocketBaseNotificationsRepository({PocketBase? this._client});

  static const collection = PbCollection.notifications;

  final PocketBase? _client;
  PocketBase get _pb => _client ?? pocketBase;

  String get _userId {
    final session = AuthRepositoryScope.session.value;
    if (session != null && session.userId.isNotEmpty) return session.userId;
    return _pb.authStore.record?.id ?? '';
  }

  @override
  Future<List<InboxNotification>> fetchMine() async {
    final userId = _userId;
    if (userId.isEmpty || !_pb.authStore.isValid) return const [];
    final records = await _pb.collection(collection).getFullList(
      filter: pbFilter('user = {:userId}', {'userId': userId}),
      sort: '-created',
    );
    final items = [for (final record in records) _map(record)];
    NotificationsRepositoryScope.setUnread(
      items.where((item) => !item.read).length,
    );
    return items;
  }

  @override
  Future<int> unreadCount() async {
    final userId = _userId;
    if (userId.isEmpty || !_pb.authStore.isValid) {
      NotificationsRepositoryScope.setUnread(0);
      return 0;
    }
    final result = await _pb.collection(collection).getList(
      page: 1,
      perPage: 1,
      filter: pbFilter(
        'user = {:userId} && read = false',
        {'userId': userId},
      ),
    );
    NotificationsRepositoryScope.setUnread(result.totalItems);
    return result.totalItems;
  }

  @override
  Future<InboxNotification> createForBooking(Booking booking) async {
    final userId = _userId;
    if (userId.isEmpty) {
      throw const NotificationException('Войдите, чтобы увидеть уведомления');
    }
    try {
      final record = await _pb.collection(collection).create(
        body: {
          'user': userId,
          'title': BookingRequestCopy.title,
          'body': BookingRequestCopy.bodyForListing(booking.title),
          'read': false,
          'booking': booking.id,
          'listing': booking.listingId,
        },
      );
      NotificationsRepositoryScope.setUnread(
        NotificationsRepositoryScope.unreadCount.value + 1,
      );
      return _map(record);
    } on ClientException catch (error) {
      throw NotificationException(_messageFor(error));
    }
  }

  @override
  Future<void> markRead(String id) async {
    if (id.isEmpty) return;
    try {
      await _pb.collection(collection).update(id, body: {'read': true});
      final current = NotificationsRepositoryScope.unreadCount.value;
      if (current > 0) {
        NotificationsRepositoryScope.setUnread(current - 1);
      }
    } on ClientException catch (error) {
      throw NotificationException(_messageFor(error));
    }
  }

  InboxNotification _map(RecordModel record) {
    return InboxNotification(
      id: record.id,
      userId: record.get<String>('user', ''),
      title: record.get<String>('title', ''),
      body: record.get<String>('body', ''),
      read: record.get<bool>('read', false),
      bookingId: record.get<String>('booking', ''),
      listingId: record.get<String>('listing', ''),
      created: DateTime.tryParse(record.get<String>('created', '')),
    );
  }

  String _messageFor(ClientException error) {
    final response = error.response;
    final message = response['message'];
    if (message is String && message.isNotEmpty) return message;
    return 'Не удалось сохранить уведомление';
  }
}
