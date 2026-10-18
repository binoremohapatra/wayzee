import 'package:flutter/material.dart';
import '../../core/theme/accessible_colors.dart';
import '../../core/accessibility/accessible_semantics.dart';
import '../../core/accessibility/haptic_service.dart';

/// Large tactile button with high contrast, haptic feedback, and complete TalkBack semantics.
class AccessibleTactileButton extends StatelessWidget {
  final String label;
  final String? hint;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final double minHeight;
  final bool isDestructive;
  final HapticService hapticService;

  const AccessibleTactileButton({
    super.key,
    required this.label,
    this.hint,
    required this.onPressed,
    this.icon,
    this.backgroundColor = AccessibleColors.surface,
    this.textColor = AccessibleColors.textPrimary,
    this.borderColor = AccessibleColors.tactileAccent,
    this.minHeight = 68.0,
    this.isDestructive = false,
    this.hapticService = const SystemHapticService(),
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor =
        isDestructive ? AccessibleColors.danger : borderColor;
    final effectiveTextColor =
        isDestructive ? AccessibleColors.danger : textColor;

    Future<void> handleTap() async {
      if (isDestructive) {
        await hapticService.warning();
      } else {
        await hapticService.confirm();
      }
      onPressed();
    }

    return Semantics(
      label: label,
      hint: hint ?? AccessibleSemantics.actionHint(label.toLowerCase()),
      button: true,
      enabled: true,
      onTap: handleTap,
      excludeSemantics: true,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16.0),
        child: InkWell(
          onTap: handleTap,
          borderRadius: BorderRadius.circular(16.0),
          child: Container(
            constraints: BoxConstraints(minHeight: minHeight),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(
                color: effectiveBorderColor,
                width: 3.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 32.0,
                    color: effectiveTextColor,
                  ),
                  const SizedBox(width: 16.0),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: effectiveTextColor,
                      fontSize: 22.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
