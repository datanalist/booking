import 'package:flutter_test/flutter_test.dart';

import 'package:booking/data/booking.dart';
import 'package:booking/screens/bookings/booking_status_style.dart';

void main() {
  test('pending_host and change_requested share the owner-wait chip', () {
    expect(
      bookingStatusChipFor(BookingStatus.pendingHost)?.label,
      'ожидание подтверждения от владельца',
    );
    expect(
      bookingStatusChipFor(BookingStatus.changeRequested)?.label,
      'ожидание подтверждения от владельца',
    );
    expect(
      bookingStatusChipFor(BookingStatus.pendingHost),
      bookingStatusChipFor(BookingStatus.changeRequested),
    );
    expect(
      BookingStatus.fromApi('pending_host'),
      BookingStatus.pendingHost,
    );
    expect(
      BookingStatus.fromApi('change_requested'),
      BookingStatus.changeRequested,
    );
    expect(
      BookingStatus.fromApi('pending_host'),
      isNot(BookingStatus.fromApi('change_requested')),
    );
    expect(BookingStatus.pendingHost.apiKey, 'pending_host');
    expect(BookingStatus.changeRequested.apiKey, 'change_requested');
  });

  test('other upcoming statuses keep distinct chips', () {
    expect(
      bookingStatusChipFor(BookingStatus.awaitingPrepayment)?.label,
      'ожидание предоплаты',
    );
    expect(
      bookingStatusChipFor(BookingStatus.confirmed)?.label,
      'бронирование подтверждено',
    );
    expect(
      bookingStatusChipFor(BookingStatus.cancelRequested)?.label,
      'отменено',
    );
    expect(
      bookingStatusChipFor(BookingStatus.cancelled)?.label,
      'отменено',
    );
    expect(
      bookingStatusChipFor(BookingStatus.cancelRequested),
      bookingStatusChipFor(BookingStatus.cancelled),
    );
  });
}
