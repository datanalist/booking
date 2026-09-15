import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Вкладка «Избранное» по макетам Figma `1:12120` (пусто) и `1:12159` (список).
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoriteStay {
  const _FavoriteStay({
    required this.id,
    required this.title,
    required this.city,
    required this.housingType,
    required this.dates,
    required this.nights,
    required this.total,
    required this.perNight,
    required this.rating,
    required this.reviews,
    required this.photos,
    this.initialPhoto = 0,
  });

  final String id;
  final String title;
  final String city;
  final String housingType;
  final String dates;
  final String nights;
  final String total;
  final String perNight;
  final String rating;
  final String reviews;
  final List<String> photos;
  final int initialPhoto;
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late List<_FavoriteStay> _items = const [];

  void _remove(String id) {
    setState(() {
      _items = _items.where((item) => item.id != id).toList(growable: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.white,
      child: SafeArea(
        child: _items.isEmpty
            ? const _EmptyFavorites()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                itemCount: _items.length,
                separatorBuilder: (context, index) => const SizedBox(height: 24),
                itemBuilder: (context, index) {
                  final stay = _items[index];
                  return _ApartmentCard(
                    stay: stay,
                    onRemove: () => _remove(stay.id),
                  );
                },
              ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NoFavouriteIllustration(),
            SizedBox(height: 24),
            Text(
              'Добавленное в избранное жилье будет отображаться здесь',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 16,
                height: 1.25,
                color: AppColors.emptyHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Замена иллюстрации `Empty State Illustrations_Light Mode_No Favourite`
/// (Figma MCP в этой сессии недоступен, экспорт ассета не выполнен).
class _NoFavouriteIllustration extends StatelessWidget {
  const _NoFavouriteIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 198,
      height: 160,
      child: Center(
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.orange.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.favorite,
            size: 56,
            color: AppColors.orange,
          ),
        ),
      ),
    );
  }
}

class _ApartmentCard extends StatefulWidget {
  const _ApartmentCard({
    required this.stay,
    required this.onRemove,
  });

  final _FavoriteStay stay;
  final VoidCallback onRemove;

  @override
  State<_ApartmentCard> createState() => _ApartmentCardState();
}

class _ApartmentCardState extends State<_ApartmentCard> {
  late final PageController _photos = PageController(
    initialPage: widget.stay.initialPhoto,
  );
  late int _photoIndex = widget.stay.initialPhoto;

  @override
  void dispose() {
    _photos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stay = widget.stay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _photos,
                  itemCount: stay.photos.length,
                  onPageChanged: (value) => setState(() => _photoIndex = value),
                  itemBuilder: (context, index) {
                    return Image.asset(
                      stay.photos[index],
                      fit: BoxFit.cover,
                    );
                  },
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
                      onTap: widget.onRemove,
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(
                          Icons.favorite,
                          size: 20,
                          color: AppColors.orange,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: _PhotoDots(
                    count: stay.photos.length,
                    index: _photoIndex,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                stay.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  height: 1.25,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              stay.rating,
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
              stay.reviews,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 20 / 14,
                color: AppColors.tabInactive,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 14,
              color: AppColors.tabInactive,
            ),
            const SizedBox(width: 4),
            Text(
              stay.city,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 18 / 14,
                color: AppColors.tabInactive,
              ),
            ),
            const SizedBox(width: 28),
            const Icon(
              Icons.home_outlined,
              size: 14,
              color: AppColors.tabInactive,
            ),
            const SizedBox(width: 4),
            Text(
              stay.housingType,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 18 / 14,
                color: AppColors.tabInactive,
              ),
            ),
            const SizedBox(width: 28),
            const Icon(
              Icons.calendar_today_outlined,
              size: 14,
              color: AppColors.tabInactive,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: stay.dates),
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: SizedBox(
                          width: 2,
                          height: 2,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.tabInactive,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                    TextSpan(text: stay.nights),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  height: 18 / 14,
                  color: AppColors.tabInactive,
                ),
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
                height: 19 / 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              stay.perNight,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 17 / 14,
                color: AppColors.tabInactive,
              ),
            ),
          ],
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
              color: i == index
                  ? AppColors.white
                  : AppColors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(50),
            ),
          ),
        ],
      ],
    );
  }
}
