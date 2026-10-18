import 'package:flutter/material.dart';
import '../widgets/big_button.dart';
import '../widgets/chips_cards_rows.dart';
import '../widgets/screen_scaffold.dart';
import '../feedback.dart';

class DemoSimulationScreen extends StatefulWidget {
  const DemoSimulationScreen({super.key});

  @override
  State<DemoSimulationScreen> createState() => _DemoSimulationScreenState();
}

class _DemoSimulationScreenState extends State<DemoSimulationScreen> {
  double _caneDistance = 150.0; // cm
  bool _simulateStairs = false;

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Simulation',
      spokenIntro: 'Simulation mode. Adjust cane distance and simulate navigation.',
      topExtras: const [
        StatusChip(label: 'Hardware simulated for testing', icon: Icons.science_rounded, color: Color(0xFF4CD08C)),
      ],
      body: [
        InfoCard(
          title: 'Cane Sensor and Beacons Simulated',
          description: 'Hardware next phase. Use this for demo and testing.',
          icon: Icons.info_rounded,
        ),
        const SizedBox(height: 16),
        StepperRow(
          label: 'Cane Sensor Distance',
          valueText: '${_caneDistance.toInt()} cm',
          onMinus: () {
            setState(() {
              _caneDistance = (_caneDistance - 20).clamp(0, 300);
            });
            Fx.speak?.call('Cane distance ${_caneDistance.toInt()} centimeters');
          },
          onPlus: () {
            setState(() {
              _caneDistance = (_caneDistance + 20).clamp(0, 300);
            });
            Fx.speak?.call('Cane distance ${_caneDistance.toInt()} centimeters');
          },
          description: 'Simulated ultrasonic distance from obstacle',
        ),
        const SizedBox(height: 16),
        SwitchRow(
          label: 'Simulate Stairs Ahead',
          value: _simulateStairs,
          onChanged: (value) {
            setState(() {
              _simulateStairs = value;
            });
            if (value) {
              Fx.haptic(Sig.error);
              Fx.speak?.call('Stairs ahead. Be careful.');
            } else {
              Fx.haptic(Sig.on);
              Fx.speak?.call('Stairs simulation turned off.');
            }
          },
          description: 'Toggle stairs detection simulation',
        ),
        const SizedBox(height: 16),
        BigButton(
          label: 'I reached the next beacon',
          icon: Icons.check_circle_rounded,
          onPressed: () {
            Fx.haptic(Sig.success);
            Fx.speak?.call('Reached next beacon. Navigation continuing.');
            // TODO: Advance navigation state
          },
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
            label: 'Apply Simulation',
            kind: BigButtonKind.primary,
            onPressed: () {
              Fx.haptic(Sig.primary);
              Fx.speak?.call('Simulation applied. Cane distance ${_caneDistance.toInt()} cm. Stairs ${_simulateStairs ? "on" : "off"}.');
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
