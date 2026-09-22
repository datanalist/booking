import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

import '../screens/search/search_listing.dart';
import 'auth_repository.dart';
import 'booking.dart';
import 'listings_repository.dart';
import 'pocketbase_client.dart';
import 'pocketbase_filter.dart';

abstract class BookingsRepository {
  Future<List<Booking>> fetchMine();

  /// Неотменённая бронь текущего гостя на объявление — ключ к чату с хозяином.
  Future<Booking?> findHostChatEligible({required String listingId});

  Future<Booking> create({
    required SearchListing listing,
    required DateTime checkIn,
    required DateTime checkOut,
    int adults = 1,
    int children = 0,
    int pets = 0,
    String guestNote = '',
  });

  Future<Booking> patch({
    required String id,
    BookingStatus? status,
    BookingCancelReason? cancelReason,
    DateTime? requestedCheckIn,
    DateTime? requestedCheckOut,
    int? adults,
    int? children,
    int? pets,
    int? total,
    int? prepay,
    int? remainder,
    int? commission,
    int? hostAmount,
  });
}

class BookingsRepositoryScope {
  static BookingsRepository instance = PocketBaseBookingsRepository();
  static final listVersion = ValueNotifier<int>(0);

  static void notifyChanged() {
    listVersion.value++;
  }
}

class PocketBaseBookingsRepository implements BookingsRepository {
  PocketBaseBookingsRepository({PocketBase? client}) : _client = client;

  static const collection = PbCollection.bookings;
  static const _expand = 'listing,host';

  final PocketBase? _client;
  PocketBase get _pb => _client ?? pocketBase;

  String get _userId {
    final session = AuthRepositoryScope.session.value;
    if (session != null && session.userId.isNotEmpty) return session.userId;
    return _pb.authStore.record?.id ?? '';
  }

  @override
  Future<List<Booking>> fetchMine() async {
    final userId = _userId;
    if (userId.isEmpty || !_pb.authStore.isValid) return const [];
    final records = await _pb.collection(collection).getFullList(
      filter: pbFilter(
        'guest = {:userId} || host = {:userId}',
        {'userId': userId},
      ),
      expand: _expand,
      sort: '-created',
    );
    return [for (final record in records) _map(record)];
  }

  @override
  Future<Booking?> findHostChatEligible({required String listingId}) async {
    final userId = _userId;
    if (userId.isEmpty || !_pb.authStore.isValid || listingId.isEmpty) {
      return null;
    }
    try {
      final records = await _pb.collection(collection).getList(
        page: 1,
        perPage: 1,
        filter: pbFilter(
          'guest = {:userId} && listing = {:listingId} && status != {:cancelled}',
          {
            'userId': userId,
            'listingId': listingId,
            'cancelled': BookingStatus.cancelled.apiKey,
          },
        ),
        expand: _expand,
        sort: '-created',
      );
      if (records.items.isEmpty) return null;
      return _map(records.items.first);
    } on ClientException {
      return null;
    }
  }

  @override
  Future<Booking> create({
    required SearchListing listing,
    required DateTime checkIn,
    required DateTime checkOut,
    int adults = 1,
    int children = 0,
    int pets = 0,
    String guestNote = '',
  }) async {
    final guestId = _userId;
    if (guestId.isEmpty) {
      throw const BookingException('Войдите, чтобы забронировать жилье');
    }
    if (listing.hostId.isEmpty) {
      throw const BookingException('Не удалось определить владельца жилья');
    }
    if (listing.hostId == guestId) {
      throw const BookingException('Нельзя забронировать своё объявление');
    }
    final nights = stayNightsBetween(checkIn, checkOut);
    if (nights <= 0) {
      throw const BookingException('Выберите даты заезда и выезда');
    }
    if (await _hasOverlap(listing.id, checkIn, checkOut)) {
      throw const BookingException('Извините, жилье уже забронировано');
    }

    final money = BookingMoney.fromStay(
      quoteStay(
        pricePerNight: listing.pricePerNight,
        price14: listing.price14,
        price28: listing.price28,
        nights: nights,
      ),
    );
    final until = DateTime.now().toUtc().add(const Duration(hours: 12));
    try {
      final record = await _pb.collection(collection).create(
        body: {
          'listing': listing.id,
          'guest': guestId,
          'host': listing.hostId,
          'check_in': _dateValue(checkIn),
          'check_out': _dateValue(checkOut),
          'adults': adults < 1 ? 1 : adults,
          'children': children < 0 ? 0 : children,
          'pets': pets < 0 ? 0 : pets,
          'guest_note': guestNote,
          'total': money.total,
          'prepay': money.prepay,
          'remainder': money.remainder,
          'commission': money.commission,
          'host_amount': money.hostAmount,
          'status': BookingStatus.pendingHost.apiKey,
          'host_respond_until': until.toIso8601String(),
        },
        expand: _expand,
      );
      final booking = _map(record);
      BookingsRepositoryScope.notifyChanged();
      return booking;
    } on ClientException catch (error) {
      throw BookingException(_messageFor(error));
    }
  }

  @override
  Future<Booking> patch({
    required String id,
    BookingStatus? status,
    BookingCancelReason? cancelReason,
    DateTime? requestedCheckIn,
    DateTime? requestedCheckOut,
    int? adults,
    int? children,
    int? pets,
    int? total,
    int? prepay,
    int? remainder,
    int? commission,
    int? hostAmount,
  }) async {
    final body = <String, dynamic>{};
    if (status != null) body['status'] = status.apiKey;
    if (cancelReason != null) body['cancel_reason'] = cancelReason.apiKey;
    if (requestedCheckIn != null) {
      body['requested_check_in'] = _dateValue(requestedCheckIn);
    }
    if (requestedCheckOut != null) {
      body['requested_check_out'] = _dateValue(requestedCheckOut);
    }
    if (adults != null) body['adults'] = adults < 1 ? 1 : adults;
    if (children != null) body['children'] = children < 0 ? 0 : children;
    if (pets != null) body['pets'] = pets < 0 ? 0 : pets;

    BookingMoney? money;
    if (total != null &&
        prepay != null &&
        remainder != null &&
        commission != null &&
        hostAmount != null) {
      money = BookingMoney(
        total: total,
        prepay: prepay,
        remainder: remainder,
        commission: commission,
        hostAmount: hostAmount,
      );
    } else if (requestedCheckIn != null || requestedCheckOut != null) {
      money = await _moneyForRequestedDates(
        id: id,
        requestedCheckIn: requestedCheckIn,
        requestedCheckOut: requestedCheckOut,
      );
    }
    if (money != null) {
      body['total'] = money.total;
      body['prepay'] = money.prepay;
      body['remainder'] = money.remainder;
      body['commission'] = money.commission;
      body['host_amount'] = money.hostAmount;
    }

    try {
      final record = await _pb.collection(collection).update(
        id,
        body: body,
        expand: _expand,
      );
      var booking = _map(record);
      // Если API не принял money/`requested_*`, всё равно отдаём гостю
      // то, что он отправил — карточка и деталка не должны молчать со старыми датами.
      booking = _withLocalChangeOverlay(
        booking,
        requestedCheckIn: requestedCheckIn,
        requestedCheckOut: requestedCheckOut,
        adults: adults,
        children: children,
        pets: pets,
        money: money,
      );
      BookingsRepositoryScope.notifyChanged();
      return booking;
    } on ClientException catch (error) {
      // Деньги могли быть отклонены правилами — повторяем без них.
      if (money == null) throw BookingException(_messageFor(error));
      try {
        final retryBody = Map<String, dynamic>.from(body)
          ..remove('total')
          ..remove('prepay')
          ..remove('remainder')
          ..remove('commission')
          ..remove('host_amount');
        final record = await _pb.collection(collection).update(
          id,
          body: retryBody,
          expand: _expand,
        );
        final booking = _withLocalChangeOverlay(
          _map(record),
          requestedCheckIn: requestedCheckIn,
          requestedCheckOut: requestedCheckOut,
          adults: adults,
          children: children,
          pets: pets,
          money: money,
        );
        BookingsRepositoryScope.notifyChanged();
        return booking;
      } on ClientException catch (retryError) {
        throw BookingException(_messageFor(retryError));
      }
    }
  }

  Future<BookingMoney?> _moneyForRequestedDates({
    required String id,
    DateTime? requestedCheckIn,
    DateTime? requestedCheckOut,
  }) async {
    try {
      final current = await _pb.collection(collection).getOne(
        id,
        expand: _expand,
      );
      final listing = _expanded(current, 'listing');
      if (listing == null) return null;
      final checkIn =
          requestedCheckIn ?? _date(current, 'check_in') ?? requestedCheckOut;
      final checkOut =
          requestedCheckOut ?? _date(current, 'check_out') ?? requestedCheckIn;
      if (checkIn == null || checkOut == null) return null;
      final nights = stayNightsBetween(checkIn, checkOut);
      if (nights <= 0) return null;
      return BookingMoney.fromStay(
        quoteStay(
          pricePerNight: _number(listing, 'price_night').round(),
          price14: _number(listing, 'price_14').round(),
          price28: _number(listing, 'price_28').round(),
          nights: nights,
        ),
      );
    } on ClientException {
      return null;
    }
  }

  Booking _withLocalChangeOverlay(
    Booking booking, {
    DateTime? requestedCheckIn,
    DateTime? requestedCheckOut,
    int? adults,
    int? children,
    int? pets,
    BookingMoney? money,
  }) {
    return booking.copyWith(
      requestedCheckIn: requestedCheckIn ?? booking.requestedCheckIn,
      requestedCheckOut: requestedCheckOut ?? booking.requestedCheckOut,
      adults: adults,
      children: children,
      pets: pets,
      total: money?.total,
      prepay: money?.prepay,
      remainder: money?.remainder,
      commission: money?.commission,
      hostAmount: money?.hostAmount,
    );
  }

  Future<bool> _hasOverlap(
    String listingId,
    DateTime checkIn,
    DateTime checkOut,
  ) async {
    // Гость не читает чужие bookings. Занятость приходит с хука.
    final ranges = await ListingsRepositoryScope.instance.fetchOccupiedDates(
      listingId: listingId,
    );
    return stayConflictsWithOccupied(
      checkIn: checkIn,
      checkOut: checkOut,
      ranges: ranges,
    );
  }

  Booking _map(RecordModel record) {
    final listing = _expanded(record, 'listing');
    final host = _expanded(record, 'host');
    final photos = listing == null
        ? const <String>[]
        : _fileUrls(listing, 'photos');
    final geo = listing == null ? (0.0, 0.0) : _geo(listing);
    final checkIn = _date(record, 'check_in') ?? DateTime.fromMillisecondsSinceEpoch(0);
    final checkOut = _date(record, 'check_out') ?? checkIn;
    final hostAvatarName = host?.get<String>('avatar', '') ?? '';
    return Booking(
      id: record.id,
      listingId: _relationId(record, 'listing'),
      guestId: _relationId(record, 'guest'),
      hostId: _relationId(record, 'host'),
      checkIn: checkIn,
      checkOut: checkOut,
      status: BookingStatus.fromApi(record.get<String>('status', '')),
      adults: _number(record, 'adults').round(),
      children: _number(record, 'children').round(),
      pets: _number(record, 'pets').round(),
      guestNote: record.get<String>('guest_note', ''),
      total: _number(record, 'total').round(),
      prepay: _number(record, 'prepay').round(),
      remainder: _number(record, 'remainder').round(),
      commission: _number(record, 'commission').round(),
      hostAmount: _number(record, 'host_amount').round(),
      prepaidAt: _date(record, 'prepaid_at'),
      cancelReason: BookingCancelReason.fromApi(
        record.get<String>('cancel_reason', ''),
      ),
      hostRespondUntil: _date(record, 'host_respond_until'),
      prepayUntil: _date(record, 'prepay_until'),
      requestedCheckIn: _date(record, 'requested_check_in'),
      requestedCheckOut: _date(record, 'requested_check_out'),
      title: listing?.get<String>('title', '') ?? '',
      photo: photos.isEmpty ? '' : photos.first,
      address: listing?.get<String>('address', '') ?? '',
      city: listing?.get<String>('city', '') ?? '',
      latitude: geo.$1,
      longitude: geo.$2,
      hostName: _hostName(host),
      hostAvatar: host == null || hostAvatarName.isEmpty
          ? ''
          : _pb.files.getURL(host, hostAvatarName).toString(),
    );
  }

  String _hostName(RecordModel? host) {
    if (host == null) return '';
    return listingHostDisplayName(
      firstName: host.get<String>('first_name', ''),
      lastName: host.get<String>('last_name', ''),
      name: host.get<String>('name', ''),
    );
  }

  (double, double) _geo(RecordModel record) {
    final raw = record.data['geo'];
    if (raw is Map) {
      final lat = raw['lat'] ?? raw['latitude'];
      final lon = raw['lon'] ?? raw['lng'] ?? raw['longitude'];
      return (
        lat is num ? lat.toDouble() : double.tryParse('$lat') ?? 0,
        lon is num ? lon.toDouble() : double.tryParse('$lon') ?? 0,
      );
    }
    return (0, 0);
  }

  RecordModel? _expanded(RecordModel record, String field) {
    final raw = record.data['expand'];
    if (raw is! Map) return null;
    final value = raw[field];
    if (value is Map<String, dynamic>) return RecordModel.fromJson(value);
    if (value is Map) {
      return RecordModel.fromJson(Map<String, dynamic>.from(value));
    }
    return null;
  }

  List<String> _fileUrls(RecordModel record, String field) {
    final raw = record.data[field];
    final names = <String>[];
    if (raw is List) {
      for (final item in raw) {
        if (item != null && '$item'.isNotEmpty) names.add('$item');
      }
    } else if (raw is String && raw.isNotEmpty) {
      names.add(raw);
    }
    return [
      for (final name in names) _pb.files.getURL(record, name).toString(),
    ];
  }

  String _relationId(RecordModel record, String field) {
    final expanded = _expanded(record, field);
    if (expanded != null) return expanded.id;
    return record.get<String>(field, '');
  }

  double _number(RecordModel record, String field) {
    final raw = record.data[field];
    if (raw is num) return raw.toDouble();
    return double.tryParse('$raw') ?? 0;
  }

  DateTime? _date(RecordModel record, String field) {
    final raw = record.data[field];
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }

  String _dateValue(DateTime date) {
    final utc = DateTime.utc(date.year, date.month, date.day);
    return utc.toIso8601String();
  }

  String _messageFor(ClientException error) {
    final response = error.response;
    final message = response['message'];
    if (message is String && message.isNotEmpty) return message;
    return 'Не удалось сохранить бронирование';
  }
}
