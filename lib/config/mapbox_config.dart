import 'package:flutter/services.dart';

/// Токен Mapbox из `--dart-define` или локального `config/mapbox.env` (не в git).
abstract final class MapboxConfig {
  static String accessToken = '';

  static Future<void> initialize() async {
    accessToken = await _readToken();
  }

  static Future<String> _readToken() async {
    const fromAccess = String.fromEnvironment('ACCESS_TOKEN');
    if (fromAccess.isNotEmpty) return fromAccess;
    const fromMapbox = String.fromEnvironment('MAPBOX_TOKEN');
    if (fromMapbox.isNotEmpty) return fromMapbox;

    for (final asset in const [
      'config/mapbox.env',
      'config/mapbox.env.example',
    ]) {
      try {
        final token = _parse(await rootBundle.loadString(asset));
        if (token.isNotEmpty) return token;
      } catch (_) {
        continue;
      }
    }
    return '';
  }

  static String _parse(String content) {
    for (final raw in content.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      const prefix = 'mapbox_token=';
      if (line.startsWith(prefix)) {
        return line.substring(prefix.length).trim().replaceAll('"', '');
      }
    }
    return '';
  }
}
