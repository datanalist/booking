import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booking/data/auth_repository.dart';
import 'package:booking/screens/auth/auth_screen.dart';

import 'fixtures/fake_auth.dart';

Finder termsCheckbox() =>
    find.byKey(const ValueKey<String>('auth-terms-checkbox'));

Finder identityField() =>
    find.byKey(const ValueKey<String>('auth-identity-field'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('identity field stays empty until the user types', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(authRepository: FakeAuthRepository())),
    );

    expect(find.text('Авторизация'), findsOneWidget);
    expect(find.text('Введите Email или номер телефона'), findsOneWidget);
    expect(find.text('Далее'), findsOneWidget);
    expect(find.text('Email'), findsNothing);
    expect(find.text('Телефон'), findsNothing);
    expect(find.text('example@mail.com'), findsNothing);

    await tester.tap(identityField());
    await tester.pump();
    expect(find.text('example@mail.com'), findsNothing);

    await tester.enterText(identityField(), 'me@example.com');
    await tester.pump();
    expect(find.text('me@example.com'), findsOneWidget);
  });

  testWidgets('continue requests email magic link after terms are accepted', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(authRepository: auth)),
    );

    await tester.enterText(identityField(), 'me@example.com');
    await tester.pump();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    expect(auth.lastEmail, isNull);

    await tester.tap(termsCheckbox());
    await tester.pump();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();

    expect(auth.lastEmail, 'me@example.com');
    expect(find.byKey(const ValueKey<String>('auth-magic-wait')), findsOneWidget);
    expect(find.textContaining('me@example.com'), findsOneWidget);
    expect(find.textContaining('Авторизоваться'), findsOneWidget);
    expect(find.text('Введите код'), findsNothing);
    expect(find.byKey(const ValueKey<String>('auth-otp-field')), findsNothing);
  });

  testWidgets('phone number requests stub OTP', (tester) async {
    final auth = FakeAuthRepository();
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(authRepository: auth)),
    );

    await tester.enterText(identityField(), kAuthPhoneStub);
    await tester.pump();
    await tester.tap(termsCheckbox());
    await tester.pump();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();

    expect(auth.lastPhone, kAuthPhoneStub);
    expect(find.text('Введите код'), findsOneWidget);
  });

  testWidgets('failed OTP request shows error on the screen', (tester) async {
    final auth = FakeAuthRepository()..failOtpRequest = true;
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(authRepository: auth)),
    );

    await tester.enterText(identityField(), 'me@example.com');
    await tester.tap(termsCheckbox());
    await tester.pump();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось отправить письмо на эту почту'), findsOneWidget);
    expect(find.text('Авторизация'), findsOneWidget);
  });

  testWidgets('invalid identity shows validation error', (tester) async {
    final auth = FakeAuthRepository();
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(authRepository: auth)),
    );

    await tester.enterText(identityField(), 'not-an-identity');
    await tester.tap(termsCheckbox());
    await tester.pump();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();

    expect(
      find.text('Введите корректный email или номер телефона'),
      findsOneWidget,
    );
    expect(auth.lastEmail, isNull);
    expect(auth.lastPhone, isNull);
  });

  testWidgets('terms checkbox copy and links match Figma', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(authRepository: FakeAuthRepository())),
    );

    expect(find.byKey(const ValueKey<String>('auth-terms-slot')), findsOneWidget);
    expect(find.textContaining('Условиями использования'), findsOneWidget);
    expect(
      find.textContaining('Политикой конфиденциальности'),
      findsOneWidget,
    );

    _tapLink(tester, kAuthTermsLinkLabel);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('auth-terms-page')), findsOneWidget);
  });

  testWidgets('auth screen does not overflow when the keyboard is open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    tester.view.viewInsets = const FakeViewPadding(bottom: 420);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(authRepository: FakeAuthRepository())),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Авторизация'), findsOneWidget);
    expect(find.text('Далее'), findsOneWidget);
  });
}

void _tapLink(WidgetTester tester, String label) {
  final rich = tester.widget<RichText>(
    find.descendant(
      of: find.byKey(const ValueKey<String>('auth-terms-slot')),
      matching: find.byType(RichText),
    ),
  );
  final root = rich.text as TextSpan;
  TapGestureRecognizer? recognizer;
  root.visitChildren((span) {
    if (span is TextSpan &&
        span.text == label &&
        span.recognizer is TapGestureRecognizer) {
      recognizer = span.recognizer as TapGestureRecognizer;
      return false;
    }
    return true;
  });
  expect(recognizer, isNotNull, reason: 'missing recognizer for $label');
  recognizer!.onTap!.call();
}
