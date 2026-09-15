import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Кнопка избранного по макету: белый круг 36×36 и глиф Iconly Heart.
class FavoriteHeartButton extends StatelessWidget {
  const FavoriteHeartButton({
    super.key,
    required this.favorite,
    required this.onTap,
    this.size = 36,
    this.iconSize = 20,
  });

  final bool favorite;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  static const outlineAsset =
      'images/SearchBarIcons/Light-Outline/Heart.png';
  static const filledAsset = 'images/SearchBarIcons/Bold/Heart.png';

  @override
  Widget build(BuildContext context) {
    final tooltip = favorite ? 'Убрать из избранного' : 'В избранное';

    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Image.asset(
                favorite ? filledAsset : outlineAsset,
                width: iconSize,
                height: iconSize,
                fit: BoxFit.contain,
                color: favorite ? AppColors.orange : AppColors.textPrimary,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
