/// Дата рождения в формате ДД.ММ.ГГГГ и правила с макета регистрации.
class BirthdateParseException implements Exception {
  const BirthdateParseException(this.message);
  final String message;
  @override
  String toString() => message;
}

final _digits = RegExp(r'[^0-9]');

/// Календарная дата как на макете: `17.08.1995`.
String formatBirthdate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString().padLeft(4, '0');
  return '$day.$month.$year';
}

/// Маска ввода: `12` → `12.`, `1203` → `12.03.`, `12031990` → `12.03.1990`.
String maskBirthdateInput(String raw) {
  final digits = raw.replaceAll(_digits, '');
  final clipped = digits.length > 8 ? digits.substring(0, 8) : digits;
  final buffer = StringBuffer();
  for (var i = 0; i < clipped.length; i++) {
    if (i == 2 || i == 4) buffer.write('.');
    buffer.write(clipped[i]);
  }
  return buffer.toString();
}

DateTime parseBirthdate(String raw, {DateTime? now}) {
  final masked = maskBirthdateInput(raw);
  final parts = masked.split('.');
  if (parts.length != 3 || parts[2].length != 4) {
    throw const BirthdateParseException('Введите дату в формате ДД.ММ.ГГГГ');
  }
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) {
    throw const BirthdateParseException('Введите дату в формате ДД.ММ.ГГГГ');
  }
  final candidate = DateTime(year, month, day);
  if (candidate.year != year ||
      candidate.month != month ||
      candidate.day != day) {
    throw const BirthdateParseException('Такой даты не существует');
  }
  final today = _dateOnly(now ?? DateTime.now());
  final value = _dateOnly(candidate);
  if (value.year < 1920) {
    throw const BirthdateParseException('Дата рождения должна быть после 1920 года');
  }
  if (value.isAfter(today)) {
    throw const BirthdateParseException('Дата рождения не может быть в будущем');
  }
  if (value == today) {
    throw const BirthdateParseException('Дата рождения не может быть сегодняшней');
  }
  return value;
}

int ageOn(DateTime birthdate, DateTime onDate) {
  var age = onDate.year - birthdate.year;
  final hadBirthday = onDate.month > birthdate.month ||
      (onDate.month == birthdate.month && onDate.day >= birthdate.day);
  if (!hadBirthday) age -= 1;
  return age;
}

bool isAdult(DateTime birthdate, {DateTime? now}) {
  return ageOn(birthdate, _dateOnly(now ?? DateTime.now())) >= 18;
}

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);
