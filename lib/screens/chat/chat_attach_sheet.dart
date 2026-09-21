import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

const _ink = Color(0xFF1A1B1D);
const _meta = Color(0xFF525353);
const _optionBorder = Color.fromRGBO(251, 192, 40, 0.17);

/// Шит «Добавить фото или файл» (Figma `1:13953`).
enum ChatAttachChoice { camera, gallery }

Future<ChatAttachChoice?> showChatAttachSheet(BuildContext context) {
  return showModalBottomSheet<ChatAttachChoice>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: _meta,
    builder: (context) {
      final bottom = MediaQuery.paddingOf(context).bottom;
      return Padding(
        key: const ValueKey<String>('chat-attach-sheet'),
        padding: EdgeInsets.fromLTRB(33, 0, 33, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const SizedBox(
                    height: 36,
                    child: Center(
                      child: Text(
                        'Добавить фото или файл',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          height: 1.5,
                          color: _meta,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: _optionBorder),
                  _AttachOption(
                    keyName: 'chat-attach-camera',
                    label: 'Сделать фото с камеры',
                    onTap: () =>
                        Navigator.of(context).pop(ChatAttachChoice.camera),
                  ),
                  const Divider(height: 1, thickness: 1, color: _optionBorder),
                  _AttachOption(
                    keyName: 'chat-attach-gallery',
                    label: 'Добавить фото из галереи',
                    onTap: () =>
                        Navigator.of(context).pop(ChatAttachChoice.gallery),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Material(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                key: const ValueKey<String>('chat-attach-cancel'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).pop(),
                child: const SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: Center(
                    child: Text(
                      'Отмена',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        height: 20 / 16,
                        color: _ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _AttachOption extends StatelessWidget {
  const _AttachOption({
    required this.keyName,
    required this.label,
    required this.onTap,
  });

  final String keyName;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey<String>(keyName),
      onTap: onTap,
      child: SizedBox(
        height: 48,
        width: double.infinity,
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w400,
              fontSize: 16,
              height: 24 / 16,
              color: _ink,
            ),
          ),
        ),
      ),
    );
  }
}
