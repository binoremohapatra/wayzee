import 'dart:ui' show SemanticsFlag, SemanticsAction;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayze/core/accessibility/haptic_service.dart';
import 'package:wayze/ui/widgets/accessible_tactile_button.dart';

void main() {
  group('AccessibleTactileButton Accessibility and Widget Tests', () {
    late MockHapticService mockHaptics;

    setUp(() {
      mockHaptics = MockHapticService();
    });

    Widget buildTestHarness(Widget child) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: child,
          ),
        ),
      );
    }

    testWidgets('renders button with accessible label and minimum height constraint',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestHarness(
          AccessibleTactileButton(
            label: 'Start Navigation',
            hint: 'Double tap to begin route guidance',
            onPressed: () {},
            hapticService: mockHaptics,
          ),
        ),
      );

      // Verify label text is found
      expect(find.text('Start Navigation'), findsOneWidget);

      // Verify touch target dimension meets accessible minimum (>= 64dp)
      final buttonSize = tester.getSize(find.byType(AccessibleTactileButton));
      expect(buttonSize.height, greaterThanOrEqualTo(64.0));
    });

    testWidgets('has correct accessibility Semantics properties for screen readers',
        (WidgetTester tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        buildTestHarness(
          AccessibleTactileButton(
            label: 'Emergency Stop',
            hint: 'Double tap to halt guidance immediately',
            isDestructive: true,
            onPressed: () {},
            hapticService: mockHaptics,
          ),
        ),
      );

      // Find semantics node for the button
      final semantics = tester.getSemantics(find.byType(AccessibleTactileButton));
      final data = semantics.getSemanticsData();
      expect(data.label, equals('Emergency Stop'));
      expect(data.hint, equals('Double tap to halt guidance immediately'));
      // ignore: deprecated_member_use
      expect(data.hasFlag(SemanticsFlag.isButton), isTrue);
      // ignore: deprecated_member_use
      expect(data.hasFlag(SemanticsFlag.isEnabled), isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);

      handle.dispose();
    });

    testWidgets('tapping normal button executes onPressed and triggers confirm haptic',
        (WidgetTester tester) async {
      var pressed = false;

      await tester.pumpWidget(
        buildTestHarness(
          AccessibleTactileButton(
            label: 'Obstacle Detection',
            onPressed: () {
              pressed = true;
            },
            hapticService: mockHaptics,
          ),
        ),
      );

      await tester.tap(find.byType(AccessibleTactileButton));
      await tester.pumpAndSettle();

      expect(pressed, isTrue);
      expect(mockHaptics.triggerHistory, contains(HapticPattern.confirm));
      expect(mockHaptics.triggerHistory.length, equals(1));
    });

    testWidgets('tapping destructive button triggers warning haptic pattern',
        (WidgetTester tester) async {
      var cancelled = false;

      await tester.pumpWidget(
        buildTestHarness(
          AccessibleTactileButton(
            label: 'Cancel Route',
            isDestructive: true,
            onPressed: () {
              cancelled = true;
            },
            hapticService: mockHaptics,
          ),
        ),
      );

      await tester.tap(find.byType(AccessibleTactileButton));
      await tester.pumpAndSettle();

      expect(cancelled, isTrue);
      expect(mockHaptics.triggerHistory, contains(HapticPattern.warning));
    });

    testWidgets('renders icon when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestHarness(
          AccessibleTactileButton(
            label: 'Settings',
            icon: Icons.settings,
            onPressed: () {},
            hapticService: mockHaptics,
          ),
        ),
      );

      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });
  });
}
