import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/booking.dart';
import '../../data/tickets_repository.dart';
import '../../screens/auth/photo_access.dart';
import '../../theme/app_theme.dart';
import 'booking_complaint_booking_dialog.dart';
import 'booking_complaint_host_sheet.dart';
import 'booking_complaint_listing_sheet.dart';
import 'booking_complaint_sent_dialog.dart';
import 'booking_complaint_support_sheet.dart';

const _ink = Color(0xFF1A1B1D);
const _backBorder = Color(0xFFFFE4B8);
const _cardFill = Color.fromRGBO(251, 192, 40, 0.06);
const _cardStroke = Color.fromRGBO(251, 192, 40, 0.17);
const _divider = Color(0xFFFFE4B8);

/// Экран «Пожаловаться» (Figma `1:11353`).
Future<void> openBookingComplaintScreen(
  BuildContext context,
  Booking booking, {
  TicketsRepository? ticketsRepository,
  PhotoLibrary? photoLibrary,
  String listingRating = '',
  String listingReviews = '',
  String listingType = '',
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => BookingComplaintScreen(
        booking: booking,
        ticketsRepository: ticketsRepository,
        photoLibrary: photoLibrary,
        listingRating: listingRating,
        listingReviews: listingReviews,
        listingType: listingType,
      ),
    ),
  );
}

class BookingComplaintScreen extends StatelessWidget {
  const BookingComplaintScreen({
    super.key,
    required this.booking,
    this.ticketsRepository,
    this.photoLibrary,
    this.listingRating = '',
    this.listingReviews = '',
    this.listingType = '',
  });

  final Booking booking;
  final TicketsRepository? ticketsRepository;
  final PhotoLibrary? photoLibrary;
  final String listingRating;
  final String listingReviews;
  final String listingType;

  TicketsRepository get _tickets =>
      ticketsRepository ?? TicketsRepositoryScope.instance;

  Future<void> _onBooking(BuildContext context) async {
    final choice = await showBookingComplaintDialog(context);
    if (!context.mounted || choice == null) return;
    if (choice == BookingComplaintChoice.chat) {
      await openHostChatStub(context, booking: booking);
      return;
    }
    final sent = await showBookingComplaintSupportSheet(
      context,
      booking: booking,
      ticketsRepository: _tickets,
      photoLibrary: photoLibrary,
    );
    if (sent == true && context.mounted) {
      await showComplaintSentDialog(context);
    }
  }

  Future<void> _onListing(BuildContext context) async {
    final sent = await showBookingComplaintListingSheet(
      context,
      booking: booking,
      ticketsRepository: _tickets,
      photoLibrary: photoLibrary,
      rating: listingRating,
      reviews: listingReviews,
      housingType: listingType,
    );
    if (sent == true && context.mounted) {
      await showComplaintSentDialog(context);
    }
  }

  Future<void> _onHost(BuildContext context) async {
    final sent = await showBookingComplaintHostSheet(
      context,
      booking: booking,
      ticketsRepository: _tickets,
      photoLibrary: photoLibrary,
    );
    if (sent == true && context.mounted) {
      await showComplaintSentDialog(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        key: const ValueKey<String>('booking-complaint-screen'),
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                _BackButton(onTap: () => Navigator.of(context).pop()),
                const SizedBox(height: 24),
                const Text(
                  'Пожаловаться на',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    height: 1,
                    letterSpacing: 0.018,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _cardFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _cardStroke),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _ComplaintRow(
                          rowKey: 'complaint-booking',
                          label: 'Бронирование',
                          onTap: () => _onBooking(context),
                        ),
                        const _ComplaintDivider(),
                        _ComplaintRow(
                          rowKey: 'complaint-listing',
                          label: 'Жилье',
                          onTap: () => _onListing(context),
                        ),
                        const _ComplaintDivider(),
                        _ComplaintRow(
                          rowKey: 'complaint-host',
                          label: 'Владельца жилья',
                          onTap: () => _onHost(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComplaintRow extends StatelessWidget {
  const _ComplaintRow({
    required this.rowKey,
    required this.label,
    required this.onTap,
  });

  final String rowKey;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>(rowKey),
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  height: 1.4,
                  color: _ink,
                ),
              ),
            ),
            SizedBox(
              width: 20,
              height: 20,
              child: Center(
                child: Transform.rotate(
                  angle: -math.pi / 2,
                  child: SvgPicture.asset(
                    'images/profile/arrow-left.svg',
                    width: 13.1667,
                    height: 7.33333,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComplaintDivider extends StatelessWidget {
  const _ComplaintDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Divider(height: 1, thickness: 1, color: _divider),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Назад',
      child: Material(
        color: AppColors.white,
        shape: const CircleBorder(side: BorderSide(color: _backBorder)),
        child: InkWell(
          key: const ValueKey<String>('booking-complaint-back'),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: Transform.rotate(
                angle: math.pi / 2,
                child: SvgPicture.asset(
                  'images/profile/arrow-left.svg',
                  width: 13.1667,
                  height: 7.33333,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
