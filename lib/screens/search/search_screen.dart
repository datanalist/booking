import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Вкладка «Поиск жилья» по макету Figma `1:16160` (пустой старт)
/// и соседним фреймам каталога `1:15179` / чипов `1:15291`.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _fieldFill = Color(0xFFF5F5F5);
  static const _chipFill = Color(0xFFF3F3F3);
  static const _meta = Color(0xFF9A9A9A);
  static const _priceMuted = Color(0xFF6B6B6B);
  static const _mapFill = Color(0xFFE8EEE4);

  final _query = TextEditingController();
  final _favorites = <String>{'old-town'};
  var _showResults = false;
  var _showMap = false;
  String? _housingType;

  static const _listings = <_Listing>[
    _Listing(
      id: 'studio-msk',
      title: 'Уютная студия в центре Москвы',
      city: 'Москва',
      type: 'Квартира',
      dates: '14-19 ноября',
      nights: '5 ночей',
      total: '15 170 ₽',
      perNight: '3 034 ₽ / ночь',
      rating: '4.5',
      reviews: '(13)',
      photo: 'images/onbordins.v1/01-find-housing.png',
      imageIndex: 0,
    ),
    _Listing(
      id: 'old-town',
      title: 'Квартира в старом городе',
      city: 'Москва',
      type: 'Квартира',
      dates: '14-19 ноября',
      nights: '5 ночей',
      total: '15 170 ₽',
      perNight: '3 034 ₽ / ночь',
      rating: '4.7',
      reviews: '(29)',
      photo: 'images/onbordins.v1/02-book-confidently.png',
      imageIndex: 1,
    ),
    _Listing(
      id: 'house-10km',
      title: 'Частный дом в 10 км от Москвы',
      city: 'Москва',
      type: 'Дом',
      dates: '14-19 ноября',
      nights: '5 ночей',
      total: '16 470 ₽',
      perNight: '3 294 ₽ / ночь',
      rating: '4.5',
      reviews: '(13)',
      photo: 'images/onbordins.v1/03-travel-without-borders.png',
      imageIndex: 2,
    ),
  ];

  static const _chips = <String>[
    'Москва',
    '14-19 ноября',
    '2 взрослых',
    '1 ребенок',
  ];

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<_Listing> get _visible {
    final type = _housingType;
    if (type == null) return _listings;
    return _listings.where((item) => item.type == type).toList();
  }

  void _runSearch() {
    setState(() {
      _showResults = true;
      _query.text = 'Москва';
    });
  }

  Future<void> _openFilters() async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _FilterSheet(selected: _housingType);
      },
    );
    if (!mounted || selected == null) return;
    setState(() {
      _housingType = selected.isEmpty ? null : selected;
      _showResults = true;
      if (_query.text.isEmpty) _query.text = 'Москва';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
            child: _SearchHeader(
              controller: _query,
              fieldFill: _fieldFill,
              mapSelected: _showMap,
              onSubmitted: (_) => _runSearch(),
              onFilter: _openFilters,
              onMap: () => setState(() => _showMap = !_showMap),
              onTapField: _runSearch,
            ),
          ),
          if (_showResults) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 26,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                itemCount: _chips.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return _Chip(label: _chips[index], fill: _chipFill);
                },
              ),
            ),
          ],
          const SizedBox(height: 24),
          Expanded(
            child: _showResults
                ? (_showMap
                    ? _MapResults(
                        listings: _visible,
                        favorites: _favorites,
                        mapFill: _mapFill,
                        meta: _meta,
                        priceMuted: _priceMuted,
                        onFavorite: _toggleFavorite,
                      )
                    : _ListingResults(
                        listings: _visible,
                        favorites: _favorites,
                        meta: _meta,
                        priceMuted: _priceMuted,
                        onFavorite: _toggleFavorite,
                      ))
                : _EmptySearch(
                    onSearch: _runSearch,
                  ),
          ),
        ],
      ),
    );
  }

  void _toggleFavorite(String id) {
    setState(() {
      if (!_favorites.remove(id)) _favorites.add(id);
    });
  }
}

class _Listing {
  const _Listing({
    required this.id,
    required this.title,
    required this.city,
    required this.type,
    required this.dates,
    required this.nights,
    required this.total,
    required this.perNight,
    required this.rating,
    required this.reviews,
    required this.photo,
    required this.imageIndex,
  });

  final String id;
  final String title;
  final String city;
  final String type;
  final String dates;
  final String nights;
  final String total;
  final String perNight;
  final String rating;
  final String reviews;
  final String photo;
  final int imageIndex;
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.fieldFill,
    required this.mapSelected,
    required this.onSubmitted,
    required this.onFilter,
    required this.onMap,
    required this.onTapField,
  });

  final TextEditingController controller;
  final Color fieldFill;
  final bool mapSelected;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onFilter;
  final VoidCallback onMap;
  final VoidCallback onTapField;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmitted,
              onTap: onTapField,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 20 / 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Город и даты',
                hintStyle: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  height: 20 / 14,
                  color: Color(0xFF9A9A9A),
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 16,
                  color: Color(0xFF9A9A9A),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 42,
                  minHeight: 44,
                ),
                filled: true,
                fillColor: fieldFill,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.orange),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _HeaderIconButton(
          icon: Icons.tune,
          selected: false,
          onTap: onFilter,
          tooltip: 'Фильтры',
        ),
        const SizedBox(width: 8),
        _HeaderIconButton(
          icon: Icons.map_outlined,
          selected: mapSelected,
          onTap: onMap,
          tooltip: 'Карта',
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? const Color(0xFFFFF3E8) : AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? AppColors.orange : AppColors.tabBarBorder,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 24,
              color: selected ? AppColors.orange : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        children: [
          const Spacer(flex: 175),
          const SizedBox(
            width: 183,
            height: 160,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFFFF6EE),
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
              child: Icon(
                Icons.travel_explore,
                size: 88,
                color: AppColors.orange,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Укажите город и даты поездки, чтобы увидеть подходящие варианты',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w400,
              fontSize: 16,
              height: 1.25,
              color: AppColors.emptyHint,
            ),
          ),
          const Spacer(flex: 123),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onSearch,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Искать жилье'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.fill});

  final String label;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w400,
          fontSize: 12,
          height: 18 / 12,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _ListingResults extends StatelessWidget {
  const _ListingResults({
    required this.listings,
    required this.favorites,
    required this.meta,
    required this.priceMuted,
    required this.onFavorite,
  });

  final List<_Listing> listings;
  final Set<String> favorites;
  final Color meta;
  final Color priceMuted;
  final ValueChanged<String> onFavorite;

  @override
  Widget build(BuildContext context) {
    if (listings.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Нет подходящих вариантов Попробуйте изменить параметры поиска',
            textAlign: TextAlign.center,
            style: TextStyle(
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

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      itemCount: listings.length,
      separatorBuilder: (_, _) => const SizedBox(height: 24),
      itemBuilder: (context, index) {
        final listing = listings[index];
        return _ApartmentCard(
          listing: listing,
          favorite: favorites.contains(listing.id),
          meta: meta,
          priceMuted: priceMuted,
          onFavorite: () => onFavorite(listing.id),
        );
      },
    );
  }
}

class _MapResults extends StatelessWidget {
  const _MapResults({
    required this.listings,
    required this.favorites,
    required this.mapFill,
    required this.meta,
    required this.priceMuted,
    required this.onFavorite,
  });

  final List<_Listing> listings;
  final Set<String> favorites;
  final Color mapFill;
  final Color meta;
  final Color priceMuted;
  final ValueChanged<String> onFavorite;

  @override
  Widget build(BuildContext context) {
    final preview = listings.isEmpty ? null : listings.first;

    return Stack(
      children: [
        ColoredBox(
          color: mapFill,
          child: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _MapGridPainter()),
              ),
              for (var i = 0; i < listings.length && i < 4; i++)
                Positioned(
                  left: 88.0 + (i * 28),
                  top: 120.0 + (i % 2) * 36,
                  child: _PricePin(label: listings[i].total, active: i == 0),
                ),
            ],
          ),
        ),
        if (preview != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: _ApartmentCard(
                listing: preview,
                favorite: favorites.contains(preview.id),
                meta: meta,
                priceMuted: priceMuted,
                compact: true,
                onFavorite: () => onFavorite(preview.id),
              ),
            ),
          ),
      ],
    );
  }
}

class _MapGridPainter extends CustomPainter {
  const _MapGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD5DDD0)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PricePin extends StatelessWidget {
  const _PricePin({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? AppColors.orange : AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          height: 20 / 12,
          color: active ? AppColors.white : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _ApartmentCard extends StatelessWidget {
  const _ApartmentCard({
    required this.listing,
    required this.favorite,
    required this.meta,
    required this.priceMuted,
    required this.onFavorite,
    this.compact = false,
  });

  final _Listing listing;
  final bool favorite;
  final Color meta;
  final Color priceMuted;
  final VoidCallback onFavorite;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final photoHeight = compact ? 218.0 : 220.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: photoHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(compact ? 16 : 12),
                  child: Image.asset(
                    listing.photo,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 20,
                right: 20,
                child: Material(
                  color: AppColors.white,
                  shape: const CircleBorder(),
                  elevation: 2,
                  shadowColor: const Color(0x33000000),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onFavorite,
                    child: SizedBox(
                      width: compact ? 34 : 36,
                      height: compact ? 34 : 36,
                      child: Icon(
                        favorite ? Icons.favorite : Icons.favorite_border,
                        size: compact ? 18 : 20,
                        color: favorite ? AppColors.orange : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 10,
                child: _PhotoDots(active: listing.imageIndex),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      listing.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 20 / 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    listing.rating,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                      height: 20 / 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.star, size: 18, color: AppColors.yellow),
                  const SizedBox(width: 2),
                  Text(
                    listing.reviews,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                      height: 20 / 14,
                      color: meta,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _Meta(
                    icon: Icons.location_on_outlined,
                    label: listing.city,
                    color: meta,
                  ),
                  const SizedBox(width: 12),
                  _Meta(
                    icon: Icons.home_outlined,
                    label: listing.type,
                    color: meta,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Meta(
                      icon: Icons.calendar_today_outlined,
                      label: '${listing.dates} · ${listing.nights}',
                      color: meta,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    listing.total,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      height: 19 / 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    listing.perNight,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      height: 17 / 12,
                      color: priceMuted,
                    ),
                  ),
                ],
              ),
              if (compact) const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w400,
            fontSize: 12,
            height: 18 / 12,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _PhotoDots extends StatelessWidget {
  const _PhotoDots({required this.active});

  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i != 0) const SizedBox(width: 4),
          Container(
            width: i == active ? 16 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == active ? AppColors.white : const Color(0x99FFFFFF),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ],
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.selected});

  final String? selected;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  static const _types = <String>['Квартира', 'Дом', 'Комната', 'Отель'];

  late String? _selected = widget.selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 43,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.tabBarBorder,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Фильтры',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 24,
                height: 29 / 24,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Вид жилья',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 16,
                height: 23 / 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in _types)
                  ChoiceChip(
                    label: Text(type),
                    selected: _selected == type,
                    selectedColor: const Color(0xFFFFF3E8),
                    labelStyle: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                      color: _selected == type
                          ? AppColors.orange
                          : AppColors.textPrimary,
                    ),
                    side: BorderSide(
                      color: _selected == type
                          ? AppColors.orange
                          : AppColors.tabBarBorder,
                    ),
                    onSelected: (value) {
                      setState(() => _selected = value ? type : null);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, ''),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      side: const BorderSide(color: AppColors.tabBarBorder),
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Сбросить'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, _selected ?? ''),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Применить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
