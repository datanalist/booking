import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/booking.dart';
import '../../data/listings_repository.dart';
import '../../data/reviews_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/listing_host_section.dart';
import '../../widgets/listing_image.dart';
import 'booking_complaint_booking_dialog.dart';
import '../listing/listing_detail.dart';
import '../listing/listing_icons.dart';
import '../search/search_listing.dart';
import 'booking_address_dialog.dart';
import 'booking_complaint_screen.dart';

const _meta = Color(0xFF525353);
const _divider = Color(0xFFFFE3B7);
const _reviewFill = Color(0x0FFBC028);
const _reviewStroke = Color(0x2BFBC028);
const _heroOverlay = Color.fromRGBO(16, 51, 99, 0.05);
const _dotInactive = Color.fromRGBO(251, 192, 40, 0.17);
const _datesFill = Color.fromRGBO(251, 192, 40, 0.06);
const _datesBorder = Color.fromRGBO(251, 192, 40, 0.17);
const _datesSplit = Color(0xFFFFE4B8);
const _fieldFill = Color.fromRGBO(251, 192, 40, 0.06);
const _fieldStroke = Color.fromRGBO(251, 192, 40, 0.17);

const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

/// Прошедшая бронь: без отзыва Figma `1:12718`, с отзывом `1:12946`.
class BookingCompletedDetailScreen extends StatefulWidget {
  const BookingCompletedDetailScreen({
    super.key,
    required this.booking,
    this.initialDetail,
    this.listingsRepository,
    this.reviewsRepository,
  });

  final Booking booking;
  final ListingDetail? initialDetail;
  final ListingsRepository? listingsRepository;
  final ReviewsRepository? reviewsRepository;

  static Future<void> open(
    BuildContext context, {
    required Booking booking,
    ListingDetail? initialDetail,
    ListingsRepository? listingsRepository,
    ReviewsRepository? reviewsRepository,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BookingCompletedDetailScreen(
          booking: booking,
          initialDetail: initialDetail,
          listingsRepository: listingsRepository,
          reviewsRepository: reviewsRepository,
        ),
      ),
    );
  }

  @override
  State<BookingCompletedDetailScreen> createState() =>
      _BookingCompletedDetailScreenState();
}

class _BookingCompletedDetailScreenState
    extends State<BookingCompletedDetailScreen> {
  late final PageController _photos = PageController();
  var _photoIndex = 0;
  late ListingDetail _detail;
  StayReview? _review;

  ListingsRepository get _listings =>
      widget.listingsRepository ?? ListingsRepositoryScope.instance;

  ReviewsRepository get _reviews =>
      widget.reviewsRepository ?? ReviewsRepositoryScope.instance;

  bool get _hasReview => _review != null;

  @override
  void initState() {
    super.initState();
    _detail =
        widget.initialDetail ??
        ListingDetail.fromListing(_listingFromBooking(widget.booking));
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object?>([
        if (widget.initialDetail == null)
          _listings.fetchDetail(_listingFromBooking(widget.booking))
        else
          Future<ListingDetail>.value(widget.initialDetail!),
        _reviews.fetchForBooking(widget.booking.id),
      ]);
      if (!mounted) return;
      setState(() {
        _detail = results[0] as ListingDetail;
        _review = results[1] as StayReview?;
      });
    } catch (_) {
      if (!mounted) return;
      try {
        final review = await _reviews.fetchForBooking(widget.booking.id);
        if (!mounted) return;
        setState(() => _review = review);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _photos.dispose();
    super.dispose();
  }

  Future<void> _openAddress() {
    return showBookingAddressDialog(context, widget.booking);
  }

  Future<void> _openComplaint() {
    final listing = _detail.listing;
    return openBookingComplaintScreen(
      context,
      widget.booking,
      listingRating: listing.rating,
      listingReviews: listing.reviews,
      listingType: listing.type,
    );
  }

  Future<void> _openReviewSheet() async {
    final created = await showBookingReviewSheet(
      context,
      booking: widget.booking,
      reviewsRepository: _reviews,
    );
    if (!mounted || created == null) return;
    setState(() => _review = created);
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final detail = _detail;
    final listing = detail.listing;
    final accessLines = _splitLines(listing.accessInfo);
    final ruleLines = _splitLines(listing.houseRules);
    final guestReview = _review;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        key: ValueKey('booking-completed-detail-${booking.id}'),
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
                          Text(
                            listing.title.isEmpty
                                ? (booking.title.isEmpty
                                      ? 'Бронирование'
                                      : booking.title)
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
                                ? booking.addressLabel
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
                            checkIn: booking.checkIn,
                            checkOut: booking.checkOut,
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
                          if (accessLines.isNotEmpty) ...[
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
                            fallbackName: booking.hostName,
                            fallbackAvatar: booking.hostAvatar,
                            onChat: () => openHostChatStub(
                              context,
                              booking: booking,
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
                          _Cost(booking: booking),
                          const SizedBox(height: 24),
                          const _Hairline(),
                          const SizedBox(height: 24),
                          _CancelTerms(booking: booking, listing: listing),
                          const SizedBox(height: 24),
                          const _Hairline(),
                          const SizedBox(height: 24),
                          _ComplainRow(onTap: _openComplaint),
                          if (guestReview != null) ...[
                            const SizedBox(height: 24),
                            _GuestReview(review: guestReview),
                            const SizedBox(height: 16),
                            const Center(
                              child: Text(
                                'Отзыв оставлен',
                                key: ValueKey('booking-review-left'),
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 12,
                                  height: 1.50,
                                  color: _meta,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!_hasReview) _LeaveReviewFooter(onTap: _openReviewSheet),
          ],
        ),
      ),
    );
  }
}

Future<StayReview?> showBookingReviewSheet(
  BuildContext context, {
  required Booking booking,
  ReviewsRepository? reviewsRepository,
}) {
  return showModalBottomSheet<StayReview>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    barrierColor: const Color(0x661A1B1C),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) => _BookingReviewSheet(
      booking: booking,
      reviewsRepository: reviewsRepository,
    ),
  );
}

class _BookingReviewSheet extends StatefulWidget {
  const _BookingReviewSheet({
    required this.booking,
    this.reviewsRepository,
  });

  final Booking booking;
  final ReviewsRepository? reviewsRepository;

  @override
  State<_BookingReviewSheet> createState() => _BookingReviewSheetState();
}

class _BookingReviewSheetState extends State<_BookingReviewSheet> {
  final _controller = TextEditingController();
  var _rating = 0;
  var _busy = false;
  String? _error;

  ReviewsRepository get _reviews =>
      widget.reviewsRepository ?? ReviewsRepositoryScope.instance;

  bool get _canSend => _rating >= 1 && !_busy;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSend) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final review = await _reviews.create(
        booking: widget.booking,
        rating: _rating,
        comment: _controller.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(review);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is ReviewException
            ? error.message
            : 'Не удалось сохранить отзыв';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      key: const ValueKey('booking-review-sheet'),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Оставить отзыв',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              height: 1.2,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 1; i <= 5; i++) ...[
                if (i != 1) const SizedBox(width: 8),
                GestureDetector(
                  key: ValueKey('booking-review-star-$i'),
                  onTap: _busy ? null : () => setState(() => _rating = i),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: i <= _rating
                        ? ListingFigmaIcon.reviewStarOn
                        : ListingFigmaIcon.reviewStarOff,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('booking-review-text'),
            controller: _controller,
            enabled: !_busy,
            maxLines: 4,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w400,
              fontSize: 14,
              height: 1.40,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Расскажите о жилье',
              hintStyle: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 1.40,
                color: _meta,
              ),
              filled: true,
              fillColor: _fieldFill,
              contentPadding: const EdgeInsets.all(16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _fieldStroke),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.orange),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _fieldStroke),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 12,
                height: 1.4,
                color: Color(0xFFC23B2A),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              key: const ValueKey('booking-review-submit'),
              onPressed: _canSend ? _submit : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Text('Отправить'),
            ),
          ),
        ],
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

class _GuestReview extends StatelessWidget {
  const _GuestReview({required this.review});

  final StayReview review;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('booking-guest-review'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ваш отзыв',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            height: 1.40,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _ReviewStars(count: review.rating),
        if (review.comment.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            review.comment,
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

class _LeaveReviewFooter extends StatelessWidget {
  const _LeaveReviewFooter({required this.onTap});

  final VoidCallback onTap;

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
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              key: const ValueKey('booking-leave-review'),
              onPressed: onTap,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Оставить отзыв'),
            ),
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
