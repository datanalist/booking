import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/booking.dart';
import '../../data/reviews_repository.dart';
import '../../theme/app_theme.dart';
import 'booking_review_listing_header.dart';

const _ink = Color(0xFF1A1B1D);
const _meta = Color(0xFF525353);
const _fieldFill = Color.fromRGBO(251, 192, 40, 0.06);
const _fieldStroke = Color.fromRGBO(251, 192, 40, 0.17);
const _handleFill = Color.fromRGBO(251, 192, 40, 0.17);

/// Боттомшит «Оценить» после завершённой брони (Figma `114:10781`).
///
/// Гость оставляет отзыв на жильё (`reviews.kind = listing`): рейтинг 1–5
/// и опциональный комментарий. «Пропустить» закрывает без записи.
Future<StayReview?> showBookingReviewSheet(
  BuildContext context, {
  required Booking booking,
  ReviewsRepository? reviewsRepository,
  String listingRating = '',
  String listingReviews = '',
  String listingType = '',
}) {
  return showModalBottomSheet<StayReview>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    barrierColor: _meta,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) => BookingReviewSheet(
      booking: booking,
      reviewsRepository: reviewsRepository,
      listingRating: listingRating,
      listingReviews: listingReviews,
      listingType: listingType,
    ),
  );
}

class BookingReviewSheet extends StatefulWidget {
  const BookingReviewSheet({
    super.key,
    required this.booking,
    this.reviewsRepository,
    this.listingRating = '',
    this.listingReviews = '',
    this.listingType = '',
  });

  final Booking booking;
  final ReviewsRepository? reviewsRepository;
  final String listingRating;
  final String listingReviews;
  final String listingType;

  @override
  State<BookingReviewSheet> createState() => _BookingReviewSheetState();
}

class _BookingReviewSheetState extends State<BookingReviewSheet> {
  final _controller = TextEditingController();
  var _rating = 0;
  var _busy = false;
  String? _error;

  ReviewsRepository get _reviews =>
      widget.reviewsRepository ?? ReviewsRepositoryScope.instance;

  bool get _canSend => _rating >= 1 && !_busy;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

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

  void _skip() {
    if (_busy) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final length = _controller.text.length;

    return Padding(
      key: const ValueKey('booking-review-sheet'),
      padding: EdgeInsets.only(bottom: keyboard),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 8 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 32),
              const SizedBox(
                width: double.infinity,
                child: Text(
                  'Оценить',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    height: 1.2,
                    color: _ink,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              BookingReviewListingHeader(
                booking: widget.booking,
                rating: widget.listingRating,
                reviews: widget.listingReviews,
                housingType: widget.listingType,
              ),
              const SizedBox(height: 40),
              const Text(
                'Насколько вам понравилось проживание?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  height: 1.4,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 12),
              _StarPicker(
                rating: _rating,
                enabled: !_busy,
                onChanged: (value) => setState(() => _rating = value),
              ),
              const SizedBox(height: 40),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: _fieldFill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _fieldStroke),
                ),
                child: TextField(
                  key: const ValueKey('booking-review-text'),
                  controller: _controller,
                  enabled: !_busy,
                  maxLines: 6,
                  minLines: 5,
                  maxLength: kReviewCommentMaxLength,
                  buildCounter:
                      (
                        context, {
                        required currentLength,
                        required isFocused,
                        required maxLength,
                      }) => const SizedBox.shrink(),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w400,
                    fontSize: 16,
                    height: 1.45,
                    color: _ink,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Здесь вы можете добавить комментарий',
                    hintStyle: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                      height: 1.45,
                      color: _meta,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(14),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  key: const ValueKey('booking-review-counter'),
                  '$length/$kReviewCommentMaxLength',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    height: 1.5,
                    color: _meta,
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
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('booking-review-skip'),
                      onPressed: _busy ? null : _skip,
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
                      child: const Text('Пропустить'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('booking-review-submit'),
                      onPressed: _canSend ? _submit : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: AppColors.orange,
                        foregroundColor: AppColors.white,
                        disabledBackgroundColor: const Color(0x66F88A2A),
                        disabledForegroundColor: AppColors.white,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _StarPicker extends StatelessWidget {
  const _StarPicker({
    required this.rating,
    required this.enabled,
    required this.onChanged,
  });

  final int rating;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++) ...[
          if (i != 1) const SizedBox(width: 5),
          GestureDetector(
            key: ValueKey('booking-review-star-$i'),
            onTap: enabled ? () => onChanged(i) : null,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: SvgPicture.asset(
                  i <= rating
                      ? 'images/listing/star-review-on.svg'
                      : 'images/listing/star-review-off.svg',
                  width: 32,
                  height: 30,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 43,
        height: 5,
        decoration: BoxDecoration(
          color: _handleFill,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
