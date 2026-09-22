import 'dart:io';

import 'package:booking/data/auth_repository.dart';
import 'package:booking/data/booking.dart';
import 'package:booking/data/tickets_repository.dart';

class FakeTicketsRepository implements TicketsRepository {
  FakeTicketsRepository([List<SupportTicket>? items])
    : items = List<SupportTicket>.from(items ?? const []);

  final List<SupportTicket> items;
  final created = <SupportTicket>[];
  Object? failCreateWith;

  @override
  Future<List<SupportTicket>> listMine() async {
    final authorId = AuthRepositoryScope.session.value?.userId ?? '';
    if (authorId.isEmpty) return const [];
    return [
      for (final ticket in items)
        if (ticket.authorId == authorId) ticket,
    ];
  }

  @override
  Future<SupportTicket> create({
    required TicketType type,
    required Booking booking,
    required String text,
    List<File> photos = const [],
  }) async {
    if (failCreateWith != null) {
      final error = failCreateWith!;
      failCreateWith = null;
      throw error;
    }
    final authorId = AuthRepositoryScope.session.value?.userId ?? '';
    if (authorId.isEmpty) {
      throw const TicketException('Войдите, чтобы отправить жалобу');
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const TicketException('Опишите свою проблему');
    }
    final ticket = SupportTicket(
      id: 'ticket-${created.length + 1}',
      authorId: authorId,
      type: type,
      text: trimmed,
      listingId: booking.listingId,
      hostId: booking.hostId,
      bookingId: booking.id,
      photos: [for (final file in photos) file.path],
      created: DateTime.now(),
    );
    created.add(ticket);
    items.add(ticket);
    return ticket;
  }
}
