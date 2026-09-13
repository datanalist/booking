import 'package:flutter/material.dart';

import '../search/search_listing.dart';

class ListingReview {
  const ListingReview({
    required this.author,
    required this.postedAgo,
    required this.stars,
    required this.text,
  });

  final String author;
  final String postedAgo;
  final int stars;
  final String text;
}

class ListingHost {
  const ListingHost({
    required this.id,
    required this.name,
    required this.rating,
    required this.reviewCount,
    required this.years,
    this.verified = true,
  });

  final String id;
  final String name;
  final String rating;
  final int reviewCount;
  final int years;
  final bool verified;
}

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

  factory ListingDetail.resolve(SearchListing listing) {
    final extras = kListingExtras[listing.id];
    final hostId = extras?.hostId ?? listing.id;
    final host = kListingHosts[hostId] ?? _fallbackHost(listing);
    final photos = [
      if (extras != null && extras.photos.isNotEmpty)
        ...extras.photos
      else
        listing.photo,
    ];
    final amenities =
        extras?.amenities ??
        listing.features.where(kAmenityIcons.containsKey).toList();
    final hostListings = [
      for (final item in kSearchListings)
        if (item.id != listing.id && kListingExtras[item.id]?.hostId == hostId)
          item,
    ];

    return ListingDetail(
      listing: listing,
      address: extras?.address ?? listing.city,
      description: extras?.description ?? 'Комфортное жилье для вашей поездки. Подробности появятся после подключения базы данных.',
      photos: photos,
      amenities: amenities,
      reviews: extras?.reviews ?? const [],
      host: host,
      hostListings: hostListings,
    );
  }
}

class _ListingExtras {
  const _ListingExtras({
    required this.address,
    required this.description,
    required this.hostId,
    this.photos = const [],
    this.amenities = const [],
    this.reviews = const [],
  });

  final String address;
  final String description;
  final String hostId;
  final List<String> photos;
  final List<String> amenities;
  final List<ListingReview> reviews;
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

const kListingHosts = <String, ListingHost>{
  'anna': ListingHost(
    id: 'anna',
    name: 'Анна Иваненко',
    rating: '4.9',
    reviewCount: 68,
    years: 4,
  ),
  'rail': ListingHost(
    id: 'rail',
    name: 'Раиль Сафин',
    rating: '4.8',
    reviewCount: 21,
    years: 2,
  ),
  'marina': ListingHost(
    id: 'marina',
    name: 'Марина Орлова',
    rating: '4.6',
    reviewCount: 8,
    years: 1,
  ),
};

const kListingExtras = <String, _ListingExtras>{
  'studio-msk': _ListingExtras(
    address: 'Москва, ул. Невская 48',
    description: 'Современное и комфортное жилье в шаговой доступности от главных достопримечательностей города. В студии есть двуспальная кровать, зона отдыха с диваном, кухня с необходимой техникой и ванная комната. Высокоскоростной Wi-Fi и круглосуточное заселение сделают ваше пребывание удобным и приятным.',
    hostId: 'anna',
    photos: [
      'images/search/studio-moscow.png',
      'images/chat/studio-moscow.jpg',
      'images/onbordins.v1/01-find-housing.png',
      'images/search/old-town.png',
    ],
    amenities: [
      'Wifi',
      'Телевизор',
      'Кондиционер',
      'Фен',
      'Утюг',
      'Кухня',
      'Стиральная машина',
      'Посуда',
    ],
    reviews: [
      ListingReview(
        author: 'Антон Киривлянов',
        postedAgo: '3 дня назад',
        stars: 5,
        text: 'Отличное жилье, полностью доволен проведенным здесь временем, еще вернусь!',
      ),
      ListingReview(
        author: 'Ирина Куленкова',
        postedAgo: 'неделю назад',
        stars: 4,
        text: 'В целом всё хорошо! Но были нюансы из-за которых 5 звезд ставить не хочется.',
      ),
    ],
  ),
  'old-town': _ListingExtras(
    address: 'Москва, ул. Пятницкая 12',
    description: 'Квартира в историческом центре: высокие потолки, тихий двор и всё нужное для короткой поездки. Рядом кафе, метро и прогулочные улицы.',
    hostId: 'anna',
    photos: [
      'images/search/old-town.png',
      'images/search/studio-moscow.png',
      'images/onbordins.v1/02-book-confidently.png',
    ],
    amenities: [
      'Wifi',
      'Телевизор',
      'Кухня',
      'Стиральная машина',
      'Посуда',
      'Парковка',
    ],
    reviews: [
      ListingReview(
        author: 'Павел Смирнов',
        postedAgo: '5 дней назад',
        stars: 5,
        text:
            'Удобное расположение и чистота. Заселили быстро, всё как на фото.',
      ),
      ListingReview(
        author: 'Елена Юрченко',
        postedAgo: '2 недели назад',
        stars: 4,
        text: 'Хорошая квартира, немного шумно с улицы по вечерам.',
      ),
    ],
  ),
  'house-10km': _ListingExtras(
    address: 'Москва, деревня Дубровки 5',
    description: 'Частный дом за городом: сад, мангал и тишина. Подходит для семьи или компании, которая хочет отдохнуть рядом с Москвой.',
    hostId: 'anna',
    photos: [
      'images/search/country-house.png',
      'images/onbordins.v1/03-travel-without-borders.png',
      'images/search/studio-moscow.png',
    ],
    amenities: ['Wifi', 'Кухня', 'Камин', 'Парковка', 'Бассейн', 'Сауна'],
    reviews: [
      ListingReview(
        author: 'Дмитрий Козлов',
        postedAgo: 'неделю назад',
        stars: 5,
        text:
            'Дом тёплый, участок ухоженный. Дети были в восторге от площадки.',
      ),
    ],
  ),
  'kazan-loft': _ListingExtras(
    address: 'Казань, ул. Баумана 15',
    description: 'Светлый лофт в пешей доступности от кремля. Высокие окна, рабочее место и кухня, если захотите готовить сами.',
    hostId: 'rail',
    photos: [
      'images/search/kazan-loft.png',
      'images/chat/minsk-loft.jpg',
      'images/onbordins.v1/01-find-housing.png',
    ],
    amenities: [
      'Wifi',
      'Телевизор',
      'Кондиционер',
      'Кухня',
      'Завтраки',
      'Спортзал',
    ],
    reviews: [
      ListingReview(
        author: 'Алина Нуриева',
        postedAgo: '4 дня назад',
        stars: 5,
        text: 'Стильный интерьер и очень удобно гулять по центру.',
      ),
    ],
  ),
  'spb-room': _ListingExtras(
    address: 'Санкт-Петербург, Невский проспект 28',
    description: 'Отдельная комната в квартире у Невского. Рядом метро, магазины и основные маршруты по центру.',
    hostId: 'marina',
    photos: [
      'images/search/spb-room.png',
      'images/chat/minsk-flat.jpg',
      'images/onbordins.v1/02-book-confidently.png',
    ],
    amenities: ['Wifi', 'Фен', 'Утюг'],
    reviews: [
      ListingReview(
        author: 'Олег Петров',
        postedAgo: '8 дней назад',
        stars: 4,
        text: 'Комната аккуратная, хозяева общительные. Для короткой поездки нормально.',
      ),
    ],
  ),
};

ListingHost _fallbackHost(SearchListing listing) {
  return ListingHost(
    id: listing.id,
    name: 'Владелец',
    rating: listing.rating,
    reviewCount: reviewCountFromLabel(listing.reviews),
    years: 1,
    verified: false,
  );
}

int reviewCountFromLabel(String reviews) {
  final match = RegExp(r'\d+').firstMatch(reviews);
  if (match == null) return 0;
  return int.parse(match.group(0)!);
}

String reviewCountLabel(int count) {
  return '($count ${_plural(count, one: 'отзыв', few: 'отзыва', many: 'отзывов')})';
}

String yearsHostingLabel(int years) {
  return '$years ${_plural(years, one: 'год', few: 'года', many: 'лет')} сдает жилье';
}

String _plural(
  int count, {
  required String one,
  required String few,
  required String many,
}) {
  final n = count % 100;
  final n1 = count % 10;
  if (n >= 11 && n <= 14) return many;
  if (n1 == 1) return one;
  if (n1 >= 2 && n1 <= 4) return few;
  return many;
}
