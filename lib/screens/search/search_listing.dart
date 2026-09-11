class SearchListing {
  const SearchListing({
    required this.id,
    required this.title,
    required this.city,
    required this.type,
    required this.dates,
    required this.nights,
    required this.total,
    required this.perNight,
    required this.rating,
    required this.reviews,
    required this.photo,
    required this.imageIndex,
    required this.latitude,
    required this.longitude,
    required this.pricePerNight,
    this.features = const {},
  });

  final String id;
  final String title;
  final String city;
  final String type;
  final String dates;
  final String nights;
  final String total;
  final String perNight;
  final String rating;
  final String reviews;
  final String photo;
  final int imageIndex;
  final double latitude;
  final double longitude;
  final int pricePerNight;
  final Set<String> features;
}

const kSearchListings = <SearchListing>[
  SearchListing(
    id: 'studio-msk',
    title: 'Уютная студия в центре Москвы',
    city: 'Москва',
    type: 'Квартира',
    dates: '14-19 ноября',
    nights: '5 ночей',
    total: '15 170 ₽',
    perNight: '3 034 ₽ / ночь',
    rating: '4.5',
    reviews: '(13)',
    photo: 'images/search/studio-moscow.png',
    imageIndex: 0,
    latitude: 55.7584,
    longitude: 37.6018,
    pricePerNight: 3034,
    features: {
      'Wifi',
      'Телевизор',
      'Кондиционер',
      'Кухня',
      'Посуда',
      'Самостоятельное заселение',
    },
  ),
  SearchListing(
    id: 'old-town',
    title: 'Квартира в старом городе',
    city: 'Москва',
    type: 'Квартира',
    dates: '14-19 ноября',
    nights: '5 ночей',
    total: '15 170 ₽',
    perNight: '3 034 ₽ / ночь',
    rating: '4.7',
    reviews: '(29)',
    photo: 'images/search/old-town.png',
    imageIndex: 1,
    latitude: 55.7536,
    longitude: 37.6232,
    pricePerNight: 3034,
    features: {
      'Wifi',
      'Телевизор',
      'Кухня',
      'Стиральная машина',
      'Посуда',
      'Парковка',
    },
  ),
  SearchListing(
    id: 'house-10km',
    title: 'Частный дом в 10 км от Москвы',
    city: 'Москва',
    type: 'Дом',
    dates: '14-19 ноября',
    nights: '5 ночей',
    total: '16 470 ₽',
    perNight: '3 294 ₽ / ночь',
    rating: '4.5',
    reviews: '(13)',
    photo: 'images/search/country-house.png',
    imageIndex: 2,
    latitude: 55.7468,
    longitude: 37.6114,
    pricePerNight: 3294,
    features: {
      'Wifi',
      'Кухня',
      'Камин',
      'Парковка',
      'Бассейн',
      'Сауна',
    },
  ),
  SearchListing(
    id: 'kazan-loft',
    title: 'Лофт у Казанского кремля',
    city: 'Казань',
    type: 'Квартира',
    dates: '2-6 декабря',
    nights: '4 ночи',
    total: '12 400 ₽',
    perNight: '3 100 ₽ / ночь',
    rating: '4.8',
    reviews: '(21)',
    photo: 'images/search/kazan-loft.png',
    imageIndex: 1,
    latitude: 55.7963,
    longitude: 49.1089,
    pricePerNight: 3100,
    features: {
      'Wifi',
      'Телевизор',
      'Кондиционер',
      'Кухня',
      'Завтраки',
      'Спортзал',
    },
  ),
  SearchListing(
    id: 'spb-room',
    title: 'Комната у Невского проспекта',
    city: 'Санкт-Петербург',
    type: 'Комната',
    dates: '8-12 января',
    nights: '4 ночи',
    total: '9 200 ₽',
    perNight: '2 300 ₽ / ночь',
    rating: '4.3',
    reviews: '(8)',
    photo: 'images/search/spb-room.png',
    imageIndex: 0,
    latitude: 59.9343,
    longitude: 30.3351,
    pricePerNight: 2300,
    features: {'Wifi', 'Фен', 'Утюг'},
  ),
];
