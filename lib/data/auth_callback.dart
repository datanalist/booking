/// Deep link / magic-link callback for passwordless email login.
abstract final class AuthCallback {
  static const appScheme = 'vallome-booking';
  static const host = 'auth-callback';
  static const magicPath = '/api/vallome/magic-auth';
  static const prefsAuthKey = 'pb_auth';

  static bool matches(Uri uri) {
    if (uri.scheme == appScheme) return true;
    final path = uri.path;
    return path == magicPath ||
        path.endsWith(magicPath) ||
        path.contains(host);
  }

  static String? token(Uri uri) {
    final query = uri.queryParameters['token'];
    if (query != null && query.isNotEmpty) return query;
    final fragment = uri.fragment;
    if (fragment.isEmpty) return null;
    if (fragment.startsWith('token=')) {
      return Uri.decodeQueryComponent(fragment.substring(6));
    }
    return Uri.splitQueryString(fragment)['token'];
  }

  static String? otpId(Uri uri) {
    return _firstNonEmpty(uri, const ['id', 'otpId', 'otp_id']);
  }

  static String? code(Uri uri) {
    return _firstNonEmpty(uri, const ['code', 'password']);
  }

  static String? _firstNonEmpty(Uri uri, List<String> keys) {
    final query = uri.queryParameters;
    final fragment = uri.fragment.isEmpty
        ? const <String, String>{}
        : Uri.splitQueryString(uri.fragment);
    for (final key in keys) {
      final value = query[key] ?? fragment[key];
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }
}
