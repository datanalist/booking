import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../data/auth_repository.dart';
import '../../data/chat.dart';
import '../../data/chats_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/listing_image.dart';
import 'chat_thread_screen.dart';

/// Список чатов вкладки «Чаты» (Figma `1:14075` / пусто `1:13967`).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.repository});

  final ChatsRepository? repository;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  var _items = const <ChatPreview>[];
  var _loading = false;
  var _tabVisible = false;
  Object? _error;
  UnsubscribeFunc? _unsubscribe;

  ChatsRepository get _repository =>
      widget.repository ?? ChatsRepositoryScope.instance;

  @override
  void initState() {
    super.initState();
    AuthRepositoryScope.session.addListener(_reload);
    ChatsRepositoryScope.listVersion.addListener(_reload);
    // Подписка живёт и на других вкладках: бейдж нижней панели
    // должен видеть входящие, пока открыт «Поиск» или «Брони».
    _load();
    _listenRealtime();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.of(context);
    if (visible && !_tabVisible) {
      _load();
    }
    _tabVisible = visible;
  }

  @override
  void dispose() {
    AuthRepositoryScope.session.removeListener(_reload);
    ChatsRepositoryScope.listVersion.removeListener(_reload);
    unawaited(_stopRealtime());
    super.dispose();
  }

  void _reload() => _load();

  Future<void> _listenRealtime() async {
    await _stopRealtime();
    try {
      _unsubscribe = await _repository.subscribeChats(() {
        if (mounted) _load();
      });
    } catch (_) {
      // Realtime optional — list still works via pull.
    }
  }

  Future<void> _stopRealtime() async {
    final stop = _unsubscribe;
    _unsubscribe = null;
    if (stop != null) await stop();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repository.fetchMine();
      if (!mounted) return;
      ChatsRepositoryScope.setUnread(
        items.fold<int>(0, (sum, chat) => sum + chat.unreadCount),
      );
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _open(ChatPreview chat) async {
    await ChatThreadScreen.open(context, chat: chat, repository: _repository);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.white,
      child: SafeArea(
        child: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading && _items.isEmpty && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return _ChatError(onRetry: _load);
    }
    if (_items.isEmpty) {
      return const _EmptyChats();
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.orange,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        itemCount: _items.length,
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
          final chat = _items[index];
          return _ChatTile(
            chat: chat,
            onTap: () => _open(chat),
          );
        },
      ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NoConversationIllustration(),
            SizedBox(height: 24),
            Text(
              'Чат с владельцем жилья появится после бронирования',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoConversationIllustration extends StatelessWidget {
  const _NoConversationIllustration();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'images/chat/empty-no-conversation.svg',
      width: 174.679,
      height: 160,
      excludeFromSemantics: true,
    );
  }
}

class _ChatError extends StatelessWidget {
  const _ChatError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Не удалось загрузить чаты',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 1.4,
                color: AppColors.emptyHint,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.onTap});

  final ChatPreview chat;
  final VoidCallback onTap;

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
    final unread = chat.unreadCount > 0;
    return InkWell(
      key: ValueKey<String>('chat-tile-${chat.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 80,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 80,
                height: 80,
                child: chat.listingPhoto.isEmpty
                    ? const ColoredBox(color: AppColors.tabBarBorder)
                    : ListingImage(
                        chat.listingPhoto,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
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
                          chat.titleForViewer(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _nameStyle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(chat.timeLabel(), style: _timeStyle),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessage.isEmpty
                              ? 'Нет сообщений'
                              : chat.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: unread ? _unreadMessageStyle : _messageStyle,
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 8),
                        _UnreadBadge(count: chat.unreadCount),
                      ],
                    ],
                  ),
                  _StayMeta(
                    city: chat.city,
                    dates: chat.datesLabel,
                    guests: chat.guestsLabel,
                    style: _metaStyle,
                  ),
                ],
              ),
            ),
          ],
        ),
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
    final parts = <String>[
      if (city.isNotEmpty) city,
      if (dates.isNotEmpty) dates,
      if (guests.isNotEmpty) guests,
    ];
    if (parts.isEmpty) return const SizedBox(height: 18);
    return Row(
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) const _MetaDot(),
          Flexible(
            child: Text(
              parts[i],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
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
    final label = count > 99 ? '99+' : '$count';
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.orange,
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
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
