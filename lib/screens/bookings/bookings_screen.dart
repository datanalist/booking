import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Каркас вкладки «Бронирования». Содержимое — по макету «Брони».
class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: Text(
            'Забронированное жилье будет отображаться здесь',
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
