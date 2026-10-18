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

  /// Для виджет-тестов: `Duration.zero` отключает Timer.periodic
  /// (иначе `pumpAndSettle` никогда не завершится).
  @visibleForTesting
  static Duration? debugPollInterval;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  /// На проде SSE по `chats` тоже бывает тихим (как create `messages`).
  /// Без poll превью и бейдж вкладки зависают, пока пользователь не
  /// переключит вкладку / не сделает pull-to-refresh.
  static const _pollInterval = Duration(seconds: 2);

  /// Дольше этого запрос списка считаем зависшим и отпускаем следующий.
  static const _refreshTimeout = Duration(seconds: 8);

  var _items = const <ChatPreview>[];
  var _loading = false;
  var _tabVisible = false;
  var _refreshInFlight = false;
  var _refreshQueued = false;
  final _threadPreviewIds = <String>{};
  Object? _error;
  UnsubscribeFunc? _unsubscribe;
  Timer? _pollTimer;

  ChatsRepository get _repository =>
      widget.repository ?? ChatsRepositoryScope.instance;

  @override
  void initState() {
    super.initState();
    AuthRepositoryScope.session.addListener(_reload);
    ChatsRepositoryScope.listVersion.addListener(_reload);
    // Подписка и poll живут и на других вкладках: бейдж нижней панели
    // должен видеть входящие, пока открыт «Поиск» или «Брони».
    unawaited(_refresh(silent: false));
    _listenRealtime();
    _startPolling();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.of(context);
    if (visible && !_tabVisible) {
      unawaited(_refresh(silent: _items.isNotEmpty));
    }
    _tabVisible = visible;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    AuthRepositoryScope.session.removeListener(_reload);
    ChatsRepositoryScope.listVersion.removeListener(_reload);
    unawaited(_stopRealtime());
    super.dispose();
  }

  void _reload() => unawaited(_refresh(silent: _items.isNotEmpty));

  void _startPolling() {
    _pollTimer?.cancel();
    final interval = ChatScreen.debugPollInterval ?? _pollInterval;
    if (interval <= Duration.zero) return;
    _pollTimer = Timer.periodic(interval, (_) {
      unawaited(_refresh(silent: true));
    });
  }

  /// Hot reload не вызывает initState: таймер мог так и не стартовать.
  void _ensurePolling() {
    final interval = ChatScreen.debugPollInterval ?? _pollInterval;
    if (interval <= Duration.zero) return;
    if (_pollTimer != null && _pollTimer!.isActive) return;
    _startPolling();
  }

  Future<void> _listenRealtime() async {
    await _stopRealtime();
    try {
      _unsubscribe = await _repository.subscribeChats(() {
        if (mounted) unawaited(_refresh(silent: true));
      });
    } catch (_) {
      // Realtime optional — list still works via poll / pull.
    }
  }

  Future<void> _stopRealtime() async {
    final stop = _unsubscribe;
    _unsubscribe = null;
    if (stop != null) await stop();
  }

  Future<void> _refresh({required bool silent}) async {
    if (!mounted) return;
    // Пока предыдущий fetch висит, новый не отбрасываем: после него
    // список всё равно перечитывается, иначе превью остаётся старым.
    if (_refreshInFlight) {
      _refreshQueued = true;
      return;
    }
    _refreshInFlight = true;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final items = await _repository.fetchMine().timeout(_refreshTimeout);
      if (!mounted) return;
      _showChats(items);
    } on TimeoutException {
      // Сокет мог зависнуть на SSL. Следующий poll / очередь возьмут свежие данные.
    } catch (error) {
      if (!mounted) return;
      if (silent && _items.isNotEmpty) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    } finally {
      _refreshInFlight = false;
      if (_refreshQueued && mounted) {
        _refreshQueued = false;
        unawaited(_refresh(silent: true));
      }
    }
  }

  void _showChats(List<ChatPreview> items) {
    final merged = _keepNewerLocalPreviews(items);
    ChatsRepositoryScope.setUnread(
      merged.fold<int>(0, (sum, chat) => sum + chat.unreadCount),
    );
    setState(() {
      _items = merged;
      _loading = false;
      _error = null;
    });
  }

  /// Ответ списка иногда старше сообщения, которое уже видно в треде.
  List<ChatPreview> _keepNewerLocalPreviews(List<ChatPreview> fetched) {
    final localById = {for (final item in _items) item.id: item};
    return [
      for (final item in fetched) _preferNewerPreview(localById[item.id], item),
    ];
  }

  ChatPreview _preferNewerPreview(ChatPreview? local, ChatPreview fetched) {
    if (local == null || !_threadPreviewIds.contains(fetched.id)) {
      return fetched;
    }
    final localAt = local.lastMessageAt;
    final fetchedAt = fetched.lastMessageAt;
    final localIsNewer =
        localAt != null && (fetchedAt == null || localAt.isAfter(fetchedAt));
    if (!localIsNewer) {
      _threadPreviewIds.remove(fetched.id);
      return fetched;
    }
    return fetched.copyWith(
      lastMessage: local.lastMessage,
      lastMessageAt: localAt,
    );
  }

  void _applyThreadPreview(ChatPreview updated) {
    final index = _items.indexWhere((item) => item.id == updated.id);
    if (index < 0) return;
    _threadPreviewIds.add(updated.id);
    final next = List<ChatPreview>.of(_items);
    next[index] = updated;
    setState(() => _items = next);
  }

  Future<void> _open(ChatPreview chat) async {
    final updated = await ChatThreadScreen.open(
      context,
      chat: chat,
      repository: _repository,
    );
    if (!mounted) return;
    if (updated != null) _applyThreadPreview(updated);
    unawaited(_refresh(silent: true));
  }

  @override
  Widget build(BuildContext context) {
    _ensurePolling();
    return ColoredBox(
      color: AppColors.white,
      child: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading && _items.isEmpty && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return _ChatError(onRetry: () => unawaited(_refresh(silent: false)));
    }
    if (_items.isEmpty) {
      return const _EmptyChats();
    }
    return RefreshIndicator(
      onRefresh: () => _refresh(silent: false),
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
          return _ChatTile(chat: chat, onTap: () => _open(chat));
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
            TextButton(onPressed: onRetry, child: const Text('Повторить')),
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
