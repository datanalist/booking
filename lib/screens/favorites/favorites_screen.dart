import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Каркас вкладки «Избранное». Содержимое — по макету «Избранное».
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: Text(
            'Добавленное в избранное жилье будет отображаться здесь',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w400,
              fontSize: 16,
              height: 1.25,
              color: AppColors.emptyHint,
            ),
          ),
        ),
      ),
    );
  }
}
