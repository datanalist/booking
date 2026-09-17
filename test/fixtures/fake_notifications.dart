import 'package:booking/data/booking.dart';
import 'package:booking/data/inbox_notification.dart';
import 'package:booking/data/notifications_repository.dart';

class FakeNotificationsRepository implements NotificationsRepository {
  FakeNotificationsRepository([List<InboxNotification>? items])
    : items = List<InboxNotification>.from(items ?? const []);

  final List<InboxNotification> items;
  final created = <InboxNotification>[];
  Object? failCreateWith;

  @override
  Future<List<InboxNotification>> fetchMine() async {
    final unread = items.where((item) => !item.read).length;
    NotificationsRepositoryScope.setUnread(unread);
    return List<InboxNotification>.from(items);
  }

  @override
  Future<int> unreadCount() async {
    final unread = items.where((item) => !item.read).length;
    NotificationsRepositoryScope.setUnread(unread);
    return unread;
  }

  @override
  Future<InboxNotification> createForBooking(Booking booking) async {
    if (failCreateWith != null) {
      final error = failCreateWith!;
      failCreateWith = null;
      throw error;
    }
    final notice = BookingRequestCopy.fromBooking(
      booking,
      id: 'notice-${created.length + 1}',
    );
    created.add(notice);
    items.insert(0, notice);
    NotificationsRepositoryScope.setUnread(
      items.where((item) => !item.read).length,
    );
    return notice;
  }

  @override
  Future<void> markRead(String id) async {
    final index = items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final current = items[index];
    items[index] = InboxNotification(
      id: current.id,
      userId: current.userId,
      title: current.title,
      body: current.body,
      read: true,
      bookingId: current.bookingId,
      listingId: current.listingId,
      created: current.created,
    );
    NotificationsRepositoryScope.setUnread(
      items.where((item) => !item.read).length,
    );
  }
}
