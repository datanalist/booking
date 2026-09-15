import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'search_listing.dart';

@immutable
class SearchFilters {
  const SearchFilters({
    this.housingTypes = const {},
    this.price,
    this.amenities = const {},
    this.extras = const {},
    this.priceMin = fallbackPriceMin,
    this.priceMax = fallbackPriceMax,
  });

  static const fallbackPriceMin = 1000.0;
  static const fallbackPriceMax = 9000.0;

  final Set<String> housingTypes;
  final RangeValues? price;
  final Set<String> amenities;
  final Set<String> extras;
  final double? priceMin;
  final double? priceMax;

  double get boundedMin => priceMin ?? fallbackPriceMin;

  double get boundedMax {
    final min = boundedMin;
    final max = priceMax ?? fallbackPriceMax;
    return max > min ? max : min + 1;
  }

  RangeValues get defaultPrice => RangeValues(boundedMin, boundedMax);

  RangeValues get displayPrice => _clamp(price ?? defaultPrice);

  static RangeValues boundsFromPrices(Iterable<int> prices) {
    var min = fallbackPriceMin;
    var max = fallbackPriceMax;
    var found = false;
    for (final price in prices) {
      if (price <= 0) continue;
      final value = price.toDouble();
      if (!found) {
        min = value;
        max = value;
        found = true;
        continue;
      }
      if (value < min) min = value;
      if (value > max) max = value;
    }
    if (!found) return const RangeValues(fallbackPriceMin, fallbackPriceMax);
    if (max <= min) return RangeValues(min, min + 1);
    return RangeValues(min, max);
  }

  SearchFilters withPriceBounds(RangeValues bounds) {
    final min = bounds.start;
    final max = bounds.end <= min ? min + 1 : bounds.end;
    return SearchFilters(
      housingTypes: housingTypes,
      price: price == null ? null : _clampRange(price!, min, max),
      amenities: amenities,
      extras: extras,
      priceMin: min,
      priceMax: max,
    );
  }

  RangeValues _clamp(RangeValues values) =>
      _clampRange(values, boundedMin, boundedMax);

  static RangeValues _clampRange(RangeValues values, double min, double max) {
    var start = values.start.clamp(min, max);
    var end = values.end.clamp(min, max);
    if (start > end) (start, end) = (end, start);
    return RangeValues(start, end);
  }

  bool get isActive =>
      housingTypes.isNotEmpty ||
      amenities.isNotEmpty ||
      extras.isNotEmpty ||
      price != null;

  int get appliedCount =>
      housingTypes.length +
      amenities.length +
      extras.length +
      (price != null ? 1 : 0);

  List<String> get chipLabels => [
    ...housingTypes,
    if (price != null) '${price!.start.round()}–${price!.end.round()} ₽',
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

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _housingTypesSelected = {...initial.housingTypes};
    _amenitiesSelected = {...initial.amenities};
    _extrasSelected = {...initial.extras};
    _price = initial.displayPrice;
  }

  bool get _priceIsCustom => !_sameRange(_price, widget.initial.defaultPrice);

  bool get _canApply {
    final initial = widget.initial;
    return !_sameSet(_housingTypesSelected, initial.housingTypes) ||
        !_sameSet(_amenitiesSelected, initial.amenities) ||
        !_sameSet(_extrasSelected, initial.extras) ||
        !_sameRange(_price, initial.displayPrice);
  }

  static bool _sameSet(Set<String> a, Set<String> b) {
    return a.length == b.length && a.containsAll(b);
  }

  static bool _sameRange(RangeValues a, RangeValues b) {
    return a.start.round() == b.start.round() && a.end.round() == b.end.round();
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
      _price = widget.initial.defaultPrice;
    });
  }

  SearchFilters _draft() {
    return SearchFilters(
      housingTypes: {..._housingTypesSelected},
      price: _priceIsCustom ? _price : null,
      amenities: {..._amenitiesSelected},
      extras: {..._extrasSelected},
      priceMin: widget.initial.boundedMin,
      priceMax: widget.initial.boundedMax,
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
                          min: widget.initial.boundedMin,
                          max: widget.initial.boundedMax,
                          onChanged: (value) {
                            setState(() => _price = value);
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
  const _PriceRange({
    required this.values,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final RangeValues values;
  final double min;
  final double max;
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

  static const _thumbPad = _ChevronThumbShape._radius;
  static const _thumbFill = Color(0xFFF99945);
  static const _gap = 4.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final track = (constraints.maxWidth - _thumbPad * 2).clamp(
              0.0,
              4000.0,
            );
            final span = (max - min).clamp(1.0, double.infinity);
            final startT = (values.start - min) / span;
            final endT = (values.end - min) / span;
            final startLabel = '${values.start.round()} ₽';
            final endLabel = '${values.end.round()} ₽';
            final startWidth = _labelSize(startLabel).width;
            final endWidth = _labelSize(endLabel).width;
            var startLeft = _thumbPad + track * startT - startWidth / 2;
            var endLeft = _thumbPad + track * endT - endWidth / 2;
            startLeft = startLeft.clamp(0.0, constraints.maxWidth - startWidth);
            endLeft = endLeft.clamp(0.0, constraints.maxWidth - endWidth);
            if (startLeft + startWidth + 8 > endLeft) {
              final overflow = startLeft + startWidth + 8 - endLeft;
              startLeft = (startLeft - overflow / 2).clamp(
                0.0,
                constraints.maxWidth - startWidth,
              );
              endLeft = (endLeft + overflow / 2).clamp(
                0.0,
                constraints.maxWidth - endWidth,
              );
            }
            final labelHeight = _labelSize(startLabel).height;
            return SizedBox(
              height: labelHeight,
              width: constraints.maxWidth,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: startLeft,
                    child: Text(startLabel, style: _labelStyle),
                  ),
                  Positioned(
                    left: endLeft,
                    child: Text(endLabel, style: _labelStyle),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: _gap),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            padding: EdgeInsets.zero,
            activeTrackColor: AppColors.orange,
            inactiveTrackColor: const Color(0xFFE2E5EA),
            overlayColor: Colors.transparent,
            rangeThumbShape: const _ChevronThumbShape(),
            rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: RangeSlider(
            padding: EdgeInsets.zero,
            values: values,
            min: min,
            max: max,
            divisions: (max - min).round().clamp(1, 80),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: _gap),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('от ${formatRub(min)}', style: _hintStyle),
            Text('до ${formatRub(max)}', style: _hintStyle),
          ],
        ),
      ],
    );
  }

  static Size _labelSize(String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _labelStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.size;
  }
}

class _ChevronThumbShape extends RangeSliderThumbShape {
  const _ChevronThumbShape();

  static const _radius = 15.0;

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
      center.translate(0, 2),
      _radius,
      Paint()
        ..color = const Color(0x3F000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(center, _radius, Paint()..color = AppColors.white);
    canvas.drawCircle(
      center,
      _radius - 4,
      Paint()..color = _PriceRange._thumbFill,
    );

    final chevron = Path();
    const size = 5.5;
    if (thumb == Thumb.start) {
      chevron
        ..moveTo(center.dx + 2.5, center.dy - size)
        ..lineTo(center.dx - 3.5, center.dy)
        ..lineTo(center.dx + 2.5, center.dy + size);
    } else {
      chevron
        ..moveTo(center.dx - 2.5, center.dy - size)
        ..lineTo(center.dx + 3.5, center.dy)
        ..lineTo(center.dx - 2.5, center.dy + size);
    }
    canvas.drawPath(
      chevron,
      Paint()
        ..color = AppColors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }
}
