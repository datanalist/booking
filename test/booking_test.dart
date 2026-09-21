import 'package:flutter_test/flutter_test.dart';

import 'package:booking/data/booking.dart';
import 'package:booking/screens/search/search_listing.dart';

void main() {
  test('past statuses are completed, cancelled and cancel_requested', () {
    expect(BookingStatus.completed.isPast, isTrue);
    expect(BookingStatus.cancelled.isPast, isTrue);
    expect(BookingStatus.cancelRequested.isPast, isTrue);
    expect(BookingStatus.pendingHost.isPast, isFalse);
    expect(BookingStatus.confirmed.isPast, isFalse);
    expect(BookingStatus.changeRequested.isPast, isFalse);
    expect(BookingStatus.awaitingPrepayment.isPast, isFalse);
    expect(
      BookingStatus.upcomingApiKeys,
      [
        for (final status in BookingStatus.values)
          if (!status.isPast) status.apiKey,
      ],
    );
    expect(BookingStatus.upcomingApiKeys, isNot(contains('cancel_requested')));
    expect(BookingStatus.upcomingApiKeys, isNot(contains('cancelled')));
    expect(BookingStatus.upcomingApiKeys, isNot(contains('completed')));
    expect(BookingStatus.fromApi('awaiting_prepayment'),
        BookingStatus.awaitingPrepayment);
    expect(BookingStatus.fromApi('pending_host'), BookingStatus.pendingHost);
    expect(
      BookingStatus.fromApi('change_requested'),
      BookingStatus.changeRequested,
    );
    expect(
      BookingStatus.fromApi('pending_host'),
      isNot(BookingStatus.fromApi('change_requested')),
    );
  });

  test('booking money splits 15 percent commission as prepay', () {
    final money = BookingMoney.fromStay(
      quoteStay(pricePerNight: 3000, nights: 2),
    );
    expect(money.total, 6000);
    expect(money.commission, 900);
    expect(money.prepay, 900);
    expect(money.hostAmount, 5100);
    expect(money.remainder, 5100);
  });

  test('card dates follow the upcoming Figma format', () {
    expect(
      Booking(
        id: '1',
        listingId: 'l',
        guestId: 'g',
        hostId: 'h',
        checkIn: DateTime(2024, 11, 14),
        checkOut: DateTime(2024, 11, 19),
        status: BookingStatus.pendingHost,
      ).datesLabel,
      '14.11.2024 - 19.11.2024',
    );
  });

  test('guest label uses russian plural', () {
    expect(
      Booking(
        id: '1',
        listingId: 'l',
        guestId: 'g',
        hostId: 'h',
        checkIn: DateTime(2026, 9, 12),
        checkOut: DateTime(2026, 9, 15),
        status: BookingStatus.confirmed,
        adults: 1,
      ).guestsLabel,
      '1 гость',
    );
    expect(
      Booking(
        id: '1',
        listingId: 'l',
        guestId: 'g',
        hostId: 'h',
        checkIn: DateTime(2026, 9, 12),
        checkOut: DateTime(2026, 9, 15),
        status: BookingStatus.confirmed,
        adults: 2,
        children: 1,
      ).guestsLabel,
      '3 гостя',
    );
  });
}
