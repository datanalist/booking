import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/auth_repository.dart';
import '../../data/booking.dart';
import '../../data/bookings_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/listing_image.dart';

/// Вкладка «Бронирования» по клиентским фреймам «Брони» 393×852.
/// Пустой таб: `1:11894`. Со списком: `1:11948`, архив — `1:12013`.
class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key, this.repository});

  final BookingsRepository? repository;

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

enum _BookingsSegment { current, past }

class _BookingsScreenState extends State<BookingsScreen> {
  _BookingsSegment _segment = _BookingsSegment.current;
  var _items = const <Booking>[];
  var _loading = false;
  Object? _error;

  BookingsRepository get _repository =>
      widget.repository ?? BookingsRepositoryScope.instance;

  List<Booking> get _visible {
    return [
      for (final item in _items)
        if (_segment == _BookingsSegment.past
            ? item.status.isPast
            : !item.status.isPast)
          item,
    ];
  }

  @override
  void initState() {
    super.initState();
    AuthRepositoryScope.session.addListener(_onSession);
    _load();
  }

  @override
  void dispose() {
    AuthRepositoryScope.session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repository.fetchMine();
      if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.orange,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: _BookingsSegmentControl(
                value: _segment,
                onChanged: (value) => setState(() => _segment = value),
              ),
            ),
          ),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: TextButton(
          onPressed: _load,
          child: const Text('Не удалось загрузить бронирования'),
        ),
      );
    }
    final items = _visible;
    if (items.isEmpty) {
      return _EmptyBookings(segment: _segment);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 24),
      itemBuilder: (context, index) {
        return _BookingCard(booking: items[index]);
      },
    );
  }
}

class _BookingsSegmentControl extends StatelessWidget {
  const _BookingsSegmentControl({
    required this.value,
    required this.onChanged,
  });

  final _BookingsSegment value;
  final ValueChanged<_BookingsSegment> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 36,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: AppColors.yellow.withValues(alpha: 0.17),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Row(
            children: [
              _tab(
                label: 'Предстоящие',
                selected: value == _BookingsSegment.current,
                onTap: () => onChanged(_BookingsSegment.current),
              ),
              _tab(
                label: 'Архив',
                selected: value == _BookingsSegment.past,
                onTap: () => onChanged(_BookingsSegment.past),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? AppColors.orange : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      offset: Offset(0, 3),
                      blurRadius: 0.5,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 1.4,
                color: selected ? AppColors.white : const Color(0xFF525353),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyBookings extends StatelessWidget {
  const _EmptyBookings({required this.segment});

  final _BookingsSegment segment;

  static const _illustrationWidth = 171.532;
  static const _illustrationHeight = 160.0;

  @override
  Widget build(BuildContext context) {
    final text = segment == _BookingsSegment.current
        ? 'Забронированное жилье\nбудет отображаться здесь'
        : 'Архив бронирований\nбудет отображаться здесь';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: _illustrationWidth,
              height: _illustrationHeight,
              child: SvgPicture.asset(
                'images/bookings/empty-no-task.svg',
                width: _illustrationWidth,
                height: _illustrationHeight,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF1A1B1D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final chip = _chipFor(booking.status);
    return SizedBox(
      height: 92,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ListingImage(
              booking.photo,
              width: 90,
              height: 90,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.title.isEmpty ? 'Бронирование' : booking.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    height: 19 / 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        booking.datesLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w400,
                          fontSize: 13,
                          height: 18 / 13,
                          color: AppColors.emptyHint,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.emptyHint,
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(width: 3, height: 3),
                      ),
                    ),
                    Text(
                      booking.guestsLabel,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w400,
                        fontSize: 13,
                        height: 18 / 13,
                        color: AppColors.emptyHint,
                      ),
                    ),
                  ],
                ),
                if (chip != null) ...[
                  const SizedBox(height: 8),
                  _StatusChip(status: chip),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final _BookingStatus status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 3, 6, 3),
        child: Text(
          status.label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w400,
            fontSize: 11,
            height: 14 / 11,
            color: status.foreground,
          ),
        ),
      ),
    );
  }
}

enum _BookingStatus {
  awaitingPrepayment,
  confirmed,
  awaitingOwner,
  cancelled,
}

_BookingStatus? _chipFor(BookingStatus status) {
  return switch (status) {
    BookingStatus.pendingHost ||
    BookingStatus.cancelRequested =>
      _BookingStatus.awaitingOwner,
    BookingStatus.awaitingPrepayment => _BookingStatus.awaitingPrepayment,
    BookingStatus.confirmed ||
    BookingStatus.changeRequested =>
      _BookingStatus.confirmed,
    BookingStatus.cancelled => _BookingStatus.cancelled,
    BookingStatus.completed => null,
  };
}

extension on _BookingStatus {
  String get label => switch (this) {
        _BookingStatus.awaitingPrepayment => 'ожидание предоплаты',
        _BookingStatus.confirmed => 'бронирование подтверждено',
        _BookingStatus.awaitingOwner => 'ожидание подтверждения от владельца',
        _BookingStatus.cancelled => 'отменено',
      };

  Color get background => switch (this) {
        _BookingStatus.awaitingPrepayment =>
          AppColors.orange.withValues(alpha: 0.12),
        _BookingStatus.confirmed => const Color(0xFFE7F6EC),
        _BookingStatus.awaitingOwner => const Color(0xFFFFF4D6),
        _BookingStatus.cancelled => const Color(0xFFF2F2F2),
      };

  Color get foreground => switch (this) {
        _BookingStatus.awaitingPrepayment => AppColors.orange,
        _BookingStatus.confirmed => const Color(0xFF2F8F4E),
        _BookingStatus.awaitingOwner => const Color(0xFFB26A00),
        _BookingStatus.cancelled => AppColors.tabInactive,
      };
}
