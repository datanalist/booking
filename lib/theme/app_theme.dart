import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppColors {
  static const white = Color(0xFFFFFFFF);
  static const orange = Color(0xFFF88A2A);
  static const yellow = Color(0xFFFBC028);
  static const overlayBottom = Color(0xFF2A2926);
  static const textPrimary = Color(0xFF1A1A1A);
  static const tabInactive = Color(0xFF9A9A9A);
  static const tabBarBorder = Color(0xFFE8E8E8);
  static const emptyHint = Color(0xFF6B6B6B);
}

abstract final class AppTheme {
  static const fontFamily = 'Noto Sans';

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.orange,
        primary: AppColors.orange,
        onPrimary: AppColors.white,
        surface: AppColors.white,
      ),
      scaffoldBackgroundColor: AppColors.white,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: fontFamily),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(56),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            height: 1.25,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
    );
  }
}
