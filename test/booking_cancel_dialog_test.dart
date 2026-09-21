import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booking/data/booking.dart';
import 'package:booking/data/bookings_repository.dart';
import 'package:booking/screens/bookings/booking_cancel_dialog.dart';
import 'package:booking/theme/app_theme.dart';

import 'fixtures/fake_bookings.dart';

const _dialog = ValueKey<String>('booking-cancel-dialog');
const _no = ValueKey<String>('booking-cancel-no');
const _yes = ValueKey<String>('booking-cancel-yes');

class _RecordingBookingsRepository extends FakeBookingsRepository {
  _RecordingBookingsRepository(super.items);

  var patchCalls = 0;

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
    patchCalls++;
    return super.patch(
      id: id,
      status: status,
      cancelReason: cancelReason,
      requestedCheckIn: requestedCheckIn,
      requestedCheckOut: requestedCheckOut,
      adults: adults,
      children: children,
      pets: pets,
      total: total,
      prepay: prepay,
      remainder: remainder,
      commission: commission,
      hostAmount: hostAmount,
    );
  }
}

Booking _booking({BookingStatus status = BookingStatus.confirmed}) {
  return Booking(
    id: 'booking-1',
    listingId: 'listing-1',
    guestId: 'guest',
    hostId: 'host',
    checkIn: DateTime(2026, 9, 12),
    checkOut: DateTime(2026, 9, 15),
    status: status,
    adults: 2,
    title: 'Уютная студия в центре Москвы',
  );
}

class _DialogResult {
  Booking? value;
}

Future<_DialogResult> _openDialog(
  WidgetTester tester,
  Booking booking,
) async {
  final result = _DialogResult();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                result.value = await showBookingCancelDialog(context, booking);
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookingsRepository previous;

  setUp(() {
    previous = BookingsRepositoryScope.instance;
  });

  tearDown(() {
    BookingsRepositoryScope.instance = previous;
  });

  testWidgets('No and barrier close without patching status', (tester) async {
    final booking = _booking();
    final repo = _RecordingBookingsRepository([booking]);
    BookingsRepositoryScope.instance = repo;

    final declined = await _openDialog(tester, booking);
    expect(find.byKey(_dialog), findsOneWidget);
    expect(find.text('Отменить бронирование?'), findsOneWidget);

    await tester.tap(find.byKey(_no));
    await tester.pumpAndSettle();

    expect(find.byKey(_dialog), findsNothing);
    expect(declined.value, isNull);
    expect(repo.patchCalls, 0);
    expect(repo.items.single.status, BookingStatus.confirmed);
    expect(repo.items.single.cancelReason, isNull);

    final dismissed = await _openDialog(tester, booking);
    expect(find.byKey(_dialog), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(find.byKey(_dialog), findsNothing);
    expect(dismissed.value, isNull);
    expect(repo.patchCalls, 0);
    expect(repo.items.single.status, BookingStatus.confirmed);
  });

  testWidgets('Yes patches cancelled with guest reason', (tester) async {
    final booking = _booking();
    final repo = _RecordingBookingsRepository([booking]);
    BookingsRepositoryScope.instance = repo;

    final result = await _openDialog(tester, booking);
    expect(find.byKey(_dialog), findsOneWidget);

    await tester.tap(find.byKey(_yes));
    await tester.pumpAndSettle();

    expect(find.byKey(_dialog), findsNothing);
    expect(result.value, isNotNull);
    expect(result.value!.id, booking.id);
    expect(result.value!.status, BookingStatus.cancelled);
    expect(result.value!.cancelReason, BookingCancelReason.guest);
    expect(repo.patchCalls, 1);
    expect(repo.items.single.status, BookingStatus.cancelled);
    expect(repo.items.single.cancelReason, BookingCancelReason.guest);
  });

  testWidgets('Yes label stays on a single line', (tester) async {
    final booking = _booking();
    BookingsRepositoryScope.instance = FakeBookingsRepository([booking]);

    await _openDialog(tester, booking);
    expect(find.byKey(_dialog), findsOneWidget);

    final size = tester.getSize(find.text('Да, отменить'));
    expect(size.height, inInclusiveRange(16, 22));
  });
}
