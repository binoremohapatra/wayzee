import 'package:flutter/material.dart';
import '../../core/theme/accessible_colors.dart';
import '../../domain/safety/safety_disclaimer.dart';
import '../widgets/accessible_scaffold.dart';
import '../widgets/accessible_tactile_button.dart';

class FirstLaunchDisclaimerScreen extends StatelessWidget {
  final SafetyDisclaimer safetyDisclaimer;
  final VoidCallback onAccepted;

  const FirstLaunchDisclaimerScreen({
    super.key,
    required this.safetyDisclaimer,
    required this.onAccepted,
  });

  @override
  Widget build(BuildContext context) {
    return AccessibleScaffold(
      screenTitle: 'Safety Disclaimer',
      spokenScreenTitle: 'Important safety disclaimer. Wayze is a supplement to the white cane, never a replacement.',
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 80.0,
                color: AccessibleColors.warning,
              ),
              const SizedBox(height: 24.0),
              const Text(
                'CRITICAL SAFETY NOTICE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AccessibleColors.warning,
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16.0),
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: AccessibleColors.surface,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: AccessibleColors.warning, width: 2.0),
                ),
                child: const Text(
                  SafetyDisclaimer.disclaimerText,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.0,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: AccessibleColors.surface,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: AccessibleColors.tactileAccent, width: 2.0),
                ),
                child: const Text(
                  SafetyDisclaimer.disclaimerHindi,
                  style: TextStyle(
                    color: AccessibleColors.tactileAccent,
                    fontSize: 20.0,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 32.0),
              AccessibleTactileButton(
                label: 'I Understand & Agree',
                hint: 'Double tap to accept the disclaimer and enter Wayze',
                onPressed: () async {
                  await safetyDisclaimer.acceptDisclaimer();
                  onAccepted();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
