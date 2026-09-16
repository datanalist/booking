import 'package:booking/data/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  String? lastEmail;
  bool fail = false;
  AuthSession session = const AuthSession(
    userId: 'authstub0000001',
    email: 'example@mail.com',
  );

  @override
  Future<AuthSession> signInWithEmail(String email) async {
    lastEmail = email;
    if (fail) {
      throw const AuthException('Пользователь не найден или вход не удался');
    }
    return AuthSession(userId: session.userId, email: email);
  }
}
