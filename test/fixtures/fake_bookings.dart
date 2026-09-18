import 'package:booking/data/booking.dart';
import 'package:booking/data/bookings_repository.dart';
import 'package:booking/screens/search/search_listing.dart';

class FakeBookingsRepository implements BookingsRepository {
  FakeBookingsRepository([List<Booking>? items])
    : items = List<Booking>.from(items ?? const []);

  final List<Booking> items;
  final created = <Booking>[];
  Object? failCreateWith;

  @override
  Future<List<Booking>> fetchMine() async => List<Booking>.from(items);

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
    if (failCreateWith != null) {
      final error = failCreateWith!;
      failCreateWith = null;
      throw error;
    }
    final money = BookingMoney.fromStay(
      quoteStay(
        pricePerNight: listing.pricePerNight,
        price14: listing.price14,
        price28: listing.price28,
        nights: stayNightsBetween(checkIn, checkOut),
      ),
    );
    final booking = Booking(
      id: 'booking-${created.length + 1}',
      listingId: listing.id,
      guestId: 'guest',
      hostId: listing.hostId,
      checkIn: checkIn,
      checkOut: checkOut,
      status: BookingStatus.pendingHost,
      adults: adults < 1 ? 1 : adults,
      children: children,
      pets: pets,
      guestNote: guestNote,
      total: money.total,
      prepay: money.prepay,
      remainder: money.remainder,
      commission: money.commission,
      hostAmount: money.hostAmount,
      title: listing.title,
      photo: listing.photo,
    );
    created.add(booking);
    items.add(booking);
    BookingsRepositoryScope.notifyChanged();
    return booking;
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
  }) async {
    final index = items.indexWhere((item) => item.id == id);
    if (index < 0) {
      throw const BookingException('Бронирование не найдено');
    }
    final next = items[index].copyWith(
      status: status,
      cancelReason: cancelReason,
      requestedCheckIn: requestedCheckIn,
      requestedCheckOut: requestedCheckOut,
      adults: adults,
      children: children,
      pets: pets,
    );
    items[index] = next;
    BookingsRepositoryScope.notifyChanged();
    return next;
  }
}
