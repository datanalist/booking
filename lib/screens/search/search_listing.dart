import 'package:intl/intl.dart';

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
    this.verified = false,
    this.avatarUrl = '',
  });

  final String id;
  final String name;
  final String rating;
  final int reviewCount;
  final int years;
  final bool verified;
  final String avatarUrl;
}

class SearchListing {
  const SearchListing({
    required this.id,
    required this.title,
    required this.city,
    required this.type,
    required this.address,
    required this.description,
    required this.dates,
    required this.nights,
    required this.total,
    required this.perNight,
    required this.rating,
    required this.reviews,
    required this.photo,
    required this.photos,
    required this.imageIndex,
    required this.latitude,
    required this.longitude,
    required this.pricePerNight,
    this.price14 = 0,
    this.price28 = 0,
    this.maxGuests = 0,
    this.petsAllowed = false,
    this.hostId = '',
    this.host,
    this.features = const {},
    this.amenities = const [],
    this.reviewsList = const [],
  });

  final String id;
  final String title;
  final String city;
  final String type;
  final String address;
  final String description;
  final String dates;
  final String nights;
  final String total;
  final String perNight;
  final String rating;
  final String reviews;
  final String photo;
  final List<String> photos;
  final int imageIndex;
  final double latitude;
  final double longitude;
  final int pricePerNight;
  final int price14;
  final int price28;
  final int maxGuests;
  final bool petsAllowed;
  final String hostId;
  final ListingHost? host;
  final Set<String> features;
  final List<String> amenities;
  final List<ListingReview> reviewsList;

  int get reviewCount => reviewCountFromLabel(reviews);

  int unitPriceForNights(int nightCount) {
    if (nightCount >= 28 && price28 > 0) return price28;
    if (nightCount >= 14 && price14 > 0) return price14;
    return pricePerNight;
  }

  SearchListing withStay({DateTime? checkIn, DateTime? checkOut}) {
    final nightCount = (checkIn != null && checkOut != null)
        ? checkOut.difference(checkIn).inDays
        : 0;
    final nightsUsed = nightCount > 0 ? nightCount : 5;
    final unit = unitPriceForNights(nightsUsed);
    final stayTotal = unit * nightsUsed;
    return SearchListing(
      id: id,
      title: title,
      city: city,
      type: type,
      address: address,
      description: description,
      dates: nightCount > 0 ? stayDatesLabel(checkIn!, checkOut!) : '',
      nights: nightCount > 0 ? nightsLabel(nightCount) : '',
      total: formatRub(stayTotal),
      perNight: '${formatRub(unit)} / ночь',
      rating: rating,
      reviews: reviews,
      photo: photo,
      photos: photos,
      imageIndex: imageIndex,
      latitude: latitude,
      longitude: longitude,
      pricePerNight: pricePerNight,
      price14: price14,
      price28: price28,
      maxGuests: maxGuests,
      petsAllowed: petsAllowed,
      hostId: hostId,
      host: host,
      features: features,
      amenities: amenities,
      reviewsList: reviewsList,
    );
  }
}

String formatRub(num value) {
  final formatted = NumberFormat.decimalPattern('ru')
      .format(value.round())
      .replaceAll('\u00a0', ' ')
      .replaceAll('\u202f', ' ');
  return '$formatted ₽';
}

String stayDatesLabel(DateTime checkIn, DateTime checkOut) {
  final lastNight = checkOut.subtract(const Duration(days: 1));
  if (checkIn.month == lastNight.month && checkIn.year == lastNight.year) {
    final month = DateFormat('MMMM', 'ru').format(checkIn);
    return '${checkIn.day}–${lastNight.day} $month';
  }
  final start = DateFormat('d MMMM', 'ru').format(checkIn);
  final end = DateFormat('d MMMM', 'ru').format(lastNight);
  return '$start – $end';
}

String nightsLabel(int count) {
  return '$count ${_plural(count, one: 'ночь', few: 'ночи', many: 'ночей')}';
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
