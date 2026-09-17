import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Иконки деталки Figma `1:10782`: внешний бокс и лист с явными размерами.
class ListingFigmaIcon extends StatelessWidget {
  const ListingFigmaIcon._({
    required this.asset,
    required this.box,
    required this.leaf,
  });

  final String asset;
  final Size box;
  final Size leaf;

  static const mapPin16 = ListingFigmaIcon._(
    asset: 'images/listing/map-pin-16.svg',
    box: Size.square(16),
    leaf: Size.square(16),
  );

  static const home16 = ListingFigmaIcon._(
    asset: 'images/listing/home-16.svg',
    box: Size.square(16),
    leaf: Size.square(16),
  );

  static const mapPin14 = ListingFigmaIcon._(
    asset: 'images/listing/map-pin-14.svg',
    box: Size.square(14),
    leaf: Size.square(14),
  );

  static const home14 = ListingFigmaIcon._(
    asset: 'images/listing/home-14.svg',
    box: Size.square(14),
    leaf: Size.square(14),
  );

  static const star18 = ListingFigmaIcon._(
    asset: 'images/listing/star-18.svg',
    box: Size.square(18),
    leaf: Size(14.5028, 13.7499),
  );

  static const star16 = ListingFigmaIcon._(
    asset: 'images/listing/star-16.svg',
    box: Size.square(16),
    leaf: Size(13.3351, 12.6675),
  );

  static const star12 = ListingFigmaIcon._(
    asset: 'images/listing/star-12.svg',
    box: Size.square(12),
    leaf: Size(10.0015, 9.50068),
  );

  static const reviewStarOn = ListingFigmaIcon._(
    asset: 'images/listing/star-review-on.svg',
    box: Size(13, 12),
    leaf: Size(13.0506, 12.2396),
  );

  static const reviewStarOff = ListingFigmaIcon._(
    asset: 'images/listing/star-review-off.svg',
    box: Size(13, 12),
    leaf: Size(13.0506, 12.2396),
  );

  static const security = ListingFigmaIcon._(
    asset: 'images/listing/security.svg',
    box: Size.square(16),
    leaf: Size.square(16),
  );

  static const time = ListingFigmaIcon._(
    asset: 'images/listing/time.svg',
    box: Size.square(16),
    leaf: Size.square(16),
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: box.width,
      height: box.height,
      child: Center(
        child: SvgPicture.asset(
          asset,
          width: leaf.width,
          height: leaf.height,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
