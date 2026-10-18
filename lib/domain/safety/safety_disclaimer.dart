import 'package:shared_preferences/shared_preferences.dart';

/// Manages first-launch safety disclaimer stating that Wayze is a supplement,
/// never a replacement for the white cane.
class SafetyDisclaimer {
  static const String keyAccepted = 'wayze_safety_disclaimer_accepted';

  static const String disclaimerText =
      'Wayze is a SUPPLEMENT to the white cane, never a replacement. '
      'You must always carry and use your primary white cane or guide dog. '
      'Sensors and cameras can be affected by lighting, glass, or device battery. '
      'Do not rely solely on Wayze for life safety.';

  static const String disclaimerHindi =
      'Wayze safed chhadi (white cane) ka sahayak hai, uska badal nahi. '
      'Hamesha apni safed chhadi ka prayog karein.';

  final SharedPreferences prefs;

  SafetyDisclaimer(this.prefs);

  bool get isDisclaimerAccepted => prefs.getBool(keyAccepted) ?? false;

  Future<void> acceptDisclaimer() async {
    await prefs.setBool(keyAccepted, true);
  }
}
