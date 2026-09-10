import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Каркас вкладки «Чат». Содержимое — по макету «Чаты».
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: Text(
            'Чат с владельцем жилья появится после бронирования',
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
