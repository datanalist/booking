import 'package:flutter/material.dart';

import '../../data/booking.dart';
import '../../theme/app_theme.dart';

/// Чип статуса на списке «Брони» и на карточке брони.
enum BookingStatusChip {
  awaitingPrepayment,
  confirmed,
  awaitingOwner,
  cancelled,
}

/// Общий чип `awaitingOwner` для `pending_host` и `change_requested`.
///
/// Это не баг и не слияние статусов в БД: ключи API разные
/// (`BookingStatus.fromApi` их различает), а в макете Предстоящих
/// (Figma `1:11949`) отдельного чипа «запрос изменений» нет — оба
/// ждут ответа хозяина (первый запрос или правки дат/гостей).
/// После «Отправить» в шите изменения чип остаётся
/// «ожидание подтверждения от владельца».
BookingStatusChip? bookingStatusChipFor(BookingStatus status) {
  return switch (status) {
    BookingStatus.pendingHost ||
    BookingStatus.changeRequested =>
      BookingStatusChip.awaitingOwner,
    BookingStatus.awaitingPrepayment => BookingStatusChip.awaitingPrepayment,
    BookingStatus.confirmed => BookingStatusChip.confirmed,
    BookingStatus.cancelRequested ||
    BookingStatus.cancelled =>
      BookingStatusChip.cancelled,
    BookingStatus.completed => null,
  };
}

extension BookingStatusChipStyle on BookingStatusChip {
  String get label => switch (this) {
        BookingStatusChip.awaitingPrepayment => 'ожидание предоплаты',
        BookingStatusChip.confirmed => 'бронирование подтверждено',
        BookingStatusChip.awaitingOwner =>
          'ожидание подтверждения от владельца',
        BookingStatusChip.cancelled => 'отменено',
      };

  Color get background => switch (this) {
        BookingStatusChip.awaitingPrepayment =>
          const Color.fromRGBO(77, 56, 232, 0.23),
        BookingStatusChip.confirmed => const Color.fromRGBO(47, 235, 39, 0.3),
        BookingStatusChip.awaitingOwner =>
          const Color.fromRGBO(91, 197, 242, 0.3),
        BookingStatusChip.cancelled => const Color.fromRGBO(251, 192, 40, 0.17),
      };
}

class BookingStatusChipView extends StatelessWidget {
  const BookingStatusChipView({super.key, required this.status});

  final BookingStatusChip status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 3, 6, 3),
        child: Text(
          status.label,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w400,
            fontSize: 10,
            height: 1.4,
            color: Color(0xFF1A1B1D),
          ),
        ),
      ),
    );
  }
}
