import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:booking/screens/auth/photo_access.dart';
import 'package:booking/screens/auth/register_screen.dart';

import 'fixtures/fake_auth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PhotoAccessMemory previousMemory;

  setUp(() {
    previousMemory = PhotoAccessMemory.instance;
    PhotoAccessMemory.instance = PhotoAccessMemory.memory();
  });

  tearDown(() {
    PhotoAccessMemory.instance = previousMemory;
  });

  test('denied OS photo status is not treated as granted', () {
    expect(photoPermissionAllowsAccess(PermissionStatus.denied), isFalse);
    expect(
      photoPermissionAllowsAccess(PermissionStatus.permanentlyDenied),
      isFalse,
    );
    expect(photoPermissionAllowsAccess(PermissionStatus.restricted), isFalse);
    expect(photoPermissionAllowsAccess(PermissionStatus.granted), isTrue);
    expect(photoPermissionAllowsAccess(PermissionStatus.limited), isTrue);
  });

  testWidgets('register avatar shows the access dialog the first time', (
    tester,
  ) async {
    final photos = FakePhotoLibrary();
    await tester.pumpWidget(_registerApp(photos));

    await tester.tap(find.byKey(const ValueKey<String>('auth-register-avatar')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('auth-photo-access-dialog')),
      findsOneWidget,
    );

    await tester.tap(find.text('Полный доступ'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('auth-photo-grid')), findsOneWidget);
    expect(photos.galleryRequests, 1);
    expect(photos.cameraRequests, 1);
    expect(photos.lastGalleryLimited, isFalse);
    expect(await PhotoAccessMemory.instance.hasGranted(), isTrue);
  });

  testWidgets('register avatar skips the in-app dialog after a grant', (
    tester,
  ) async {
    final photos = FakePhotoLibrary();
    await tester.pumpWidget(_registerApp(photos));

    await tester.tap(find.byKey(const ValueKey<String>('auth-register-avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ограниченный доступ'));
    await tester.pumpAndSettle();
    expect(photos.lastGalleryLimited, isTrue);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('auth-register-avatar')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('auth-photo-access-dialog')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey<String>('auth-photo-grid')), findsOneWidget);
    expect(photos.galleryRequests, 2);
    expect(photos.cameraRequests, 2);
  });

  testWidgets('register avatar asks again after sheet deny', (tester) async {
    await tester.pumpWidget(_registerApp(FakePhotoLibrary()));

    await tester.tap(find.byKey(const ValueKey<String>('auth-register-avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Не предоставлять'));
    await tester.pumpAndSettle();
    expect(await PhotoAccessMemory.instance.hasGranted(), isFalse);
    expect(find.byKey(const ValueKey<String>('auth-photo-grid')), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('auth-register-avatar')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('auth-photo-access-dialog')),
      findsOneWidget,
    );
  });

  testWidgets('register avatar asks again when the OS denies gallery', (
    tester,
  ) async {
    final photos = FakePhotoLibrary(galleryGranted: false);
    await tester.pumpWidget(_registerApp(photos));

    await tester.tap(find.byKey(const ValueKey<String>('auth-register-avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Полный доступ'));
    await tester.pumpAndSettle();
    expect(await PhotoAccessMemory.instance.hasGranted(), isFalse);
    expect(find.byKey(const ValueKey<String>('auth-photo-grid')), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('auth-register-avatar')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('auth-photo-access-dialog')),
      findsOneWidget,
    );
  });

  testWidgets('register avatar asks again when the OS denies camera', (
    tester,
  ) async {
    final photos = FakePhotoLibrary(cameraGranted: false);
    await tester.pumpWidget(_registerApp(photos));

    await tester.tap(find.byKey(const ValueKey<String>('auth-register-avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Полный доступ'));
    await tester.pumpAndSettle();
    expect(await PhotoAccessMemory.instance.hasGranted(), isFalse);
    expect(find.byKey(const ValueKey<String>('auth-photo-grid')), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('auth-register-avatar')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('auth-photo-access-dialog')),
      findsOneWidget,
    );
  });

  testWidgets('picking a gallery photo opens PhotoCropScreen', (tester) async {
    await tester.pumpWidget(_registerApp(FakePhotoLibrary()));

    await tester.tap(find.byKey(const ValueKey<String>('auth-register-avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Полный доступ'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('auth-photo-grid')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('auth-photo-gallery-tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(PhotoCropScreen), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('auth-photo-crop')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('auth-photo-crop-circle')),
      findsOneWidget,
    );
    expect(find.text('Сохранить'), findsOneWidget);
  });

  testWidgets('crop circle can be dragged over the photo', (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(400, 800);
    view.devicePixelRatio = 1;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    final file = File('${Directory.systemTemp.path}/crop_pan_test.png');
    file.writeAsBytesSync(_png);

    await tester.pumpWidget(
      MaterialApp(home: PhotoCropScreen(file: file)),
    );
    await tester.pump();

    final circle = find.byKey(const ValueKey<String>('auth-photo-crop-circle'));
    expect(circle, findsOneWidget);
    final start = tester.getTopLeft(circle);

    await tester.drag(circle, const Offset(48, 36));
    await tester.pump();

    final moved = tester.getTopLeft(circle);
    expect(moved.dx, closeTo(start.dx + 48, 0.5));
    expect(moved.dy, closeTo(start.dy + 36, 0.5));
    expect(find.text('Сохранить'), findsOneWidget);
  });
}

Widget _registerApp(PhotoLibrary photos) {
  return MaterialApp(
    home: RegisterScreen(
      initialEmail: 'me@example.com',
      authRepository: FakeAuthRepository(),
      photoLibrary: photos,
    ),
  );
}

const _png = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
  0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
  0x00, 0x00, 0x03, 0x00, 0x01, 0x00, 0x05, 0xFE, 0xD4, 0xEF, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];
