import 'dart:io';
import 'dart:typed_data';

import 'package:booking/data/auth_repository.dart';
import 'package:booking/screens/auth/photo_access.dart';

class FakeAuthRepository implements AuthRepository {
  String? lastEmail;
  String? lastPhone;
  String? lastOtp;
  bool failOtpRequest = false;
  bool failOtpVerify = false;
  bool failProfile = false;
  bool existingProfile = false;

  AuthSession session = const AuthSession(
    userId: 'user00000000001',
    email: 'new.user@mail.com',
  );

  @override
  AuthSession? currentSession() =>
      session.userId.isEmpty ? null : session;

  @override
  Future<OtpChallenge> requestEmailOtp(String email) async {
    lastEmail = email;
    if (failOtpRequest) {
      throw const AuthException('Не удалось отправить код на эту почту');
    }
    return OtpChallenge(
      otpId: 'otp-email',
      channel: OtpChannel.email,
      destination: email,
    );
  }

  @override
  Future<AuthSession> verifyEmailOtp({
    required String otpId,
    required String code,
  }) async {
    lastOtp = code;
    if (failOtpVerify) {
      throw const AuthException('Неверный код');
    }
    session = AuthSession(
      userId: session.userId,
      email: lastEmail ?? session.email,
      profileComplete: existingProfile,
      displayName: existingProfile ? 'Гость Тестов' : '',
    );
    return session;
  }

  @override
  Future<OtpChallenge> requestPhoneOtp(String phone) async {
    lastPhone = phone;
    return const OtpChallenge(
      otpId: kAuthPhoneStubOtpId,
      channel: OtpChannel.phone,
      destination: kAuthPhoneStub,
    );
  }

  @override
  Future<AuthSession> verifyPhoneOtp({
    required String otpId,
    required String code,
  }) async {
    lastOtp = code;
    if (code != kAuthPhoneStubCode) {
      throw const AuthException('Неверный код');
    }
    session = AuthSession(
      userId: '',
      email: '',
      phone: phoneOrStub,
      profileComplete: false,
    );
    return session;
  }

  String get phoneOrStub => lastPhone?.isNotEmpty == true
      ? lastPhone!
      : kAuthPhoneStub;

  @override
  Future<AuthSession> completeProfile({
    required String firstName,
    required String lastName,
    required DateTime birthdate,
    String email = '',
    String phone = '',
    File? avatar,
    bool limitedBrowse = false,
  }) async {
    if (failProfile) {
      throw const AuthException('Не удалось сохранить профиль');
    }
    session = AuthSession(
      userId: session.userId.isEmpty ? 'user00000000001' : session.userId,
      email: email,
      phone: phone,
      firstName: firstName,
      lastName: lastName,
      displayName: '$firstName $lastName'.trim(),
      birthdate: birthdate,
      profileComplete: true,
      limitedBrowse: limitedBrowse,
    );
    return session;
  }
}

class FakePhotoLibrary implements PhotoLibrary {
  FakePhotoLibrary({this.galleryGranted = true, this.cameraGranted = true});

  bool galleryGranted;
  bool cameraGranted;
  bool captureCalled = false;

  @override
  Future<bool> requestGallery({required bool limited}) async => galleryGranted;

  @override
  Future<bool> requestCamera() async => cameraGranted;

  @override
  Future<List<PhotoAssetItem>> list({int limit = 90}) async {
    return const [PhotoAssetItem(id: 'fake-1')];
  }

  @override
  Future<Uint8List?> thumbnail(PhotoAssetItem item) async => null;

  @override
  Future<File?> load(PhotoAssetItem item) async {
    final file = File('${Directory.systemTemp.path}/fake_gallery.png');
    await file.writeAsBytes(_png);
    return file;
  }

  @override
  Future<File?> capture() async {
    captureCalled = true;
    final file = File('${Directory.systemTemp.path}/fake_camera.png');
    await file.writeAsBytes(_png);
    return file;
  }
}

const _png = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
  0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
  0x00, 0x00, 0x03, 0x00, 0x01, 0x00, 0x05, 0xFE, 0xD4, 0xEF, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];
