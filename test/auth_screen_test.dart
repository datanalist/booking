import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booking/data/auth_repository.dart';
import 'package:booking/screens/auth/auth_screen.dart';

import 'fixtures/fake_auth.dart';

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

    await tester.tap(find.byKey(const ValueKey<String>('auth-email-field')));
    await tester.pump();
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

    await tester.tap(find.byKey(const ValueKey<String>('auth-email-field')));
    await tester.pump();
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    expect(
      find.text('Пользователь не найден или вход не удался'),
      findsOneWidget,
    );
    expect(find.text('Авторизация'), findsOneWidget);
    expect(find.text('Поиск'), findsNothing);
  });

  testWidgets('terms checkbox is not on the email tab yet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(authRepository: FakeAuthRepository())),
    );
    expect(find.textContaining('Условиями использования'), findsNothing);
  });
}
