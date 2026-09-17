import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/booking_draft.dart';
import '../../theme/app_theme.dart';

class GuestsSheet extends StatefulWidget {
  const GuestsSheet({
    super.key,
    this.initialAdults = StayGuests.minAdults,
    this.initialChildren = StayGuests.minChildren,
    this.initialPets = StayGuests.minPets,
    this.petsAllowed = true,
  });

  final int initialAdults;
  final int initialChildren;
  final int initialPets;
  final bool petsAllowed;

  static Future<StayGuests?> show(
    BuildContext context, {
    int adults = StayGuests.minAdults,
    int children = StayGuests.minChildren,
    int pets = StayGuests.minPets,
    bool petsAllowed = true,
  }) {
    return showModalBottomSheet<StayGuests>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      barrierColor: const Color(0x661A1B1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => GuestsSheet(
        initialAdults: adults,
        initialChildren: children,
        initialPets: pets,
        petsAllowed: petsAllowed,
      ),
    );
  }

  @override
  State<GuestsSheet> createState() => _GuestsSheetState();
}

class _GuestsSheetState extends State<GuestsSheet> {
  late StayGuests _guests;

  @override
  void initState() {
    super.initState();
    _guests = StayGuests.normalized(
      adults: widget.initialAdults,
      children: widget.initialChildren,
      pets: widget.initialPets,
      petsAllowed: widget.petsAllowed,
    );
  }

  void _save() {
    Navigator.pop(
      context,
      StayGuests.normalized(
        adults: _guests.adults,
        children: _guests.children,
        pets: _guests.pets,
        petsAllowed: widget.petsAllowed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      key: const ValueKey('guests-sheet'),
      padding: EdgeInsets.fromLTRB(24, 8, 24, 8 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SheetHandle(),
          const SizedBox(height: 32),
          const SizedBox(
            width: double.infinity,
            child: Text(
              'Гости',
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
          _GuestRow(
            key: const ValueKey('guests-adults'),
            title: 'Количество взрослых',
            subtitle: '12 лет и старше',
            value: _guests.adults,
            min: StayGuests.minAdults,
            onChanged: (value) => setState(
              () => _guests = StayGuests.normalized(
                adults: value,
                children: _guests.children,
                pets: _guests.pets,
                petsAllowed: widget.petsAllowed,
              ),
            ),
          ),
          const SizedBox(height: 40),
          _GuestRow(
            key: const ValueKey('guests-children'),
            title: 'Количество детей',
            subtitle: '0-11 лет',
            value: _guests.children,
            min: StayGuests.minChildren,
            onChanged: (value) => setState(
              () => _guests = StayGuests.normalized(
                adults: _guests.adults,
                children: value,
                pets: _guests.pets,
                petsAllowed: widget.petsAllowed,
              ),
            ),
          ),
          const SizedBox(height: 40),
          _GuestRow(
            key: const ValueKey('guests-pets'),
            title: 'Количество животных',
            value: _guests.pets,
            min: StayGuests.minPets,
            enabled: widget.petsAllowed,
            onChanged: (value) => setState(
              () => _guests = StayGuests.normalized(
                adults: _guests.adults,
                children: _guests.children,
                pets: value,
                petsAllowed: widget.petsAllowed,
              ),
            ),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('guests-back'),
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
                  key: const ValueKey('guests-save'),
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.orange,
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

class _GuestRow extends StatelessWidget {
  const _GuestRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.min = StayGuests.minChildren,
    this.max = StayGuests.maxCount,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final bool enabled;

  String get rowId {
    final widgetKey = key;
    if (widgetKey is ValueKey<String>) return widgetKey.value;
    return 'guests-row';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                  height: 1.45,
                  color: Color(0xFF1A1B1C),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    height: 1.5,
                    color: Color(0xFF525353),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          width: 98,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StepperButton(
                key: ValueKey('$rowId-minus'),
                minus: true,
                enabled: enabled && value > min,
                onTap: () => onChanged(value - 1),
              ),
              Text(
                key: ValueKey('$rowId-value'),
                '$value',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                  height: 1.45,
                  color: Color(0xFF1A1B1C),
                ),
              ),
              _StepperButton(
                key: ValueKey('$rowId-plus'),
                minus: false,
                enabled: enabled && value < max,
                onTap: () => onChanged(value + 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    super.key,
    required this.minus,
    required this.enabled,
    required this.onTap,
  });

  final bool minus;
  final bool enabled;
  final VoidCallback onTap;

  static const _on = 'images/listing/plus-16.svg';
  static const _offMinus = 'images/listing/minus-16-off.svg';
  static const _onMinus = 'images/listing/minus-16.svg';
  static const _disabledStroke = Color(0xFFFFE4B8);

  @override
  Widget build(BuildContext context) {
    final border = enabled ? AppColors.orange : _disabledStroke;
    final asset = minus ? (enabled ? _onMinus : _offMinus) : _on;
    final icon = SvgPicture.asset(
      asset,
      width: 16,
      height: 16,
      excludeFromSemantics: true,
      colorFilter: !minus && !enabled
          ? const ColorFilter.mode(_disabledStroke, BlendMode.srcIn)
          : null,
    );
    return Material(
      color: AppColors.white,
      shape: StadiumBorder(side: BorderSide(color: border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(width: 16, height: 16, child: icon),
        ),
      ),
    );
  }
}
