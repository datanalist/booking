import 'package:pocketbase/pocketbase.dart';

import 'pocketbase_client.dart';

/// Пароль сид-пользователя авторизации (`scripts/seed_auth_stub.py`).
/// В макете нет поля пароля — вкладка Email входит этим паролем.
const kAuthStubPassword = 'SeedPass123!';

class AuthSession {
  const AuthSession({required this.userId, required this.email});

  final String userId;
  final String email;
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class AuthRepository {
  Future<AuthSession> signInWithEmail(String email);
}

class AuthRepositoryScope {
  static AuthRepository instance = PocketBaseAuthRepository();
}

class PocketBaseAuthRepository implements AuthRepository {
  PocketBaseAuthRepository({PocketBase? client}) : _pb = client ?? pocketBase;

  final PocketBase _pb;

  @override
  Future<AuthSession> signInWithEmail(String email) async {
    final identity = email.trim();
    try {
      final auth = await _pb
          .collection('users')
          .authWithPassword(identity, kAuthStubPassword);
      final record = auth.record;
      return AuthSession(
        userId: record.id,
        email: record.get<String>('email', identity),
      );
    } on ClientException catch (error) {
      throw AuthException(_messageFor(error));
    }
  }

  static String _messageFor(ClientException error) {
    final status = error.statusCode;
    if (status == 400 || status == 401 || status == 403) {
      return 'Пользователь не найден или вход не удался';
    }
    return 'Не удалось войти. Проверьте соединение';
  }
}
