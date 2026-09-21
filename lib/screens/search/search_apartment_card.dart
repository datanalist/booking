import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/favorite_heart_button.dart';
import '../../widgets/listing_image.dart';
import 'search_listing.dart';

/// Карточка жилья в списке поиска и в preview на карте (`compact: true`).
class SearchApartmentCard extends StatelessWidget {
  const SearchApartmentCard({
    super.key,
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
