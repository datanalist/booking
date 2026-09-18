import 'package:flutter/material.dart';

import '../../data/booking.dart';
import 'booking_cancelled_detail_screen.dart';
import 'booking_completed_detail_screen.dart';
import 'booking_detail_screen.dart';

/// Открывает карточку брони по статусу: предстоящая / отмена / архив.
Future<void> openBookingCard(
  BuildContext context, {
  required Booking booking,
}) {
  return switch (booking.status) {
    BookingStatus.cancelled ||
    BookingStatus.cancelRequested =>
      BookingCancelledDetailScreen.open(context, booking: booking),
    BookingStatus.completed =>
      BookingCompletedDetailScreen.open(context, booking: booking),
    _ => BookingDetailScreen.open(context, booking: booking),
  };
}
