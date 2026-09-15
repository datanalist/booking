import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/listings_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/favorite_heart_button.dart';
import '../../widgets/listing_image.dart';
import '../search/search_listing.dart';
import '../search/search_query_sheet.dart';
import 'host_listings_screen.dart';
import 'listing_detail.dart';

const _meta = Color(0xFF525252);
const _divider = Color(0xFFFFE3B7);
const _reviewFill = Color(0x0FFBC028);
const _reviewStroke = Color(0x2BFBC028);
const _badgeGreen = Color(0xFF49CB5E);

class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({
    super.key,
    required this.listing,
    required this.favorites,
    required this.onFavorite,
    this.initialDetail,
    this.repository,
  });

  final SearchListing listing;
  final Set<String> favorites;
  final ValueChanged<String> onFavorite;
  final ListingDetail? initialDetail;
  final ListingsRepository? repository;

  static Future<void> open(
    BuildContext context, {
    required SearchListing listing,
    required Set<String> favorites,
    required ValueChanged<String> onFavorite,
    ListingDetail? initialDetail,
    ListingsRepository? repository,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ListingDetailScreen(
          listing: listing,
          favorites: favorites,
          onFavorite: onFavorite,
          initialDetail: initialDetail,
          repository: repository,
        ),
      ),
    );
  }

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  late final PageController _photos = PageController();
  var _photoIndex = 0;
  late ListingDetail _detail;

  ListingsRepository get _repository =>
      widget.repository ?? ListingsRepositoryScope.instance;

  @override
  void initState() {
    super.initState();
    _detail = widget.initialDetail ?? ListingDetail.fromListing(widget.listing);
    if (widget.initialDetail == null) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final detail = await _repository.fetchDetail(widget.listing);
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (_) {
      // Карточка уже собрана из записи списка; хозяин/другие объекты подтянутся при повторе.
    }
  }

  bool _isFavorite(String id) => widget.favorites.contains(id);

  void _toggleFavorite(String id) {
    widget.onFavorite(id);
    setState(() {});
  }

  Future<void> _openListing(SearchListing listing) {
    return ListingDetailScreen.open(
      context,
      listing: listing,
      favorites: widget.favorites,
      onFavorite: widget.onFavorite,
      repository: _repository,
    );
  }

  @override
  void dispose() {
    _photos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final listing = detail.listing;
    final favorite = _isFavorite(listing.id);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        key: ValueKey('listing-detail-${listing.id}'),
        backgroundColor: AppColors.white,
        body: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _HeroGallery(
                      photos: detail.photos,
                      controller: _photos,
                      index: _photoIndex,
                      favorite: favorite,
                      onPageChanged: (value) {
                        setState(() => _photoIndex = value);
                      },
                      onBack: () => Navigator.of(context).pop(),
                      onFavorite: () => _toggleFavorite(listing.id),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Header(detail: detail),
                          const SizedBox(height: 20),
                          const _Hairline(),
                          const SizedBox(height: 20),
                          _Amenities(items: detail.amenities),
                          const SizedBox(height: 20),
                          const _Hairline(),
                          const SizedBox(height: 20),
                          _Reviews(detail: detail),
                          const SizedBox(height: 20),
                          const _Hairline(),
                          const SizedBox(height: 20),
                          _Host(host: detail.host),
                          if (detail.hostListings.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _HostListings(
                              listings: detail.hostListings,
                              favorites: widget.favorites,
                              onOpen: _openListing,
                              onFavorite: _toggleFavorite,
                              onSeeAll: () => HostListingsScreen.open(
                                context,
                                hostName: detail.host.name,
                                listings: detail.hostListings,
                                favorites: widget.favorites,
                                onFavorite: _toggleFavorite,
                                onOpen: _openListing,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _BookingBar(listing: listing),
          ],
        ),
      ),
    );
  }
}

class _HeroGallery extends StatelessWidget {
  const _HeroGallery({
    required this.photos,
    required this.controller,
    required this.index,
    required this.favorite,
    required this.onPageChanged,
    required this.onBack,
    required this.onFavorite,
  });

  final List<String> photos;
  final PageController controller;
  final int index;
  final bool favorite;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onBack;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 332,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: controller,
            itemCount: photos.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, page) {
              return ListingImage(photos[page], fit: BoxFit.cover);
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CircleButton(
                      icon: Icons.arrow_back,
                      tooltip: 'Назад',
                      onTap: onBack,
                    ),
                    FavoriteHeartButton(
                      key: const ValueKey('listing-hero-favorite'),
                      favorite: favorite,
                      onTap: onFavorite,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (photos.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: _PhotoDots(count: photos.length, index: index),
            ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.color = AppColors.textPrimary,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
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

class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final ListingDetail detail;

  @override
  Widget build(BuildContext context) {
    final listing = detail.listing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          listing.title,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            height: 1.2,
            letterSpacing: 0.02,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _MetaRow(icon: Icons.location_on_outlined, label: detail.address),
        const SizedBox(height: 6),
        _MetaRow(icon: Icons.home_outlined, label: listing.type),
        const SizedBox(height: 12),
        Text(
          detail.description,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w400,
            fontSize: 14,
            height: 1.40,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _meta),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w400,
              fontSize: 14,
              height: 1.40,
              color: _meta,
            ),
          ),
        ),
      ],
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 0.5, color: _divider);
  }
}

class _Amenities extends StatelessWidget {
  const _Amenities({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Удобства',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            height: 1.40,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              _AmenityChip(
                icon: kAmenityIcons[item] ?? Icons.check,
                label: item,
              ),
          ],
        ),
      ],
    );
  }
}

class _AmenityChip extends StatelessWidget {
  const _AmenityChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.orange),
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.orange),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w400,
              fontSize: 14,
              height: 1.40,
              color: AppColors.orange,
            ),
          ),
        ],
      ),
    );
  }
}

class _Reviews extends StatelessWidget {
  const _Reviews({required this.detail});

  final ListingDetail detail;

  @override
  Widget build(BuildContext context) {
    final listing = detail.listing;
    final count = reviewCountFromLabel(listing.reviews);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Отзывы',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                height: 1.40,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
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
            const Icon(Icons.star, size: 18, color: AppColors.yellow),
            const SizedBox(width: 2),
            Text(
              reviewCountLabel(count),
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                fontSize: 12,
                height: 1.50,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            const _SeeAll(),
          ],
        ),
        if (detail.reviews.isNotEmpty) ...[
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < detail.reviews.length; i++) ...[
                  if (i != 0) const SizedBox(width: 12),
                  _ReviewCard(review: detail.reviews[i]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SeeAll extends StatelessWidget {
  const _SeeAll({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const label = Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Text(
        'Смотреть все',
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w400,
          fontSize: 12,
          height: 1.30,
          color: AppColors.orange,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.orange,
        ),
      ),
    );
    if (onTap == null) return label;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: label,
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final ListingReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: _reviewFill,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: _reviewStroke),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(label: review.author, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.author,
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
                    Text(
                      review.postedAgo,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w400,
                        fontSize: 10,
                        height: 1.40,
                        color: _meta,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Stars(count: review.stars, size: 13),
          const SizedBox(height: 10),
          Text(
            review.text,
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
    );
  }
}

class _Host extends StatelessWidget {
  const _Host({required this.host});

  final ListingHost host;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Владелец',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            height: 1.40,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _Avatar(label: host.name, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    host.name,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                      height: 1.40,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        host.rating,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          height: 1.50,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        reviewCountLabel(host.reviewCount),
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          height: 1.50,
                          color: _meta,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Flexible(child: _Stars(count: 5, size: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (host.verified)
              const _HostBadge(
                icon: Icons.verified_outlined,
                label: 'Верификация пройдена',
              ),
            if (host.years > 0)
              _HostBadge(
                icon: Icons.calendar_month_outlined,
                label: yearsHostingLabel(host.years),
              ),
          ],
        ),
      ],
    );
  }
}

class _HostBadge extends StatelessWidget {
  const _HostBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: ShapeDecoration(
        color: _badgeGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w400,
              fontSize: 12,
              height: 1.50,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _HostListings extends StatelessWidget {
  const _HostListings({
    required this.listings,
    required this.favorites,
    required this.onOpen,
    required this.onFavorite,
    required this.onSeeAll,
  });

  final List<SearchListing> listings;
  final Set<String> favorites;
  final ValueChanged<SearchListing> onOpen;
  final ValueChanged<String> onFavorite;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Другие объявления владельца',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  height: 1.40,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            _SeeAll(
              key: const ValueKey('listing-host-see-all'),
              onTap: onSeeAll,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < listings.length; i++) ...[
                if (i != 0) const SizedBox(width: 12),
                HostListingCard(
                  listing: listings[i],
                  favorite: favorites.contains(listings[i].id),
                  width: 260,
                  onTap: () => onOpen(listings[i]),
                  onFavorite: () => onFavorite(listings[i].id),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BookingBar extends StatefulWidget {
  const _BookingBar({required this.listing});

  final SearchListing listing;

  @override
  State<_BookingBar> createState() => _BookingBarState();
}

class _BookingBarState extends State<_BookingBar> {
  late SearchListing _stay;

  @override
  void initState() {
    super.initState();
    _stay = widget.listing;
  }

  @override
  void didUpdateWidget(_BookingBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listing.id != widget.listing.id) {
      _stay = widget.listing;
      return;
    }
    _stay = widget.listing.withStay(
      checkIn: _stay.checkIn,
      checkOut: _stay.checkOut,
    );
  }

  Future<void> _pickStayDates() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final checkIn = await _pickDate(checkOut: false, today: today);
    if (!mounted || checkIn == null) return;
    final checkOut = await _pickDate(
      checkOut: true,
      today: today,
      checkIn: checkIn,
    );
    if (!mounted || checkOut == null) return;
    setState(() {
      _stay = widget.listing.withStay(checkIn: checkIn, checkOut: checkOut);
    });
  }

  Future<DateTime?> _pickDate({
    required bool checkOut,
    required DateTime today,
    DateTime? checkIn,
  }) {
    final bounds = stayDatePickerBounds(
      checkOut: checkOut,
      today: today,
      currentCheckIn: checkIn ?? _stay.checkIn,
      currentCheckOut: _stay.checkOut,
    );
    return showDatePicker(
      context: context,
      locale: const Locale('ru', 'RU'),
      initialDate: bounds.initial,
      firstDate: bounds.first,
      lastDate: bounds.last,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.orange,
              onPrimary: AppColors.white,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final listing = _stay;
    final hasStay = listing.stayNightCount > 0;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: AppColors.white,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _reviewStroke)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    key: const ValueKey('listing-booking-total'),
                    listing.total,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      letterSpacing: 0.02,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      listing.perNight,
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
                  ),
                  GestureDetector(
                    key: const ValueKey('listing-booking-dates'),
                    onTap: _pickStayDates,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hasStay ? listing.dates : 'Выберите даты',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                            height: 1.50,
                            color: _meta,
                            decoration: TextDecoration.underline,
                            decorationColor: _meta,
                          ),
                        ),
                        if (hasStay) ...[
                          const Padding(
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
                          Text(
                            listing.nights,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontWeight: FontWeight.w400,
                              fontSize: 12,
                              height: 1.50,
                              color: _meta,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Забронировать'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.count, required this.size});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++) ...[
          if (i != 0) const SizedBox(width: 6),
          Icon(
            Icons.star,
            size: size,
            color: i < count ? AppColors.yellow : const Color(0xFFE8E8E8),
          ),
        ],
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.label, required this.size});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFFFFE3B7),
      child: Text(
        label.isEmpty ? '?' : label.characters.first,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
          color: AppColors.orange,
        ),
      ),
    );
  }
}
