import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../feedback.dart';
import 'big_button.dart';

enum Direction { left, right, forward, stairs, stop, reached }

extension DirectionX on Direction {
  IconData get icon => switch (this) {
        Direction.left => Icons.turn_left_rounded,
        Direction.right => Icons.turn_right_rounded,
        Direction.forward => Icons.arrow_upward_rounded,
        Direction.stairs => Icons.stairs_rounded,
        Direction.stop => Icons.front_hand_rounded,
        Direction.reached => Icons.check_circle_rounded,
      };
  Color get color => switch (this) {
        Direction.stairs || Direction.stop => WC.bad,
        Direction.reached => WC.ok,
        _ => WC.accent,
      };
  String get word => switch (this) {
        Direction.left => 'Turn left',
        Direction.right => 'Turn right',
        Direction.forward => 'Go straight',
        Direction.stairs => 'Stairs ahead',
        Direction.stop => 'Stop',
        Direction.reached => 'You have arrived',
      };
}

/// Fed by the REAL navigation state. 250 ms easeOutBack; respects reduce-motion.
class DirectionArrow extends StatelessWidget {
  const DirectionArrow({super.key, required this.direction});
  final Direction direction;
  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return Semantics(
      liveRegion: true,
      label: direction.word,
      excludeSemantics: true,
      child: Container(
        width: 240,
        height: 240,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: WC.card,
          shape: BoxShape.circle,
          border: Border.all(color: direction.color, width: 8),
        ),
        child: AnimatedSwitcher(
          duration: reduce ? Duration.zero : const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: child,
          ),
          child: Icon(direction.icon, key: ValueKey(direction), size: 150, color: direction.color),
        ),
      ),
    );
  }
}

/// Live region: big instruction + distance. Text comes from my Alerter/navigation, not hardcoded.
class InstructionBlock extends StatelessWidget {
  const InstructionBlock({super.key, required this.instruction, this.nextBeacon, this.distance});
  final String instruction;
  final String? nextBeacon;
  final int? distance;
  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        label: distance == null ? instruction : '$instruction. $distance steps',
        excludeSemantics: true,
        child: Column(children: [
          Text(instruction, textAlign: TextAlign.center, style: WT.hero),
          if (nextBeacon != null) ...[
            const SizedBox(height: 8),
            Text(nextBeacon!, textAlign: TextAlign.center, style: WT.headline.copyWith(color: WC.muted, fontWeight: FontWeight.w500)),
          ],
          if (distance != null) ...[
            const SizedBox(height: 8),
            Text('$distance steps', textAlign: TextAlign.center, style: WT.headline.copyWith(color: WC.muted, fontWeight: FontWeight.w500)),
          ],
        ]),
      );
}

/// Always at the top, never hidden. Null message = nothing shown. Pulses unless reduce-motion.
class DangerBanner extends StatefulWidget {
  const DangerBanner({super.key, this.message});
  final String? message;
  @override
  State<DangerBanner> createState() => _DangerBannerState();
}

class _DangerBannerState extends State<DangerBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    if (m == null) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      label: 'Danger. $m',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: WC.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: WC.bad.withValues(alpha: 0.45 + 0.55 * _c.value), width: 4),
          ),
          child: Row(children: [
            const Icon(Icons.warning_rounded, color: WC.bad, size: 34),
            const SizedBox(width: 12),
            Expanded(child: Text(m, style: WT.headline.copyWith(color: WC.bad))),
          ]),
        ),
      ),
    );
  }
}

/// Safe option on top ("No, go back"), risky option below. Returns true only if user confirms.
class ConfirmSheet {
  static Future<bool> show(BuildContext context, {required String title, required String body, required String yesLabel, String noLabel = 'No, go back'}) async {
    Fx.speak?.call('$title $body');
    final r = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      backgroundColor: WC.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Semantics(header: true, child: Text(title, style: WT.headline, textAlign: TextAlign.center)),
            const SizedBox(height: 12),
            Text(body, style: WT.body.copyWith(color: WC.muted), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            BigButton(label: noLabel, icon: Icons.arrow_back_rounded, sig: Sig.back, onPressed: () => Navigator.pop(ctx, false)),
            const SizedBox(height: 16),
            BigButton(label: yesLabel, kind: BigButtonKind.danger, sig: Sig.sos, onPressed: () => Navigator.pop(ctx, true)),
          ]),
        ),
      ),
    );
    return r ?? false;
  }
}

/// Fall detection countdown. Parent drives `remaining` (from my real fall logic) and speaks every 5 s + last 3 s.
class CountdownRing extends StatelessWidget {
  const CountdownRing({super.key, required this.remaining, required this.total});
  final int remaining;
  final int total;
  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        label: '$remaining seconds left',
        excludeSemantics: true,
        child: SizedBox(
          width: 240,
          height: 240,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 240,
              height: 240,
              child: CircularProgressIndicator(
                value: total == 0 ? 0 : remaining / total,
                strokeWidth: 20,
                color: WC.bad,
                backgroundColor: WC.card,
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$remaining', style: WT.hero.copyWith(fontSize: 72)),
              Text('SECONDS', style: WT.label),
            ]),
          ]),
        ),
  );
}
