import 'package:flutter_test/flutter_test.dart';

import 'package:booking/data/auth_repository.dart';
import 'package:booking/data/booking.dart';
import 'package:booking/data/tickets_repository.dart';

import 'fixtures/demo_listings.dart';
import 'fixtures/fake_tickets.dart';

Booking _booking() {
  final listing = kDemoListings.firstWhere((item) => item.id == 'studio-msk');
  return Booking(
    id: 'booking-1',
    listingId: listing.id,
    guestId: 'guest-1',
    hostId: listing.hostId,
    checkIn: DateTime(2026, 9, 12),
    checkOut: DateTime(2026, 9, 15),
    status: BookingStatus.confirmed,
    adults: 2,
    title: listing.title,
    photo: listing.photo,
    city: listing.city,
    address: listing.address,
    hostName: listing.host?.name ?? '',
    hostAvatar: listing.host?.avatarUrl ?? '',
  );
}

void main() {
  late AuthSession? previousSession;

  setUp(() {
    previousSession = AuthRepositoryScope.session.value;
    AuthRepositoryScope.session.value = const AuthSession(
      userId: 'guest-1',
      email: 'guest@example.com',
    );
  });

  tearDown(() {
    AuthRepositoryScope.session.value = previousSession;
  });

  test('create stores a booking ticket that listMine returns', () async {
    final tickets = FakeTicketsRepository();
    final created = await tickets.create(
      type: TicketType.booking,
      booking: _booking(),
      text: 'Жалоба на бронирование',
    );

    expect(created.id, 'ticket-1');
    expect(created.type, TicketType.booking);
    expect(created.authorId, 'guest-1');
    expect(created.bookingId, 'booking-1');
    expect(created.listingId, 'studio-msk');
    expect(created.hostId, 'anna');
    expect(created.text, 'Жалоба на бронирование');

    final listed = await tickets.listMine();
    expect(listed, hasLength(1));
    expect(listed.single.id, created.id);
    expect(listed.single.type, TicketType.booking);
  });

  test('create rejects empty text', () async {
    final tickets = FakeTicketsRepository();
    await expectLater(
      tickets.create(
        type: TicketType.listing,
        booking: _booking(),
        text: '   ',
      ),
      throwsA(
        isA<TicketException>().having(
          (error) => error.message,
          'message',
          'Опишите свою проблему',
        ),
      ),
    );
    expect(tickets.created, isEmpty);
  });
}
