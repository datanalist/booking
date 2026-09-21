import 'package:booking/data/listings_repository.dart';
import 'package:booking/screens/listing/listing_detail.dart';
import 'package:booking/screens/search/search_listing.dart';

const kAnna = ListingHost(
  id: 'anna',
  name: 'Анна Иваненко',
  rating: '4.9',
  reviewCount: 68,
  years: 4,
  verified: true,
);

const kRail = ListingHost(
  id: 'rail',
  name: 'Раиль Сафин',
  rating: '4.8',
  reviewCount: 21,
  years: 2,
  verified: true,
);

const kMarina = ListingHost(
  id: 'marina',
  name: 'Марина Орлова',
  rating: '4.6',
  reviewCount: 8,
  years: 1,
  verified: true,
);

SearchListing _stay({
  required String id,
  required String title,
  required String city,
  required String type,
  required String address,
  required String description,
  required String rating,
  required int reviews,
  required String photo,
  required int imageIndex,
  required double latitude,
  required double longitude,
  required int pricePerNight,
  required ListingHost host,
  required Set<String> features,
  List<String> photos = const [],
  List<ListingReview> reviewsList = const [],
  String houseRules = '',
  String checkInTime = '',
  String checkOutTime = '',
  String accessInfo = '',
  bool cancellationAllowed = false,
}) {
  return SearchListing(
    id: id,
    title: title,
    city: city,
    type: type,
    address: address,
    description: description,
    dates: '',
    nights: '',
    total: '',
    perNight: '',
    rating: rating,
    reviews: reviewCountLabel(reviews),
    photo: photo,
    photos: photos.isEmpty ? [photo] : photos,
    imageIndex: imageIndex,
    latitude: latitude,
    longitude: longitude,
    pricePerNight: pricePerNight,
    price14: pricePerNight,
    price28: pricePerNight,
    maxGuests: 4,
    petsAllowed: true,
    hostId: host.id,
    host: host,
    features: features,
    amenities: features.where((item) => item != 'Парковка' && item != 'Бассейн' && item != 'Сауна' && item != 'Камин' && item != 'Завтраки' && item != 'Спортзал' && item != 'Самостоятельное заселение').toList(),
    reviewsList: reviewsList,
    houseRules: houseRules,
    checkInTime: checkInTime,
    checkOutTime: checkOutTime,
    accessInfo: accessInfo,
    cancellationAllowed: cancellationAllowed,
  ).withStay();
}

final kDemoListings = <SearchListing>[
  _stay(
    id: 'studio-msk',
    title: 'Уютная студия в центре Москвы',
    city: 'Москва',
    type: 'Квартира',
    address: 'Москва, ул. Невская 48',
    description:
        'Современное и комфортное жилье в шаговой доступности от главных достопримечательностей города.',
    rating: '4.5',
    reviews: 13,
    photo: 'images/search/studio-moscow.png',
    photos: [
      'images/search/studio-moscow.png',
      'images/chat/studio-moscow.jpg',
      'images/onbordins.v1/01-find-housing.png',
      'images/search/old-town.png',
    ],
    imageIndex: 0,
    latitude: 55.7584,
    longitude: 37.6018,
    pricePerNight: 3034,
    host: kAnna,
    features: {
      'Wifi',
      'Телевизор',
      'Кондиционер',
      'Фен',
      'Утюг',
      'Кухня',
      'Стиральная машина',
      'Посуда',
      'Самостоятельное заселение',
    },
    reviewsList: const [
      ListingReview(
        author: 'Антон Киривлянов',
        postedAgo: '3 дня назад',
        stars: 5,
        text:
            'Отличное жилье, полностью доволен проведенным здесь временем, еще вернусь!',
      ),
      ListingReview(
        author: 'Ирина Куленкова',
        postedAgo: 'неделю назад',
        stars: 4,
        text:
            'В целом всё хорошо! Но были нюансы из-за которых 5 звезд ставить не хочется.',
      ),
    ],
    houseRules:
        'Максимум 4 гостя\nНе включать громко музыку или телевизор после 22:00\nНе курить\nНельзя с животными',
    checkInTime: '14:00',
    checkOutTime: '12:00',
    accessInfo:
        'Введите код домофона 3486\nПоднимитесь на 4 этаж\nВведите код на двери 846395',
    cancellationAllowed: false,
  ),
  _stay(
    id: 'old-town',
    title: 'Квартира в старом городе',
    city: 'Москва',
    type: 'Квартира',
    address: 'Москва, ул. Пятницкая 12',
    description: 'Квартира в историческом центре.',
    rating: '4.7',
    reviews: 29,
    photo: 'images/search/old-town.png',
    imageIndex: 1,
    latitude: 55.7536,
    longitude: 37.6232,
    pricePerNight: 3034,
    host: kAnna,
    features: {
      'Wifi',
      'Телевизор',
      'Кухня',
      'Стиральная машина',
      'Посуда',
      'Парковка',
    },
  ),
  _stay(
    id: 'house-10km',
    title: 'Частный дом в 10 км от Москвы',
    city: 'Москва',
    type: 'Дом',
    address: 'Москва, деревня Дубровки 5',
    description: 'Частный дом за городом.',
    rating: '4.5',
    reviews: 13,
    photo: 'images/search/country-house.png',
    imageIndex: 2,
    latitude: 55.7468,
    longitude: 37.6114,
    pricePerNight: 3294,
    host: kAnna,
    features: {'Wifi', 'Кухня', 'Камин', 'Парковка', 'Бассейн', 'Сауна'},
  ),
  _stay(
    id: 'kazan-loft',
    title: 'Лофт у Казанского кремля',
    city: 'Казань',
    type: 'Квартира',
    address: 'Казань, ул. Баумана 15',
    description: 'Светлый лофт у кремля.',
    rating: '4.8',
    reviews: 21,
    photo: 'images/search/kazan-loft.png',
    imageIndex: 1,
    latitude: 55.7963,
    longitude: 49.1089,
    pricePerNight: 3100,
    host: kRail,
    features: {
      'Wifi',
      'Телевизор',
      'Кондиционер',
      'Кухня',
      'Завтраки',
      'Спортзал',
    },
  ),
  _stay(
    id: 'spb-room',
    title: 'Комната у Невского проспекта',
    city: 'Санкт-Петербург',
    type: 'Комната',
    address: 'Санкт-Петербург, Невский проспект 28',
    description: 'Комната у Невского.',
    rating: '4.3',
    reviews: 8,
    photo: 'images/search/spb-room.png',
    imageIndex: 0,
    latitude: 59.9343,
    longitude: 30.3351,
    pricePerNight: 2300,
    host: kMarina,
    features: {'Wifi', 'Фен', 'Утюг'},
  ),
];

class FakeListingsRepository implements ListingsRepository {
  FakeListingsRepository([List<SearchListing>? items])
    : items = items ?? kDemoListings;

  final List<SearchListing> items;
  final occupiedStays = <String, List<(DateTime, DateTime)>>{};
  final occupiedByBooking = <String, List<(DateTime, DateTime)>>{};

  @override
  Future<List<SearchListing>> fetchPublished({
    DateTime? checkIn,
    DateTime? checkOut,
  }) async {
    if (checkIn == null || checkOut == null || !checkOut.isAfter(checkIn)) {
      return items;
    }
    return [
      for (final item in items)
        if (!_occupied(item.id, checkIn, checkOut)) item,
    ];
  }

  bool _occupied(String listingId, DateTime checkIn, DateTime checkOut) {
    final ranges = occupiedStays[listingId];
    if (ranges == null) return false;
    for (final range in ranges) {
      if (stayRangeOverlaps(
        occupiedStart: range.$1,
        occupiedEnd: range.$2,
        requestedCheckIn: checkIn,
        requestedCheckOut: checkOut,
      )) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<List<OccupiedStayRange>> fetchOccupiedDates({
    required String listingId,
    String? excludeBookingId,
  }) async {
    var ranges = occupiedStays[listingId] ?? const <(DateTime, DateTime)>[];
    final exclude = excludeBookingId?.trim() ?? '';
    if (exclude.isNotEmpty) {
      final own = occupiedByBooking[exclude];
      if (own != null) {
        ranges = [
          for (final range in ranges)
            if (!own.any((item) => item.$1 == range.$1 && item.$2 == range.$2))
              range,
        ];
      }
    }
    return [
      for (final range in ranges)
        OccupiedStayRange(start: range.$1, end: range.$2),
    ];
  }

  @override
  Future<ListingDetail> fetchDetail(SearchListing listing) async {
    final matches = items.where((item) => item.id == listing.id);
    final resolved = matches.isEmpty ? listing : matches.first;
    return ListingDetail.fromListing(
      resolved,
      hostListings: [
        for (final item in items)
          if (item.id != resolved.id && item.hostId == resolved.hostId) item,
      ],
    );
  }
}
