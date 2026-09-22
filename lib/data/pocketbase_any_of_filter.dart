import 'pocketbase_filter.dart';

final _field = RegExp(r'^[A-Za-z_][A-Za-z0-9_.]*$');

/// `(field = 'a' || field = 'b')` — совпадение поля с любым из [values].
///
/// PocketBase `~` / `?~` — это SQL `LIKE '%…%'`, а не regex, поэтому
/// `field ?~ 'a|b'` не находит ни одной записи.
String pbAnyOf(String field, Iterable<String> values) {
  if (!_field.hasMatch(field)) {
    throw ArgumentError.value(field, 'field', 'Filter field must be a literal');
  }
  final clauses = [for (final value in values) '$field = ${pbLiteral(value)}'];
  if (clauses.isEmpty) {
    throw ArgumentError.value(values, 'values', 'Need at least one value');
  }
  return '(${clauses.join(' || ')})';
}
