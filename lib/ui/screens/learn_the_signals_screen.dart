import 'package:flutter/material.dart';
import '../widgets/big_button.dart';
import '../widgets/chips_cards_rows.dart';
import '../widgets/screen_scaffold.dart';
import '../feedback.dart';

class LearnTheSignalsScreen extends StatelessWidget {
  const LearnTheSignalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Learn the Signals',
      spokenIntro: 'Learn the signals. Tap each signal to hear its sound and feel its vibration.',
      body: [
        InfoCard(
          title: 'Practice touch and sound',
          description: 'Tap each signal to hear its sound and feel its unique vibration pattern.',
          icon: Icons.school_rounded,
        ),
        const SizedBox(height: 16),
        SignalRow(
          title: 'Danger Signal',
          description: 'Long-short-long vibration. High-pitched warning tone.',
          icon: Icons.report_problem_rounded,
          sig: Sig.sos,
          earcon: 'danger',
        ),
        const SizedBox(height: 16),
        SignalRow(
          title: 'Success Signal',
          description: 'Three rising pulses. Cheerful melodic chime.',
          icon: Icons.check_circle_rounded,
          sig: Sig.success,
          earcon: 'success',
        ),
        const SizedBox(height: 16),
        SignalRow(
          title: 'Turn Signal',
          description: 'Sharp double-tick. Short directional earcon.',
          icon: Icons.turn_right_rounded,
          sig: Sig.repeat,
          earcon: 'select',
        ),
        const SizedBox(height: 16),
        SignalRow(
          title: 'Reached Goal',
          description: 'Continuous steady pulse. Long success tone.',
          icon: Icons.sports_score_rounded,
          sig: Sig.success,
          earcon: 'success',
        ),
      ],
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BigButton(
            label: 'Back',
            icon: Icons.arrow_back_ios_new_rounded,
            onPressed: () {
              Fx.haptic(Sig.back);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 16),
          BigButton(
            label: 'I understand the signals',
            kind: BigButtonKind.primary,
            onPressed: () {
              Fx.haptic(Sig.primary);
              Fx.speak?.call('I understand the signals.');
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
