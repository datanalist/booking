import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../data/auth_repository.dart';
import '../../data/booking.dart';
import '../../data/bookings_repository.dart';
import '../../data/chat.dart';
import '../../data/chats_repository.dart';
import '../../screens/auth/photo_access.dart';
import '../../theme/app_theme.dart';
import '../../widgets/listing_image.dart';
import 'chat_attach_sheet.dart';

const _ink = Color(0xFF1A1B1D);
const _meta = Color(0xFF525353);
const _bubbleBorder = Color.fromRGBO(251, 192, 40, 0.17);
const _outgoingFill = Color.fromRGBO(251, 192, 40, 0.06);
const _contextFill = Color.fromRGBO(251, 192, 40, 0.06);
const _composerFill = Color.fromRGBO(248, 138, 42, 0.08);
const _dayColor = Color(0xFF8D8D8D);
const _backBorder = Color(0xFFFFE4B8);
const _placeholder = Color(0xFF717171);
const _roleColor = Color(0xFFFBC028);

/// Тред чата (Figma `1:14157` / с админом `1:14238`).
class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.chat,
    this.repository,
    this.photoLibrary,
  });

  final ChatPreview chat;
  final ChatsRepository? repository;
  final PhotoLibrary? photoLibrary;

  /// Для виджет-тестов: `Duration.zero` отключает Timer.periodic
  /// (иначе `pumpAndSettle` никогда не завершится).
  @visibleForTesting
  static Duration? debugPollInterval;

  static Future<ChatPreview?> open(
    BuildContext context, {
    required ChatPreview chat,
    ChatsRepository? repository,
  }) {
    return Navigator.of(context).push<ChatPreview>(
      MaterialPageRoute<ChatPreview>(
        builder: (context) =>
            ChatThreadScreen(chat: chat, repository: repository),
      ),
    );
  }

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  /// Пока SSE create по `messages` на сервере не доходит стабильно —
  /// короткий poll держит тред свежим (макс. задержка ≈ интервал).
  static const _pollInterval = Duration(seconds: 2);

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  late ChatPreview _chat = widget.chat;
  var _messages = const <ChatMessage>[];

  /// Дольше этого poll треда считаем зависшим и пускаем следующий.
  static const _pollTimeout = Duration(seconds: 8);

  var _loading = true;
  var _sending = false;
  var _pollInFlight = false;
  var _pollQueued = false;
  var _closing = false;
  Object? _error;
  UnsubscribeFunc? _unsubscribe;
  UnsubscribeFunc? _unsubscribeChats;
  Timer? _pollTimer;

  ChatsRepository get _repository =>
      widget.repository ?? ChatsRepositoryScope.instance;

  PhotoLibrary get _photos => widget.photoLibrary ?? DevicePhotoLibrary();

  String get _userId {
    final session = AuthRepositoryScope.session.value;
    if (session != null && session.userId.isNotEmpty) return session.userId;
    return '';
  }

  @override
  void initState() {
    super.initState();
    _load();
    _listenRealtime();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scroll.dispose();
    unawaited(_stopRealtime());
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    final interval = ChatThreadScreen.debugPollInterval ?? _pollInterval;
    if (interval <= Duration.zero) return;
    _pollTimer = Timer.periodic(interval, (_) {
      unawaited(_pollMessages());
    });
  }

  Future<void> _pollMessages() async {
    if (!mounted || _chat.id.isEmpty) return;
    if (_pollInFlight) {
      _pollQueued = true;
      return;
    }
    _pollInFlight = true;
    try {
      final items = await _repository
          .fetchMessages(_chat.id, chat: _chat)
          .timeout(_pollTimeout);
      if (!mounted) return;
      _mergeMessages(items, fromPoll: true);
    } on TimeoutException {
      // Зависший poll не должен глушить следующие сообщения.
    } catch (_) {
      // Poll — запасной канал; ошибки не показываем поверх треда.
    } finally {
      _pollInFlight = false;
      if (_pollQueued && mounted) {
        _pollQueued = false;
        unawaited(_pollMessages());
      }
    }
  }

  ChatPreview _previewForList() {
    ChatMessage? newest;
    for (final item in _messages) {
      final at = item.created;
      final bestAt = newest?.created;
      final newer =
          newest == null ||
          (at != null && (bestAt == null || at.isAfter(bestAt)));
      if (newer) newest = item;
    }
    if (newest == null) return _chat.copyWith(unreadCount: 0);
    return _chat.copyWith(
      lastMessage: newest.previewLabel(),
      lastMessageAt: newest.created ?? _chat.lastMessageAt,
      unreadCount: 0,
    );
  }

  void _close() {
    if (_closing || !mounted) return;
    setState(() => _closing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop(_previewForList());
    });
  }

  void _mergeMessages(List<ChatMessage> items, {required bool fromPoll}) {
    final prevIds = {for (final item in _messages) item.id};
    final added = <ChatMessage>[
      for (final item in items)
        if (!prevIds.contains(item.id)) item,
    ];
    if (added.isEmpty && items.length == _messages.length) {
      // Тот же набор — не дёргаем setState лишний раз, но сбрасываем
      // loading: иначе пустой тред навсегда крутит индикатор.
      if (_loading || _error != null) {
        setState(() {
          _loading = false;
          _error = null;
        });
      }
      return;
    }
    final hadIncoming = added.any((item) => item.authorId != _userId);
    setState(() {
      _messages = items;
      _loading = false;
      _error = null;
    });
    if (hadIncoming || (!fromPoll && added.isNotEmpty)) {
      _scrollToEnd();
    }
    if (hadIncoming) {
      unawaited(_repository.markRead(_chat));
    }
  }

  Future<void> _listenRealtime() async {
    await _stopRealtime();
    try {
      _unsubscribe = await _repository.subscribeMessages(_chat.id, (message) {
        if (!mounted) return;
        if (_messages.any((item) => item.id == message.id)) return;
        setState(() {
          _messages = [..._messages, message];
        });
        _scrollToEnd();
        unawaited(_repository.markRead(_chat));
      });
    } catch (_) {}
    // create по messages молчит; PATCH/hook chats.last_message доходит —
    // сразу тянем тред, не дожидаясь poll-интервала (его не меняем).
    try {
      _unsubscribeChats = await _repository.subscribeChat(_chat.id, () {
        if (mounted) unawaited(_pollMessages());
      });
    } catch (_) {
      try {
        _unsubscribeChats = await _repository.subscribeChats(() {
          if (mounted) unawaited(_pollMessages());
        });
      } catch (_) {}
    }
  }

  Future<void> _stopRealtime() async {
    final stop = _unsubscribe;
    _unsubscribe = null;
    if (stop != null) await stop();
    final stopChats = _unsubscribeChats;
    _unsubscribeChats = null;
    if (stopChats != null) await stopChats();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repository.fetchMessages(_chat.id, chat: _chat);
      if (!mounted) return;
      // Merge, не replace: поздний fetch не должен затирать то, что уже
      // пришло через poll/realtime, пока грузился список.
      _mergeMessages(items, fromPoll: false);
      await _repository.markRead(_chat);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final message = await _repository.sendText(chatId: _chat.id, text: text);
      if (!mounted) return;
      _controller.clear();
      setState(() {
        if (!_messages.any((item) => item.id == message.id)) {
          _messages = [..._messages, message];
        }
        _sending = false;
        _chat = _chat.copyWith(unreadCount: 0);
      });
      _scrollToEnd();
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      final message = error is ChatException
          ? error.message
          : 'Не удалось отправить сообщение';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _attach() async {
    final choice = await showChatAttachSheet(context);
    if (choice == null || !mounted) return;
    File? file;
    if (choice == ChatAttachChoice.camera) {
      final ok = await _photos.requestCamera();
      if (!ok || !mounted) {
        _permissionDenied();
        return;
      }
      file = await _photos.capture();
    } else {
      final ok = await _photos.requestGallery(limited: true);
      if (!ok || !mounted) {
        _permissionDenied();
        return;
      }
      file = await _photos.pickFromGallery();
    }
    if (file == null || !mounted) return;
    setState(() => _sending = true);
    try {
      final message = await _repository.sendImages(
        chatId: _chat.id,
        images: [file],
      );
      if (!mounted) return;
      setState(() {
        if (!_messages.any((item) => item.id == message.id)) {
          _messages = [..._messages, message];
        }
        _sending = false;
      });
      _scrollToEnd();
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      final message = error is ChatException
          ? error.message
          : 'Не удалось отправить фото';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _permissionDenied() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Нужен доступ к камере или галерее')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return PopScope(
      canPop: _closing,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _close();
      },
      child: Scaffold(
        key: const ValueKey<String>('chat-thread'),
        backgroundColor: AppColors.white,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: _ThreadHeader(chat: _chat, onBack: _close),
              ),
              if (_chat.kind != ChatKind.support)
                _ListingContextBar(chat: _chat),
              Expanded(child: _messagesBody()),
              _ComposerBar(
                controller: _controller,
                sending: _sending,
                bottomInset: bottomInset,
                onAttach: _attach,
                onSend: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messagesBody() {
    if (_loading && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _messages.isEmpty) {
      return Center(
        child: TextButton(onPressed: _load, child: const Text('Повторить')),
      );
    }
    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          'Напишите первое сообщение',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w400,
            fontSize: 14,
            height: 1.4,
            color: _meta,
          ),
        ),
      );
    }

    final rows = _buildRows(_messages);
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row is _DayRow) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Center(
              child: Text(
                row.label,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  height: 1.5,
                  color: _dayColor,
                ),
              ),
            ),
          );
        }
        if (row is _SystemRow) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Center(
              child: Text(
                row.label,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  height: 1.5,
                  color: _dayColor,
                ),
              ),
            ),
          );
        }
        final message = (row as _MessageRow).message;
        final mine = message.authorId == _userId;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _MessageBubble(
            message: message,
            mine: mine,
            showIdentity: _chat.hasStaff && !mine,
          ),
        );
      },
    );
  }

  List<_ThreadRow> _buildRows(List<ChatMessage> messages) {
    final rows = <_ThreadRow>[];
    DateTime? lastDay;
    var staffAnnounced = false;
    for (final message in messages) {
      final created = message.created?.toLocal();
      if (created != null) {
        final day = DateTime(created.year, created.month, created.day);
        if (lastDay == null || day != lastDay) {
          rows.add(_DayRow(chatDaySeparatorLabel(created)));
          lastDay = day;
        }
      }
      if (_chat.hasStaff &&
          !staffAnnounced &&
          message.authorId == _chat.staffId) {
        rows.add(const _SystemRow('в чат добавлен Администратор'));
        staffAnnounced = true;
      }
      rows.add(_MessageRow(message));
    }
    return rows;
  }
}

sealed class _ThreadRow {
  const _ThreadRow();
}

class _DayRow extends _ThreadRow {
  const _DayRow(this.label);
  final String label;
}

class _SystemRow extends _ThreadRow {
  const _SystemRow(this.label);
  final String label;
}

class _MessageRow extends _ThreadRow {
  const _MessageRow(this.message);
  final ChatMessage message;
}

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({required this.chat, required this.onBack});

  final ChatPreview chat;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Material(
            color: AppColors.white,
            shape: const CircleBorder(side: BorderSide(color: _backBorder)),
            child: InkWell(
              key: const ValueKey<String>('chat-thread-back'),
              customBorder: const CircleBorder(),
              onTap: onBack,
              child: SizedBox(
                width: 36,
                height: 36,
                child: Center(
                  child: Transform.rotate(
                    angle: math.pi / 2,
                    child: SvgPicture.asset(
                      'images/profile/arrow-left.svg',
                      width: 13.1667,
                      height: 7.33333,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              chat.titleForViewer(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                height: 1.2,
                color: _ink,
              ),
            ),
          ),
          _HeaderAvatars(chat: chat),
        ],
      ),
    );
  }
}

class _HeaderAvatars extends StatelessWidget {
  const _HeaderAvatars({required this.chat});

  final ChatPreview chat;

  @override
  Widget build(BuildContext context) {
    if (chat.hasStaff && chat.staffAvatar.isNotEmpty) {
      return SizedBox(
        width: 64,
        height: 36,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              child: _Avatar(url: chat.counterpartyAvatar, size: 36),
            ),
            Positioned(
              left: 28,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 1),
                ),
                child: _Avatar(url: chat.staffAvatar, size: 36),
              ),
            ),
          ],
        ),
      );
    }
    return _Avatar(url: chat.counterpartyAvatar, size: 36);
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? const ColoredBox(color: AppColors.tabBarBorder)
            : ListingImage(url, width: size, height: size, fit: BoxFit.cover),
      ),
    );
  }
}

class _ListingContextBar extends StatelessWidget {
  const _ListingContextBar({required this.chat});

  final ChatPreview chat;

  @override
  Widget build(BuildContext context) {
    final guests = chat.guestsLabel;
    final dates = chat.datesLabel;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      color: _contextFill,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 44,
              height: 44,
              child: chat.listingPhoto.isEmpty
                  ? const ColoredBox(color: Color(0xFFEFF2F6))
                  : ListingImage(
                      chat.listingPhoto,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chat.listingTitle.isEmpty ? 'Объявление' : chat.listingTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    height: 1.4,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 2),
                _StayMetaLine(city: chat.city, dates: dates, guests: guests),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StayMetaLine extends StatelessWidget {
  const _StayMetaLine({
    required this.city,
    required this.dates,
    required this.guests,
  });

  final String city;
  final String dates;
  final String guests;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontWeight: FontWeight.w400,
      fontSize: 12,
      height: 1.5,
      color: _meta,
    );
    final parts = <String>[
      if (city.isNotEmpty) city,
      if (dates.isNotEmpty) dates,
      if (guests.isNotEmpty) guests,
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.showIdentity,
  });

  final ChatMessage message;
  final bool mine;
  final bool showIdentity;

  @override
  Widget build(BuildContext context) {
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * (mine ? 0.72 : 0.82),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: mine ? _outgoingFill : AppColors.white,
          border: Border.all(color: _bubbleBorder),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(mine ? 16 : 0),
            topRight: Radius.circular(mine ? 0 : 16),
            bottomLeft: const Radius.circular(16),
            bottomRight: const Radius.circular(16),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (showIdentity) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        message.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1.4,
                          color: _ink,
                        ),
                      ),
                    ),
                    if (message.authorRoleLabel.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        message.authorRoleLabel,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          height: 1.5,
                          color: _roleColor,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
              ],
              if (message.text.isNotEmpty)
                Text(
                  message.text,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    height: 1.4,
                    color: _ink,
                  ),
                ),
              for (final url in message.imageUrls) ...[
                if (message.text.isNotEmpty) const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 116,
                    height: 116,
                    child: ListingImage(url, fit: BoxFit.cover),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                message.timeLabel(),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  height: 1.5,
                  color: _meta,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!showIdentity) {
      return Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: bubble,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(url: message.authorAvatar, size: 36),
        const SizedBox(width: 8),
        Flexible(child: bubble),
      ],
    );
  }
}

/// Панель ввода (Figma `1:14230`).
class _ComposerBar extends StatelessWidget {
  const _ComposerBar({
    required this.controller,
    required this.sending,
    required this.bottomInset,
    required this.onAttach,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final double bottomInset;
  final VoidCallback onAttach;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _composerFill,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: Row(
          children: [
            _SquareIconButton(
              keyName: 'chat-attach',
              background: AppColors.white,
              onTap: sending ? null : onAttach,
              child: SvgPicture.asset(
                'images/chat/attach.svg',
                width: 20,
                height: 20,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  key: const ValueKey<String>('chat-input'),
                  controller: controller,
                  enabled: !sending,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w400,
                    fontSize: 16,
                    height: 24 / 16,
                    color: _ink,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Написать...',
                    hintStyle: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                      height: 24 / 16,
                      color: _placeholder,
                    ),
                    filled: true,
                    fillColor: AppColors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: Padding(
                      key: const ValueKey<String>('chat-mic'),
                      padding: const EdgeInsets.only(right: 9),
                      child: SizedBox.square(
                        dimension: 36,
                        child: Center(
                          child: SvgPicture.asset(
                            'images/chat/mic.svg',
                            width: 20,
                            height: 20,
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                    ),
                    suffixIconConstraints: const BoxConstraints.tightFor(
                      width: 45,
                      height: 36,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            _SquareIconButton(
              keyName: 'chat-send',
              background: AppColors.orange,
              onTap: sending ? null : onSend,
              child: SvgPicture.asset(
                'images/chat/send.svg',
                width: 20,
                height: 20,
                excludeFromSemantics: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.keyName,
    required this.background,
    required this.child,
    this.onTap,
  });

  final String keyName;
  final Color background;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 48,
      child: Center(
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: ValueKey<String>(keyName),
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox.square(dimension: 40, child: Center(child: child)),
          ),
        ),
      ),
    );
  }
}

/// Открыть чат с владельцем из брони / карточки объявления.
/// Без брони текущего гостя на это жильё диалог не создаётся.
Future<void> openHostChat(
  BuildContext context, {
  Booking? booking,
  String hostName = '',
  String listingId = '',
  String hostId = '',
  ChatsRepository? repository,
  BookingsRepository? bookingsRepository,
}) async {
  final repo = repository ?? ChatsRepositoryScope.instance;
  final bookings = bookingsRepository ?? BookingsRepositoryScope.instance;
  try {
    var resolved = booking;
    if (resolved == null) {
      final listing = listingId.trim();
      if (listing.isEmpty) {
        throw const ChatException(
          'Чат с владельцем откроется после бронирования этого жилья',
        );
      }
      resolved = await bookings.findHostChatEligible(listingId: listing);
    }
    if (resolved == null) {
      throw const ChatException(
        'Чат с владельцем откроется после бронирования этого жилья',
      );
    }
    final chat = await repo.getOrCreateForBooking(resolved);
    if (!context.mounted) return;
    await ChatThreadScreen.open(context, chat: chat, repository: repo);
  } catch (error) {
    if (!context.mounted) return;
    final message = error is ChatException
        ? error.message
        : 'Не удалось открыть чат';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Alias для старых вызовов; данные — из PocketBase, не stub.
Future<void> openHostChatStub(
  BuildContext context, {
  Booking? booking,
  String hostName = '',
  String listingId = '',
  String hostId = '',
}) {
  return openHostChat(
    context,
    booking: booking,
    hostName: hostName,
    listingId: listingId,
    hostId: hostId,
  );
}
