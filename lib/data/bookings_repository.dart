import 'package:pocketbase/pocketbase.dart';

import '../screens/search/search_listing.dart';
import 'auth_repository.dart';
import 'booking.dart';
import 'pocketbase_client.dart';

abstract class BookingsRepository {
  Future<List<Booking>> fetchMine();

  Future<Booking> create({
    required SearchListing listing,
    required DateTime checkIn,
    required DateTime checkOut,
    int adults = 1,
    int children = 0,
    int pets = 0,
    String guestNote = '',
  });
}

class BookingsRepositoryScope {
  static BookingsRepository instance = PocketBaseBookingsRepository();
}

class PocketBaseBookingsRepository implements BookingsRepository {
  PocketBaseBookingsRepository({PocketBase? client}) : _client = client;

  static const collection = 'bookings';
  static const _expand = 'listing';
  static const occupyingStatuses = [
    'pending_host',
    'awaiting_prepayment',
    'confirmed',
    'change_requested',
    'cancel_requested',
  ];

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
    final escaped = _escape(userId);
    final records = await _pb.collection(collection).getFullList(
      filter: 'guest = "$escaped" || host = "$escaped"',
      expand: _expand,
      sort: '-created',
    );
    return [for (final record in records) _map(record)];
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
      throw const BookingException('На эти даты жилье уже занято');
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
      return _map(record);
    } on ClientException catch (error) {
      throw BookingException(_messageFor(error));
    }
  }

  Future<bool> _hasOverlap(
    String listingId,
    DateTime checkIn,
    DateTime checkOut,
  ) async {
    final listing = _escape(listingId);
    final start = _dateValue(checkIn);
    final end = _dateValue(checkOut);
    final statuses = occupyingStatuses
        .map((status) => 'status = "$status"')
        .join(' || ');
    final result = await _pb.collection(collection).getList(
      page: 1,
      perPage: 1,
      filter:
          'listing = "$listing" && ($statuses) && '
          'check_in < "$end" && check_out > "$start"',
    );
    return result.totalItems > 0;
  }

  Booking _map(RecordModel record) {
    final listing = _expanded(record, 'listing');
    final photos = listing == null
        ? const <String>[]
        : _fileUrls(listing, 'photos');
    final checkIn = _date(record, 'check_in') ?? DateTime.fromMillisecondsSinceEpoch(0);
    final checkOut = _date(record, 'check_out') ?? checkIn;
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
    );
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

  String _escape(String value) => value.replaceAll('"', '');

  String _messageFor(ClientException error) {
    final response = error.response;
    final message = response['message'];
    if (message is String && message.isNotEmpty) return message;
    return 'Не удалось сохранить бронирование';
  }
}
