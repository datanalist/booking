import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

@immutable
class SearchFilters {
  const SearchFilters({
    this.housingTypes = const {},
    this.price,
    this.amenities = const {},
    this.extras = const {},
  });

  static const priceMin = 1000.0;
  static const priceMax = 9000.0;
  static const defaultPrice = RangeValues(2500, 7000);

  final Set<String> housingTypes;
  final RangeValues? price;
  final Set<String> amenities;
  final Set<String> extras;

  RangeValues get displayPrice => price ?? defaultPrice;

  bool get isActive =>
      housingTypes.isNotEmpty ||
      amenities.isNotEmpty ||
      extras.isNotEmpty ||
      price != null;

  List<String> get chipLabels => [
    ...housingTypes,
    if (price != null)
      '${price!.start.round()}–${price!.end.round()} ₽',
    ...amenities,
    ...extras,
  ];
}

class SearchFiltersSheet extends StatefulWidget {
  const SearchFiltersSheet({super.key, required this.initial});

  final SearchFilters initial;

  static Future<SearchFilters?> show(
    BuildContext context, {
    required SearchFilters initial,
  }) {
    return showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      barrierColor: const Color(0x661A1B1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => SearchFiltersSheet(initial: initial),
    );
  }

  @override
  State<SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends State<SearchFiltersSheet> {
  static const _housingTypes = ['Квартира', 'Дом', 'Комната', 'Отель'];

  static const _amenities = <(IconData, String)>[
    (Icons.wifi, 'Wifi'),
    (Icons.tv_outlined, 'Телевизор'),
    (Icons.ac_unit, 'Кондиционер'),
    (Icons.thermostat_outlined, 'Обогреватель'),
    (Icons.dry_outlined, 'Фен'),
    (Icons.iron_outlined, 'Утюг'),
    (Icons.kitchen_outlined, 'Кухня'),
    (Icons.local_laundry_service_outlined, 'Стиральная машина'),
    (Icons.dinner_dining_outlined, 'Посуда'),
  ];

  static const _extras = <(IconData, String)>[
    (Icons.free_breakfast_outlined, 'Завтраки'),
    (Icons.pool_outlined, 'Бассейн'),
    (Icons.fireplace_outlined, 'Камин'),
    (Icons.smoking_rooms_outlined, 'Разрешено курение'),
    (Icons.fitness_center, 'Спортзал'),
    (Icons.key_outlined, 'Самостоятельное заселение'),
    (Icons.hot_tub_outlined, 'Сауна'),
    (Icons.local_parking_outlined, 'Парковка'),
  ];

  late Set<String> _housingTypesSelected;
  late Set<String> _amenitiesSelected;
  late Set<String> _extrasSelected;
  late RangeValues _price;
  var _priceAdjusted = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _housingTypesSelected = {...initial.housingTypes};
    _amenitiesSelected = {...initial.amenities};
    _extrasSelected = {...initial.extras};
    _price = initial.displayPrice;
    _priceAdjusted = initial.price != null;
  }

  bool get _canApply {
    final initial = widget.initial;
    return !_sameSet(_housingTypesSelected, initial.housingTypes) ||
        !_sameSet(_amenitiesSelected, initial.amenities) ||
        !_sameSet(_extrasSelected, initial.extras) ||
        _price != initial.displayPrice;
  }

  static bool _sameSet(Set<String> a, Set<String> b) {
    return a.length == b.length && a.containsAll(b);
  }

  void _toggle(Set<String> target, String value) {
    setState(() {
      if (!target.remove(value)) target.add(value);
    });
  }

  void _reset() {
    setState(() {
      _housingTypesSelected.clear();
      _amenitiesSelected.clear();
      _extrasSelected.clear();
      _price = SearchFilters.defaultPrice;
      _priceAdjusted = false;
    });
  }

  SearchFilters _draft() {
    final noChips =
        _housingTypesSelected.isEmpty &&
        _amenitiesSelected.isEmpty &&
        _extrasSelected.isEmpty;
    final priceUnchanged = _price == SearchFilters.defaultPrice;
    return SearchFilters(
      housingTypes: {..._housingTypesSelected},
      price: (!_priceAdjusted || (noChips && priceUnchanged)) ? null : _price,
      amenities: {..._amenitiesSelected},
      extras: {..._extrasSelected},
    );
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
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(child: _SheetHandle()),
                      const SizedBox(height: 32),
                      const SizedBox(
                        width: double.infinity,
                        child: Text(
                          'Фильтры',
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
                      const SizedBox(height: 32),
                      _Section(
                        title: 'Вид жилья',
                        child: _ChipWrap(
                          children: [
                            for (final type in _housingTypes)
                              _FilterChip(
                                label: type,
                                selected: _housingTypesSelected.contains(type),
                                onTap: () =>
                                    _toggle(_housingTypesSelected, type),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      _Section(
                        title: 'Диапазон цен',
                        child: _PriceRange(
                          values: _price,
                          onChanged: (value) {
                            setState(() {
                              _price = value;
                              _priceAdjusted = true;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                      _Section(
                        title: 'Удобства',
                        child: _ChipWrap(
                          children: [
                            for (final item in _amenities)
                              _FilterChip(
                                icon: item.$1,
                                label: item.$2,
                                selected: _amenitiesSelected.contains(item.$2),
                                onTap: () =>
                                    _toggle(_amenitiesSelected, item.$2),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      _Section(
                        title: 'Дополнительные характеристики',
                        child: _ChipWrap(
                          children: [
                            for (final item in _extras)
                              _FilterChip(
                                icon: item.$1,
                                label: item.$2,
                                selected: _extrasSelected.contains(item.$2),
                                onTap: () => _toggle(_extrasSelected, item.$2),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Center(
                        child: GestureDetector(
                          onTap: _reset,
                          child: const Text(
                            'Сбросить фильтры',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              height: 1.4,
                              color: AppColors.orange,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.orange,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
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
                      onPressed: _canApply
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
                      child: const Text('Применить'),
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
    return Container(
      width: 43,
      height: 5,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E5EA),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
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
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.white : AppColors.orange;
    return Material(
      color: selected ? AppColors.orange : AppColors.white,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.orange)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  height: 1.4,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceRange extends StatelessWidget {
  const _PriceRange({required this.values, required this.onChanged});

  final RangeValues values;
  final ValueChanged<RangeValues> onChanged;

  static const _labelStyle = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 14,
    letterSpacing: -0.3,
    color: Color(0xFF1A1B1C),
  );

  static const _hintStyle = TextStyle(
    fontFamily: AppTheme.fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.4,
    color: Color(0xFF89919D),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const pad = 24.0;
            final track = (constraints.maxWidth - pad * 2).clamp(0.0, 4000.0);
            final span = SearchFilters.priceMax - SearchFilters.priceMin;
            final startT = (values.start - SearchFilters.priceMin) / span;
            final endT = (values.end - SearchFilters.priceMin) / span;
            return SizedBox(
              height: 22,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: pad + track * startT - 22,
                    child: Text('${values.start.round()} ₽', style: _labelStyle),
                  ),
                  Positioned(
                    left: pad + track * endT - 22,
                    child: Text('${values.end.round()} ₽', style: _labelStyle),
                  ),
                ],
              ),
            );
          },
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: AppColors.orange,
            inactiveTrackColor: const Color(0xFFE2E5EA),
            overlayColor: Colors.transparent,
            rangeThumbShape: const _OrangeThumbShape(),
            rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: RangeSlider(
            values: values,
            min: SearchFilters.priceMin,
            max: SearchFilters.priceMax,
            divisions: 80,
            onChanged: onChanged,
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('от 1 000 ₽', style: _hintStyle),
            Text('до 9 000 ₽', style: _hintStyle),
          ],
        ),
      ],
    );
  }
}

class _OrangeThumbShape extends RangeSliderThumbShape {
  const _OrangeThumbShape();

  static const _radius = 11.0;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size.fromRadius(_radius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    bool isEnabled = false,
    bool? isOnTop,
    required SliderThemeData sliderTheme,
    TextDirection? textDirection,
    Thumb? thumb,
    bool? isPressed,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(
      center.translate(0, 1),
      11,
      Paint()
        ..color = const Color(0x3F000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(center, 13, Paint()..color = AppColors.white);
    canvas.drawCircle(center, 9, Paint()..color = const Color(0xFFF99945));
  }
}
