import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/booking.dart';
import '../../theme/app_theme.dart';

const _barrier = Color(0xFF525353);
const _ink = Color(0xFF1A1B1D);

enum BookingComplaintChoice { chat, support }

/// Диалог «Пожаловаться на бронирование» (Figma `1:11848`).
Future<BookingComplaintChoice?> showBookingComplaintDialog(
  BuildContext context,
) {
  return showGeneralDialog<BookingComplaintChoice>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'complaint-booking-dialog',
    barrierColor: _barrier,
    pageBuilder: (context, animation, secondaryAnimation) {
      return const _BookingComplaintDialog();
    },
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class _BookingComplaintDialog extends StatelessWidget {
  const _BookingComplaintDialog();

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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Text(
                            'Пожаловаться на бронирование',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              height: 1,
                              letterSpacing: 0.018,
                              color: _ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: const ValueKey<String>(
                              'complaint-booking-close',
                            ),
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: Center(
                                child: SvgPicture.asset(
                                  'images/bookings/complaint-close-20.svg',
                                  width: 20,
                                  height: 20,
                                  excludeFromSemantics: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Вы можете решить вопрос с владельцем жилья напрямую '
                      'в чате или обратиться в поддержку',
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
                      width: double.infinity,
                      child: FilledButton(
                        key: const ValueKey<String>('complaint-booking-chat'),
                        onPressed: () =>
                            Navigator.of(context)
                                .pop(BookingComplaintChoice.chat),
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
                        child: const Text('Написать владельцу'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 52,
                      width: double.infinity,
                      child: OutlinedButton(
                        key: const ValueKey<String>(
                          'complaint-booking-support',
                        ),
                        onPressed: () =>
                            Navigator.of(context)
                                .pop(BookingComplaintChoice.support),
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
                        child: const Text('Обратиться в поддержку'),
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

/// Заглушка чата с владельцем: серверных тредов ещё нет.
Future<void> openHostChatStub(
  BuildContext context, {
  Booking? booking,
  String hostName = '',
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => HostChatStubScreen(
        booking: booking,
        hostName: hostName,
      ),
    ),
  );
}

class HostChatStubScreen extends StatelessWidget {
  const HostChatStubScreen({
    super.key,
    this.booking,
    this.hostName = '',
  });

  final Booking? booking;
  final String hostName;

  @override
  Widget build(BuildContext context) {
    final fromBooking = booking?.hostName.trim() ?? '';
    final name = hostName.trim().isNotEmpty
        ? hostName.trim()
        : fromBooking.isEmpty
            ? 'владельцем'
            : fromBooking;
    return Scaffold(
      key: const ValueKey<String>('complaint-host-chat'),
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: AppColors.white,
                shape: const CircleBorder(
                  side: BorderSide(color: Color(0xFFFFE4B8)),
                ),
                child: InkWell(
                  key: const ValueKey<String>('complaint-host-chat-back'),
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).pop(),
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
              const SizedBox(height: 24),
              const Text(
                'Чат с владельцем',
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
              Text(
                'Диалог с $name появится здесь, когда чаты будут на сервере.',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  height: 1.4,
                  color: Color(0xFF525353),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
