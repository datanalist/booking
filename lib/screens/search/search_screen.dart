import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/auth_repository.dart';
import '../../data/favorites_repository.dart';
import '../../data/listings_repository.dart';
import '../../theme/app_theme.dart';
import '../listing/listing_detail_screen.dart';
import 'active_search_stay.dart';
import 'search_apartment_card.dart';
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

  var _favGen = 0;

  FavoritesRepository get _favoritesRepository =>
      FavoritesRepositoryScope.instance;

  @override
  void initState() {
    super.initState();
    _publishStay();
    FavoritesRepositoryScope.listVersion.addListener(_onFavoritesChanged);
    AuthRepositoryScope.session.addListener(_onFavoritesChanged);
    _syncFavorites();
    _load();
  }

  @override
  void dispose() {
    FavoritesRepositoryScope.listVersion.removeListener(_onFavoritesChanged);
    AuthRepositoryScope.session.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  void _publishStay() {
    ActiveSearchStay.publish(
      checkIn: _query.checkIn,
      checkOut: _query.checkOut,
      adults: _query.adults,
      children: _query.children,
      pets: _query.pets,
    );
  }

  void _onFavoritesChanged() => _syncFavorites();

  Future<void> _syncFavorites() async {
    if (!favoritesCanWrite) return;
    final gen = ++_favGen;
    try {
      final items = await _favoritesRepository.fetchMine();
      if (!mounted || gen != _favGen) return;
      setState(() {
        _favorites
          ..clear()
          ..addAll([for (final item in items) item.id]);
      });
    } catch (_) {}
  }

  var _loadGen = 0;

  Future<void> _load() async {
    final gen = ++_loadGen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final listings = await _repository.fetchPublished(
        checkIn: _query.checkIn,
        checkOut: _query.checkOut,
      );
      if (!mounted || gen != _loadGen) return;
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
      if (!mounted || gen != _loadGen) return;
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

  List<String> get _activeChips => _query.chipLabels;

  static String _normalize(String value) {
    return value.toLowerCase().replaceAll('ё', 'е').trim();
  }

  Future<void> _openSearchQuery() async {
    final selected = await SearchQuerySheet.show(
      context,
      initial: _query,
      cities: _cities,
    );
    if (!mounted || selected == null) return;
    final now = DateTime.now();
    final next = selected.completed(
      today: DateTime(now.year, now.month, now.day),
    );
    final datesChanged =
        next.checkIn != _query.checkIn || next.checkOut != _query.checkOut;
    setState(() => _query = next);
    _publishStay();
    if (datesChanged) await _load();
  }

  Future<void> _openFilters() async {
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
                    SingleChildScrollView(
                      key: const ValueKey('search-chips-scroll'),
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < _activeChips.length; i++) ...[
                            if (i != 0) const SizedBox(width: 8),
                            _Chip(label: _activeChips[i]),
                          ],
                        ],
                      ),
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
    final removing = _favorites.contains(id);
    setState(() {
      if (removing) {
        _favorites.remove(id);
      } else {
        _favorites.add(id);
      }
    });
    _favGen++;
    _writeFavorite(id, removing: removing);
  }

  Future<void> _writeFavorite(String id, {required bool removing}) async {
    try {
      await writeFavorite(
        repository: _favoritesRepository,
        listingId: id,
        removing: removing,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (removing) {
          _favorites.add(id);
        } else {
          _favorites.remove(id);
        }
      });
    }
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
              : SearchApartmentCard(
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
      adults: _query.adults < 1 ? 1 : _query.adults,
      children: _query.children,
      pets: _query.pets,
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
        return SearchApartmentCard(
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
