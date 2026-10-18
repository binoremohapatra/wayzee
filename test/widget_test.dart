import 'package:flutter_test/flutter_test.dart';

import 'package:wayze/main.dart';

void main() {
  testWidgets('App starts correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const WayzeApp());

    // Verify that the app builds
    expect(find.byType(WayzeApp), findsOneWidget);
  });
}
