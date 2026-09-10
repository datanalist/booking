import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class _ChatPreview {
  const _ChatPreview({
    required this.name,
    required this.timeLabel,
    required this.message,
    required this.city,
    required this.dates,
    required this.guests,
    required this.photoAsset,
    this.unreadCount = 0,
  });

  final String name;
  final String timeLabel;
  final String message;
  final String city;
  final String dates;
  final String guests;
  final String photoAsset;
  final int unreadCount;
}

/// Заглушечные диалоги по макету «Чаты» (фрейм списка `1:14075`).
const _stubChats = <_ChatPreview>[
  _ChatPreview(
    name: 'Анна Иваненко',
    timeLabel: '13:40',
    message: 'Добрый день, бронирование…',
    city: 'Москва',
    dates: '12.09.24 - 15.09.24',
    guests: '4 гостя',
    photoAsset: 'images/chat/studio-moscow.jpg',
    unreadCount: 2,
  ),
  _ChatPreview(
    name: 'Игнат Прокопенко',
    timeLabel: '15.09.2024',
    message: 'Добрый день, бронирование оплачено',
    city: 'Минск',
    dates: '12.09.24 - 15.09.24',
    guests: '3 гостя',
    photoAsset: 'images/chat/minsk-loft.jpg',
  ),
  _ChatPreview(
    name: 'Ольга Филипова, Админ',
    timeLabel: '13:40',
    message: 'Добрый день, бронирование оплачено',
    city: 'Москва',
    dates: '12.09.24 - 15.09.24',
    guests: '4 гостя',
    photoAsset: 'images/chat/admin-stay.jpg',
  ),
  _ChatPreview(
    name: 'Полина Остапович',
    timeLabel: '15.09.2024',
    message: 'Добрый день, бронирование оплачено',
    city: 'Минск',
    dates: '12.09.24 - 15.09.24',
    guests: '3 гостя',
    photoAsset: 'images/chat/minsk-flat.jpg',
  ),
];

/// Список чатов вкладки «Чат». Нижняя панель общая, здесь не дублируется.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.white,
      child: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
          itemCount: _stubChats.length,
          separatorBuilder: (context, index) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(
                height: 1,
                thickness: 1,
                color: AppColors.tabBarBorder,
              ),
            );
          },
          itemBuilder: (context, index) {
            return _ChatTile(chat: _stubChats[index]);
          },
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat});

  final _ChatPreview chat;

  static const _nameStyle = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 16,
    height: 19 / 16,
    color: AppColors.textPrimary,
  );

  static const _timeStyle = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 18 / 12,
    color: AppColors.tabInactive,
  );

  static const _messageStyle = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 20 / 16,
    color: AppColors.textPrimary,
  );

  static const _unreadMessageStyle = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 16,
    height: 20 / 16,
    color: AppColors.textPrimary,
  );

  static const _metaStyle = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 18 / 12,
    color: AppColors.tabInactive,
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              chat.photoAsset,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const ColoredBox(
                  color: AppColors.tabBarBorder,
                  child: SizedBox(width: 80, height: 80),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        chat.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _nameStyle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(chat.timeLabel, style: _timeStyle),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        chat.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: chat.unreadCount > 0
                            ? _unreadMessageStyle
                            : _messageStyle,
                      ),
                    ),
                    if (chat.unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      _UnreadBadge(count: chat.unreadCount),
                    ],
                  ],
                ),
                _StayMeta(
                  city: chat.city,
                  dates: chat.dates,
                  guests: chat.guests,
                  style: _metaStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StayMeta extends StatelessWidget {
  const _StayMeta({
    required this.city,
    required this.dates,
    required this.guests,
    required this.style,
  });

  final String city;
  final String dates;
  final String guests;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            city,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const _MetaDot(),
        Flexible(
          child: Text(
            dates,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const _MetaDot(),
        Text(guests, style: style),
      ],
    );
  }
}

class _MetaDot extends StatelessWidget {
  const _MetaDot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.tabInactive,
          shape: BoxShape.circle,
        ),
        child: SizedBox(width: 2, height: 2),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.orange,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          height: 1,
          color: AppColors.white,
        ),
      ),
    );
  }
}
