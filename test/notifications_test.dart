import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:booking/data/auth_repository.dart';
import 'package:booking/data/booking.dart';
import 'package:booking/data/booking_draft.dart';
import 'package:booking/data/inbox_notification.dart';
import 'package:booking/data/notifications_repository.dart';
import 'package:booking/screens/listing/booking_confirmation_sheet.dart';
import 'package:booking/screens/profile/notifications_screen.dart';
import 'package:booking/screens/profile/profile_screen.dart';
import 'package:booking/screens/search/search_listing.dart';
import 'package:booking/theme/app_theme.dart';

import 'fixtures/demo_listings.dart';
import 'fixtures/fake_bookings.dart';
import 'fixtures/fake_notifications.dart';

Widget _app(Widget home) {
  return MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('ru', 'RU'),
    supportedLocales: const [Locale('ru', 'RU')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
  );
}

BookingDraft _draft() {
  return BookingDraft(
    listingId: 'studio-msk',
    checkIn: DateTime(2026, 9, 12),
    checkOut: DateTime(2026, 9, 15),
    adults: 2,
    children: 1,
    pets: 1,
  );
}

SearchListing _listing() {
  return kDemoListings
      .firstWhere((item) => item.id == 'studio-msk')
      .withStay(
        checkIn: DateTime(2026, 9, 12),
        checkOut: DateTime(2026, 9, 15),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NotificationsRepository previousNotifications;

  setUpAll(() async {
    await initializeDateFormatting('ru');
  });

  setUp(() {
    previousNotifications = NotificationsRepositoryScope.instance;
    NotificationsRepositoryScope.setUnread(0);
    AuthRepositoryScope.session.value = const AuthSession(
      userId: 'guest-1',
      email: 'guest@test.com',
    );
  });

  tearDown(() {
    NotificationsRepositoryScope.instance = previousNotifications;
    NotificationsRepositoryScope.setUnread(0);
    AuthRepositoryScope.session.value = null;
  });

  test('booking request copy uses the listing title', () {
    expect(
      BookingRequestCopy.bodyForListing('Уютная студия в центре Москвы'),
      'Ожидайте подтверждение бронирования «Уютная студия в центре Москвы» '
      'от владельца жилья в течение 12 часов',
    );
    expect(notificationWhenLabel(DateTime(2026, 9, 17), now: DateTime(2026, 9, 18)), 'Вчера');
    expect(notificationWhenLabel(DateTime(2026, 9, 18), now: DateTime(2026, 9, 18)), 'Сегодня');
  });

  testWidgets('successful book shows the Figma popup and stores a notification', (
    tester,
  ) async {
    final drafts = BookingDraftStore.memory(_draft());
    final bookings = FakeBookingsRepository();
    final notifications = FakeNotificationsRepository();
    NotificationsRepositoryScope.instance = notifications;

    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  BookingConfirmationSheet.show(
                    context,
                    listing: _listing(),
                    draft: _draft(),
                    draftStore: drafts,
                    bookingsRepository: bookings,
                    notificationsRepository: notifications,
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmation-book')));
    await tester.pumpAndSettle();

    expect(bookings.created, hasLength(1));
    expect(notifications.created, hasLength(1));
    expect(notifications.created.single.title, BookingRequestCopy.title);
    expect(
      notifications.created.single.body,
      contains('Уютная студия в центре Москвы'),
    );
    expect(find.byKey(const ValueKey('booking-request-sent-dialog')), findsOneWidget);
    expect(find.text(BookingRequestCopy.title), findsOneWidget);
    expect(find.text(BookingRequestCopy.body), findsOneWidget);
    expect(find.text(BookingRequestCopy.ok), findsOneWidget);
    expect(find.byKey(const ValueKey('confirmation-sheet')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('booking-request-sent-ok')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('booking-request-sent-dialog')), findsNothing);
    expect(find.byKey(const ValueKey('confirmation-sheet')), findsNothing);
  });

  testWidgets('popup still appears if the inbox write fails', (tester) async {
    final drafts = BookingDraftStore.memory(_draft());
    final bookings = FakeBookingsRepository();
    final notifications = FakeNotificationsRepository()
      ..failCreateWith = const NotificationException('blocked');
    NotificationsRepositoryScope.instance = notifications;

    await tester.pumpWidget(
      _app(
        Scaffold(
          body: BookingConfirmationSheet(
            listing: _listing(),
            draft: _draft(),
            draftStore: drafts,
            bookingsRepository: bookings,
            notificationsRepository: notifications,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('confirmation-book')));
    await tester.pumpAndSettle();

    expect(bookings.created, hasLength(1));
    expect(notifications.created, isEmpty);
    expect(find.byKey(const ValueKey('booking-request-sent-dialog')), findsOneWidget);
    expect(find.text(BookingRequestCopy.title), findsOneWidget);
  });

  testWidgets('profile notifications lists the stored booking notice', (
    tester,
  ) async {
    final notifications = FakeNotificationsRepository([
      InboxNotification(
        id: 'notice-1',
        userId: 'guest-1',
        title: BookingRequestCopy.title,
        body: BookingRequestCopy.bodyForListing('Уютная студия в центре Москвы'),
        read: false,
        bookingId: 'booking-1',
        listingId: 'studio-msk',
        created: DateTime(2026, 9, 18, 10),
      ),
    ]);
    NotificationsRepositoryScope.instance = notifications;

    await tester.pumpWidget(
      _app(const Scaffold(body: ProfileScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('profile-notifications')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('notifications-screen')), findsOneWidget);
    expect(find.text('Уведомления'), findsWidgets);
    expect(find.text(BookingRequestCopy.title), findsOneWidget);
    expect(find.textContaining('Уютная студия в центре Москвы'), findsOneWidget);
    final card = find.byKey(const ValueKey<String>('notifications-item-notice-1'));
    expect(
      tester.getSize(find.descendant(of: card, matching: find.byType(SvgPicture))),
      const Size(7, 7),
    );
  });
}
