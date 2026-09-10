import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Каркас вкладки «Профиль». Содержимое — по макету «Профиль».
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: Text(
            'Профиль',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 24,
              height: 1.2,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
