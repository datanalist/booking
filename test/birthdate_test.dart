import 'package:flutter_test/flutter_test.dart';

import 'package:booking/data/birthdate.dart';

void main() {
  test('masks digits as DD.MM.YYYY', () {
    expect(maskBirthdateInput('1'), '1');
    expect(maskBirthdateInput('12'), '12');
    expect(maskBirthdateInput('1203'), '12.03');
    expect(maskBirthdateInput('12031990'), '12.03.1990');
  });

  test('rejects today, future and pre-1920 dates', () {
    final now = DateTime(2026, 9, 16);
    expect(
      () => parseBirthdate('16.09.2026', now: now),
      throwsA(isA<BirthdateParseException>()),
    );
    expect(
      () => parseBirthdate('17.09.2026', now: now),
      throwsA(isA<BirthdateParseException>()),
    );
    expect(
      () => parseBirthdate('01.01.1919', now: now),
      throwsA(isA<BirthdateParseException>()),
    );
    expect(parseBirthdate('01.01.1990', now: now), DateTime(1990, 1, 1));
  });

  test('formats calendar date as DD.MM.YYYY', () {
    expect(formatBirthdate(DateTime(1995, 8, 17)), '17.08.1995');
  });

  test('age helper treats under 18 as not adult', () {
    final now = DateTime(2026, 9, 16);
    expect(isAdult(DateTime(2010, 1, 1), now: now), isFalse);
    expect(isAdult(DateTime(2000, 1, 1), now: now), isTrue);
  });
}
