import 'package:flutter/material.dart';

import '../../data/booking.dart';
import '../../data/tickets_repository.dart';
import '../../screens/auth/photo_access.dart';
import '../../theme/app_theme.dart';
import '../../widgets/listing_image.dart';
import 'booking_complaint_form.dart';

const _ink = Color(0xFF1A1B1D);
const _avatarFill = Color(0xFFFFE3B7);

/// Боттомшит «Пожаловаться на владельца жилья» (Figma `1:11726`).
Future<bool?> showBookingComplaintHostSheet(
  BuildContext context, {
  required Booking booking,
  TicketsRepository? ticketsRepository,
  PhotoLibrary? photoLibrary,
}) {
  return showComplaintSheet(
    context: context,
    sheetKey: 'complaint-host-sheet',
    title: 'Пожаловаться на владельца жилья',
    header: _HostHeader(booking: booking),
    form: BookingComplaintForm(
      booking: booking,
      type: TicketType.host,
      textKey: 'complaint-host-text',
      sendKey: 'complaint-host-send',
      backKey: 'complaint-host-back',
      ticketsRepository: ticketsRepository,
      photoLibrary: photoLibrary,
    ),
  );
}

class _HostHeader extends StatelessWidget {
  const _HostHeader({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final name = booking.hostName.trim().isEmpty
        ? 'Владелец'
        : booking.hostName.trim();
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Column(
        children: [
          _HostAvatar(name: name, url: booking.hostAvatar),
          const SizedBox(height: 16),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              height: 1.2,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _HostAvatar extends StatelessWidget {
  const _HostAvatar({required this.name, required this.url});

  final String name;
  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isNotEmpty) {
      return ClipOval(
        child: ListingImage(url, width: 80, height: 80, fit: BoxFit.cover),
      );
    }
    return CircleAvatar(
      radius: 40,
      backgroundColor: _avatarFill,
      child: Text(
        name.isEmpty ? '?' : name.characters.first,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 28,
          color: AppColors.orange,
        ),
      ),
    );
  }
}
