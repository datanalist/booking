import 'package:flutter_test/flutter_test.dart';

import 'package:booking/data/pocketbase_filter.dart';

void main() {
  group('PbCollection.requireKnown', () {
    test('accepts hardcoded collection names', () {
      expect(PbCollection.requireKnown(PbCollection.users), 'users');
      expect(PbCollection.requireKnown(PbCollection.listings), 'listings');
      expect(PbCollection.requireKnown(PbCollection.bookings), 'bookings');
    });

    test('rejects unsanitized collection names', () {
      expect(
        () => PbCollection.requireKnown('users; drop table'),
        throwsArgumentError,
      );
      expect(
        () => PbCollection.requireKnown('listings || id != ""'),
        throwsArgumentError,
      );
    });
  });

  group('pbFilter', () {
    test('binds strings with official {:name} placeholders', () {
      expect(
        pbFilter(
          'guest = {:userId} || host = {:userId}',
          {'userId': 'abc123'},
        ),
        "guest = 'abc123' || host = 'abc123'",
      );
    });

    test('keeps published-status literals and binds ids', () {
      expect(
        pbFilter(
          'status = "published" && host = {:hostId} && id != {:exceptId}',
          {'hostId': 'host1', 'exceptId': 'list1'},
        ),
        'status = "published" && host = \'host1\' && id != \'list1\'',
      );
    });

    test('does not let quotes or operators break out of a value', () {
      const payload = 'x" || status = "published" || guest = "';
      final filter = pbFilter('guest = {:userId}', {'userId': payload});
      expect(filter, "guest = 'x\" || status = \"published\" || guest = \"'");
      expect(filter.startsWith("guest = '"), isTrue);
      expect(filter.endsWith("'"), isTrue);
      expect(filter.contains('guest = {:userId}'), isFalse);
    });

    test('escapes backslash before quotes so a slash cannot cancel quoting', () {
      const payload = r"a\' || status = 'published";
      expect(
        pbFilter('guest = {:userId}', {'userId': payload}),
        r"guest = 'a\\\' || status = \'published'",
      );
    });

    test('binds numbers, bools, null and dates without concatenation', () {
      final when = DateTime.utc(2026, 9, 17, 12);
      expect(pbLiteral(12), '12');
      expect(pbLiteral(true), 'true');
      expect(pbLiteral(null), 'null');
      expect(pbLiteral(when), "'2026-09-17 12:00:00.000Z'");
      expect(
        pbFilter(
          'listing = {:listing} && check_in < {:end} && check_out > {:start}',
          {
            'listing': 'lid',
            'end': '2026-09-20T00:00:00.000Z',
            'start': '2026-09-17T00:00:00.000Z',
          },
        ),
        "listing = 'lid' && check_in < '2026-09-20T00:00:00.000Z' && "
        "check_out > '2026-09-17T00:00:00.000Z'",
      );
    });

    test('rejects illegal param names and non-finite numbers', () {
      expect(
        () => pbFilter('a = {:x}', {'x;y': '1'}),
        throwsArgumentError,
      );
      expect(() => pbLiteral(double.nan), throwsArgumentError);
      expect(() => pbLiteral(double.infinity), throwsArgumentError);
    });

    test('leaves unknown placeholders in place', () {
      expect(
        pbFilter('a = {:missing} && b = {:b}', {'b': 'ok'}),
        "a = {:missing} && b = 'ok'",
      );
    });
  });
}
