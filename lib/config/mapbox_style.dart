import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';

import 'mapbox_config.dart';

/// Подставляет русские подписи в стиль Mapbox Streets (`name_en` → `name_ru`).
String localizeMapboxStyleJson(String source, {String language = 'ru'}) {
  return source
      .replaceAll('"name_en"', '"name_$language"')
      .replaceAll('{name_en}', '{name_$language}');
}

void preferAppFonts(dynamic node) {
  if (node is Map<String, dynamic>) {
    final fonts = node['text-font'];
    if (fonts is List && fonts.isNotEmpty) {
      final stack = fonts.map((item) => item.toString()).join(' ').toLowerCase();
      node['text-font'] = stack.contains('bold')
          ? <String>['Noto Sans Bold']
          : <String>['Noto Sans Regular'];
    }
    for (final value in node.values) {
      preferAppFonts(value);
    }
  } else if (node is List) {
    for (final value in node) {
      preferAppFonts(value);
    }
  }
}

/// Raster Streets с запросом русской локали (если API её учтёт).
String mapboxStreetsRasterUrl(String token) {
  return 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/512'
      '/{z}/{x}/{y}?access_token=$token&language=ru&worldview=ru';
}

String mapboxStreetsRasterFallbackUrl(String token) {
  return 'https://api.mapbox.com/v4/mapbox.streets/{z}/{x}/{y}@2x.png'
      '?access_token=$token&language=ru';
}

Future<Style>? _cachedStyle;

/// Стиль Streets с русскими подписями и теми же векторными тайлами Mapbox.
Future<Style> loadRussianMapboxStyle({
  String? token,
  http.Client? client,
}) async {
  final accessToken = token ?? MapboxConfig.accessToken;
  if (accessToken.isEmpty) {
    throw StateError('Mapbox token is empty');
  }
  if (client == null) {
    return _cachedStyle ??= _loadRussianMapboxStyle(accessToken, null);
  }
  return _loadRussianMapboxStyle(accessToken, client);
}

Future<Style> _loadRussianMapboxStyle(
  String accessToken,
  http.Client? client,
) async {
  final httpClient = client ?? http.Client();
  final ownsClient = client == null;
  try {
    final style = await StyleReader(
      uri: 'mapbox://styles/mapbox/streets-v12?access_token={key}',
      apiKey: accessToken,
    ).read();

    final uri = Uri.parse(
      'https://api.mapbox.com/styles/v1/mapbox/streets-v12',
    ).replace(queryParameters: {'access_token': accessToken});
    final response = await httpClient
        .get(uri)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      return style;
    }

    final localized = localizeMapboxStyleJson(response.body);
    final decoded = jsonDecode(localized);
    if (decoded is! Map<String, dynamic>) return style;
    preferAppFonts(decoded);

    return Style(
      name: style.name,
      theme: ThemeReader().read(decoded),
      providers: style.providers,
      sprites: style.sprites,
      center: style.center,
      zoom: style.zoom,
    );
  } finally {
    if (ownsClient) httpClient.close();
  }
}
