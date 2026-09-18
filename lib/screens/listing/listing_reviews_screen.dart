import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/app_theme.dart';
import '../../widgets/listing_image.dart';
import '../search/search_listing.dart';
import 'listing_icons.dart';

const _meta = Color(0xFF525353);
const _backBorder = Color(0xFFFFE4B8);
const _reviewFill = Color(0x0FFBC028);
const _reviewStroke = Color(0x2BFBC028);

/// Полный список отзывов по макету Figma `1:11227`.
class ListingReviewsScreen extends StatelessWidget {
  const ListingReviewsScreen({
    super.key,
    required this.rating,
    required this.reviews,
    this.reviewCount,
  });

  final String rating;
  final List<ListingReview> reviews;
  final int? reviewCount;

  int get _count => reviewCount ?? reviews.length;

  static Future<void> open(
    BuildContext context, {
    required String rating,
    required List<ListingReview> reviews,
    int? reviewCount,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ListingReviewsScreen(
          rating: rating,
          reviews: reviews,
          reviewCount: reviewCount,
        ),
      ),
    );
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
        key: const ValueKey('listing-reviews'),
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
                    Row(
                      children: [
                        const Text(
                          'Отзывы',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            height: 25 / 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          rating,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                            height: 1.50,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        ListingFigmaIcon.star18,
                        const SizedBox(width: 2),
                        Text(
                          reviewCountLabel(_count),
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
                    if (reviews.isNotEmpty) const SizedBox(height: 12),
                    for (var i = 0; i < reviews.length; i++) ...[
                      if (i != 0) const SizedBox(height: 12),
                      _ReviewCard(review: reviews[i]),
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
        shape: const CircleBorder(side: BorderSide(color: _backBorder)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: Center(child: _BackArrowIcon()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackArrowIcon extends StatelessWidget {
  const _BackArrowIcon();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 2,
      child: SvgPicture.asset(
        'images/profile/arrow-left.svg',
        width: 13.1667,
        height: 7.33333,
        excludeFromSemantics: true,
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final ListingReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(
                label: review.author,
                size: 30,
                url: review.avatarUrl,
              ),
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
              const SizedBox(width: 8),
              _ReviewStars(count: review.stars),
            ],
          ),
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

class _ReviewStars extends StatelessWidget {
  const _ReviewStars({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++) ...[
          if (i != 0) const SizedBox(width: 6),
          i < count
              ? ListingFigmaIcon.reviewStarOn
              : ListingFigmaIcon.reviewStarOff,
        ],
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.label, required this.size, this.url = ''});

  final String label;
  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (url.isNotEmpty) {
      return ClipOval(
        child: ListingImage(url, width: size, height: size, fit: BoxFit.cover),
      );
    }
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
