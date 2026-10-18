import 'package:flutter/services.dart';

enum HapticPattern {
  click,
  confirm,
  warning,
  danger,
}

abstract class HapticService {
  Future<void> click();
  Future<void> confirm();
  Future<void> warning();
  Future<void> danger();
}

class SystemHapticService implements HapticService {
  const SystemHapticService();

  @override
  Future<void> click() async {
    await HapticFeedback.selectionClick();
  }

  @override
  Future<void> confirm() async {
    await HapticFeedback.mediumImpact();
  }

  @override
  Future<void> warning() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }

  @override
  Future<void> danger() async {
    // 3 heavy vibration pulses for life-safety hazard alerts
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }
}

class MockHapticService implements HapticService {
  final List<HapticPattern> triggerHistory = [];

  @override
  Future<void> click() async {
    triggerHistory.add(HapticPattern.click);
  }

  @override
  Future<void> confirm() async {
    triggerHistory.add(HapticPattern.confirm);
  }

  @override
  Future<void> warning() async {
    triggerHistory.add(HapticPattern.warning);
  }

  @override
  Future<void> danger() async {
    triggerHistory.add(HapticPattern.danger);
  }

  void clear() {
    triggerHistory.clear();
  }
}
