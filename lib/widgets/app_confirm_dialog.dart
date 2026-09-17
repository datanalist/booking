import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const _barrier = Color(0xFF525353);
const _titleColor = Color(0xFF1A1B1D);
const _bodyColor = Color(0xFF525353);

/// Модалка Да/Нет в стиле выхода из профиля (Figma `1:14582`).
Future<bool?> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  String? body,
  required String dialogKey,
  required String noKey,
  required String yesKey,
  String barrierLabel = 'confirm',
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: _barrier,
    pageBuilder: (context, animation, secondaryAnimation) {
      return _AppConfirmDialog(
        title: title,
        body: body,
        dialogKey: dialogKey,
        noKey: noKey,
        yesKey: yesKey,
      );
    },
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class _AppConfirmDialog extends StatelessWidget {
  const _AppConfirmDialog({
    required this.title,
    required this.body,
    required this.dialogKey,
    required this.noKey,
    required this.yesKey,
  });

  final String title;
  final String? body;
  final String dialogKey;
  final String noKey;
  final String yesKey;

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
              key: ValueKey<String>(dialogKey),
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
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        height: 1,
                        letterSpacing: 0.018,
                        color: _titleColor,
                      ),
                    ),
                    if (body != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        body!,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          height: 1.4,
                          color: _bodyColor,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 52,
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              key: ValueKey<String>(noKey),
                              onPressed: () => Navigator.of(context).pop(false),
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
                              child: const Text('Нет'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              key: ValueKey<String>(yesKey),
                              onPressed: () => Navigator.of(context).pop(true),
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
                              child: const Text('Да'),
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
