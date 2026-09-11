import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

@immutable
class SearchQuery {
  const SearchQuery({
    this.city = '',
    this.checkIn,
    this.checkOut,
    this.adults = 0,
    this.children = 0,
    this.pets = 0,
  });

  final String city;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int adults;
  final int children;
  final int pets;

  bool get isActive => city.trim().isNotEmpty;

  List<String> get chipLabels {
    final cityLabel = city.trim();
    return [
      if (cityLabel.isNotEmpty) cityLabel,
      if (checkIn != null && checkOut != null)
        '${formatSearchDate(checkIn!)} – ${formatSearchDate(checkOut!)}',
      if (adults > 0) _countLabel(adults, 'взрослый', 'взрослых', 'взрослых'),
      if (children > 0) _countLabel(children, 'ребёнок', 'ребёнка', 'детей'),
      if (pets > 0) _countLabel(pets, 'животное', 'животных', 'животных'),
    ];
  }

  static String _countLabel(int count, String one, String few, String many) {
    final mod100 = count % 100;
    final mod10 = count % 10;
    final word = (mod100 >= 11 && mod100 <= 14)
        ? many
        : (mod10 == 1)
        ? one
        : (mod10 >= 2 && mod10 <= 4)
        ? few
        : many;
    return '$count $word';
  }
}

String formatSearchDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

class SearchQuerySheet extends StatefulWidget {
  const SearchQuerySheet({
    super.key,
    required this.initial,
    required this.cities,
  });

  final SearchQuery initial;
  final List<String> cities;

  static Future<SearchQuery?> show(
    BuildContext context, {
    required SearchQuery initial,
    required List<String> cities,
  }) {
    return showModalBottomSheet<SearchQuery>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      barrierColor: const Color(0x661A1B1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SearchQuerySheet(initial: initial, cities: cities),
      ),
    );
  }

  @override
  State<SearchQuerySheet> createState() => _SearchQuerySheetState();
}

class _SearchQuerySheetState extends State<SearchQuerySheet> {
  late final TextEditingController _city;
  late DateTime? _checkIn;
  late DateTime? _checkOut;
  late int _adults;
  late int _children;
  late int _pets;
  var _showCities = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _city = TextEditingController(text: initial.city);
    _checkIn = initial.checkIn;
    _checkOut = initial.checkOut;
    _adults = initial.adults;
    _children = initial.children;
    _pets = initial.pets;
  }

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  bool get _canSearch {
    final city = _city.text.trim();
    if (city.isNotEmpty) return true;
    return widget.initial.isActive;
  }

  List<String> get _citySuggestions {
    final query = _city.text.trim().toLowerCase();
    if (query.isEmpty) return widget.cities;
    return widget.cities
        .where((city) => city.toLowerCase().contains(query))
        .toList();
  }

  SearchQuery _draft() {
    return SearchQuery(
      city: _city.text.trim(),
      checkIn: _checkIn,
      checkOut: _checkOut,
      adults: _adults,
      children: _children,
      pets: _pets,
    );
  }

  Future<void> _pickDate({required bool checkOut}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final first = checkOut && _checkIn != null
        ? _checkIn!.add(const Duration(days: 1))
        : today;
    final initial = checkOut ? (_checkOut ?? first) : (_checkIn ?? today);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: today.add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.orange,
              onPrimary: AppColors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      if (checkOut) {
        _checkOut = picked;
      } else {
        _checkIn = picked;
        if (_checkOut != null && !_checkOut!.isAfter(picked)) {
          _checkOut = picked.add(const Duration(days: 1));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return SizedBox(
      height: maxHeight,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 8 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 32),
              const SizedBox(
                width: double.infinity,
                child: Text(
                  'Снять жилье',
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
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Город'),
                      const SizedBox(height: 8),
                      _PillField(
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const ValueKey('search-city-field'),
                                controller: _city,
                                onChanged: (_) => setState(() {}),
                                onTap: () => setState(() => _showCities = true),
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 16,
                                  height: 1.45,
                                  color: Color(0xFF1A1B1C),
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  hintText: 'Укажите город',
                                  hintStyle: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontWeight: FontWeight.w400,
                                    fontSize: 16,
                                    height: 1.45,
                                    color: Color(0xFF89919D),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _showCities = !_showCities),
                              child: const Icon(
                                Icons.keyboard_arrow_down,
                                size: 20,
                                color: Color(0xFF89919D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_showCities && _citySuggestions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E5EA)),
                          ),
                          child: Column(
                            children: [
                              for (final city in _citySuggestions)
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _city.text = city;
                                      _showCities = false;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: Text(
                                        city,
                                        style: const TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          fontWeight: FontWeight.w400,
                                          fontSize: 16,
                                          height: 1.45,
                                          color: Color(0xFF1A1B1C),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 40),
                      Row(
                        children: [
                          Expanded(
                            child: _DateField(
                              label: 'Дата заезда',
                              value: _checkIn,
                              hint: '14.11.2024',
                              onTap: () => _pickDate(checkOut: false),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _DateField(
                              label: 'Дата выезда',
                              value: _checkOut,
                              hint: '15.11.2024',
                              onTap: () => _pickDate(checkOut: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      _GuestRow(
                        title: 'Количество взрослых',
                        subtitle: '12 лет и старше',
                        value: _adults,
                        onChanged: (value) => setState(() => _adults = value),
                      ),
                      const SizedBox(height: 40),
                      _GuestRow(
                        title: 'Количество детей',
                        subtitle: '0-11 лет',
                        value: _children,
                        onChanged: (value) => setState(() => _children = value),
                      ),
                      const SizedBox(height: 40),
                      _GuestRow(
                        title: 'Количество животных',
                        value: _pets,
                        onChanged: (value) => setState(() => _pets = value),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
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
                      onPressed: _canSearch
                          ? () => Navigator.pop(context, _draft())
                          : null,
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
                      child: const Text('Найти'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
          color: const Color(0xFFE2E5EA),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontWeight: FontWeight.w400,
        fontSize: 16,
        height: 1.45,
        color: Color(0xFF1A1B1C),
      ),
    );
  }
}

class _PillField extends StatelessWidget {
  const _PillField({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final field = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.orange),
      ),
      child: child,
    );
    if (onTap == null) return field;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: field,
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = value == null ? hint : formatSearchDate(value!);
    final color = value == null
        ? const Color(0xFF89919D)
        : const Color(0xFF1A1B1C);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        _PillField(
          onTap: onTap,
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
              const Icon(
                Icons.calendar_today_outlined,
                size: 20,
                color: AppColors.orange,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuestRow extends StatelessWidget {
  const _GuestRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.max = 16,
  });

  final String title;
  final String? subtitle;
  final int value;
  final ValueChanged<int> onChanged;
  final int max;

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
                    color: Color(0xFF89919D),
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
                icon: Icons.remove,
                enabled: value > 0,
                onTap: () => onChanged(value - 1),
              ),
              Text(
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
                icon: Icons.add,
                enabled: value < max,
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
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.orange : const Color(0xFFBBC1C9);
    return Material(
      color: AppColors.white,
      shape: StadiumBorder(side: BorderSide(color: color)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
