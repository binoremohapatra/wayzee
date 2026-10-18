import 'package:flutter/material.dart';
import '../widgets/big_button.dart';
import '../widgets/chips_cards_rows.dart';
import '../widgets/screen_scaffold.dart';
import '../widgets/guiding_widgets.dart';
import '../feedback.dart';

class LiveGuidingScreen extends StatefulWidget {
  const LiveGuidingScreen({super.key});

  @override
  State<LiveGuidingScreen> createState() => _LiveGuidingScreenState();
}

class _LiveGuidingScreenState extends State<LiveGuidingScreen> {
  final String _currentInstruction = 'Go straight';
  final String _nextBeacon = 'Beacon 2: Turn right';
  final int _distanceToNext = 12; // steps

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Guiding',
      spokenIntro: 'Live guiding. Current instruction: $_currentInstruction.',
      topExtras: const [
        StatusChip(label: 'Beacon navigation: simulated', icon: Icons.science_rounded, color: Color(0xFFFF9F43)),
      ],
      body: [
        DirectionArrow(direction: Direction.forward),
        const SizedBox(height: 32),
        InstructionBlock(
          instruction: _currentInstruction,
          nextBeacon: _nextBeacon,
          distance: _distanceToNext,
        ),
        const SizedBox(height: 16),
        const InfoCard(
          title: 'Hold your phone',
          description: 'Keep phone upright. Follow the arrow direction.',
          icon: Icons.phone_android_rounded,
        ),
      ],
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BigButton(
            label: 'Stop Guiding',
            kind: BigButtonKind.danger,
            icon: Icons.stop_rounded,
            onPressed: () {
              Fx.haptic(Sig.off);
              Fx.speak?.call('Navigation stopped.');
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 16),
          BigButton(
            label: 'SOS',
            kind: BigButtonKind.danger,
            icon: Icons.emergency_rounded,
            onPressed: () {
              Fx.haptic(Sig.sos);
              Navigator.pushNamed(context, '/sos');
            },
          ),
          const SizedBox(height: 16),
          BigButton(
            label: 'Reached Place',
            kind: BigButtonKind.primary,
            icon: Icons.check_circle_rounded,
            onPressed: () {
              Fx.haptic(Sig.success);
              Fx.speak?.call('You have reached your destination.');
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
