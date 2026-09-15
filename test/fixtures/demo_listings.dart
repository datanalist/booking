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

  @override
  Future<List<SearchListing>> fetchPublished() async => items;

  @override
  Future<ListingDetail> fetchDetail(SearchListing listing) async {
    return ListingDetail.fromListing(
      listing,
      hostListings: [
        for (final item in items)
          if (item.id != listing.id && item.hostId == listing.hostId) item,
      ],
    );
  }
}
