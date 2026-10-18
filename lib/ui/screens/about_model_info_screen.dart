import 'package:flutter/material.dart';
import '../widgets/big_button.dart';
import '../widgets/chips_cards_rows.dart';
import '../widgets/screen_scaffold.dart';
import '../feedback.dart';

class AboutModelInfoScreen extends StatelessWidget {
  const AboutModelInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'About the Model',
      spokenIntro: 'About the object detection model. Model detects indoor obstacles for navigation.',
      body: [
        InfoCard(
          title: 'YOLOv8n - Custom Trained',
          description: 'Detects doors, stairs, glass doors, pillars, and wet floor signs. Runs offline on this device.',
          icon: Icons.smart_toy_rounded,
        ),
        const SizedBox(height: 16),
        StatRow(
          label: 'Input Size',
          value: '320 x 320 pixels',
          icon: Icons.crop_free_rounded,
        ),
        const SizedBox(height: 16),
        StatRow(
          label: 'Inference Time',
          value: 'About 20 ms per frame',
          icon: Icons.speed_rounded,
        ),
        const SizedBox(height: 16),
        StatRow(
          label: 'Classes',
          value: '5 classes',
          icon: Icons.category_rounded,
        ),
        const SizedBox(height: 16),
        StatRow(
          label: 'Framework',
          value: 'TensorFlow Lite',
          icon: Icons.memory_rounded,
        ),
        const SizedBox(height: 16),
        const InfoCard(
          title: 'Limitations',
          description: 'This is a hackathon prototype. Not medically certified. Does not replace your white cane.',
          icon: Icons.warning_rounded,
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
            label: 'I understand',
            kind: BigButtonKind.primary,
            onPressed: () {
              Fx.haptic(Sig.primary);
              Fx.speak?.call('I understand the model limitations.');
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
