import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/booking.dart';
import '../../data/listings_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/listing_host_section.dart';
import '../../widgets/listing_image.dart';
import 'booking_complaint_booking_dialog.dart';
import '../listing/listing_detail.dart';
import '../listing/listing_icons.dart';
import '../search/search_listing.dart';
import 'booking_address_dialog.dart';
import 'booking_cancel_dialog.dart';
import 'booking_change_sheet.dart';
import 'booking_complaint_screen.dart';
import 'booking_status_style.dart';

const _meta = Color(0xFF525353);
const _divider = Color(0xFFFFE3B7);
const _reviewFill = Color(0x0FFBC028);
const _reviewStroke = Color(0x2BFBC028);
const _heroOverlay = Color.fromRGBO(16, 51, 99, 0.05);
const _dotInactive = Color.fromRGBO(251, 192, 40, 0.17);
const _datesFill = Color.fromRGBO(251, 192, 40, 0.06);
const _datesBorder = Color.fromRGBO(251, 192, 40, 0.17);
const _datesSplit = Color(0xFFFFE4B8);

const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

/// Карточка брони: pending/change `1:13403`, предоплата `1:13173`, confirmed `1:12259`.
class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({
    super.key,
    required this.booking,
    this.initialDetail,
    this.listingsRepository,
  });

  final Booking booking;
  final ListingDetail? initialDetail;
  final ListingsRepository? listingsRepository;

  static Future<void> open(
    BuildContext context, {
    required Booking booking,
    ListingDetail? initialDetail,
    ListingsRepository? listingsRepository,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BookingDetailScreen(
          booking: booking,
          initialDetail: initialDetail,
          listingsRepository: listingsRepository,
        ),
      ),
    );
  }

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late final PageController _photos = PageController();
  var _photoIndex = 0;
  late Booking _booking;
  late ListingDetail _detail;

  ListingsRepository get _repository =>
      widget.listingsRepository ?? ListingsRepositoryScope.instance;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    _detail =
        widget.initialDetail ??
        ListingDetail.fromListing(_listingFromBooking(_booking));
    if (widget.initialDetail == null) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final detail = await _repository.fetchDetail(
        _listingFromBooking(_booking),
      );
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (_) {
      // Карточка уже собрана из брони; детали объявления подтянутся при повторе.
    }
  }

  @override
  void dispose() {
    _photos.dispose();
    super.dispose();
  }

  Future<void> _openAddress() {
    return showBookingAddressDialog(context, _booking);
  }

  Future<void> _openChange() async {
    final next = await showBookingChangeSheet(context, _booking);
    if (!mounted || next == null) return;
    setState(() => _booking = next);
  }

  Future<void> _openCancel() async {
    final next = await showBookingCancelDialog(context, _booking);
    if (!mounted || next == null) return;
    Navigator.of(context).pop();
  }

  Future<void> _openComplaint() {
    final listing = _detail.listing;
    return openBookingComplaintScreen(
      context,
      _booking,
      listingRating: listing.rating,
      listingReviews: listing.reviews,
      listingType: listing.type,
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final listing = detail.listing;
    final chip = bookingStatusChipFor(_booking.status);
    final accessLines = _splitLines(listing.accessInfo);
    final ruleLines = _splitLines(listing.houseRules);
    final showAccess =
        _booking.status == BookingStatus.confirmed && accessLines.isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        key: ValueKey('booking-detail-${_booking.id}'),
        backgroundColor: AppColors.white,
        body: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _HeroGallery(
                      photos: detail.photos,
                      controller: _photos,
                      index: _photoIndex,
                      onPageChanged: (value) {
                        setState(() => _photoIndex = value);
                      },
                      onBack: () => Navigator.of(context).pop(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (chip != null) ...[
                            BookingStatusChipView(status: chip),
                            const SizedBox(height: 12),
                          ],
                          Text(
                            listing.title.isEmpty
                                ? (_booking.title.isEmpty
                                      ? 'Бронирование'
                                      : _booking.title)
                                : listing.title,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              height: 1.2,
                              letterSpacing: 0.018,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _AddressRow(
                            label: listing.address.isEmpty
                                ? _booking.addressLabel
                                : listing.address,
                            onTap: _openAddress,
                          ),
                          if (listing.type.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _MetaRow(
                              icon: ListingFigmaIcon.home16,
                              label: listing.type,
                            ),
                          ],
                          const SizedBox(height: 12),
                          _StayDates(
                            checkIn: _booking.checkIn,
                            checkOut: _booking.checkOut,
                            checkInTime: listing.checkInTime,
                            checkOutTime: listing.checkOutTime,
                          ),
                          if (detail.description.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              detail.description,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontWeight: FontWeight.w400,
                                fontSize: 14,
                                height: 1.40,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                          if (showAccess) ...[
                            const SizedBox(height: 24),
                            const _Hairline(),
                            const SizedBox(height: 24),
                            _NumberedBlock(
                              title: 'Как попасть внутрь',
                              lines: accessLines,
                            ),
                          ],
                          if (ruleLines.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const _Hairline(),
                            const SizedBox(height: 24),
                            _NumberedBlock(
                              title: 'Правила проживания',
                              lines: ruleLines,
                            ),
                          ],
                          if (detail.amenities.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const _Hairline(),
                            const SizedBox(height: 24),
                            _Amenities(items: detail.amenities),
                          ],
                          const SizedBox(height: 24),
                          const _Hairline(),
                          const SizedBox(height: 24),
                          ListingHostSection(
                            host: detail.host,
                            fallbackName: _booking.hostName,
                            fallbackAvatar: _booking.hostAvatar,
                            onChat: () => openHostChatStub(
                              context,
                              booking: _booking,
                              hostName: detail.host.name,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const _Hairline(),
                          const SizedBox(height: 24),
                          _Reviews(detail: detail),
                          const SizedBox(height: 24),
                          const _Hairline(),
                          const SizedBox(height: 24),
                          _Cost(booking: _booking),
                          const SizedBox(height: 24),
                          const _Hairline(),
                          const SizedBox(height: 24),
                          _CancelTerms(
                            booking: _booking,
                            listing: listing,
                          ),
                          const SizedBox(height: 24),
                          const _Hairline(),
                          const SizedBox(height: 24),
                          _ComplainRow(onTap: _openComplaint),
                          const SizedBox(height: 24),
                          _CancelLink(onTap: _openCancel),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _BookingFooter(
              booking: _booking,
              onPrepay: () {},
              onChange: _openChange,
            ),
          ],
        ),
      ),
    );
  }
}

SearchListing _listingFromBooking(Booking booking) {
  return SearchListing(
    id: booking.listingId,
    title: booking.title,
    city: booking.city,
    type: '',
    address: booking.address,
    description: '',
    dates: '',
    nights: '',
    total: formatRub(booking.total),
    perNight: '',
    rating: '—',
    reviews: reviewCountLabel(0),
    photo: booking.photo,
    photos: booking.photo.isEmpty ? const [] : [booking.photo],
    imageIndex: 0,
    latitude: booking.latitude,
    longitude: booking.longitude,
    pricePerNight: 0,
    hostId: booking.hostId,
    host: booking.hostName.isEmpty
        ? null
        : ListingHost(
            id: booking.hostId,
            name: booking.hostName,
            rating: '—',
            reviewCount: 0,
            years: 0,
            avatarUrl: booking.hostAvatar,
          ),
  );
}

List<String> _splitLines(String raw) {
  return [
    for (final line in raw.split(RegExp(r'\r?\n+')))
      if (line.trim().isNotEmpty)
        line.trim().replaceFirst(RegExp(r'^\d+[.)]\s*'), ''),
  ];
}

String _two(int value) => value.toString().padLeft(2, '0');

String _dateWithWeekday(DateTime date) {
  return '${_two(date.day)}.${_two(date.month)}.${date.year}, ${_weekdays[date.weekday - 1]}';
}

String _shortDate(DateTime date) {
  return '${_two(date.day)}.${_two(date.month)}.${_two(date.year % 100)}';
}

String _dateTimeLabel(DateTime date, String time) {
  return '${_two(date.day)}.${_two(date.month)}.${date.year} $time';
}

class _HeroGallery extends StatelessWidget {
  const _HeroGallery({
    required this.photos,
    required this.controller,
    required this.index,
    required this.onPageChanged,
    required this.onBack,
  });

  final List<String> photos;
  final PageController controller;
  final int index;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final pages = photos.isEmpty ? const [''] : photos;
    return SizedBox(
      height: 332,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: controller,
            itemCount: pages.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, page) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  ListingImage(pages[page], fit: BoxFit.cover),
                  const ColoredBox(color: _heroOverlay),
                ],
              );
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _CircleButton(
                    tooltip: 'Назад',
                    onTap: onBack,
                    child: const _BackArrowIcon(),
                  ),
                ),
              ),
            ),
          ),
          if (pages.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: _PhotoDots(count: pages.length, index: index),
            ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.child,
    required this.onTap,
    required this.tooltip,
  });

  final Widget child;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackArrowIcon extends StatelessWidget {
  const _BackArrowIcon();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 2,
      child: SvgPicture.asset(
        'images/profile/arrow-left.svg',
        width: 13.1667,
        height: 7.33333,
        excludeFromSemantics: true,
      ),
    );
  }
}

class _PhotoDots extends StatelessWidget {
  const _PhotoDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i != 0) const SizedBox(width: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: i == index ? 16 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index ? AppColors.white : _dotInactive,
              borderRadius: BorderRadius.circular(50),
            ),
          ),
        ],
      ],
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('booking-address'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          ListingFigmaIcon.mapPin16,
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 1.40,
                color: _meta,
                decoration: TextDecoration.underline,
                decorationColor: _meta,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        icon,
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w400,
              fontSize: 14,
              height: 1.40,
              color: _meta,
            ),
          ),
        ),
      ],
    );
  }
}

class _StayDates extends StatelessWidget {
  const _StayDates({
    required this.checkIn,
    required this.checkOut,
    required this.checkInTime,
    required this.checkOutTime,
  });

  final DateTime checkIn;
  final DateTime checkOut;
  final String checkInTime;
  final String checkOutTime;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: _datesFill,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: _datesBorder),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _StayDateColumn(
                title: 'Заселение',
                date: checkIn,
                time: checkInTime.isEmpty ? '14:00' : checkInTime,
              ),
            ),
            const SizedBox(
              width: 1,
              height: 41,
              child: ColoredBox(color: _datesSplit),
            ),
            Expanded(
              child: _StayDateColumn(
                title: 'Выселение',
                date: checkOut,
                time: checkOutTime.isEmpty ? '12:00' : checkOutTime,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StayDateColumn extends StatelessWidget {
  const _StayDateColumn({
    required this.title,
    required this.date,
    required this.time,
  });

  final String title;
  final DateTime date;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            height: 1.40,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            Text(
              _dateWithWeekday(date),
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 12,
                height: 1.50,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              time,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 12,
                height: 1.50,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NumberedBlock extends StatelessWidget {
  const _NumberedBlock({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            height: 1.40,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < lines.length; i++) ...[
          if (i != 0) const SizedBox(height: 8),
          Text(
            '${i + 1}. ${lines[i]}',
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w400,
              fontSize: 14,
              height: 1.40,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ],
    );
  }
}

class _Amenities extends StatelessWidget {
  const _Amenities({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Удобства',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            height: 1.40,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              _AmenityChip(
                icon: kAmenityIcons[item] ?? Icons.check,
                label: item,
              ),
          ],
        ),
      ],
    );
  }
}

class _AmenityChip extends StatelessWidget {
  const _AmenityChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.orange),
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.orange),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w400,
              fontSize: 14,
              height: 1.40,
              color: AppColors.orange,
            ),
          ),
        ],
      ),
    );
  }
}

class _Reviews extends StatelessWidget {
  const _Reviews({required this.detail});

  final ListingDetail detail;

  @override
  Widget build(BuildContext context) {
    final listing = detail.listing;
    final count = reviewCountFromLabel(listing.reviews);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 2,
                children: [
                  const Text(
                    'Отзывы',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      height: 1.40,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    listing.rating,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      height: 1.50,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  ListingFigmaIcon.star18,
                  Text(
                    reviewCountLabel(count),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      height: 1.50,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Смотреть все',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 12,
                height: 1.30,
                color: AppColors.orange,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.orange,
              ),
            ),
          ],
        ),
        if (detail.reviews.isNotEmpty) ...[
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < detail.reviews.length; i++) ...[
                  if (i != 0) const SizedBox(width: 12),
                  _ReviewCard(review: detail.reviews[i]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final ListingReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: _reviewFill,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: _reviewStroke),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(label: review.author, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        height: 1.40,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      review.postedAgo,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w400,
                        fontSize: 10,
                        height: 1.40,
                        color: _meta,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ReviewStars(count: review.stars),
          const SizedBox(height: 10),
          Text(
            review.text,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w400,
              fontSize: 12,
              height: 1.50,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Cost extends StatelessWidget {
  const _Cost({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final nights = stayNightsBetween(booking.checkIn, booking.checkOut);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Стоимость',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            height: 1.40,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _PriceRow(
          label: nights > 0 ? nightsLabel(nights) : 'Итого',
          value: formatRub(booking.total),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(height: 1, thickness: 0.5, color: _divider),
        ),
        _PriceRow(
          label: 'Предоплата онлайн',
          value: formatRub(booking.prepay),
        ),
        const SizedBox(height: 8),
        _PriceRow(
          label: 'Оплатить при заселении ${_shortDate(booking.checkIn)}',
          value: formatRub(booking.remainder),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w400,
              fontSize: 14,
              height: 1.40,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w400,
            fontSize: 14,
            height: 1.40,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _CancelTerms extends StatelessWidget {
  const _CancelTerms({required this.booking, required this.listing});

  final Booking booking;
  final SearchListing listing;

  @override
  Widget build(BuildContext context) {
    final until = DateTime(
      booking.checkIn.year,
      booking.checkIn.month,
      booking.checkIn.day,
    ).subtract(const Duration(days: 1));
    final time = listing.checkOutTime.isEmpty ? '12:00' : listing.checkOutTime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Условия отмены бронирования',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            height: 1.40,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _PriceRow(
          label: 'Отмена доступна до',
          value: _dateTimeLabel(until, time),
        ),
        const SizedBox(height: 8),
        _PriceRow(
          label: 'Возврат предоплаты',
          value: listing.cancellationAllowed ? 'да' : 'нет',
        ),
      ],
    );
  }
}

class _ComplainRow extends StatelessWidget {
  const _ComplainRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('booking-complain'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: const Row(
        children: [
          ListingFigmaIcon.warningInfo20,
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Пожаловаться',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 1.40,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Icon(Icons.chevron_right, size: 20, color: AppColors.textPrimary),
        ],
      ),
    );
  }
}

class _CancelLink extends StatelessWidget {
  const _CancelLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('booking-cancel'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'Отменить бронирование',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w400,
            fontSize: 12,
            height: 1.30,
            color: AppColors.orange,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.orange,
          ),
        ),
      ),
    );
  }
}

class _BookingFooter extends StatelessWidget {
  const _BookingFooter({
    required this.booking,
    required this.onPrepay,
    required this.onChange,
  });

  final Booking booking;
  final VoidCallback onPrepay;
  final VoidCallback onChange;

  bool get _awaitingPrepay =>
      booking.status == BookingStatus.awaitingPrepayment;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: AppColors.white,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _datesBorder)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_awaitingPrepay) ...[
                Row(
                  children: [
                    Text(
                      formatRub(booking.prepay),
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: 0.018,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'предоплата',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                        height: 1.50,
                        color: _meta,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    key: const ValueKey('booking-prepay-button'),
                    onPressed: onPrepay,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Внести предоплату'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    key: const ValueKey('booking-change-button'),
                    onPressed: onChange,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: AppColors.orange,
                      side: const BorderSide(color: AppColors.orange),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        height: 1.2,
                      ),
                    ),
                    child: const Text('Изменить бронирование'),
                  ),
                ),
              ] else
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    key: const ValueKey('booking-change-button'),
                    onPressed: onChange,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Изменить бронирование'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewStars extends StatelessWidget {
  const _ReviewStars({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++) ...[
          if (i != 0) const SizedBox(width: 6),
          i < count
              ? ListingFigmaIcon.reviewStarOn
              : ListingFigmaIcon.reviewStarOff,
        ],
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.label, required this.size, this.url = ''});

  final String label;
  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (url.isNotEmpty) {
      return ClipOval(
        child: ListingImage(url, width: size, height: size, fit: BoxFit.cover),
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFFFFE3B7),
      child: Text(
        label.isEmpty ? '?' : label.characters.first,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
          color: AppColors.orange,
        ),
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 0.5, color: _divider);
  }
}
