import 'package:flutter/material.dart';
import '../widgets/big_button.dart';
import '../widgets/screen_scaffold.dart';
import '../widgets/chips_cards_rows.dart';
import '../widgets/guiding_widgets.dart';
import '../feedback.dart';

class FallDetectedScreen extends StatelessWidget {
  const FallDetectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Fall Detected',
      spokenIntro: 'Fall detected. Sending SOS in 15 seconds unless you cancel.',
      body: [
        const CountdownRing(remaining: 15, total: 15),
        const SizedBox(height: 32),
        InfoCard(
          title: 'Sending SOS in 15 seconds',
          description: 'If you do not cancel, an SMS with your last known place will be sent to your emergency contact.',
          icon: Icons.report_problem_rounded,
        ),
      ],
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BigButton(
            label: "I'm OK, Cancel",
            kind: BigButtonKind.danger,
            icon: Icons.check_circle_rounded,
            sig: Sig.success,
            onPressed: () {
              Fx.haptic(Sig.success);
              Fx.speak?.call('SOS cancelled. You are safe.');
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 16),
          BigButton(
            label: 'Send SOS Now',
            kind: BigButtonKind.danger,
            icon: Icons.emergency_share_rounded,
            sig: Sig.sos,
            onPressed: () {
              Fx.haptic(Sig.sos);
              Fx.speak?.call('Sending SOS immediately.');
              Navigator.pop(context);
              // TODO: Implement actual SOS sending
            },
          ),
        ],
      ),
    );
  }
}
