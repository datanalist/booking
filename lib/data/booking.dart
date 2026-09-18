import '../screens/search/search_listing.dart';

enum BookingStatus {
  pendingHost('pending_host'),
  awaitingPrepayment('awaiting_prepayment'),
  confirmed('confirmed'),
  completed('completed'),
  cancelRequested('cancel_requested'),
  changeRequested('change_requested'),
  cancelled('cancelled');

  const BookingStatus(this.apiKey);

  final String apiKey;

  bool get isPast =>
      this == BookingStatus.completed ||
      this == BookingStatus.cancelled ||
      this == BookingStatus.cancelRequested;

  static BookingStatus fromApi(String value) {
    for (final status in BookingStatus.values) {
      if (status.apiKey == value) return status;
    }
    return BookingStatus.pendingHost;
  }
}

enum BookingCancelReason {
  guest('guest'),
  host('host'),
  hostTimeout('host_timeout'),
  prepayTimeout('prepay_timeout');

  const BookingCancelReason(this.apiKey);

  final String apiKey;

  static BookingCancelReason? fromApi(String value) {
    if (value.isEmpty) return null;
    for (final reason in BookingCancelReason.values) {
      if (reason.apiKey == value) return reason;
    }
    return null;
  }
}

class Booking {
  const Booking({
    required this.id,
    required this.listingId,
    required this.guestId,
    required this.hostId,
    required this.checkIn,
    required this.checkOut,
    required this.status,
    this.adults = 0,
    this.children = 0,
    this.pets = 0,
    this.guestNote = '',
    this.total = 0,
    this.prepay = 0,
    this.remainder = 0,
    this.commission = 0,
    this.hostAmount = 0,
    this.prepaidAt,
    this.cancelReason,
    this.hostRespondUntil,
    this.prepayUntil,
    this.requestedCheckIn,
    this.requestedCheckOut,
    this.title = '',
    this.photo = '',
    this.address = '',
    this.city = '',
    this.latitude = 0,
    this.longitude = 0,
    this.hostName = '',
    this.hostAvatar = '',
  });

  final String id;
  final String listingId;
  final String guestId;
  final String hostId;
  final DateTime checkIn;
  final DateTime checkOut;
  final BookingStatus status;
  final int adults;
  final int children;
  final int pets;
  final String guestNote;
  final int total;
  final int prepay;
  final int remainder;
  final int commission;
  final int hostAmount;
  final DateTime? prepaidAt;
  final BookingCancelReason? cancelReason;
  final DateTime? hostRespondUntil;
  final DateTime? prepayUntil;
  final DateTime? requestedCheckIn;
  final DateTime? requestedCheckOut;
  final String title;
  final String photo;
  final String address;
  final String city;
  final double latitude;
  final double longitude;
  final String hostName;
  final String hostAvatar;

  String get addressLabel {
    if (address.isNotEmpty) return address;
    return city;
  }

  Booking copyWith({
    String? id,
    String? listingId,
    String? guestId,
    String? hostId,
    DateTime? checkIn,
    DateTime? checkOut,
    BookingStatus? status,
    int? adults,
    int? children,
    int? pets,
    String? guestNote,
    int? total,
    int? prepay,
    int? remainder,
    int? commission,
    int? hostAmount,
    DateTime? prepaidAt,
    BookingCancelReason? cancelReason,
    DateTime? hostRespondUntil,
    DateTime? prepayUntil,
    DateTime? requestedCheckIn,
    DateTime? requestedCheckOut,
    String? title,
    String? photo,
    String? address,
    String? city,
    double? latitude,
    double? longitude,
    String? hostName,
    String? hostAvatar,
  }) {
    return Booking(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      guestId: guestId ?? this.guestId,
      hostId: hostId ?? this.hostId,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      status: status ?? this.status,
      adults: adults ?? this.adults,
      children: children ?? this.children,
      pets: pets ?? this.pets,
      guestNote: guestNote ?? this.guestNote,
      total: total ?? this.total,
      prepay: prepay ?? this.prepay,
      remainder: remainder ?? this.remainder,
      commission: commission ?? this.commission,
      hostAmount: hostAmount ?? this.hostAmount,
      prepaidAt: prepaidAt ?? this.prepaidAt,
      cancelReason: cancelReason ?? this.cancelReason,
      hostRespondUntil: hostRespondUntil ?? this.hostRespondUntil,
      prepayUntil: prepayUntil ?? this.prepayUntil,
      requestedCheckIn: requestedCheckIn ?? this.requestedCheckIn,
      requestedCheckOut: requestedCheckOut ?? this.requestedCheckOut,
      title: title ?? this.title,
      photo: photo ?? this.photo,
      address: address ?? this.address,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      hostName: hostName ?? this.hostName,
      hostAvatar: hostAvatar ?? this.hostAvatar,
    );
  }

  /// Даты карточки «Брони» (Figma `1:11949`): `14.11.2024 - 19.11.2024`.
  String get datesLabel {
    String two(int value) => value.toString().padLeft(2, '0');
    String format(DateTime date) =>
        '${two(date.day)}.${two(date.month)}.${date.year}';
    return '${format(checkIn)} - ${format(checkOut)}';
  }

  String get guestsLabel {
    final count = adults + children;
    if (count <= 0) return '1 гость';
    return '$count ${_pluralGuests(count)}';
  }
}

String _pluralGuests(int count) {
  final n = count % 100;
  final n1 = count % 10;
  if (n >= 11 && n <= 14) return 'гостей';
  if (n1 == 1) return 'гость';
  if (n1 >= 2 && n1 <= 4) return 'гостя';
  return 'гостей';
}

class BookingMoney {
  const BookingMoney({
    required this.total,
    required this.prepay,
    required this.remainder,
    required this.commission,
    required this.hostAmount,
  });

  /// Комиссия сервиса, пока нет отдельной коллекции настроек.
  static const rate = 0.15;

  final int total;
  final int prepay;
  final int remainder;
  final int commission;
  final int hostAmount;

  factory BookingMoney.fromStay(StayQuote stay) {
    final total = stay.total;
    final commission = (total * rate).round();
    final hostAmount = total - commission;
    return BookingMoney(
      total: total,
      prepay: commission,
      remainder: hostAmount,
      commission: commission,
      hostAmount: hostAmount,
    );
  }
}

class BookingException implements Exception {
  const BookingException(this.message);

  final String message;

  @override
  String toString() => message;
}
