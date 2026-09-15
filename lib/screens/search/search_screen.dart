import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/listings_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/favorite_heart_button.dart';
import '../../widgets/listing_image.dart';
import '../listing/listing_detail_screen.dart';
import 'search_filters_sheet.dart';
import 'search_listing.dart';
import 'search_map_view.dart';
import 'search_query_sheet.dart';

/// Вкладка «Поиск жилья» по макету Figma `1:16160` (пустой старт)
/// и соседним фреймам каталога `1:15179` / чипов `1:15291`.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.repository});

  final ListingsRepository? repository;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _meta = Color(0xFF9A9A9A);
  static const _priceMuted = Color(0xFF6B6B6B);

  final _favorites = <String>{};
  var _showMap = false;
  var _query = const SearchQuery();
  var _filters = const SearchFilters();
  var _listings = const <SearchListing>[];
  var _loading = true;
  Object? _error;
  String? _selectedMapListingId;

  ListingsRepository get _repository =>
      widget.repository ?? ListingsRepositoryScope.instance;

  List<String> get _cities {
    return {for (final item in _listings) item.city}.toList()..sort();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final listings = await _repository.fetchPublished();
      if (!mounted) return;
      setState(() {
        _listings = listings;
        _filters = _filters.withPriceBounds(
          SearchFilters.boundsFromPrices([
            for (final item in listings) item.pricePerNight,
          ]),
        );
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

  bool get _hasQuery => _query.isActive;

  bool get _hasCriteria => _hasQuery || _filters.isActive;

  bool get _showNoMatches =>
      !_loading && _error == null && _hasCriteria && _visible.isEmpty;

  List<SearchListing> get _visible {
    final query = _normalize(_query.city);
    final guests = _query.adults + _query.children;
    return [
      for (final raw in _listings)
        if (_matchesFilters(raw) &&
            (guests == 0 || raw.maxGuests <= 0 || raw.maxGuests >= guests) &&
            (_query.pets == 0 || raw.petsAllowed) &&
            (query.isEmpty || _matchesCity(raw, query)))
          raw.withStay(checkIn: _query.checkIn, checkOut: _query.checkOut),
    ];
  }

  bool _matchesCity(SearchListing item, String query) {
    final haystack = [
      item.city,
      item.title,
      item.type,
      if (_normalize(item.city) == 'санкт-петербург') 'питер спб',
    ].map(_normalize).join(' ');
    return haystack.contains(query) || query.contains(_normalize(item.city));
  }

  bool _matchesFilters(SearchListing item) {
    final filters = _filters;
    if (filters.housingTypes.isNotEmpty &&
        !filters.housingTypes.contains(item.type)) {
      return false;
    }
    if (filters.price case final price?) {
      if (item.pricePerNight < price.start || item.pricePerNight > price.end) {
        return false;
      }
    }
    if (filters.amenities.isNotEmpty &&
        !filters.amenities.every(item.features.contains)) {
      return false;
    }
    if (filters.extras.isNotEmpty &&
        !filters.extras.every(item.features.contains)) {
      return false;
    }
    return true;
  }

  List<String> get _activeChips {
    return [..._query.chipLabels, ..._filters.chipLabels];
  }

  static String _normalize(String value) {
    return value.toLowerCase().replaceAll('ё', 'е').trim();
  }

  Future<void> _openSearchQuery() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await SearchQuerySheet.show(
      context,
      initial: _query,
      cities: _cities,
    );
    if (!mounted || selected == null) return;
    setState(() => _query = selected);
  }

  Future<void> _openFilters() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await SearchFiltersSheet.show(context, initial: _filters);
    if (!mounted || selected == null) return;
    setState(() => _filters = selected);
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SearchHeader(
                    label: _query.city,
                    filterCount: _filters.appliedCount,
                    onSearch: _openSearchQuery,
                    onFilter: _openFilters,
                    onMap: () => setState(() {
                      _showMap = !_showMap;
                      if (!_showMap) _selectedMapListingId = null;
                    }),
                  ),
                  if (_activeChips.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      key: const ValueKey('search-chips-scroll'),
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final label in _activeChips) _Chip(label: label),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: _showMap ? const Color(0xFFE8EEE4) : AppColors.white,
            child: _showMap ? _mapBody() : _listBody(),
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

  Widget _mapBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _LoadError(onRetry: _load);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        SearchMapView(
          listings: _visible,
          selectedId: _selectedMapListingId,
          onSelectPin: (id) {
            setState(() => _selectedMapListingId = id);
          },
          preview: _selectedMapListing == null
              ? null
              : _ApartmentCard(
                  listing: _selectedMapListing!,
                  favorite: _favorites.contains(_selectedMapListing!.id),
                  meta: _meta,
                  priceMuted: _priceMuted,
                  compact: true,
                  onOpen: () => _openListing(_selectedMapListing!),
                  onFavorite: () => _toggleFavorite(_selectedMapListing!.id),
                  onClose: () {
                    setState(() => _selectedMapListingId = null);
                  },
                ),
        ),
        if (_showNoMatches) const _NoMatches(asCard: true),
      ],
    );
  }

  Widget _listBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _LoadError(onRetry: _load);
    }
    if (!_hasCriteria) {
      return _EmptySearch(onSearch: _openSearchQuery);
    }
    return _ListingResults(
      listings: _visible,
      favorites: _favorites,
      meta: _meta,
      priceMuted: _priceMuted,
      onOpen: _openListing,
      onFavorite: _toggleFavorite,
    );
  }

  void _openListing(SearchListing listing) {
    ListingDetailScreen.open(
      context,
      listing: listing,
      favorites: _favorites,
      onFavorite: _toggleFavorite,
      repository: _repository,
    );
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.label,
    required this.filterCount,
    required this.onSearch,
    required this.onFilter,
    required this.onMap,
  });

  final String label;
  final int filterCount;
  final VoidCallback onSearch;
  final VoidCallback onFilter;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    final hasLabel = label.trim().isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: Tooltip(
              message: 'Поиск',
              child: Material(
                color: AppColors.searchFieldFill,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  onTap: onSearch,
                  borderRadius: BorderRadius.circular(22),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          size: 18,
                          color: Color(0xFF9A9A9A),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            hasLabel ? label : 'Хочу снять жилье в...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontWeight: FontWeight.w400,
                              fontSize: 14,
                              height: 20 / 14,
                              color: hasLabel
                                  ? AppColors.textPrimary
                                  : const Color(0xFF9A9A9A),
                            ),
                          ),
                        ),
                      ],
                    ),
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
              child: SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Image.asset(
                      'images/search/Frame 1851040266.png',
                      width: 44,
                      height: 44,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                    if (filterCount > 0)
                      Positioned(
                        right: -6,
                        top: -5,
                        child: _FilterCountBadge(count: filterCount),
                      ),
                  ],
                ),
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

class _FilterCountBadge extends StatelessWidget {
  const _FilterCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('filter-count-badge'),
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const ShapeDecoration(
        color: Color(0xFFE34043),
        shape: StadiumBorder(),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w400,
          fontSize: 10,
          height: 1.4,
          color: AppColors.white,
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
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const ShapeDecoration(
        color: AppColors.searchFieldFill,
        shape: StadiumBorder(side: BorderSide(color: AppColors.orange)),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w400,
          fontSize: 14,
          height: 1.4,
          color: AppColors.orange,
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({this.asCard = false});

  static const message =
      'Нет подходящих вариантов\nПопробуйте изменить параметры поиска';

  final bool asCard;

  @override
  Widget build(BuildContext context) {
    final illustration = SvgPicture.asset(
      'images/search/empty-no-matches.svg',
      width: asCard ? 103 : 164,
      height: asCard ? 100 : 160,
    );
    const text = Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontWeight: FontWeight.w400,
        fontSize: 14,
        height: 1.40,
        color: Color(0xFF1A1B1C),
      ),
    );

    if (!asCard) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: 308,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [illustration, const SizedBox(height: 24), text],
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 53),
        child: SizedBox(
          width: double.infinity,
          child: DecoratedBox(
            key: const ValueKey('no-matches-map-card'),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [illustration, const SizedBox(height: 24), text],
              ),
            ),
          ),
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
    required this.onOpen,
    required this.onFavorite,
  });

  final List<SearchListing> listings;
  final Set<String> favorites;
  final Color meta;
  final Color priceMuted;
  final ValueChanged<SearchListing> onOpen;
  final ValueChanged<String> onFavorite;

  @override
  Widget build(BuildContext context) {
    if (listings.isEmpty) {
      return const _NoMatches();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      itemCount: listings.length,
      separatorBuilder: (_, _) => const SizedBox(height: 24),
      itemBuilder: (context, index) {
        final listing = listings[index];
        return _ApartmentCard(
          listing: listing,
          favorite: favorites.contains(listing.id),
          meta: meta,
          priceMuted: priceMuted,
          onOpen: () => onOpen(listing),
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
    required this.onOpen,
    required this.onFavorite,
    this.onClose,
    this.compact = false,
  });

  final SearchListing listing;
  final bool favorite;
  final Color meta;
  final Color priceMuted;
  final VoidCallback onOpen;
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
                  child: ListingImage(listing.photo, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 20,
                right: 20,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FavoriteHeartButton(
                      favorite: favorite,
                      size: buttonSize,
                      iconSize: compact ? 18 : 20,
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
              if (listing.photos.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: _PhotoDots(
                    active: listing.imageIndex,
                    count: listing.photos.length,
                  ),
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
                  if (listing.dates.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Meta(
                        icon: Icons.calendar_today_outlined,
                        label: listing.nights.isEmpty
                            ? listing.dates
                            : '${listing.dates} · ${listing.nights}',
                        color: meta,
                      ),
                    ),
                  ],
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

    if (!compact) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('listing-card-${listing.id}'),
          onTap: onOpen,
          child: card,
        ),
      );
    }

    return Material(
      key: ValueKey('listing-card-${listing.id}'),
      color: AppColors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onOpen, child: card),
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

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Не удалось загрузить объявления',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                height: 1.3,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Проверьте соединение и попробуйте ещё раз',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF6B6B6B),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}

class _PhotoDots extends StatelessWidget {
  const _PhotoDots({required this.active, this.count = 4});

  final int active;
  final int count;

  @override
  Widget build(BuildContext context) {
    final dots = count.clamp(1, 8);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < dots; i++) ...[
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
