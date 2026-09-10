import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Каркас вкладки «Поиск жилья». Содержимое — по макету «Поиск».
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: Text(
            'Укажите город и даты поездки, чтобы увидеть подходящие варианты',
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
