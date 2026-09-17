import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/pocketbase_config.dart';
import 'auth_callback.dart';

/// Общий клиент PocketBase для приложения.
///
/// До [initPocketBase] — in-memory store (тесты). После инициализации
/// токен пишется в SharedPreferences и переживает перезапуск.
PocketBase pocketBase = PocketBase(PocketBaseConfig.url);

Future<void> initPocketBase() async {
  final prefs = await SharedPreferences.getInstance();
  pocketBase = PocketBase(
    PocketBaseConfig.url,
    authStore: AsyncAuthStore(
      save: (data) async => prefs.setString(AuthCallback.prefsAuthKey, data),
      initial: prefs.getString(AuthCallback.prefsAuthKey),
      clear: () async => prefs.remove(AuthCallback.prefsAuthKey),
    ),
  );
}
