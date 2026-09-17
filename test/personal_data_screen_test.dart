import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booking/data/auth_repository.dart';
import 'package:booking/screens/profile/personal_data_screen.dart';
import 'package:booking/screens/profile/profile_screen.dart';
import 'package:booking/theme/app_theme.dart';

import 'fixtures/fake_auth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthRepository previousAuth;
  late AuthSession? previousSession;

  setUp(() {
    previousAuth = AuthRepositoryScope.instance;
    previousSession = AuthRepositoryScope.session.value;
  });

  tearDown(() {
    AuthRepositoryScope.instance = previousAuth;
    AuthRepositoryScope.session.value = previousSession;
  });

  AuthSession guestSession() {
    return AuthSession(
      userId: 'user00000000001',
      email: 'vladislav_kovalenko@gmail.com',
      firstName: 'Владислав',
      lastName: 'Коваленко',
      displayName: 'Владислав Коваленко',
      birthdate: DateTime(1995, 8, 17),
      profileComplete: true,
    );
  }

  testWidgets('personal data loads session fields from profile menu', (
    tester,
  ) async {
    final auth = FakeAuthRepository()..session = guestSession();
    AuthRepositoryScope.instance = auth;
    AuthRepositoryScope.session.value = auth.session;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: ProfileScreen(authRepository: auth)),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('profile-personal-data')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('personal-data-screen')), findsOneWidget);
    expect(find.text('Личные данные'), findsWidgets);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey<String>('personal-data-first')),
          )
          .controller
          ?.text,
      'Владислав',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey<String>('personal-data-last')),
          )
          .controller
          ?.text,
      'Коваленко',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey<String>('personal-data-birth')),
          )
          .controller
          ?.text,
      '17.08.1995',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey<String>('personal-data-email')),
          )
          .controller
          ?.text,
      'vladislav_kovalenko@gmail.com',
    );
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('personal-data-back'))),
      const Size(36, 36),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('personal-data-avatar'))),
      const Size(72, 72),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('personal-data-calendar'))),
      const Size(20, 20),
    );
    final icons = tester.widgetList<SvgPicture>(find.byType(SvgPicture)).toList();
    expect(icons, hasLength(3));
    expect(icons[0].width, 13.1667);
    expect(icons[0].height, 7.33333);
    expect(icons[1].width, 104);
    expect(icons[1].height, 104);
    expect(icons[2].width, 16.5);
    expect(icons[2].height, 18.1667);
  });

  testWidgets('saving personal data updates the profile name', (tester) async {
    final auth = FakeAuthRepository()..session = guestSession();
    AuthRepositoryScope.instance = auth;
    AuthRepositoryScope.session.value = auth.session;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: ProfileScreen(authRepository: auth)),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('profile-personal-data')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('personal-data-first')),
      'Анна',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('personal-data-last')),
      'Иванова',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('personal-data-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('personal-data-screen')), findsNothing);
    expect(auth.session.firstName, 'Анна');
    expect(auth.session.lastName, 'Иванова');
    expect(auth.session.email, 'vladislav_kovalenko@gmail.com');
    expect(auth.session.birthdate, DateTime(1995, 8, 17));
    expect(AuthRepositoryScope.session.value?.displayName, 'Анна Иванова');
    expect(find.text('Анна Иванова'), findsOneWidget);
    expect(find.text('Владислав Коваленко'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('personal-data-email-dialog')),
      findsNothing,
    );
    expect(auth.currentSession(), isNotNull);
  });

  testWidgets('invalid birthdate stays on the form with an error', (
    tester,
  ) async {
    final auth = FakeAuthRepository()..session = guestSession();
    AuthRepositoryScope.instance = auth;
    AuthRepositoryScope.session.value = auth.session;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PersonalDataScreen(authRepository: auth),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('personal-data-birth')),
      '32011990',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('personal-data-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('personal-data-error')), findsOneWidget);
    expect(find.text('Такой даты не существует'), findsOneWidget);
    expect(auth.session.firstName, 'Владислав');
    expect(find.byKey(const ValueKey<String>('personal-data-screen')), findsOneWidget);
  });

  testWidgets('back returns to profile without saving', (tester) async {
    final auth = FakeAuthRepository()..session = guestSession();
    AuthRepositoryScope.instance = auth;
    AuthRepositoryScope.session.value = auth.session;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: ProfileScreen(authRepository: auth)),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('profile-personal-data')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('personal-data-first')),
      'Анна',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('personal-data-back')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('personal-data-screen')), findsNothing);
    expect(auth.session.firstName, 'Владислав');
    expect(find.text('Владислав Коваленко'), findsOneWidget);
  });

  testWidgets('unchanged email saves without the logout dialog', (
    tester,
  ) async {
    final auth = FakeAuthRepository()..session = guestSession();
    AuthRepositoryScope.instance = auth;
    AuthRepositoryScope.session.value = auth.session;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: ProfileScreen(authRepository: auth)),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('profile-personal-data')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('personal-data-email')),
      '  Vladislav_Kovalenko@gmail.com  ',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('personal-data-save')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('personal-data-email-dialog')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey<String>('personal-data-screen')), findsNothing);
    expect(auth.currentSession(), isNotNull);
    expect(AuthRepositoryScope.session.value, isNotNull);
    expect(find.text('Авторизация'), findsNothing);
    expect(find.text('Владислав Коваленко'), findsOneWidget);
  });

  testWidgets('email change cancel keeps the session and form', (tester) async {
    final auth = FakeAuthRepository()..session = guestSession();
    AuthRepositoryScope.instance = auth;
    AuthRepositoryScope.session.value = auth.session;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: ProfileScreen(authRepository: auth)),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('profile-personal-data')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('personal-data-email')),
      'anna.ivanova@mail.com',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('personal-data-save')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('personal-data-email-dialog')),
      findsOneWidget,
    );
    expect(find.text('Изменить email?'), findsOneWidget);
    expect(
      find.text(
        'После смены email будет выполнен выход из аккаунта. Войдите снова по новому адресу.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('personal-data-email-no')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('personal-data-email-dialog')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey<String>('personal-data-screen')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey<String>('personal-data-email')),
          )
          .controller
          ?.text,
      'vladislav_kovalenko@gmail.com',
    );
    expect(find.text('anna.ivanova@mail.com'), findsNothing);
    expect(auth.lastUpdatedEmail, isNull);
    expect(auth.session.email, 'vladislav_kovalenko@gmail.com');
    expect(auth.currentSession(), isNotNull);
    expect(AuthRepositoryScope.session.value, isNotNull);
    expect(find.text('Авторизация'), findsNothing);
  });

  testWidgets('tapping outside the email dialog does not save', (tester) async {
    final auth = FakeAuthRepository()..session = guestSession();
    AuthRepositoryScope.instance = auth;
    AuthRepositoryScope.session.value = auth.session;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PersonalDataScreen(authRepository: auth),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('personal-data-email')),
      'anna.ivanova@mail.com',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('personal-data-save')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('personal-data-email-dialog')),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('personal-data-email-dialog')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey<String>('personal-data-screen')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey<String>('personal-data-email')),
          )
          .controller
          ?.text,
      'vladislav_kovalenko@gmail.com',
    );
    expect(find.text('anna.ivanova@mail.com'), findsNothing);
    expect(auth.lastUpdatedEmail, isNull);
    expect(auth.session.email, 'vladislav_kovalenko@gmail.com');
    expect(auth.currentSession(), isNotNull);
    expect(find.text('Авторизация'), findsNothing);
  });

  testWidgets('email change confirm saves, signs out and opens auth', (
    tester,
  ) async {
    final auth = FakeAuthRepository()..session = guestSession();
    AuthRepositoryScope.instance = auth;
    AuthRepositoryScope.session.value = auth.session;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: ProfileScreen(authRepository: auth)),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('profile-personal-data')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('personal-data-email')),
      'anna.ivanova@mail.com',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('personal-data-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('personal-data-email-yes')));
    await tester.pumpAndSettle();

    expect(auth.lastUpdatedEmail, 'anna.ivanova@mail.com');
    expect(auth.currentSession(), isNull);
    expect(AuthRepositoryScope.session.value, isNull);
    expect(find.text('Авторизация'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('personal-data-screen')), findsNothing);
    expect(find.text('Личные данные'), findsNothing);
  });

  testWidgets('email change does not sign out if save fails', (tester) async {
    final auth = FakeAuthRepository()
      ..session = guestSession()
      ..failProfile = true;
    AuthRepositoryScope.instance = auth;
    AuthRepositoryScope.session.value = auth.session;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PersonalDataScreen(authRepository: auth),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('personal-data-email')),
      'anna.ivanova@mail.com',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('personal-data-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('personal-data-email-yes')));
    await tester.pumpAndSettle();

    expect(auth.lastUpdatedEmail, isNull);
    expect(auth.session.email, 'vladislav_kovalenko@gmail.com');
    expect(auth.currentSession(), isNotNull);
    expect(AuthRepositoryScope.session.value, isNotNull);
    expect(find.byKey(const ValueKey<String>('personal-data-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('personal-data-error')), findsOneWidget);
    expect(find.text('Не удалось сохранить профиль'), findsOneWidget);
    expect(find.text('Авторизация'), findsNothing);
  });
}
