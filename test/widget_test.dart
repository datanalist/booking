import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booking/main.dart';
import 'package:booking/screens/onboarding_screen.dart';
import 'package:booking/screens/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('splash shows logo then opens onboarding', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(delay: Duration.zero),
      ),
    );

    expect(find.byType(SvgPicture), findsOneWidget);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Находите идеальное жилье'), findsOneWidget);
    expect(find.text('Далее'), findsOneWidget);
  });

  testWidgets('onboarding advances pages and finishes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: OnboardingScreen()),
    );

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
  });

  testWidgets('app boots on splash', (tester) async {
    await tester.pumpWidget(const BookingApp());
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();
    expect(find.text('Находите идеальное жилье'), findsOneWidget);
  });
}
