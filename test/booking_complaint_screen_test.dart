import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:booking/data/auth_repository.dart';
import 'package:booking/data/booking.dart';
import 'package:booking/data/chats_repository.dart';
import 'package:booking/data/tickets_repository.dart';
import 'package:booking/screens/bookings/booking_complaint_screen.dart';
import 'package:booking/screens/search/search_listing.dart';
import 'package:booking/theme/app_theme.dart';

import 'fixtures/demo_listings.dart';
import 'fixtures/fake_chats.dart';
import 'fixtures/fake_tickets.dart';

Widget _app(Widget home) {
  return MaterialApp(
    theme: AppTheme.light,
    scrollBehavior: AppTheme.scrollBehavior,
    home: home,
  );
}

Booking _booking() {
  final listing = kDemoListings.firstWhere((item) => item.id == 'studio-msk');
  return Booking(
    id: 'booking-1',
    listingId: listing.id,
    guestId: 'guest-1',
    hostId: listing.hostId,
    checkIn: DateTime(2026, 9, 12),
    checkOut: DateTime(2026, 9, 15),
    status: BookingStatus.confirmed,
    adults: 2,
    title: listing.title,
    photo: listing.photo,
    city: listing.city,
    address: listing.address,
    hostName: listing.host?.name ?? 'Анна Иваненко',
    hostAvatar: listing.host?.avatarUrl ?? '',
  );
}

SearchListing _listing() {
  return kDemoListings.firstWhere((item) => item.id == 'studio-msk');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TicketsRepository previousTickets;
  late ChatsRepository previousChats;

  setUpAll(() async {
    await initializeDateFormatting('ru');
  });

  setUp(() {
    previousTickets = TicketsRepositoryScope.instance;
    previousChats = ChatsRepositoryScope.instance;
    ChatsRepositoryScope.instance = FakeChatsRepository();
    AuthRepositoryScope.session.value = const AuthSession(
      userId: 'guest-1',
      email: 'guest@test.com',
    );
  });

  tearDown(() {
    TicketsRepositoryScope.instance = previousTickets;
    ChatsRepositoryScope.instance = previousChats;
    AuthRepositoryScope.session.value = null;
  });

  Future<void> openScreen(
    WidgetTester tester, {
    required FakeTicketsRepository tickets,
    Booking? booking,
  }) async {
    TicketsRepositoryScope.instance = tickets;
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final listing = _listing();
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  openBookingComplaintScreen(
                    context,
                    booking ?? _booking(),
                    ticketsRepository: tickets,
                    listingRating: listing.rating,
                    listingReviews: listing.reviews,
                    listingType: listing.type,
                  );
                },
                child: const Text('open-complaint'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open-complaint'));
    await tester.pumpAndSettle();
  }

  testWidgets('complaint screen lists three targets from Figma 1:11353', (
    tester,
  ) async {
    await openScreen(tester, tickets: FakeTicketsRepository());

    expect(
      find.byKey(const ValueKey('booking-complaint-screen')),
      findsOneWidget,
    );
    expect(find.text('Пожаловаться на'), findsOneWidget);
    expect(find.byKey(const ValueKey('complaint-booking')), findsOneWidget);
    expect(find.byKey(const ValueKey('complaint-listing')), findsOneWidget);
    expect(find.byKey(const ValueKey('complaint-host')), findsOneWidget);
    expect(find.text('Бронирование'), findsOneWidget);
    expect(find.text('Жилье'), findsOneWidget);
    expect(find.text('Владельца жилья'), findsOneWidget);
  });

  testWidgets('booking complaint can open the host chat stub', (tester) async {
    await openScreen(tester, tickets: FakeTicketsRepository());

    await tester.tap(find.byKey(const ValueKey('complaint-booking')));
    await tester.pumpAndSettle();

    expect(find.text('Пожаловаться на бронирование'), findsOneWidget);
    expect(find.text('Написать владельцу'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('complaint-booking-chat')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chat-thread-back')), findsOneWidget);
    expect(find.text('Анна Иваненко'), findsWidgets);
    expect(find.byKey(const ValueKey('chat-input')), findsOneWidget);
  });

  testWidgets('booking support writes a booking ticket and shows sent dialog', (
    tester,
  ) async {
    final tickets = FakeTicketsRepository();
    await openScreen(tester, tickets: tickets);

    await tester.tap(find.byKey(const ValueKey('complaint-booking')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('complaint-booking-support')));
    await tester.pumpAndSettle();

    expect(tickets.created, hasLength(1));
    expect(tickets.created.single.type, TicketType.booking);
    expect(tickets.created.single.authorId, 'guest-1');
    expect(tickets.created.single.bookingId, 'booking-1');
    expect(tickets.created.single.listingId, 'studio-msk');
    expect(tickets.created.single.hostId, 'anna');
    expect(tickets.created.single.text, 'Жалоба на бронирование');

    expect(find.byKey(const ValueKey('complaint-sent-dialog')), findsOneWidget);
    expect(find.text('Жалоба отправлена'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('complaint-sent-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('complaint-sent-dialog')), findsNothing);
    expect(
      find.byKey(const ValueKey('booking-complaint-screen')),
      findsOneWidget,
    );
  });

  testWidgets('listing complaint writes a listing ticket after text', (
    tester,
  ) async {
    final tickets = FakeTicketsRepository();
    await openScreen(tester, tickets: tickets);

    await tester.tap(find.byKey(const ValueKey('complaint-listing')));
    await tester.pumpAndSettle();

    expect(find.text('Пожаловаться на жилье'), findsOneWidget);
    expect(find.text('Уютная студия в центре Москвы'), findsOneWidget);
    expect(find.text('Москва'), findsOneWidget);
    expect(find.text('Квартира'), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);

    final send = tester.widget<FilledButton>(
      find.byKey(const ValueKey('complaint-listing-send')),
    );
    expect(send.onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('complaint-listing-text')),
      'Грязно и нет горячей воды',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('complaint-listing-send')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('complaint-listing-send')));
    await tester.pumpAndSettle();

    expect(tickets.created, hasLength(1));
    expect(tickets.created.single.type, TicketType.listing);
    expect(tickets.created.single.text, 'Грязно и нет горячей воды');
    expect(tickets.created.single.listingId, 'studio-msk');
    expect(tickets.created.single.bookingId, 'booking-1');

    expect(find.byKey(const ValueKey('complaint-sent-dialog')), findsOneWidget);
    expect(
      find.text('Техподдержка рассмотрит вашу жалобу в ближайшее время'),
      findsOneWidget,
    );
  });

  testWidgets('host complaint shows host photo name and writes a host ticket', (
    tester,
  ) async {
    final tickets = FakeTicketsRepository();
    await openScreen(tester, tickets: tickets);

    await tester.tap(find.byKey(const ValueKey('complaint-host')));
    await tester.pumpAndSettle();

    expect(find.text('Пожаловаться на владельца жилья'), findsOneWidget);
    expect(find.text('Анна Иваненко'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('complaint-host-text')),
      'Хозяин не отвечает',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('complaint-host-send')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('complaint-host-send')));
    await tester.pumpAndSettle();

    expect(tickets.created, hasLength(1));
    expect(tickets.created.single.type, TicketType.host);
    expect(tickets.created.single.hostId, 'anna');
    expect(tickets.created.single.text, 'Хозяин не отвечает');
    expect(find.byKey(const ValueKey('complaint-sent-dialog')), findsOneWidget);
  });
}
