import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/app_theme.dart';

export '../chat/chat_thread_screen.dart' show openHostChatStub;

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
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 355),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 24),
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
                            height: 1.2,
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
    );
  }
}
