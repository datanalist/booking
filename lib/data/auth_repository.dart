import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import 'auth_callback.dart';
import 'pocketbase_client.dart';

/// Заглушка только для вкладки телефона (код на номер не отправляем).
const kAuthPhoneStub = '+79999999999';
const kAuthPhoneStubCode = '77777';
const kAuthPhoneStubOtpId = 'stub-phone-otp';

enum OtpChannel { email, phone }

class OtpChallenge {
  const OtpChallenge({
    required this.otpId,
    required this.channel,
    required this.destination,
  });

  final String otpId;
  final OtpChannel channel;
  final String destination;
}

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.email,
    this.phone = '',
    this.firstName = '',
    this.lastName = '',
    this.displayName = '',
    this.avatarUrl,
    this.birthdate,
    this.profileComplete = false,
    this.limitedBrowse = false,
  });

  final String userId;
  final String email;
  final String phone;
  final String firstName;
  final String lastName;
  final String displayName;
  final String? avatarUrl;
  final DateTime? birthdate;
  final bool profileComplete;
  final bool limitedBrowse;
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class AuthRepository {
  Future<OtpChallenge> requestEmailOtp(String email);
  Future<AuthSession> verifyEmailOtp({
    required String otpId,
    required String code,
  });

  Future<OtpChallenge> requestPhoneOtp(String phone);
  Future<AuthSession> verifyPhoneOtp({
    required String otpId,
    required String code,
  });

  Future<AuthSession> completeProfile({
    required String firstName,
    required String lastName,
    required DateTime birthdate,
    String email = '',
    String phone = '',
    File? avatar,
    bool limitedBrowse = false,
  });

  /// Обновляет анкету текущего пользователя. Id записи берётся из auth store,
  /// не из ввода: чужой `users` так не переписать.
  Future<AuthSession> updatePersonalData({
    required String firstName,
    required String lastName,
    required DateTime birthdate,
    required String email,
    File? avatar,
    bool limitedBrowse = false,
  });

  AuthSession? currentSession();
  Future<AuthSession?> restoreSession();
  Future<AuthSession?> completeFromAuthUri(Uri uri);
  Future<AuthSession?> pollMagicLogin(String otpId);
  Future<void> signOut();
}

class AuthRepositoryScope {
  static AuthRepository instance = PocketBaseAuthRepository();
  static final ValueNotifier<AuthSession?> session = ValueNotifier<AuthSession?>(null);
  static final ValueNotifier<String?> authLinkError = ValueNotifier<String?>(null);
}

class PocketBaseAuthRepository implements AuthRepository {
  PocketBaseAuthRepository({this._client});

  final PocketBase? _client;
  PocketBase get _pb => _client ?? pocketBase;
  AuthSession? _session;
  String _pendingPhone = '';

  @override
  AuthSession? currentSession() => _session ?? _fromRecord(_pb.authStore.record);

  @override
  Future<AuthSession?> restoreSession() async {
    if (!_pb.authStore.isValid) {
      _session = null;
      AuthRepositoryScope.session.value = null;
      return null;
    }
    try {
      final auth = await _pb.collection('users').authRefresh();
      _session = _fromRecord(auth.record);
    } on ClientException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await signOut();
        return null;
      }
      _session = _fromRecord(_pb.authStore.record);
    }
    if (_session == null || _session!.userId.isEmpty) {
      await signOut();
      return null;
    }
    AuthRepositoryScope.session.value = _session;
    return _session;
  }

  @override
  Future<AuthSession?> completeFromAuthUri(Uri uri) async {
    if (!AuthCallback.matches(uri)) return null;
    final token = AuthCallback.token(uri);
    if (token != null && token.isNotEmpty) {
      return _signInWithToken(token);
    }
    final otpId = AuthCallback.otpId(uri);
    final code = AuthCallback.code(uri);
    if (otpId != null && code != null) {
      return verifyEmailOtp(otpId: otpId, code: code);
    }
    throw const AuthException(
      'Ссылка недействительна или устарела. Запросите новое письмо',
    );
  }

  @override
  Future<AuthSession?> pollMagicLogin(String otpId) async {
    final id = otpId.trim();
    if (id.isEmpty) return null;
    try {
      final raw = await _pb.send(
        '/api/vallome/magic-wait',
        query: {'id': id},
      );
      final token = raw is Map ? raw['token']?.toString() ?? '' : '';
      if (token.isEmpty) return null;
      return _signInWithToken(token);
    } on ClientException catch (error) {
      if (error.statusCode == 404 ||
          error.statusCode == 204 ||
          error.statusCode == 400) {
        return null;
      }
      return null;
    }
  }

  Future<AuthSession> _signInWithToken(String token) async {
    try {
      _pb.authStore.save(token, _pb.authStore.record);
      final auth = await _pb.collection('users').authRefresh();
      _session = _fromRecord(auth.record);
      if (_session == null || _session!.userId.isEmpty) {
        throw const AuthException(
          'Ссылка недействительна или устарела. Запросите новое письмо',
        );
      }
      AuthRepositoryScope.session.value = _session;
      return _session!;
    } on AuthException {
      rethrow;
    } on ClientException catch (error) {
      _pb.authStore.clear();
      throw AuthException(_messageFor(error, otp: true));
    }
  }

  @override
  Future<void> signOut() async {
    _session = null;
    _pendingPhone = '';
    _pb.authStore.clear();
    AuthRepositoryScope.session.value = null;
    AuthRepositoryScope.authLinkError.value = null;
  }

  @override
  Future<OtpChallenge> requestEmailOtp(String email) async {
    final identity = email.trim();
    if (!_looksLikeEmail(identity)) {
      throw const AuthException('Введите корректный email');
    }
    try {
      // Без записи в users PocketBase не шлёт письмо, но отдаёт фиктивный otpId.
      await _ensureUserForEmailOtp(identity);
      final result = await _pb.collection('users').requestOTP(identity);
      _pendingPhone = '';
      return OtpChallenge(
        otpId: result.otpId,
        channel: OtpChannel.email,
        destination: identity,
      );
    } on ClientException catch (error) {
      throw AuthException(_messageFor(error, email: true));
    }
  }

  Future<void> _ensureUserForEmailOtp(String email) async {
    try {
      final password = _randomPassword();
      await _pb.collection('users').create(
        body: {
          'email': email,
          'password': password,
          'passwordConfirm': password,
        },
      );
    } on ClientException catch (error) {
      if (_isExistingEmail(error) || error.statusCode == 403) return;
      throw AuthException(_messageFor(error, email: true));
    }
  }

  @override
  Future<AuthSession> verifyEmailOtp({
    required String otpId,
    required String code,
  }) async {
    try {
      final auth = await _pb.collection('users').authWithOTP(otpId, code.trim());
      _session = _fromRecord(
        auth.record,
        fallbackEmail: auth.record.get<String>('email', ''),
      );
      AuthRepositoryScope.session.value = _session;
      return _session!;
    } on ClientException catch (error) {
      throw AuthException(_messageFor(error, otp: true));
    }
  }

  @override
  Future<OtpChallenge> requestPhoneOtp(String phone) async {
    final normalized = phone.replaceAll(RegExp(r'\s'), '');
    if (normalized.isEmpty) {
      throw const AuthException('Введите номер телефона');
    }
    _pendingPhone = normalized;
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
    if (otpId != kAuthPhoneStubOtpId || code.trim() != kAuthPhoneStubCode) {
      throw const AuthException('Неверный код');
    }
    _session = AuthSession(
      userId: '',
      email: '',
      phone: _pendingPhone.isEmpty ? kAuthPhoneStub : _pendingPhone,
      profileComplete: false,
    );
    AuthRepositoryScope.session.value = _session;
    return _session!;
  }

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
    final first = firstName.trim();
    final last = lastName.trim();
    final display = '$first $last'.trim();
    final body = <String, dynamic>{
      'first_name': first,
      'last_name': last,
      'name': display,
      'birthdate':
          '${birthdate.year.toString().padLeft(4, '0')}-${birthdate.month.toString().padLeft(2, '0')}-${birthdate.day.toString().padLeft(2, '0')} 00:00:00.000Z',
      'emailVisibility': true,
      'limited_browse': limitedBrowse,
    };
    if (phone.trim().isNotEmpty) {
      body['phone'] = phone.trim();
    }

    final files = <http.MultipartFile>[];
    if (avatar != null) {
      files.add(
        http.MultipartFile.fromBytes(
          'avatar',
          await avatar.readAsBytes(),
          filename: 'avatar.jpg',
        ),
      );
    }

    try {
      RecordModel record;
      if (_pb.authStore.isValid && _pb.authStore.record != null) {
        if (email.trim().isNotEmpty) {
          body['email'] = email.trim();
        }
        record = await _pb
            .collection('users')
            .update(_pb.authStore.record!.id, body: body, files: files);
      } else {
        final identity = email.trim();
        if (!_looksLikeEmail(identity)) {
          throw const AuthException('Укажите email, чтобы сохранить профиль');
        }
        final password = _randomPassword();
        record = await _pb
            .collection('users')
            .create(
              body: {
                ...body,
                'email': identity,
                'password': password,
                'passwordConfirm': password,
              },
              files: files,
            );
        await _pb.collection('users').authWithPassword(identity, password);
        record = _pb.authStore.record ?? record;
      }
      _session = _fromRecord(record, fallbackEmail: email);
      AuthRepositoryScope.session.value = _session;
      return _session!;
    } on AuthException {
      rethrow;
    } on ClientException catch (error) {
      throw AuthException(_messageFor(error));
    }
  }

  @override
  Future<AuthSession> updatePersonalData({
    required String firstName,
    required String lastName,
    required DateTime birthdate,
    required String email,
    File? avatar,
    bool limitedBrowse = false,
  }) async {
    final recordId = _pb.authStore.record?.id ?? '';
    if (!_pb.authStore.isValid || recordId.isEmpty) {
      throw const AuthException(
        'Войдите в аккаунт, чтобы сохранить данные',
      );
    }

    final first = _sanitizeName(firstName);
    final last = _sanitizeName(lastName);
    final identity = email.trim();
    if (first.isEmpty || last.isEmpty) {
      throw const AuthException('Укажите имя и фамилию');
    }
    if (!_looksLikeEmail(identity)) {
      throw const AuthException('Введите корректный email');
    }

    final display = '$first $last';
    final body = <String, dynamic>{
      'first_name': first,
      'last_name': last,
      'name': display,
      'birthdate':
          '${birthdate.year.toString().padLeft(4, '0')}-${birthdate.month.toString().padLeft(2, '0')}-${birthdate.day.toString().padLeft(2, '0')} 00:00:00.000Z',
      'emailVisibility': true,
      'limited_browse': limitedBrowse,
    };
    final currentEmail = _pb.authStore.record!.get<String>('email', '');
    if (identity.toLowerCase() != currentEmail.toLowerCase()) {
      body['email'] = identity;
    }

    final files = <http.MultipartFile>[];
    if (avatar != null) {
      files.add(
        http.MultipartFile.fromBytes(
          'avatar',
          await avatar.readAsBytes(),
          filename: 'avatar.jpg',
        ),
      );
    }

    try {
      final record = await _pb
          .collection('users')
          .update(recordId, body: body, files: files);
      _session = _fromRecord(record, fallbackEmail: identity);
      AuthRepositoryScope.session.value = _session;
      return _session!;
    } on ClientException catch (error) {
      if (_isExistingEmail(error)) {
        throw const AuthException('Этот email уже занят');
      }
      throw AuthException(_messageFor(error));
    }
  }

  AuthSession? _fromRecord(RecordModel? record, {String fallbackEmail = ''}) {
    if (record == null) return null;
    final email = record.get<String>('email', fallbackEmail);
    final first = record.get<String>('first_name', '');
    final last = record.get<String>('last_name', '');
    final name = record.get<String>('name', '$first $last'.trim());
    final birthRaw = record.get<String>('birthdate', '');
    return AuthSession(
      userId: record.id,
      email: email,
      phone: record.get<String>('phone', ''),
      firstName: first,
      lastName: last,
      displayName: name.trim(),
      avatarUrl: _avatarUrl(record),
      birthdate: _parsePbDate(birthRaw),
      profileComplete: name.trim().isNotEmpty,
      limitedBrowse: record.get<bool>('limited_browse', false),
    );
  }

  String? _avatarUrl(RecordModel record) {
    final file = record.get<String>('avatar', '');
    if (file.isEmpty) return null;
    return _pb.files.getUrl(record, file).toString();
  }

  static DateTime? _parsePbDate(String raw) {
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static bool _looksLikeEmail(String value) {
    return value.contains('@') && value.contains('.');
  }

  static final _nameCleanup = RegExp(r'\s+');

  static String _sanitizeName(String raw) {
    final trimmed = raw.trim().replaceAll(_nameCleanup, ' ');
    if (trimmed.length <= 80) return trimmed;
    return trimmed.substring(0, 80);
  }

  static String _randomPassword() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#';
    final random = Random.secure();
    return List.generate(18, (_) => chars[random.nextInt(chars.length)]).join();
  }

  static bool _isExistingEmail(ClientException error) {
    if (error.statusCode != 400) return false;
    final data = error.response['data'];
    if (data is! Map) return false;
    final email = data['email'];
    if (email is! Map) return false;
    return email['code'] == 'validation_not_unique';
  }

  static String _messageFor(
    ClientException error, {
    bool email = false,
    bool otp = false,
  }) {
    final status = error.statusCode;
    if (otp && (status == 400 || status == 401 || status == 403)) {
      return 'Ссылка недействительна или устарела. Запросите новое письмо';
    }
    if (email && (status == 400 || status == 403)) {
      return 'Не удалось отправить письмо на эту почту';
    }
    if (status == 400 || status == 401 || status == 403) {
      return 'Не удалось продолжить. Проверьте данные';
    }
    return 'Не удалось продолжить. Проверьте соединение';
  }
}
