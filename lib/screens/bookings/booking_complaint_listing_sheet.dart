import 'package:flutter/material.dart';

import '../../data/booking.dart';
import '../../data/tickets_repository.dart';
import '../../screens/auth/photo_access.dart';
import '../../theme/app_theme.dart';
import '../../widgets/listing_image.dart';
import '../listing/listing_icons.dart';
import 'booking_complaint_form.dart';

const _ink = Color(0xFF1A1B1D);
const _meta = Color(0xFF525353);
const _heroOverlay = Color.fromRGBO(16, 51, 99, 0.05);

/// Боттомшит «Пожаловаться на жилье» (Figma `1:11623`).
Future<bool?> showBookingComplaintListingSheet(
  BuildContext context, {
  required Booking booking,
  TicketsRepository? ticketsRepository,
  PhotoLibrary? photoLibrary,
  String rating = '',
  String reviews = '',
  String housingType = '',
}) {
  return showComplaintSheet(
    context: context,
    sheetKey: 'complaint-listing-sheet',
    title: 'Пожаловаться на жилье',
    header: _ListingHeader(
      booking: booking,
      rating: rating,
      reviews: reviews,
      housingType: housingType,
    ),
    form: BookingComplaintForm(
      booking: booking,
      type: TicketType.listing,
      textKey: 'complaint-listing-text',
      sendKey: 'complaint-listing-send',
      backKey: 'complaint-listing-back',
      ticketsRepository: ticketsRepository,
      photoLibrary: photoLibrary,
    ),
  );
}

class _ListingHeader extends StatelessWidget {
  const _ListingHeader({
    required this.booking,
    required this.rating,
    required this.reviews,
    required this.housingType,
  });

  final Booking booking;
  final String rating;
  final String reviews;
  final String housingType;

  @override
  Widget build(BuildContext context) {
    final city = booking.city.isNotEmpty ? booking.city : booking.addressLabel;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                booking.title.isEmpty ? 'Жилье' : booking.title,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  height: 1.2,
                  color: _ink,
                ),
              ),
              if (rating.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      rating,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                        height: 1.4,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(width: 2),
                    ListingFigmaIcon.star16,
                    if (reviews.isNotEmpty) ...[
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          reviews,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                            height: 1.4,
                            color: _ink,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              if (city.isNotEmpty || housingType.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (city.isNotEmpty) ...[
                      ListingFigmaIcon.mapPin14,
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          city,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                            height: 1.5,
                            color: _meta,
                          ),
                        ),
                      ),
                    ],
                    if (city.isNotEmpty && housingType.isNotEmpty)
                      const SizedBox(width: 12),
                    if (housingType.isNotEmpty) ...[
                      ListingFigmaIcon.home14,
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          housingType,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                            height: 1.5,
                            color: _meta,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
