import 'package:flutter_test/flutter_test.dart';

import 'package:booking/data/pocketbase_any_of_filter.dart';

void main() {
  test('pbAnyOf joins bound equality clauses with ||', () {
    expect(
      pbAnyOf('listing', ['a1', 'b2']),
      "(listing = 'a1' || listing = 'b2')",
    );
  });

  test('pbAnyOf keeps quotes inside values escaped', () {
    expect(
      pbAnyOf('listing', ["x' || kind = 'guest"]),
      r"(listing = 'x\' || kind = \'guest')",
    );
  });

  test('pbAnyOf rejects empty values and non-literal fields', () {
    expect(() => pbAnyOf('listing', const []), throwsArgumentError);
    expect(() => pbAnyOf('listing || 1', ['a']), throwsArgumentError);
  });
}
