import 'package:flutter/material.dart';

import '../../data/booking.dart';
import '../../theme/app_theme.dart';
import 'booking_address_map_screen.dart';

const _barrier = Color(0xFF525353);
const _titleColor = Color(0xFF1A1B1D);

/// Подтверждение открытия карты по адресу брони (Figma `1:13629`).
Future<void> showBookingAddressDialog(
  BuildContext context,
  Booking booking,
) async {
  final openMap = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'booking-address',
    barrierColor: _barrier,
    pageBuilder: (context, animation, secondaryAnimation) {
      return const _BookingAddressDialog();
    },
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
  if (openMap != true || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BookingAddressMapScreen(booking: booking),
    ),
  );
}

class _BookingAddressDialog extends StatelessWidget {
  const _BookingAddressDialog();

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
              key: const ValueKey<String>('booking-address-dialog'),
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
                      'Посмотреть адрес на картах?',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        height: 1,
                        letterSpacing: 0.018,
                        color: _titleColor,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 52,
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              key: const ValueKey<String>('booking-address-no'),
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
                                  'Нет',
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              key: const ValueKey<String>('booking-address-yes'),
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
                                  'Да, смотреть',
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
