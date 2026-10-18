import 'package:flutter/services.dart';

enum Sig { tick, primary, back, repeat, sos, success, error, on, off }

class Fx {
  /// Wire these to my real Alerter / TTS / earcon player / vibration package in main.dart.
  static void Function(String text)? speak;
  static void Function(String name)? earcon; // 'select','success','error','danger'
  static Future<void> Function(Sig sig)? vibrate; // override with the `vibration` package patterns

  static Future<void> haptic(Sig s) async {
    if (vibrate != null) return vibrate!(s);
    switch (s) {
      case Sig.tick:
      case Sig.back:
        return HapticFeedback.selectionClick();
      case Sig.primary:
      case Sig.on:
        return HapticFeedback.mediumImpact();
      case Sig.off:
        return HapticFeedback.lightImpact();
      case Sig.repeat:
        await HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 120));
        return HapticFeedback.lightImpact();
      case Sig.error:
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        return HapticFeedback.heavyImpact();
      case Sig.success:
        await HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 120));
        await HapticFeedback.mediumImpact();
        await Future.delayed(const Duration(milliseconds: 120));
        return HapticFeedback.heavyImpact();
      case Sig.sos:
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 150));
        await HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 150));
        return HapticFeedback.heavyImpact();
    }
  }
}
