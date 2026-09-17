import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../widgets/favorite_heart_button.dart';
import '../../widgets/listing_image.dart';
import '../search/search_listing.dart';
import 'listing_icons.dart';

const _meta = Color(0xFF525353);
const _cardStroke = Color(0x2BFBC028);

/// Полный список объявлений хозяина по макету Figma `1:11268`.
class HostListingsScreen extends StatefulWidget {
  const HostListingsScreen({
    super.key,
    required this.hostName,
    required this.listings,
    required this.favorites,
    required this.onFavorite,
    required this.onOpen,
  });

  final String hostName;
  final List<SearchListing> listings;
  final Set<String> favorites;
  final ValueChanged<String> onFavorite;
  final Future<void> Function(SearchListing listing) onOpen;

  static Future<void> open(
    BuildContext context, {
    required String hostName,
    required List<SearchListing> listings,
    required Set<String> favorites,
    required ValueChanged<String> onFavorite,
    required Future<void> Function(SearchListing listing) onOpen,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => HostListingsScreen(
          hostName: hostName,
          listings: listings,
          favorites: favorites,
          onFavorite: onFavorite,
          onOpen: onOpen,
        ),
      ),
    );
  }

  @override
  State<HostListingsScreen> createState() => _HostListingsScreenState();
}

class _HostListingsScreenState extends State<HostListingsScreen> {
  bool _isFavorite(String id) => widget.favorites.contains(id);

  void _toggleFavorite(String id) {
    widget.onFavorite(id);
    setState(() {});
  }

  Future<void> _openListing(SearchListing listing) async {
    await widget.onOpen(listing);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        key: const ValueKey('host-listings'),
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _BackButton(onTap: () => Navigator.of(context).pop()),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  children: [
                    Text(
                      'Объявления владельца ${widget.hostName}',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        height: 25 / 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < widget.listings.length; i++) ...[
                      if (i != 0) const SizedBox(height: 12),
                      HostListingCard(
                        listing: widget.listings[i],
                        favorite: _isFavorite(widget.listings[i].id),
                        onTap: () => _openListing(widget.listings[i]),
                        onFavorite: () =>
                            _toggleFavorite(widget.listings[i].id),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Назад',
      child: Material(
        color: AppColors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              Icons.arrow_back,
              size: 20,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class HostListingCard extends StatelessWidget {
  const HostListingCard({
    super.key,
    required this.listing,
    required this.favorite,
    required this.onTap,
    required this.onFavorite,
    this.width = double.infinity,
    this.showFavorite = true,
  });

  final SearchListing listing;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final double width;
  final bool showFavorite;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: _cardStroke),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: 247,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ListingImage(
                      listing.photo,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    const ColoredBox(color: Color.fromRGBO(16, 51, 99, 0.05)),
                    if (showFavorite)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: FavoriteHeartButton(
                          favorite: favorite,
                          size: 32,
                          iconSize: 18,
                          onTap: onFavorite,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        height: 1.40,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _TinyMeta(
                          icon: ListingFigmaIcon.mapPin14,
                          label: listing.city,
                        ),
                        _TinyMeta(
                          icon: ListingFigmaIcon.home14,
                          label: listing.type,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          listing.rating,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                            height: 1.50,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        ListingFigmaIcon.star16,
                        const SizedBox(width: 2),
                        Text(
                          reviewCountLabel(
                            reviewCountFromLabel(listing.reviews),
                          ),
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                            height: 1.50,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TinyMeta extends StatelessWidget {
  const _TinyMeta({required this.icon, required this.label});

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
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w400,
            fontSize: 12,
            height: 1.50,
            color: _meta,
          ),
        ),
      ],
    );
  }
}
