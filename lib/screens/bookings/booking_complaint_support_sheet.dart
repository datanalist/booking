import 'package:flutter/material.dart';

import '../../data/booking.dart';
import '../../data/tickets_repository.dart';
import '../../screens/auth/photo_access.dart';
import '../../theme/app_theme.dart';
import '../../widgets/listing_image.dart';
import 'booking_complaint_form.dart';

const _ink = Color(0xFF1A1B1D);
const _heroOverlay = Color.fromRGBO(16, 51, 99, 0.05);

/// Боттомшит «Обратиться в поддержку» по жалобе на бронирование.
/// Пишет новую запись `tickets` (`type = booking`), не чат поддержки.
Future<bool?> showBookingComplaintSupportSheet(
  BuildContext context, {
  required Booking booking,
  TicketsRepository? ticketsRepository,
  PhotoLibrary? photoLibrary,
}) {
  return showComplaintSheet(
    context: context,
    sheetKey: 'complaint-booking-support-sheet',
    title: 'Обратиться в поддержку',
    header: _BookingSupportHeader(booking: booking),
    form: BookingComplaintForm(
      booking: booking,
      type: TicketType.booking,
      textKey: 'complaint-booking-support-text',
      sendKey: 'complaint-booking-support-send',
      backKey: 'complaint-booking-support-back',
      ticketsRepository: ticketsRepository,
      photoLibrary: photoLibrary,
    ),
  );
}

class _BookingSupportHeader extends StatelessWidget {
  const _BookingSupportHeader({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ListingImage(booking.photo, fit: BoxFit.cover),
                const ColoredBox(color: _heroOverlay),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            booking.title.isEmpty ? 'Бронирование' : booking.title,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              height: 1.2,
              color: _ink,
            ),
          ),
        ),
      ],
    );
  }
}
