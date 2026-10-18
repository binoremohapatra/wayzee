import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Accessibility utilities ensuring complete TalkBack and screen reader compliance.
class AccessibleSemantics {
  /// Triggers an immediate verbal announcement through TalkBack / VoiceOver.
  static void announce(String message, {TextDirection textDirection = TextDirection.ltr}) {
    SemanticsService.announce(message, textDirection);
  }

  /// Builds standardized TalkBack button hints.
  static String actionHint(String action) => 'Double-tap to $action';
}
