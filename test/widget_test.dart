import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booking/data/auth_repository.dart';
import 'package:booking/data/bookings_repository.dart';
import 'package:booking/data/listings_repository.dart';
import 'package:booking/main.dart';
import 'package:booking/screens/onboarding_screen.dart';
import 'package:booking/screens/splash_screen.dart';

import 'fixtures/demo_listings.dart';
import 'fixtures/fake_auth.dart';
import 'fixtures/fake_bookings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ListingsRepositoryScope.instance = FakeListingsRepository();
    BookingsRepositoryScope.instance = FakeBookingsRepository();
    AuthRepositoryScope.instance = PocketBaseAuthRepository();
    AuthRepositoryScope.session.value = null;
    AuthRepositoryScope.authLinkError.value = null;
  });

  testWidgets('splash shows logo then opens onboarding', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SplashScreen(delay: Duration.zero)),
    );

    expect(find.byType(SvgPicture), findsOneWidget);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Находите идеальное жилье'), findsOneWidget);
    expect(find.text('Далее'), findsOneWidget);
  });

  testWidgets('onboarding advances pages and finishes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));

    expect(find.text('Находите идеальное жилье'), findsOneWidget);

    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    expect(find.text('Бронируйте жилье уверенно'), findsOneWidget);

    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    expect(find.text('Путешествуйте без границ'), findsOneWidget);
    expect(find.text('Начать'), findsOneWidget);

    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();
    expect(find.text('Авторизация'), findsOneWidget);
    expect(find.text('Введите Email или номер телефона'), findsOneWidget);
    expect(find.text('Далее'), findsOneWidget);
    expect(find.text('Поиск'), findsNothing);
  });

  testWidgets('swiping through onboarding opens authorization', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));

    expect(find.text('Находите идеальное жилье'), findsOneWidget);

    Future<void> swipeNext() async {
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
    }

    await swipeNext();
    expect(find.text('Бронируйте жилье уверенно'), findsOneWidget);

    await swipeNext();
    expect(find.text('Путешествуйте без границ'), findsOneWidget);
    expect(find.text('Начать'), findsOneWidget);
    expect(find.text('Авторизация'), findsNothing);

    await swipeNext();
    expect(find.text('Авторизация'), findsOneWidget);
    expect(find.text('Введите Email или номер телефона'), findsOneWidget);
    expect(find.text('Далее'), findsOneWidget);
    expect(find.text('Поиск'), findsNothing);
  });

  testWidgets('app boots on splash', (tester) async {
    await tester.pumpWidget(const BookingApp());
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();
    expect(find.text('Находите идеальное жилье'), findsOneWidget);
  });

  testWidgets('splash restores a logged-in session into the shell', (
    tester,
  ) async {
    final previousAuth = AuthRepositoryScope.instance;
    final previousSession = AuthRepositoryScope.session.value;
    addTearDown(() {
      AuthRepositoryScope.instance = previousAuth;
      AuthRepositoryScope.session.value = previousSession;
    });

    final auth = FakeAuthRepository()
      ..session = const AuthSession(
        userId: 'user00000000001',
        email: 'me@example.com',
        displayName: 'Гость Тестов',
        profileComplete: true,
      );
    AuthRepositoryScope.instance = auth;
    AuthRepositoryScope.session.value = null;

    await tester.pumpWidget(
      const MaterialApp(home: SplashScreen(delay: Duration.zero)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Поиск'), findsWidgets);
    expect(find.text('Находите идеальное жилье'), findsNothing);
    expect(find.text('Авторизация'), findsNothing);
  });
}
