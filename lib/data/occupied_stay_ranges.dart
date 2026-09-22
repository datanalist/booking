import 'booking.dart';
import 'bookings_repository.dart';
import 'listings_repository.dart';

/// Занятые ночи жилья: ответ `occupied-dates` плюс свои предстоящие брони.
///
/// Свои `requested_*` нужны сразу: хук может ещё отдавать только
/// подтверждённые `check_in` / `check_out`, а карточка «Брони» уже
/// показывает запрошенные даты.
Future<List<OccupiedStayRange>> loadOccupiedStayRanges({
  required ListingsRepository listings,
  required BookingsRepository bookings,
  required String listingId,
  String? excludeBookingId,
}) async {
  final remoteFuture = listings.fetchOccupiedDates(
    listingId: listingId,
    excludeBookingId: excludeBookingId,
  );
  final mineFuture = bookings.fetchMine();
  final remote = await remoteFuture;
  List<Booking> mine = const [];
  try {
    mine = await mineFuture;
  } catch (_) {
    mine = const [];
  }
  return mergeOccupiedStayRanges(
    remote: remote,
    mine: mine,
    listingId: listingId,
    excludeBookingId: excludeBookingId,
  );
}

List<OccupiedStayRange> mergeOccupiedStayRanges({
  required List<OccupiedStayRange> remote,
  required Iterable<Booking> mine,
  required String listingId,
  String? excludeBookingId,
}) {
  final id = listingId.trim();
  final exclude = excludeBookingId?.trim() ?? '';
  final ranges = List<OccupiedStayRange>.of(remote);
  for (final booking in mine) {
    if (booking.listingId != id) continue;
    if (exclude.isNotEmpty && booking.id == exclude) continue;
    if (!BookingStatus.upcomingApiKeys.contains(booking.status.apiKey)) {
      continue;
    }
    _addRange(ranges, booking.checkIn, booking.checkOut);
    final requestedIn = booking.requestedCheckIn;
    final requestedOut = booking.requestedCheckOut;
    if (requestedIn != null && requestedOut != null) {
      _addRange(ranges, requestedIn, requestedOut);
    }
  }
  return ranges;
}

void _addRange(List<OccupiedStayRange> ranges, DateTime start, DateTime end) {
  final from = stayDay(start);
  final to = stayDay(end);
  if (!to.isAfter(from)) return;
  ranges.add(OccupiedStayRange(start: from, end: to));
}
