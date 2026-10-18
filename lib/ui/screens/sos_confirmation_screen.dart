import 'package:flutter/material.dart';
import '../widgets/big_button.dart';
import '../widgets/screen_scaffold.dart';
import '../widgets/chips_cards_rows.dart';
import '../feedback.dart';

class SOSConfirmationScreen extends StatelessWidget {
  const SOSConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Emergency SOS',
      spokenIntro: 'Emergency SOS. Confirm your request to send an SMS to your emergency contact.',
      body: [
        InfoCard(
          title: 'Send SOS Alert?',
          description: 'This will notify emergency contacts with your last known place. SMS needs mobile network.',
          icon: Icons.warning_rounded,
        ),
      ],
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BigButton(
            label: 'No, go back',
            icon: Icons.arrow_back_rounded,
            sig: Sig.back,
            onPressed: () {
              Fx.haptic(Sig.back);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 16),
          BigButton(
            label: 'Yes, send SOS',
            kind: BigButtonKind.danger,
            icon: Icons.contact_emergency_rounded,
            sig: Sig.sos,
            onPressed: () {
              Fx.haptic(Sig.sos);
              Fx.speak?.call('Sending SOS alert to emergency contacts');
              Navigator.pop(context);
              // TODO: Implement actual SOS sending
            },
          ),
        ],
      ),
    );
  }
}
