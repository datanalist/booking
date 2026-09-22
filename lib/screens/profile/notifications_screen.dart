import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/inbox_notification.dart';
import '../../data/notifications_repository.dart';
import '../../theme/app_theme.dart';

const _ink = Color(0xFF1A1B1D);
const _meta = Color(0xFF525353);
const _backBorder = Color(0xFFFFE4B8);
const _cardFill = Color.fromRGBO(251, 192, 40, 0.06);
const _cardStroke = Color.fromRGBO(251, 192, 40, 0.17);

/// Инбокс «Уведомления» по макету Figma `1:11396`.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.repository});

  final NotificationsRepository? repository;

  /// Для виджет-тестов: `Duration.zero` отключает Timer.periodic
  /// (иначе `pumpAndSettle` никогда не завершится).
  @visibleForTesting
  static Duration? debugPollInterval;

  static Future<void> open(
    BuildContext context, {
    NotificationsRepository? repository,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => NotificationsScreen(repository: repository),
      ),
    );
  }

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  /// На проде SSE по `notifications` ненадёжен так же, как create `messages`.
  /// Пока экран открыт — тот же запасной poll, что у списка чатов.
  static const _pollInterval = Duration(seconds: 2);

  var _items = const <InboxNotification>[];
  var _loading = true;
  var _refreshInFlight = false;
  Timer? _pollTimer;

  NotificationsRepository get _repository =>
      widget.repository ?? NotificationsRepositoryScope.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_load(silent: false));
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    final interval = NotificationsScreen.debugPollInterval ?? _pollInterval;
    if (interval <= Duration.zero) return;
    _pollTimer = Timer.periodic(interval, (_) {
      unawaited(_load(silent: true));
    });
  }

  /// Hot reload не вызывает initState: таймер мог так и не стартовать.
  void _ensurePolling() {
    final interval = NotificationsScreen.debugPollInterval ?? _pollInterval;
    if (interval <= Duration.zero) return;
    if (_pollTimer != null && _pollTimer!.isActive) return;
    _startPolling();
  }

  Future<void> _load({required bool silent}) async {
    if (!mounted || _refreshInFlight) return;
    _refreshInFlight = true;
    try {
      final items = await _repository.fetchMine();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (silent && _items.isNotEmpty) return;
      setState(() => _loading = false);
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<void> _onTap(InboxNotification item) async {
    if (item.read) return;
    try {
      await _repository.markRead(item.id);
      if (!mounted) return;
      setState(() {
        _items = [
          for (final notice in _items)
            if (notice.id == item.id)
              InboxNotification(
                id: notice.id,
                userId: notice.userId,
                title: notice.title,
                body: notice.body,
                read: true,
                bookingId: notice.bookingId,
                listingId: notice.listingId,
                chatId: notice.chatId,
                created: notice.created,
                updated: notice.updated,
              )
            else
              notice,
        ];
      });
    } catch (_) {
      // Бейдж и точка остаются непрочитанными, если сервер отклонил запись.
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensurePolling();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        key: const ValueKey<String>('notifications-screen'),
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                _BackButton(onTap: () => Navigator.of(context).pop()),
                const SizedBox(height: 24),
                const Text(
                  'Уведомления',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    height: 1,
                    letterSpacing: 0.018,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _items.isEmpty
                      ? const Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            'Пока нет уведомлений',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontWeight: FontWeight.w400,
                              fontSize: 14,
                              height: 1.4,
                              color: _meta,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return _NotificationCard(
                              item: item,
                              onTap: () => _onTap(item),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final InboxNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stamp = item.when;
    final when = stamp == null ? '' : notificationWhenLabel(stamp);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('notifications-item-${item.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _cardFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardStroke),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (!item.read) ...[
                      const _UnreadDot(),
                      const SizedBox(width: 9),
                    ],
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1.4,
                          color: _ink,
                        ),
                      ),
                    ),
                    if (when.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        when,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w400,
                          fontSize: 10,
                          height: 1.4,
                          color: _meta,
                        ),
                      ),
                    ],
                  ],
                ),
                if (item.body.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.body,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      height: 1.5,
                      color: _ink,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 7,
      height: 7,
      child: SvgPicture.asset(
        'images/profile/unread-dot-7.svg',
        width: 7,
        height: 7,
        excludeFromSemantics: true,
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Назад',
      child: Material(
        color: AppColors.white,
        shape: const CircleBorder(side: BorderSide(color: _backBorder)),
        child: InkWell(
          key: const ValueKey<String>('notifications-back'),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: Center(child: _BackArrowIcon()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackArrowIcon extends StatelessWidget {
  const _BackArrowIcon();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 2,
      child: SvgPicture.asset(
        'images/profile/arrow-left.svg',
        width: 13.1667,
        height: 7.33333,
        excludeFromSemantics: true,
      ),
    );
  }
}
