import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../widgets/big_button.dart';
import '../widgets/chips_cards_rows.dart';
import '../widgets/screen_scaffold.dart';
import '../feedback.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ScreenScaffold(
        title: 'Wayze',
        subtitle: 'See the way. Feel the way.',
        spokenIntro: 'Wayze. Indoor navigation and hazard alerts.',
        topExtras: const [StatusChip(label: 'Cane sensor and beacons: simulated', icon: Icons.science_rounded, color: Color(0xFFFF9F43))],
        body: const [
          InfoCard(title: 'Works with your white cane', description: 'Camera tells what. Cane sensor tells how far. Haptics buzz before voice.', icon: Icons.visibility_rounded),
          InfoCard(title: 'Works offline', description: 'Detection, voice and navigation run on this device.', icon: Icons.cloud_off_rounded),
        ],
        bottom: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          BigButton(label: 'Where am I?', icon: Icons.my_location_rounded, onPressed: () async {
            Fx.haptic(Sig.primary);
            final service = ref.read(locationQueryServiceProvider);
            await service.queryAndSpeak();
          }),
          const SizedBox(height: 16),
          BigButton(label: 'Settings', icon: Icons.settings_rounded, onPressed: () {
            Fx.haptic(Sig.primary);
            Navigator.pushNamed(context, '/settings');
          }),
          const SizedBox(height: 16),
          BigButton(label: 'Obstacle Detection', icon: Icons.visibility_rounded, onPressed: () {
            Fx.haptic(Sig.primary);
            Navigator.pushNamed(context, '/camera');
          }),
          const SizedBox(height: 16),
          BigButton(label: 'YOLO Model Benchmark & Test', icon: Icons.speed_rounded, onPressed: () {
            Fx.haptic(Sig.primary);
            Navigator.pushNamed(context, '/model_test');
          }),
          const SizedBox(height: 16),
          BigButton(label: 'Indoor Map Setup & Share', icon: Icons.map_rounded, onPressed: () {
            Fx.haptic(Sig.primary);
            Navigator.pushNamed(context, '/map_setup');
          }),
          const SizedBox(height: 16),
          BigButton(label: 'Sensor & Vision Debugger', icon: Icons.tune_rounded, onPressed: () {
            Fx.haptic(Sig.primary);
            Navigator.pushNamed(context, '/debug');
          }),
          const SizedBox(height: 16),
          BigButton(label: 'Demo Simulation', icon: Icons.science_rounded, onPressed: () {
            Fx.haptic(Sig.primary);
            Navigator.pushNamed(context, '/demo');
          }),
          const SizedBox(height: 16),
          BigButton(label: 'Start Guiding', icon: Icons.navigation_rounded, kind: BigButtonKind.primary, onPressed: () {
            Fx.haptic(Sig.primary);
            Navigator.pushNamed(context, '/destination');
          }),
        ]),
      );
}
