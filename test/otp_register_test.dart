import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booking/data/auth_repository.dart';
import 'package:booking/screens/auth/otp_screen.dart';
import 'package:booking/screens/auth/register_screen.dart';

import 'fixtures/fake_auth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('wrong email code shows error banner', (tester) async {
    final auth = FakeAuthRepository()..failOtpVerify = true;
    await tester.pumpWidget(
      MaterialApp(
        home: OtpScreen(
          challenge: const OtpChallenge(
            otpId: 'otp-email',
            channel: OtpChannel.email,
            destination: 'me@example.com',
          ),
          authRepository: auth,
          resendSeconds: 1,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('auth-otp-field')),
      '12345',
    );
    await tester.pump();
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('auth-otp-error')), findsOneWidget);
    expect(find.text('Неверный код'), findsOneWidget);
  });

  testWidgets('phone stub accepts 77777 and rejects other codes', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    AuthSession? session;
    await tester.pumpWidget(
      MaterialApp(
        home: OtpScreen(
          challenge: const OtpChallenge(
            otpId: kAuthPhoneStubOtpId,
            channel: OtpChannel.phone,
            destination: kAuthPhoneStub,
          ),
          authRepository: auth,
          onVerified: (value) => session = value,
          resendSeconds: 1,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('auth-otp-field')),
      '00000',
    );
    await tester.pump();
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    expect(find.text('Неверный код'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('auth-otp-field')),
      kAuthPhoneStubCode,
    );
    await tester.pump();
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    expect(session, isNotNull);
  });

  testWidgets('resend becomes tappable after the timer', (tester) async {
    final auth = FakeAuthRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: OtpScreen(
          challenge: const OtpChallenge(
            otpId: 'otp-email',
            channel: OtpChannel.email,
            destination: 'me@example.com',
          ),
          authRepository: auth,
          resendSeconds: 1,
        ),
      ),
    );

    expect(find.text('00:01'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('00:01'), findsNothing);
    await tester.tap(find.text('Отправить код повторно'));
    await tester.pumpAndSettle();
    expect(auth.lastEmail, 'me@example.com');
  });

  testWidgets('registration validates birthdate and underage alert', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterScreen(
          initialEmail: 'me@example.com',
          authRepository: auth,
          photoLibrary: FakePhotoLibrary(),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('auth-register-first')),
      'Анна',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('auth-register-last')),
      'Иванова',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('auth-register-birth')),
      '01012020',
    );
    await tester.pump();
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('auth-age-alert')), findsOneWidget);
    expect(find.textContaining('только просмотр'), findsOneWidget);
    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();
    expect(auth.session.limitedBrowse, isTrue);
  });

  testWidgets('avatar tap opens photo access dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterScreen(
          initialEmail: 'me@example.com',
          authRepository: FakeAuthRepository(),
          photoLibrary: FakePhotoLibrary(),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('auth-register-avatar')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('auth-photo-access-dialog')),
      findsOneWidget,
    );
    expect(find.text('Ограниченный доступ'), findsOneWidget);
    expect(find.text('Полный доступ'), findsOneWidget);
    expect(find.text('Не предоставлять'), findsOneWidget);

    await tester.tap(find.text('Полный доступ'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('auth-photo-grid')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('auth-photo-camera-tile')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('auth-camera-access-dialog')),
      findsOneWidget,
    );
  });
}
