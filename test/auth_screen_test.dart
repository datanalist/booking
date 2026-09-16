import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booking/data/auth_repository.dart';
import 'package:booking/screens/auth/auth_screen.dart';

import 'fixtures/fake_auth.dart';

Finder termsCheckbox() =>
    find.byKey(const ValueKey<String>('auth-terms-checkbox'));

Future<void> fillEmailAndAcceptTerms(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('auth-email-field')));
  await tester.pump();
  await tester.tap(termsCheckbox());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('email field is empty until tapped, then stub is editable', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(authRepository: auth)),
    );

    expect(find.text('Авторизация'), findsOneWidget);
    expect(find.text('Продолжить'), findsOneWidget);
    expect(find.text('Email'), findsWidgets);
    expect(find.text(kAuthEmailStub), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('auth-email-field')));
    await tester.pump();

    expect(find.text(kAuthEmailStub), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('auth-email-field')),
      'edited@mail.com',
    );
    await tester.pump();
    expect(find.text('edited@mail.com'), findsOneWidget);
    expect(find.text(kAuthEmailStub), findsNothing);
  });

  testWidgets('continue stays disabled until terms are accepted', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    AuthSession? signedIn;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          authRepository: auth,
          onSignedIn: (session) => signedIn = session,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('auth-email-field')));
    await tester.pump();
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    expect(auth.lastEmail, isNull);
    expect(signedIn, isNull);

    await tester.tap(termsCheckbox());
    await tester.pump();
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    expect(auth.lastEmail, kAuthEmailStub);
    expect(signedIn?.email, kAuthEmailStub);
  });

  testWidgets('continue authenticates the typed email against the repository', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    AuthSession? signedIn;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          authRepository: auth,
          onSignedIn: (session) => signedIn = session,
        ),
      ),
    );

    await fillEmailAndAcceptTerms(tester);
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    expect(auth.lastEmail, kAuthEmailStub);
    expect(signedIn?.email, kAuthEmailStub);
  });

  testWidgets('failed auth shows error and stays on the email tab', (
    tester,
  ) async {
    final auth = FakeAuthRepository()..fail = true;
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(authRepository: auth)),
    );

    await fillEmailAndAcceptTerms(tester);
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    expect(
      find.text('Пользователь не найден или вход не удался'),
      findsOneWidget,
    );
    expect(find.text('Авторизация'), findsOneWidget);
    expect(find.text('Поиск'), findsNothing);
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
    expect(
      find.textContaining('Я прочитал(а) и согласен(сна)'),
      findsOneWidget,
    );

    _tapLink(tester, kAuthTermsLinkLabel);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('auth-terms-page')), findsOneWidget);
    expect(find.text('Условия использования'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    _tapLink(tester, kAuthPrivacyLinkLabel);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('auth-privacy-page')),
      findsOneWidget,
    );
    expect(find.text('Политика конфиденциальности'), findsOneWidget);
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

