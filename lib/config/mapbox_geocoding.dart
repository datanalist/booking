import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'mapbox_config.dart';

@immutable
class AddressSuggestion {
  const AddressSuggestion({
    required this.label,
    this.city,
    this.latitude,
    this.longitude,
  });

  final String label;
  final String? city;
  final double? latitude;
  final double? longitude;
}

/// Обёртка над Mapbox Geocoding API v5 для подсказок адреса.
abstract final class MapboxGeocoding {
  static const _minQueryLength = 2;

  static Future<List<AddressSuggestion>> suggest(
    String query, {
    http.Client? client,
  }) async {
    final token = MapboxConfig.accessToken;
    final trimmed = query.trim();
    if (token.isEmpty || trimmed.length < _minQueryLength) {
      return const [];
    }

    final encoded = Uri.encodeComponent(trimmed);
    final uri = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/$encoded.json',
    ).replace(
      queryParameters: {
        'access_token': token,
        'autocomplete': 'true',
        'language': 'ru',
        'limit': '6',
        'types': 'address,place,locality,neighborhood,district',
        'worldview': 'ru',
      },
    );

    final httpClient = client ?? http.Client();
    final ownsClient = client == null;
    try {
      final response = await httpClient
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return const [];
      return parseMapboxGeocodingBody(response.body);
    } catch (_) {
      return const [];
    } finally {
      if (ownsClient) httpClient.close();
    }
  }
}

List<AddressSuggestion> parseMapboxGeocodingBody(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) return const [];
  final features = decoded['features'];
  if (features is! List) return const [];

  final result = <AddressSuggestion>[];
  for (final feature in features) {
    if (feature is! Map<String, dynamic>) continue;
    final label = (feature['place_name'] as String?)?.trim();
    if (label == null || label.isEmpty) continue;

    final types = feature['place_type'];
    String? city;
    if (types is List &&
        types.any((type) => type == 'place' || type == 'locality')) {
      city = feature['text'] as String?;
    }

    final context = feature['context'];
    if (city == null && context is List) {
      for (final item in context) {
        if (item is! Map<String, dynamic>) continue;
        final id = item['id'] as String? ?? '';
        if (id.startsWith('place.') || id.startsWith('locality.')) {
          city = item['text'] as String?;
          break;
        }
      }
    }

    double? longitude;
    double? latitude;
    final center = feature['center'];
    if (center is List && center.length >= 2) {
      final lng = center[0];
      final lat = center[1];
      if (lng is num && lat is num) {
        longitude = lng.toDouble();
        latitude = lat.toDouble();
      }
    }

    result.add(
      AddressSuggestion(
        label: label,
        city: city,
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }
  return result;
}
