import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/app_theme.dart';
import '../search/search_listing.dart';
import '../search/search_query_sheet.dart';

@immutable
class StayDates {
  const StayDates({required this.checkIn, required this.checkOut});

  final DateTime checkIn;
  final DateTime checkOut;
}

class StayDatesSheet extends StatefulWidget {
  const StayDatesSheet({
    super.key,
    this.initialCheckIn,
    this.initialCheckOut,
  });

  final DateTime? initialCheckIn;
  final DateTime? initialCheckOut;

  static Future<StayDates?> show(
    BuildContext context, {
    DateTime? checkIn,
    DateTime? checkOut,
  }) {
    return showModalBottomSheet<StayDates>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      barrierColor: const Color(0x661A1B1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => StayDatesSheet(
        initialCheckIn: checkIn,
        initialCheckOut: checkOut,
      ),
    );
  }

  @override
  State<StayDatesSheet> createState() => _StayDatesSheetState();
}

class _StayDatesSheetState extends State<StayDatesSheet> {
  late DateTime? _checkIn;
  late DateTime? _checkOut;

  @override
  void initState() {
    super.initState();
    _checkIn = widget.initialCheckIn;
    _checkOut = widget.initialCheckOut;
  }

  bool get _canSave => stayNightsBetween(_checkIn, _checkOut) > 0;

  Future<void> _pickDate({required bool checkOut}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showStayDatePicker(
      context,
      checkOut: checkOut,
      today: today,
      currentCheckIn: _checkIn,
      currentCheckOut: _checkOut,
    );
    if (picked == null) return;
    setState(() {
      if (checkOut) {
        _checkOut = picked;
      } else {
        _checkIn = picked;
      }
      final completed = completeSearchStayDates(
        checkIn: _checkIn,
        checkOut: _checkOut,
        today: today,
      );
      _checkIn = completed.checkIn;
      _checkOut = completed.checkOut;
    });
  }

  void _save() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final completed = completeSearchStayDates(
      checkIn: _checkIn,
      checkOut: _checkOut,
      today: today,
    );
    final checkIn = completed.checkIn;
    final checkOut = completed.checkOut;
    if (checkIn == null ||
        checkOut == null ||
        stayNightsBetween(checkIn, checkOut) <= 0) {
      return;
    }
    Navigator.pop(context, StayDates(checkIn: checkIn, checkOut: checkOut));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      key: const ValueKey('stay-dates-sheet'),
      padding: EdgeInsets.fromLTRB(24, 8, 24, 8 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SheetHandle(),
          const SizedBox(height: 32),
          const SizedBox(
            width: double.infinity,
            child: Text(
              'Даты проживания',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 24,
                height: 1.2,
                color: Color(0xFF1A1B1C),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  key: const ValueKey('stay-dates-check-in'),
                  label: 'Дата заезда',
                  value: _checkIn,
                  onTap: () => _pickDate(checkOut: false),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DateField(
                  key: const ValueKey('stay-dates-check-out'),
                  label: 'Дата выезда',
                  value: _checkOut,
                  onTap: () => _pickDate(checkOut: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('stay-dates-back'),
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: AppColors.orange,
                    side: const BorderSide(color: AppColors.orange),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      height: 1.2,
                    ),
                  ),
                  child: const Text('Вернуться'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('stay-dates-save'),
                  onPressed: _canSave ? _save : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.orange,
                    disabledBackgroundColor: const Color(0x66F88A2A),
                    disabledForegroundColor: AppColors.white,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      height: 1.2,
                    ),
                  ),
                  child: const Text('Сохранить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 43,
        height: 5,
        decoration: BoxDecoration(
          color: const Color.fromRGBO(251, 192, 40, 0.17),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = value == null ? 'дд.мм.гггг' : formatSearchDate(value!);
    final color = value == null
        ? const Color(0xFF89919D)
        : const Color(0xFF1A1B1C);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w400,
            fontSize: 16,
            height: 1.45,
            color: Color(0xFF1A1B1C),
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(100),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AppColors.orange),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w400,
                        fontSize: 16,
                        height: 1.45,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: Center(child: _CalendarIcon()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CalendarIcon extends StatelessWidget {
  const _CalendarIcon();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'images/profile/calendar.svg',
      width: 16.5,
      height: 18.1667,
      excludeFromSemantics: true,
    );
  }
}
