import 'package:flutter/material.dart';
import '../feedback.dart';
import 'big_button.dart';

/// Back always bottom-left, primary action always lowest/right: same place on every screen.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    this.onBack,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryIcon,
    this.primaryKind = BigButtonKind.primary,
  });
  final VoidCallback? onBack;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final IconData? primaryIcon;
  final BigButtonKind primaryKind;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (onBack != null) ...[
          SizedBox(
            width: 150,
            child: BigButton(
              label: 'Back',
              icon: Icons.arrow_back_ios_new_rounded,
              onPressed: onBack!,
              sig: Sig.back,
              hint: 'Go to the previous screen',
            ),
          ),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: BigButton(label: primaryLabel, icon: primaryIcon, kind: primaryKind, onPressed: onPrimary),
        ),
      ],
    );
  }
}
