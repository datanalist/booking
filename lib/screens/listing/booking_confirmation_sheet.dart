import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/auth_repository.dart';
import '../../data/booking.dart';
import '../../data/booking_draft.dart';
import '../../data/bookings_repository.dart';
import '../../data/inbox_notification.dart';
import '../../data/notifications_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/listing_image.dart';
import '../search/search_listing.dart';
import '../search/search_query_sheet.dart';
import 'booking_request_sent_dialog.dart';
import 'booking_unavailable_alert.dart';
import 'guests_sheet.dart';
import 'listing_icons.dart';
import 'stay_dates_sheet.dart';

const _ink = Color(0xFF1A1B1C);
const _meta = Color(0xFF525353);
const _divider = Color(0xFFFFE4B8);
const _heroOverlay = Color.fromRGBO(16, 51, 99, 0.05);
const _infoFill = Color.fromRGBO(251, 192, 40, 0.06);

const _loginRequired = 'Войдите, чтобы забронировать жилье';

String confirmationDatesLabel(DateTime checkIn, DateTime checkOut) {
  return '${formatSearchDate(checkIn)} - ${formatSearchDate(checkOut)}';
}

String confirmationGuestsLabel({
  required int adults,
  required int children,
  required int pets,
}) {
  final parts = <String>[
    _countLabel(adults, 'взрослый', 'взрослых', 'взрослых'),
    if (children > 0) _countLabel(children, 'ребенок', 'ребенка', 'детей'),
    if (pets > 0) _countLabel(pets, 'животное', 'животных', 'животных'),
  ];
  return parts.join(', ');
}

/// Noon on the calendar day before [checkIn] — existing free-cancel cutoff.
DateTime confirmationCancelDeadline(DateTime checkIn) {
  final dayBefore = DateTime(checkIn.year, checkIn.month, checkIn.day)
      .subtract(const Duration(days: 1));
  return DateTime(dayBefore.year, dayBefore.month, dayBefore.day, 12);
}

/// Label for «Отмена доступна до». Past cutoffs show «недоступна», not a stale date.
String confirmationCancelUntilLabel(
  DateTime checkIn, {
  DateTime? now,
}) {
  final deadline = confirmationCancelDeadline(checkIn);
  final at = now ?? DateTime.now();
  if (!deadline.isAfter(at)) {
    return 'недоступна';
  }
  return DateFormat('dd.MM.yyyy HH:mm', 'ru').format(deadline);
}

String _countLabel(int count, String one, String few, String many) {
  final mod100 = count % 100;
  final mod10 = count % 10;
  final word = (mod100 >= 11 && mod100 <= 14)
      ? many
      : (mod10 == 1)
      ? one
      : (mod10 >= 2 && mod10 <= 4)
      ? few
      : many;
  return '$count $word';
}

class BookingConfirmationSheet extends StatefulWidget {
  const BookingConfirmationSheet({
    super.key,
    required this.listing,
    required this.draft,
    this.draftStore,
    this.bookingsRepository,
    this.notificationsRepository,
    this.onBookingCreated,
  });

  final SearchListing listing;
  final BookingDraft draft;
  final BookingDraftStore? draftStore;
  final BookingsRepository? bookingsRepository;
  final NotificationsRepository? notificationsRepository;
  final ValueChanged<Booking>? onBookingCreated;

  static Future<Booking?> show(
    BuildContext context, {
    required SearchListing listing,
    required BookingDraft draft,
    BookingDraftStore? draftStore,
    BookingsRepository? bookingsRepository,
    NotificationsRepository? notificationsRepository,
    ValueChanged<Booking>? onBookingCreated,
  }) {
    return showModalBottomSheet<Booking>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      barrierColor: const Color(0x661A1B1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => BookingConfirmationSheet(
        listing: listing,
        draft: draft,
        draftStore: draftStore,
        bookingsRepository: bookingsRepository,
        notificationsRepository: notificationsRepository,
        onBookingCreated: onBookingCreated,
      ),
    );
  }

  @override
  State<BookingConfirmationSheet> createState() =>
      _BookingConfirmationSheetState();
}

class _BookingConfirmationSheetState extends State<BookingConfirmationSheet> {
  late BookingDraft _draft;
  late SearchListing _listing;
  var _busy = false;

  BookingDraftStore get _drafts =>
      widget.draftStore ?? BookingDraftStore.instance;

  BookingsRepository get _bookings =>
      widget.bookingsRepository ?? BookingsRepositoryScope.instance;

  NotificationsRepository get _notifications =>
      widget.notificationsRepository ?? NotificationsRepositoryScope.instance;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft;
    _listing = widget.listing.withStay(
      checkIn: _draft.checkIn,
      checkOut: _draft.checkOut,
    );
  }

  BookingMoney get _money {
    return BookingMoney.fromStay(
      quoteStay(
        pricePerNight: _listing.pricePerNight,
        price14: _listing.price14,
        price28: _listing.price28,
        nights: stayNightsBetween(_draft.checkIn, _draft.checkOut),
      ),
    );
  }

  Future<void> _editDates() async {
    if (_busy) return;
    final result = await StayDatesSheet.show(
      context,
      checkIn: _draft.checkIn,
      checkOut: _draft.checkOut,
      listingId: _listing.id,
      bookingsRepository: _bookings,
    );
    if (!mounted || result == null) return;
    final next = _draft.copyWith(
      checkIn: result.checkIn,
      checkOut: result.checkOut,
    );
    await _drafts.save(next);
    if (!mounted) return;
    setState(() {
      _draft = next;
      _listing = widget.listing.withStay(
        checkIn: next.checkIn,
        checkOut: next.checkOut,
      );
    });
  }

  Future<void> _editGuests() async {
    if (_busy) return;
    final guests = await GuestsSheet.show(
      context,
      adults: _draft.adults,
      children: _draft.children,
      pets: _draft.pets,
      petsAllowed: widget.listing.petsAllowed,
    );
    if (!mounted || guests == null) return;
    final next = _draft.copyWith(
      adults: guests.adults,
      children: guests.children,
      pets: guests.pets,
      petsAllowed: widget.listing.petsAllowed,
    );
    await _drafts.save(next);
    if (!mounted) return;
    setState(() => _draft = next);
  }

  Future<void> _goBack() async {
    if (_busy) return;
    await _drafts.clear();
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _book() async {
    if (_busy) return;
    final session = AuthRepositoryScope.session.value;
    if (session == null || session.userId.isEmpty) {
      _showMessage(_loginRequired);
      return;
    }
    setState(() => _busy = true);
    try {
      final booking = await _bookings.create(
        listing: _listing,
        checkIn: _draft.checkIn,
        checkOut: _draft.checkOut,
        adults: _draft.adults,
        children: _draft.children,
        pets: _draft.pets,
      );
      await _drafts.clear();
      try {
        await _notifications.createForBooking(booking);
      } on NotificationException catch (_) {
        // Попап 1:11832 — основной UX; инбокс не должен его блокировать.
      } catch (_) {}
      if (!mounted) return;
      widget.onBookingCreated?.call(booking);
      await showBookingRequestSentDialog(context);
      if (!mounted) return;
      Navigator.pop(context, booking);
    } on BookingException catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      await showBookingUnavailableAlert(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      await showBookingUnavailableAlert(context);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height - 36;
    final money = _money;
    final nights = stayNightsBetween(_draft.checkIn, _draft.checkOut);

    return SizedBox(
      key: const ValueKey('confirmation-sheet'),
      height: maxHeight,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, 8 + bottomInset),
        child: Column(
          children: [
            const _SheetHandle(),
            const SizedBox(height: 32),
            const SizedBox(
              width: double.infinity,
              child: Text(
                'Бронирование',
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
            const SizedBox(height: 32),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _ListingSummary(listing: _listing),
                    const SizedBox(height: 32),
                    _FactRow(
                      title: 'Даты проживания',
                      value: confirmationDatesLabel(
                        _draft.checkIn,
                        _draft.checkOut,
                      ),
                      valueKey: const ValueKey('confirmation-dates'),
                      onEdit: _busy ? null : _editDates,
                      editKey: const ValueKey('confirmation-edit-dates'),
                    ),
                    const SizedBox(height: 32),
                    _FactRow(
                      title: 'Гости',
                      value: confirmationGuestsLabel(
                        adults: _draft.adults,
                        children: _draft.children,
                        pets: _draft.pets,
                      ),
                      valueKey: const ValueKey('confirmation-guests'),
                      onEdit: _busy ? null : _editGuests,
                      editKey: const ValueKey('confirmation-edit-guests'),
                    ),
                    const SizedBox(height: 32),
                    _CostBlock(nights: nights, money: money),
                    const SizedBox(height: 32),
                    _CancelBlock(checkIn: _draft.checkIn),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('confirmation-back'),
                    onPressed: _busy ? null : _goBack,
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
                    child: const Text('Вернуться'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('confirmation-book'),
                    onPressed: _busy ? null : _book,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: AppColors.orange,
                      disabledBackgroundColor: const Color(0x66F88A2A),
                      disabledForegroundColor: AppColors.white,
                      foregroundColor: AppColors.white,
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
                    child: const Text('Забронировать'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
          color: const Color.fromRGBO(251, 192, 40, 0.17),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _ListingSummary extends StatelessWidget {
  const _ListingSummary({required this.listing});

  final SearchListing listing;

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
                ListingImage(listing.photo, fit: BoxFit.cover),
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
                listing.title,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  height: 1.2,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    listing.rating,
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
                  const SizedBox(width: 2),
                  Text(
                    reviewCountLabel(reviewCountFromLabel(listing.reviews)),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                      height: 1.4,
                      color: _ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ListingFigmaIcon.mapPin14,
                  const SizedBox(width: 4),
                  Text(
                    listing.city,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      height: 1.5,
                      color: _meta,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ListingFigmaIcon.home14,
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      listing.type,
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
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.title,
    required this.value,
    required this.valueKey,
    required this.editKey,
    this.onEdit,
  });

  final String title;
  final String value;
  final Key valueKey;
  final Key editKey;
  final VoidCallback? onEdit;

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
            height: 1.4,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                key: valueKey,
                value,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  height: 1.4,
                  color: _ink,
                ),
              ),
            ),
            GestureDetector(
              key: editKey,
              onTap: onEdit,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Изменить',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    height: 1.3,
                    color: AppColors.orange,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.orange,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CostBlock extends StatelessWidget {
  const _CostBlock({required this.nights, required this.money});

  final int nights;
  final BookingMoney money;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Стоимость',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            height: 1.4,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        _PriceLine(
          label: nightsLabel(nights),
          labelKey: const ValueKey('confirmation-nights'),
          value: formatRub(money.total),
          valueKey: const ValueKey('confirmation-total'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(height: 1, thickness: 0.5, color: _divider),
        ),
        _PriceLine(
          label: 'Предоплата онлайн',
          value: formatRub(money.prepay),
          valueKey: const ValueKey('confirmation-prepay'),
        ),
        const SizedBox(height: 8),
        _PriceLine(
          label: 'Оплата при заселении',
          value: formatRub(money.remainder),
          valueKey: const ValueKey('confirmation-remainder'),
        ),
        const SizedBox(height: 8),
        const _InfoBanner(),
      ],
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.label,
    required this.value,
    required this.valueKey,
    this.labelKey,
  });

  final String label;
  final String value;
  final Key valueKey;
  final Key? labelKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            key: labelKey,
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
        Text(
          key: valueKey,
          value,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w400,
            fontSize: 14,
            height: 1.4,
            color: _ink,
          ),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _infoFill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Padding(
        padding: EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListingFigmaIcon.warningInfo20,
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Владелец жилья ответит на запрос бронирования в течение 12 часов. '
                'В случае подтверждения брони необходимо внести сумму предоплаты '
                'в течение 12 часов',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CancelBlock extends StatelessWidget {
  const _CancelBlock({required this.checkIn});

  final DateTime checkIn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Условия отмены бронирования',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            height: 1.4,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        _PriceLine(
          label: 'Отмена доступна до',
          value: confirmationCancelUntilLabel(checkIn),
          valueKey: const ValueKey('confirmation-cancel-until'),
        ),
        const SizedBox(height: 8),
        const _PriceLine(
          label: 'Возврат предоплаты',
          value: 'нет',
          valueKey: ValueKey('confirmation-prepay-refund'),
        ),
      ],
    );
  }
}
