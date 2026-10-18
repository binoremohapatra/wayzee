import 'package:shared_preferences/shared_preferences.dart';

class PrivacyPolicy {
  static const String keyOptInImprovement = 'privacy_opt_in_anonymous_metrics';

  final SharedPreferences prefs;

  PrivacyPolicy(this.prefs);

  bool get isOptInImprovementEnabled => prefs.getBool(keyOptInImprovement) ?? false;

  Future<void> setOptInImprovement(bool value) async {
    await prefs.setBool(keyOptInImprovement, value);
  }

  /// Core privacy guarantees for blind and visually impaired users.
  static const List<String> coreGuarantees = [
    'Camera frames are processed purely in RAM and discarded immediately.',
    'No photo, video, or frame buffer is ever saved to disk or transmitted over the network.',
    'Wayze functions 100% offline without requiring internet access or cloud ML.',
    'Anonymous error reports (if opted in) never include camera frames or voice recordings.',
  ];
}
