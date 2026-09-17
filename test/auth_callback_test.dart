import 'package:flutter_test/flutter_test.dart';

import 'package:booking/data/auth_callback.dart';

void main() {
  test('parses app-scheme magic callback with token', () {
    final uri = Uri.parse('vallome-booking://auth-callback?token=abc.def');
    expect(AuthCallback.matches(uri), isTrue);
    expect(AuthCallback.token(uri), 'abc.def');
    expect(AuthCallback.otpId(uri), isNull);
  });

  test('parses https magic-auth link with otp id and code', () {
    final uri = Uri.parse(
      'https://pb.booking.vallome.ru/api/vallome/magic-auth?id=otp1&code=12345',
    );
    expect(AuthCallback.matches(uri), isTrue);
    expect(AuthCallback.otpId(uri), 'otp1');
    expect(AuthCallback.code(uri), '12345');
  });

  test('ignores unrelated uris', () {
    expect(AuthCallback.matches(Uri.parse('https://example.com/x')), isFalse);
  });
}
