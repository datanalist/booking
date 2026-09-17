import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';

import 'auth_callback.dart';
import 'auth_repository.dart';

/// Completes magic-link login when the OS opens the app from an email button.
class AuthLinkListener {
  AuthLinkListener._();

  static final AuthLinkListener instance = AuthLinkListener._();

  StreamSubscription<Uri>? _sub;
  var _started = false;

  Future<void> handleInitialLink() async {
    try {
      final uri = await AppLinks().getInitialLink();
      if (uri != null) {
        await _complete(uri);
      }
    } catch (error, stack) {
      debugPrint('AuthLinkListener initial: $error\n$stack');
    }
  }

  Future<void> listenWhileRunning() async {
    if (_started) return;
    _started = true;
    if (WidgetsBinding.instance.runtimeType.toString().contains('TestWidgets')) {
      return;
    }
    try {
      _sub = AppLinks().uriLinkStream.listen(
        (uri) {
          unawaited(_complete(uri));
        },
        onError: (Object error, StackTrace stack) {
          debugPrint('AuthLinkListener stream: $error\n$stack');
        },
      );
    } catch (error, stack) {
      debugPrint('AuthLinkListener listen: $error\n$stack');
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }

  Future<void> _complete(Uri uri) async {
    if (!AuthCallback.matches(uri)) return;
    try {
      AuthRepositoryScope.authLinkError.value = null;
      await AuthRepositoryScope.instance.completeFromAuthUri(uri);
    } on AuthException catch (error) {
      AuthRepositoryScope.authLinkError.value = error.message;
    } catch (_) {
      AuthRepositoryScope.authLinkError.value =
          'Не удалось войти по ссылке. Запросите новое письмо';
    }
  }
}
