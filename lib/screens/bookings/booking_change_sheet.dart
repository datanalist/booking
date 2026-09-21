import 'package:flutter/material.dart';

import '../../data/booking.dart';
import '../../data/bookings_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/listing_image.dart';
import '../listing/booking_confirmation_sheet.dart';
import '../listing/guests_sheet.dart';
import '../listing/listing_icons.dart';
import '../listing/stay_dates_sheet.dart';
import '../search/search_listing.dart';

const _ink = Color(0xFF1A1B1C);
const _meta = Color(0xFF525353);
const _divider = Color(0xFFFFE4B8);
const _heroOverlay = Color.fromRGBO(16, 51, 99, 0.05);
const _infoFill = Color.fromRGBO(251, 192, 40, 0.06);
const _dialogInk = Color(0xFF1A1B1D);
const _dialogBarrier = Color(0xFF525353);

/// Боттомшит «Изменить бронирование» (Figma `1:11560`).
///
/// После «Отправить» пишет `status = change_requested` и показывает
/// окно `1:11840`. Возвращает обновлённую запись.
Future<Booking?> showBookingChangeSheet(
  BuildContext context,
  Booking booking,
) {
  return showModalBottomSheet<Booking>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    barrierColor: const Color(0x661A1B1C),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) => BookingChangeSheet(booking: booking),
  );
}

class BookingChangeSheet extends StatefulWidget {
  const BookingChangeSheet({
    super.key,
    required this.booking,
    this.repository,
  });

  final Booking booking;
  final BookingsRepository? repository;

  @override
  State<BookingChangeSheet> createState() => _BookingChangeSheetState();
}

class _BookingChangeSheetState extends State<BookingChangeSheet> {
  late DateTime _checkIn;
  late DateTime _checkOut;
  late int _adults;
  late int _children;
  late int _pets;
  var _busy = false;

  BookingsRepository get _bookings =>
      widget.repository ?? BookingsRepositoryScope.instance;

  @override
  void initState() {
    super.initState();
    final booking = widget.booking;
    _checkIn = booking.checkIn;
    _checkOut = booking.checkOut;
    _adults = booking.adults;
    _children = booking.children;
    _pets = booking.pets;
  }

  bool get _datesChanged =>
      !_sameDay(_checkIn, widget.booking.checkIn) ||
      !_sameDay(_checkOut, widget.booking.checkOut);

  bool get _guestsChanged =>
      _adults != widget.booking.adults ||
      _children != widget.booking.children ||
      _pets != widget.booking.pets;

  Future<void> _editDates() async {
    if (_busy) return;
    final result = await StayDatesSheet.show(
      context,
      checkIn: _checkIn,
      checkOut: _checkOut,
      listingId: widget.booking.listingId,
      excludeBookingId: widget.booking.id,
    );
    if (!mounted || result == null) return;
    setState(() {
      _checkIn = result.checkIn;
      _checkOut = result.checkOut;
    });
  }

  Future<void> _editGuests() async {
    if (_busy) return;
    final guests = await GuestsSheet.show(
      context,
      adults: _adults < 1 ? 1 : _adults,
      children: _children,
      pets: _pets,
    );
    if (!mounted || guests == null) return;
    setState(() {
      _adults = guests.adults;
      _children = guests.children;
      _pets = guests.pets;
    });
  }

  Future<void> _send() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await _bookings.patch(
        id: widget.booking.id,
        status: BookingStatus.changeRequested,
        requestedCheckIn: _datesChanged ? _checkIn : null,
        requestedCheckOut: _datesChanged ? _checkOut : null,
        adults: _guestsChanged ? _adults : null,
        children: _guestsChanged ? _children : null,
        pets: _guestsChanged ? _pets : null,
      );
      if (!mounted) return;
      await showBookingChangeSentDialog(context);
      if (!mounted) return;
      Navigator.pop(context, updated);
    } on BookingException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage('Не удалось сохранить бронирование');
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
    final nights = stayNightsBetween(_checkIn, _checkOut);
    final money = widget.booking;

    return SizedBox(
      key: const ValueKey<String>('booking-change-sheet'),
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
                'Изменить бронирование',
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
                    _ListingSummary(booking: widget.booking),
                    const SizedBox(height: 32),
                    _FactRow(
                      title: 'Даты проживания',
                      value: confirmationDatesLabel(_checkIn, _checkOut),
                      valueKey: const ValueKey<String>('booking-change-dates'),
                      onEdit: _busy ? null : _editDates,
                      editKey: const ValueKey<String>(
                        'booking-change-edit-dates',
                      ),
                    ),
                    const SizedBox(height: 32),
                    _FactRow(
                      title: 'Гости',
                      value: confirmationGuestsLabel(
                        adults: _adults,
                        children: _children,
                        pets: _pets,
                      ),
                      valueKey: const ValueKey<String>('booking-change-guests'),
                      onEdit: _busy ? null : _editGuests,
                      editKey: const ValueKey<String>(
                        'booking-change-edit-guests',
                      ),
                    ),
                    const SizedBox(height: 32),
                    _CostBlock(
                      nights: nights,
                      total: money.total,
                      prepay: money.prepay,
                      remainder: money.remainder,
                    ),
                    const SizedBox(height: 32),
                    _CancelBlock(checkIn: _checkIn),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey<String>('booking-change-back'),
                    onPressed: _busy ? null : () => Navigator.pop(context),
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
                    key: const ValueKey<String>('booking-change-send'),
                    onPressed: _busy ? null : _send,
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
                    child: const Text('Отправить'),
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

/// Модалка «Запрос на изменение бронирования отправлен» (Figma `1:11840`).
Future<void> showBookingChangeSentDialog(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'booking-change-sent',
    barrierColor: _dialogBarrier,
    pageBuilder: (context, animation, secondaryAnimation) {
      return const _BookingChangeSentDialog();
    },
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class _BookingChangeSentDialog extends StatelessWidget {
  const _BookingChangeSentDialog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 19),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 355),
            child: DecoratedBox(
              key: const ValueKey<String>('booking-change-sent-dialog'),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Запрос на изменение бронирования отправлен',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        height: 1,
                        letterSpacing: 0.018,
                        color: _dialogInk,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Ожидайте подтверждение внесенных изменений от '
                      'владельца жилья в течение 12 часов',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                        height: 1.4,
                        color: _dialogInk,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 52,
                      width: double.infinity,
                      child: FilledButton(
                        key: const ValueKey<String>('booking-change-sent-ok'),
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: AppColors.orange,
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
                        child: const Text('Ок'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
  const _ListingSummary({required this.booking});

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                booking.title,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  height: 1.2,
                  color: _ink,
                ),
              ),
              if (booking.city.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    ListingFigmaIcon.mapPin14,
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        booking.city,
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
  const _CostBlock({
    required this.nights,
    required this.total,
    required this.prepay,
    required this.remainder,
  });

  final int nights;
  final int total;
  final int prepay;
  final int remainder;

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
          labelKey: const ValueKey<String>('booking-change-nights'),
          value: formatRub(total),
          valueKey: const ValueKey<String>('booking-change-total'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(height: 1, thickness: 0.5, color: _divider),
        ),
        _PriceLine(
          label: 'Предоплата онлайн',
          value: formatRub(prepay),
          valueKey: const ValueKey<String>('booking-change-prepay'),
        ),
        const SizedBox(height: 8),
        _PriceLine(
          label: 'Оплата при заселении',
          value: formatRub(remainder),
          valueKey: const ValueKey<String>('booking-change-remainder'),
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
          valueKey: const ValueKey<String>('booking-change-cancel-until'),
        ),
        const SizedBox(height: 8),
        const _PriceLine(
          label: 'Возврат предоплаты',
          value: 'нет',
          valueKey: ValueKey<String>('booking-change-prepay-refund'),
        ),
      ],
    );
  }
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
