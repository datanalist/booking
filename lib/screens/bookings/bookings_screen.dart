import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Вкладка «Бронирования» по клиентским фреймам «Брони» 393×852.
/// Макет: `1:11948` (текущие с карточками), сегмент прошлых — `1:12013`.
class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

enum _BookingsSegment { current, past }

class _BookingsScreenState extends State<BookingsScreen> {
  _BookingsSegment _segment = _BookingsSegment.current;

  static const _current = <_BookingStub>[
    _BookingStub(
      title: 'Уютная студия в центре Москвы',
      dates: '14.11.2024 - 19.11.2024',
      guests: '3 гостя',
      status: _BookingStatus.awaitingPrepayment,
      imageAsset: 'images/onbordins.v1/01-find-housing.png',
    ),
    _BookingStub(
      title: 'Частный дом в 10 км от Москвы',
      dates: '16.12.2024 - 18.12.2024',
      guests: '4 гостя',
      status: _BookingStatus.confirmed,
      imageAsset: 'images/onbordins.v1/02-book-confidently.png',
    ),
    _BookingStub(
      title: 'Отель Венеция',
      dates: '07.01.2025 - 10.01.2025',
      guests: '2 гостя',
      status: _BookingStatus.awaitingOwner,
      imageAsset: 'images/onbordins.v1/03-travel-without-borders.png',
    ),
  ];

  static const _past = <_BookingStub>[
    _BookingStub(
      title: 'Уютная студия в центре Москвы',
      dates: '14.11.2024 - 19.11.2024',
      guests: '3 гостя',
      status: _BookingStatus.cancelled,
      imageAsset: 'images/onbordins.v1/01-find-housing.png',
    ),
    _BookingStub(
      title: 'Частный дом в 10 км от Москвы',
      dates: '12.09.2024 - 15.09.2024',
      guests: '4 гостя',
      imageAsset: 'images/onbordins.v1/02-book-confidently.png',
    ),
  ];

  List<_BookingStub> get _items =>
      _segment == _BookingsSegment.current ? _current : _past;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _BookingsSegmentControl(
              value: _segment,
              onChanged: (value) => setState(() => _segment = value),
            ),
          ),
          Expanded(
            child: _items.isEmpty
                ? _EmptyBookings(segment: _segment)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 24),
                    itemBuilder: (context, index) {
                      return _BookingCard(booking: _items[index]);
                    },
                  ),
          ),
        ],
      ),
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
      child: CupertinoSlidingSegmentedControl<_BookingsSegment>(
        groupValue: value,
        backgroundColor: const Color(0x1F767680),
        thumbColor: AppColors.white,
        padding: const EdgeInsets.all(2),
        children: {
          _BookingsSegment.current: _label(
            'Текущие',
            selected: value == _BookingsSegment.current,
          ),
          _BookingsSegment.past: _label(
            'Прошлые',
            selected: value == _BookingsSegment.past,
          ),
        },
        onValueChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }

  static Widget _label(String text, {required bool selected}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w400,
          fontSize: 13,
          height: 20 / 13,
          color: selected ? AppColors.textPrimary : const Color(0xFF3C3C43),
        ),
      ),
    );
  }
}

class _EmptyBookings extends StatelessWidget {
  const _EmptyBookings({required this.segment});

  final _BookingsSegment segment;

  @override
  Widget build(BuildContext context) {
    final text = segment == _BookingsSegment.current
        ? 'Забронированное жилье будет отображаться здесь'
        : 'История бронирований будет отображаться здесь';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w400,
            fontSize: 16,
            height: 1.25,
            color: AppColors.emptyHint,
          ),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});

  final _BookingStub booking;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              booking.imageAsset,
              width: 90,
              height: 90,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Color(0xFFE8E8E8),
                child: SizedBox(
                  width: 90,
                  height: 90,
                  child: Icon(
                    Icons.home_outlined,
                    color: AppColors.tabInactive,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.title,
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
                        booking.dates,
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
                      booking.guests,
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
                if (booking.status != null) ...[
                  const SizedBox(height: 8),
                  _StatusChip(status: booking.status!),
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

class _BookingStub {
  const _BookingStub({
    required this.title,
    required this.dates,
    required this.guests,
    required this.imageAsset,
    this.status,
  });

  final String title;
  final String dates;
  final String guests;
  final String imageAsset;
  final _BookingStatus? status;
}
