import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/auth_repository.dart';
import '../../data/favorites_repository.dart';
import '../../data/listings_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/favorite_heart_button.dart';
import '../../widgets/listing_image.dart';
import '../listing/listing_detail_screen.dart';
import '../listing/listing_icons.dart';
import '../search/active_search_stay.dart';
import '../search/search_listing.dart';

const _meta = Color(0xFF525353);
const _photoOverlay = Color.fromRGBO(16, 51, 99, 0.05);
const _dotInactive = Color.fromRGBO(251, 192, 40, 0.17);

/// Вкладка «Избранное» по макетам Figma `1:12120` (пусто) и `1:12159` (список).
/// Записи — коллекция PocketBase `favorites` текущего гостя.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, this.repository});

  final FavoritesRepository? repository;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _ids = <String>{};
  var _items = const <SearchListing>[];
  var _loading = true;
  Object? _error;

  FavoritesRepository get _repository =>
      widget.repository ?? FavoritesRepositoryScope.instance;

  ListingsRepository get _listings => ListingsRepositoryScope.instance;

  @override
  void initState() {
    super.initState();
    FavoritesRepositoryScope.listVersion.addListener(_reload);
    AuthRepositoryScope.session.addListener(_reload);
    ActiveSearchStay.current.addListener(_onStay);
    _load();
  }

  @override
  void dispose() {
    FavoritesRepositoryScope.listVersion.removeListener(_reload);
    AuthRepositoryScope.session.removeListener(_reload);
    ActiveSearchStay.current.removeListener(_onStay);
    super.dispose();
  }

  void _onStay() {
    if (mounted) setState(() {});
  }

  void _reload() => _load();

  Future<void> _load() async {
    final quiet = _items.isNotEmpty;
    if (!quiet && !_loading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final items = await _repository.fetchMine();
      if (!mounted) return;
      setState(() {
        _apply(items);
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _items.isEmpty ? error : _error;
      });
    }
  }

  void _apply(List<SearchListing> items) {
    _items = items;
    _ids
      ..clear()
      ..addAll([for (final item in items) item.id]);
  }

  List<SearchListing> get _shown {
    final stay = ActiveSearchStay.current.value;
    return [
      for (final item in _items)
        item.withStay(checkIn: stay.checkIn, checkOut: stay.checkOut),
    ];
  }

  void _toggle(String id) {
    final removing = _ids.contains(id);
    setState(() {
      if (removing) {
        _ids.remove(id);
        _items = [for (final item in _items) if (item.id != id) item];
      } else {
        _ids.add(id);
      }
    });
    _write(id, removing: removing);
  }

  Future<void> _write(String id, {required bool removing}) async {
    try {
      if (removing) {
        await _repository.remove(id);
      } else {
        await _repository.add(id);
      }
      if (!mounted) return;
      FavoritesRepositoryScope.notifyChanged();
    } catch (error) {
      if (!mounted) return;
      final message = error is FavoriteException
          ? error.message
          : 'Не удалось обновить избранное';
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(message)),
      );
      await _load();
    }
  }

  void _open(SearchListing listing) {
    final stay = ActiveSearchStay.current.value;
    ListingDetailScreen.open(
      context,
      listing: listing,
      favorites: _ids,
      onFavorite: _toggle,
      repository: _listings,
      adults: stay.adults < 1 ? 1 : stay.adults,
      children: stay.children,
      pets: stay.pets,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _shown;
    return ColoredBox(
      color: AppColors.white,
      child: SafeArea(
        child: _loading && _items.isEmpty && _error == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _items.isEmpty
            ? _FavoritesError(onRetry: _load)
            : items.isEmpty
            ? const _EmptyFavorites()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 24),
                itemBuilder: (context, index) {
                  final stay = items[index];
                  return _ApartmentCard(
                    stay: stay,
                    onOpen: () => _open(stay),
                    onToggle: () => _toggle(stay.id),
                  );
                },
              ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  static const _illustrationWidth = 198.333;
  static const _illustrationHeight = 160.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: _illustrationWidth,
              height: _illustrationHeight,
              child: SvgPicture.asset(
                'images/favorites/empty-no-favourite.svg',
                width: _illustrationWidth,
                height: _illustrationHeight,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Добавленное в избранное жилье будет отображаться здесь',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF1A1B1D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesError extends StatelessWidget {
  const _FavoritesError({required this.onRetry});

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
              'Не удалось загрузить избранное',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                height: 1.3,
                color: AppColors.textPrimary,
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

class _ApartmentCard extends StatefulWidget {
  const _ApartmentCard({
    required this.stay,
    required this.onOpen,
    required this.onToggle,
  });

  final SearchListing stay;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  @override
  State<_ApartmentCard> createState() => _ApartmentCardState();
}

class _ApartmentCardState extends State<_ApartmentCard> {
  late final PageController _photos = PageController(
    initialPage: widget.stay.imageIndex,
  );
  late int _photoIndex = widget.stay.imageIndex;

  @override
  void dispose() {
    _photos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stay = widget.stay;
    final photos = stay.photos.isEmpty
        ? <String>[stay.photo]
        : stay.photos;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('favorite-card-${stay.id}'),
        onTap: widget.onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      controller: _photos,
                      itemCount: photos.length,
                      onPageChanged: (value) =>
                          setState(() => _photoIndex = value),
                      itemBuilder: (context, index) {
                        return ListingImage(photos[index], fit: BoxFit.cover);
                      },
                    ),
                    const ColoredBox(color: _photoOverlay),
                    Positioned(
                      top: 20,
                      right: 20,
                      child: FavoriteHeartButton(
                        favorite: true,
                        onTap: widget.onToggle,
                      ),
                    ),
                    if (photos.length > 1)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 10,
                        child: _PhotoDots(
                          count: photos.length,
                          index: _photoIndex,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        stay.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1.4,
                          color: Color(0xFF1A1B1D),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          stay.rating,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                            height: 1.4,
                            color: Color(0xFF1A1B1D),
                          ),
                        ),
                        const SizedBox(width: 2),
                        ListingFigmaIcon.star18,
                        const SizedBox(width: 2),
                        Text(
                          '(${stay.reviewCount})',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                            height: 1.4,
                            color: Color(0xFF1A1B1D),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MetaChip(
                      icon: ListingFigmaIcon.mapPin14,
                      label: stay.city,
                    ),
                    _MetaChip(
                      icon: ListingFigmaIcon.home14,
                      label: stay.type,
                    ),
                    if (stay.dates.isNotEmpty)
                      Flexible(
                        child: _DatesChip(
                          dates: stay.dates,
                          nights: stay.nights,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      stay.total,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        height: 1.2,
                        color: Color(0xFF1A1B1D),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      stay.perNight,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        height: 1.4,
                        color: _meta,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w400,
            fontSize: 12,
            height: 1.5,
            color: _meta,
          ),
        ),
      ],
    );
  }
}

class _DatesChip extends StatelessWidget {
  const _DatesChip({required this.dates, required this.nights});

  final String dates;
  final String nights;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListingFigmaIcon.calendar14,
        const SizedBox(width: 4),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: dates),
                if (nights.isNotEmpty) ...[
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: SizedBox(
                        width: 2,
                        height: 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _meta,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  TextSpan(text: nights),
                ],
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w400,
              fontSize: 12,
              height: 1.5,
              color: _meta,
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoDots extends StatelessWidget {
  const _PhotoDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i != 0) const SizedBox(width: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: i == index ? 16 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index ? AppColors.white : _dotInactive,
              borderRadius: BorderRadius.circular(50),
            ),
          ),
        ],
      ],
    );
  }
}
