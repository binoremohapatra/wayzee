import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../feedback.dart';

enum BigButtonKind { primary, outline, danger }

class BigButton extends StatefulWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = BigButtonKind.outline,
    this.hint,
    this.sig = Sig.primary,
  });
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final BigButtonKind kind;
  final String? hint;
  final Sig sig;
  @override
  State<BigButton> createState() => _BigButtonState();
}

class _BigButtonState extends State<BigButton> {
  bool _down = false;

  void _fire() {
    Fx.haptic(widget.sig);
    Fx.earcon?.call(widget.kind == BigButtonKind.danger ? 'danger' : 'select');
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kind;
    final fill = k == BigButtonKind.primary ? WC.accent : Colors.transparent;
    final border = k == BigButtonKind.primary ? WC.accent : (k == BigButtonKind.danger ? WC.bad : WC.line);
    final fg = k == BigButtonKind.primary ? Colors.black : (k == BigButtonKind.danger ? WC.bad : WC.text);
    final reduce = MediaQuery.of(context).disableAnimations;
    return Semantics(
      container: true,
      button: true,
      label: widget.label,
      hint: widget.hint,
      onTap: _fire,
      child: AnimatedScale(
        scale: _down && !reduce ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: InkWell(
          onTap: _fire,
          onHighlightChanged: (h) => setState(() => _down = h),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 30, color: fg),
                  const SizedBox(width: 12),
                ],
                Flexible(
                  child: Text(widget.label, textAlign: TextAlign.center, style: WT.button.copyWith(color: fg)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
