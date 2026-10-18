import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../feedback.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.icon, this.color = WC.muted});
  final String label;
  final IconData? icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: label,
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: WC.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: WC.line),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 20, color: color), const SizedBox(width: 8)],
            Flexible(child: Text(label, style: WT.label.copyWith(color: WC.text))),
          ]),
        ),
      );
}

/// One semantic node: read as "title. description".
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.title, required this.description, this.icon});
  final String title;
  final String description;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: '$title. $description',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: WC.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: WC.line),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            if (icon != null) ...[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: WC.surface, shape: BoxShape.circle, border: Border.all(color: WC.line)),
                child: Icon(icon, color: WC.accent, size: 28),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: WT.body.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(description, style: WT.label),
              ]),
            ),
          ]),
        ),
      );
}

/// Used for destinations and languages. REAL selection state comes from the parent (no hardcoded selected:true).
class SelectableRow extends StatelessWidget {
  const SelectableRow({super.key, required this.label, required this.sub, required this.selected, required this.onTap, this.icon});
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  void _fire() {
    Fx.haptic(Sig.tick);
    Fx.earcon?.call('select');
    onTap();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: true,
        selected: selected,
        label: '$label, $sub, ${selected ? "selected" : "not selected"}',
        onTap: _fire,
        excludeSemantics: true,
        child: InkWell(
          onTap: _fire,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF2A2210) : WC.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? WC.accent : WC.line, width: 2),
            ),
            child: Row(children: [
              if (icon != null) ...[Icon(icon, color: selected ? WC.accent : WC.muted, size: 28), const SizedBox(width: 14)],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: WT.body.copyWith(fontWeight: FontWeight.w700)),
                  Text(sub, style: WT.label),
                ]),
              ),
              Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: selected ? WC.accent : WC.muted, size: 30),
            ]),
          ),
        ),
      );
}

/// Replaces sliders. Parent updates the value, then calls Fx.speak('$label $newValue').
class StepperRow extends StatelessWidget {
  const StepperRow({super.key, required this.label, required this.valueText, required this.onMinus, required this.onPlus, this.description});
  final String label;
  final String valueText;
  final String? description;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  Widget _btn(IconData icon, String sem, VoidCallback cb) => Semantics(
        button: true,
        label: sem,
        onTap: () {
          Fx.haptic(Sig.tick);
          cb();
        },
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Fx.haptic(Sig.tick);
            cb();
          },
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: WC.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: WC.line, width: 2),
            ),
            child: Icon(icon, color: WC.accent, size: 36),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: WC.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: WC.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(label, style: WT.body.copyWith(fontWeight: FontWeight.w700)),
          if (description != null) Text(description!, style: WT.label),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _btn(Icons.remove_rounded, 'Decrease $label', onMinus),
            Expanded(
              child: Semantics(
                liveRegion: true,
                label: '$label $valueText',
                excludeSemantics: true,
                child: Text(valueText, textAlign: TextAlign.center, style: WT.headline),
              ),
            ),
            _btn(Icons.add_rounded, 'Increase $label', onPlus),
          ]),
        ]),
      );
}

/// Whole row is the button. ONE switch only (the old export drew two).
class SwitchRow extends StatelessWidget {
  const SwitchRow({super.key, required this.label, required this.value, required this.onChanged, this.description});
  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  void _fire() {
    Fx.haptic(value ? Sig.off : Sig.on);
    onChanged(!value);
  }

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        toggled: value,
        label: label,
        hint: description,
        onTap: _fire,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _fire,
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: WC.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: WC.line)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: WT.body.copyWith(fontWeight: FontWeight.w700)),
                  if (description != null) Text(description!, style: WT.label),
                ]),
              ),
              const SizedBox(width: 12),
              IgnorePointer(
                child: CupertinoSwitch(value: value, activeTrackColor: WC.accent, onChanged: (_) {}),
              ),
            ]),
          ),
        ),
      );
}

/// Signal row for "Learn the signals": tap = play haptic + earcon + speak what it means.
class SignalRow extends StatelessWidget {
  const SignalRow({super.key, required this.title, required this.description, required this.icon, required this.sig, required this.earcon});
  final String title;
  final String description;
  final IconData icon;
  final Sig sig;
  final String earcon;

  void _play() {
    Fx.haptic(sig); // haptic first
    Fx.earcon?.call(earcon);
    Fx.speak?.call('$title. $description');
  }

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: true,
        label: '$title. $description. Double tap to play.',
        onTap: _play,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _play,
          child: Container(
            constraints: const BoxConstraints(minHeight: 88),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: WC.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: WC.line)),
            child: Row(children: [
              Icon(icon, color: WC.accent, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: WT.body.copyWith(fontWeight: FontWeight.w700)),
                  Text(description, style: WT.label),
                ]),
              ),
              const Icon(Icons.play_circle_fill_rounded, color: WC.accent, size: 36),
            ]),
          ),
        ),
      );
}

class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.label, required this.value, this.icon});
  final String label;
  final String value;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: '$label: $value',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            if (icon != null) ...[
              Icon(icon, color: WC.muted, size: 20),
              const SizedBox(width: 8),
            ],
            Flexible(child: Text(label, style: WT.body.copyWith(color: WC.muted))),
            const SizedBox(width: 12),
            Flexible(child: Text(value, textAlign: TextAlign.right, style: WT.body.copyWith(fontWeight: FontWeight.w700))),
          ]),
        ),
      );
}
