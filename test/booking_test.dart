import 'package:flutter_test/flutter_test.dart';

import 'package:booking/data/booking.dart';
import 'package:booking/screens/search/search_listing.dart';

void main() {
  test('past statuses are completed and cancelled', () {
    expect(BookingStatus.completed.isPast, isTrue);
    expect(BookingStatus.cancelled.isPast, isTrue);
    expect(BookingStatus.pendingHost.isPast, isFalse);
    expect(BookingStatus.confirmed.isPast, isFalse);
    expect(BookingStatus.fromApi('awaiting_prepayment'),
        BookingStatus.awaitingPrepayment);
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
