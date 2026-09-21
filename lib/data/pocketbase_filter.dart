/// Безопасная сборка PocketBase filter-выражений.
///
/// Клиентский API PocketBase принимает **строку фильтра**, не SQL со
/// связанными плейсхолдерами драйвера. Любая склейка пользовательского
/// текста в эту строку — filter injection (`||`, `&&`, кавычки).
///
/// Правила:
/// - Имена коллекций только из [PbCollection], никогда из ввода.
/// - Имена полей — литералы в [expr], не интерполировать ввод в шаблон.
/// - Значения передавать картой в [pbFilter] через `{:name}`.
///
/// Пример:
/// ```dart
/// final filter = pbFilter(
///   'status = "published" && host = {:hostId} && id != {:exceptId}',
///   {'hostId': hostId, 'exceptId': exceptId},
/// );
/// await pb.collection(PbCollection.listings).getFullList(filter: filter);
/// ```
///
/// Это тот же синтаксис, что и [PocketBase.filter] в Dart SDK, плюс
/// экранирование `\` до `'`, чтобы обратный слэш не ломал кавычку.
library;

final _placeholder = RegExp(r'\{:([A-Za-z_][A-Za-z0-9_]*)\}');
final _ident = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

/// Известные коллекции клиента. Новые коллекции добавлять сюда явно.
abstract final class PbCollection {
  static const users = 'users';
  static const listings = 'listings';
  static const bookings = 'bookings';
  static const notifications = 'notifications';
  static const tickets = 'tickets';
  static const reviews = 'reviews';
  static const favorites = 'favorites';
  static const chats = 'chats';
  static const messages = 'messages';

  static const Set<String> known = {
    users,
    listings,
    bookings,
    notifications,
    tickets,
    reviews,
    favorites,
    chats,
    messages,
  };

  /// Возвращает [name], если это литерал из [known].
  ///
  /// Бросает [ArgumentError], если имя не из списка — так нельзя передать
  /// несанитизированный ввод как коллекцию.
  static String requireKnown(String name) {
    if (!known.contains(name)) {
      throw ArgumentError.value(
        name,
        'collection',
        'Unknown PocketBase collection',
      );
    }
    return name;
  }
}

/// Подставляет значения [params] в [expr] вместо `{:name}`.
///
/// Неизвестные плейсхолдеры оставляются как есть (как в SDK).
String pbFilter(String expr, [Map<String, Object?> params = const {}]) {
  if (params.isEmpty) return expr;
  for (final key in params.keys) {
    if (!_ident.hasMatch(key)) {
      throw ArgumentError.value(key, 'params', 'Filter param names must be identifiers');
    }
  }
  return expr.replaceAllMapped(_placeholder, (match) {
    final key = match.group(1)!;
    if (!params.containsKey(key)) return match.group(0)!;
    return pbLiteral(params[key]);
  });
}

/// Литерал значения для filter-языка PocketBase.
String pbLiteral(Object? value) {
  if (value == null) return 'null';
  if (value is bool) return value ? 'true' : 'false';
  if (value is num) {
    if (value.isNaN || value.isInfinite) {
      throw ArgumentError.value(
        value,
        'value',
        'Non-finite numbers cannot be used in filters',
      );
    }
    return '$value';
  }
  if (value is DateTime) {
    final utc = value.toUtc().toIso8601String().replaceFirst('T', ' ');
    return "'$utc'";
  }
  return "'${_escapeString('$value')}'";
}

String _escapeString(String value) {
  return value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
}
