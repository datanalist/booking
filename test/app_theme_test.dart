import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booking/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'app scrollBehavior does not apply a stretching overscroll indicator',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            scrollBehavior: AppTheme.scrollBehavior,
            home: const Scaffold(body: SizedBox()),
          ),
        );

        final context = tester.element(find.byType(Scaffold));
        final behavior = ScrollConfiguration.of(context);
        expect(behavior, isA<AppScrollBehavior>());
        expect(behavior.getScrollPhysics(context), isA<ClampingScrollPhysics>());

        const child = SizedBox.shrink();
        final indicator = behavior.buildOverscrollIndicator(
          context,
          child,
          const ScrollableDetails(direction: AxisDirection.down),
        );
        expect(indicator, same(child));
        expect(indicator, isNot(isA<StretchingOverscrollIndicator>()));
        expect(find.byType(StretchingOverscrollIndicator), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
