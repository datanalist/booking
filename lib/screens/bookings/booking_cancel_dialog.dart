import 'package:flutter/material.dart';

import '../../data/booking.dart';
import '../../data/bookings_repository.dart';
import '../../theme/app_theme.dart';

const _barrier = Color(0xFF525353);
const _ink = Color(0xFF1A1B1D);

/// Подтверждение отмены брони (Figma `1:13635`).
///
/// После «Да, отменить» пишет `status = cancelled` и возвращает
/// обновлённую запись.
Future<Booking?> showBookingCancelDialog(
  BuildContext context,
  Booking booking,
) async {
  final confirmed = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'booking-cancel',
    barrierColor: _barrier,
    pageBuilder: (context, animation, secondaryAnimation) {
      return const _BookingCancelDialog();
    },
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
  if (confirmed != true) return null;
  return BookingsRepositoryScope.instance.patch(
    id: booking.id,
    status: BookingStatus.cancelled,
    cancelReason: BookingCancelReason.guest,
  );
}

class _BookingCancelDialog extends StatelessWidget {
  const _BookingCancelDialog();

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
              key: const ValueKey<String>('booking-cancel-dialog'),
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
                      'Отменить бронирование?',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        height: 1,
                        letterSpacing: 0.018,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'В случае отмены бронирования средства\n'
                      'за предоплату не возвращаются',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                        height: 1.4,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 52,
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              key: const ValueKey<String>('booking-cancel-no'),
                              onPressed: () => Navigator.of(context).pop(false),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Вернуться',
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              key: const ValueKey<String>('booking-cancel-yes'),
                              onPressed: () => Navigator.of(context).pop(true),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Да, отменить',
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              ),
                            ),
                          ),
                        ],
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
