import 'package:flutter/material.dart';

import '../search/search_listing.dart';

export '../search/search_listing.dart'
    show
        ListingHost,
        ListingReview,
        listingHostDisplayName,
        reviewCountFromLabel,
        reviewCountLabel,
        yearsHostingLabel;

class ListingDetail {
  const ListingDetail({
    required this.listing,
    required this.address,
    required this.description,
    required this.photos,
    required this.amenities,
    required this.reviews,
    required this.host,
    required this.hostListings,
  });

  final SearchListing listing;
  final String address;
  final String description;
  final List<String> photos;
  final List<String> amenities;
  final List<ListingReview> reviews;
  final ListingHost host;
  final List<SearchListing> hostListings;

  factory ListingDetail.fromListing(
    SearchListing listing, {
    List<SearchListing> hostListings = const [],
    List<ListingReview> reviews = const [],
  }) {
    return ListingDetail(
      listing: listing,
      address: listing.address.isEmpty ? listing.city : listing.address,
      description: listing.description,
      photos: listing.photos.isNotEmpty ? listing.photos : [listing.photo],
      amenities: listing.amenities.isNotEmpty
          ? listing.amenities
          : listing.features.where(kAmenityIcons.containsKey).toList(),
      reviews: reviews.isNotEmpty ? reviews : listing.reviewsList,
      host: listing.host ?? fallbackHost(listing),
      hostListings: hostListings,
    );
  }
}

const kAmenityIcons = <String, IconData>{
  'Wifi': Icons.wifi,
  'Телевизор': Icons.tv_outlined,
  'Кондиционер': Icons.ac_unit,
  'Обогреватель': Icons.thermostat_outlined,
  'Фен': Icons.dry_outlined,
  'Утюг': Icons.iron_outlined,
  'Кухня': Icons.kitchen_outlined,
  'Стиральная машина': Icons.local_laundry_service_outlined,
  'Посуда': Icons.dinner_dining_outlined,
  'Завтраки': Icons.free_breakfast_outlined,
  'Бассейн': Icons.pool_outlined,
  'Камин': Icons.fireplace_outlined,
  'Разрешено курение': Icons.smoking_rooms_outlined,
  'Спортзал': Icons.fitness_center,
  'Самостоятельное заселение': Icons.key_outlined,
  'Сауна': Icons.hot_tub_outlined,
  'Парковка': Icons.local_parking_outlined,
};

ListingHost fallbackHost(SearchListing listing) {
  return ListingHost(
    id: listing.hostId.isEmpty ? listing.id : listing.hostId,
    name: 'Хозяин',
    rating: listing.rating,
    reviewCount: listing.reviewCount,
    years: 0,
  );
}
