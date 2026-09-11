import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/app_theme.dart';
import 'search_listing.dart';
import 'search_map_view.dart';

/// Вкладка «Поиск жилья» по макету Figma `1:16160` (пустой старт)
/// и соседним фреймам каталога `1:15179` / чипов `1:15291`.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _chipFill = Color(0xFFF3F3F3);
  static const _meta = Color(0xFF9A9A9A);
  static const _priceMuted = Color(0xFF6B6B6B);

  final _query = TextEditingController();
  final _searchFocus = FocusNode();
  final _favorites = <String>{'old-town'};
  var _showMap = false;
  String? _housingType;
  String? _selectedMapListingId;

  @override
  void dispose() {
    _query.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  bool get _hasQuery => _query.text.trim().isNotEmpty;

  bool get _hasCriteria => _hasQuery || _housingType != null;

  List<SearchListing> get _visible {
    final query = _normalize(_query.text);
    final type = _housingType;
    return kSearchListings.where((item) {
      if (type != null && item.type != type) return false;
      if (query.isEmpty) return true;
      final haystack = [
        item.city,
        item.title,
        item.type,
        if (_normalize(item.city) == 'санкт-петербург') 'питер спб',
      ].map(_normalize).join(' ');
      return haystack.contains(query);
    }).toList();
  }

  List<String> get _activeChips {
    final query = _query.text.trim();
    return [
      if (query.isNotEmpty) query,
      ?_housingType,
    ];
  }

  static String _normalize(String value) {
    return value.toLowerCase().replaceAll('ё', 'е').trim();
  }

  void _runSearch() {
    if (!_hasCriteria) {
      _searchFocus.requestFocus();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {});
  }

  Future<void> _openFilters() async {
    FocusManager.instance.primaryFocus?.unfocus();
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ColoredBox(
          color: AppColors.orange,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _SearchHeader(
                controller: _query,
                focusNode: _searchFocus,
                onSubmitted: (_) => _runSearch(),
                onChanged: (_) => setState(() {}),
                onFilter: _openFilters,
                onMap: () => setState(() {
                  _showMap = !_showMap;
                  if (!_showMap) _selectedMapListingId = null;
                }),
              ),
            ),
          ),
        ),
        if (_hasQuery && _activeChips.isNotEmpty && !_showMap)
          ColoredBox(
            color: AppColors.white,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                height: 26,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  scrollDirection: Axis.horizontal,
                  itemCount: _activeChips.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return _Chip(label: _activeChips[index], fill: _chipFill);
                  },
                ),
              ),
            ),
          ),
        Expanded(
          child: ColoredBox(
            color: _showMap ? const Color(0xFFE8EEE4) : AppColors.white,
            child: _showMap
                ? SearchMapView(
                    listings: _visible,
                    selectedId: _selectedMapListingId,
                    onSelectPin: (id) {
                      setState(() => _selectedMapListingId = id);
                    },
                    preview: _selectedMapListing == null
                        ? null
                        : _ApartmentCard(
                            listing: _selectedMapListing!,
                            favorite: _favorites.contains(
                              _selectedMapListing!.id,
                            ),
                            meta: _meta,
                            priceMuted: _priceMuted,
                            compact: true,
                            onFavorite: () =>
                                _toggleFavorite(_selectedMapListing!.id),
                            onClose: () {
                              setState(() => _selectedMapListingId = null);
                            },
                          ),
                  )
                : (!_hasQuery
                      ? _EmptySearch(onSearch: _runSearch)
                      : _ListingResults(
                          listings: _visible,
                          favorites: _favorites,
                          meta: _meta,
                          priceMuted: _priceMuted,
                          onFavorite: _toggleFavorite,
                        )),
          ),
        ),
      ],
    );
  }

  SearchListing? get _selectedMapListing {
    final id = _selectedMapListingId;
    if (id == null) return null;
    for (final item in _visible) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _toggleFavorite(String id) {
    setState(() {
      if (!_favorites.remove(id)) _favorites.add(id);
    });
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onChanged,
    required this.onFilter,
    required this.onMap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilter;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: Material(
              color: AppColors.searchFieldFill,
              borderRadius: BorderRadius.circular(22),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.search,
                textCapitalization: TextCapitalization.sentences,
                enableInteractiveSelection: true,
                showCursor: true,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  height: 20 / 14,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Хочу снять жилье в...',
                  hintStyle: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    height: 20 / 14,
                    color: Color(0xFF9A9A9A),
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 18,
                    color: Color(0xFF9A9A9A),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 42,
                    minHeight: 44,
                  ),
                  filled: true,
                  fillColor: AppColors.searchFieldFill,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Фильтры',
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onFilter,
              customBorder: const CircleBorder(),
              child: Image.asset(
                'images/search/Frame 1851040266.png',
                width: 44,
                height: 44,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Карта',
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onMap,
              customBorder: const CircleBorder(),
              child: SvgPicture.asset(
                'images/ mapFrame.svg',
                width: 44,
                height: 44,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ],
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
          SvgPicture.asset(
            'images/search/empty-search.svg',
            width: 200,
            height: 160,
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
              color: AppColors.textPrimary,
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
              child: const Text('Найти отель'),
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

  final List<SearchListing> listings;
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
            'Нет подходящих вариантов.\nПопробуйте изменить параметры поиска',
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

class _ApartmentCard extends StatelessWidget {
  const _ApartmentCard({
    required this.listing,
    required this.favorite,
    required this.meta,
    required this.priceMuted,
    required this.onFavorite,
    this.onClose,
    this.compact = false,
  });

  final SearchListing listing;
  final bool favorite;
  final Color meta;
  final Color priceMuted;
  final VoidCallback onFavorite;
  final VoidCallback? onClose;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final photoHeight = compact ? 218.0 : 220.0;
    const radius = 12.0;
    final buttonSize = compact ? 34.0 : 36.0;

    Widget card = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: photoHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(radius),
                    bottom: Radius.circular(compact ? 0 : radius),
                  ),
                  child: Image.asset(listing.photo, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 20,
                right: 20,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RoundIconButton(
                      size: buttonSize,
                      icon: favorite ? Icons.favorite : Icons.favorite_border,
                      iconSize: compact ? 18 : 20,
                      color: favorite
                          ? AppColors.orange
                          : AppColors.textPrimary,
                      onTap: onFavorite,
                    ),
                    if (onClose != null) ...[
                      const SizedBox(width: 12),
                      _RoundIconButton(
                        size: buttonSize,
                        icon: Icons.close,
                        iconSize: compact ? 16 : 18,
                        color: AppColors.textPrimary,
                        tooltip: 'Закрыть',
                        onTap: onClose!,
                      ),
                    ],
                  ],
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

    if (!compact) return card;

    return Material(
      color: AppColors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: card,
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.size,
    required this.icon,
    required this.iconSize,
    required this.color,
    required this.onTap,
    this.tooltip,
  });

  final double size;
  final IconData icon;
  final double iconSize;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AppColors.white,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: const Color(0x33000000),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: color),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label, required this.color});

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
                    onPressed: () => Navigator.pop(context, _selected ?? ''),
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
