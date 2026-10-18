import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:android_intent_plus/android_intent_plus.dart';  // Import path issue
// import 'package:permission_handler/permission_handler.dart';  // Voice commands disabled
import 'core/theme/app_theme.dart';
import 'ui/feedback.dart';
import 'ui/screens/welcome_language_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/camera_detection_screen.dart';
import 'ui/screens/choose_destination_screen.dart';
import 'ui/screens/live_guiding_screen.dart';
import 'ui/screens/sos_confirmation_screen.dart';
import 'ui/screens/fall_detected_screen.dart';
import 'ui/screens/learn_the_signals_screen.dart';
import 'ui/screens/demo_simulation_screen.dart';
import 'ui/screens/about_model_info_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Wire Fx hooks to real implementations
  final flutterTts = FlutterTts();
  
  // Initialize TTS with natural voice settings
  flutterTts.setLanguage('en-US');
  flutterTts.setVolume(1.0);
  flutterTts.setPitch(1.0);  // Natural pitch
  flutterTts.setSpeechRate(0.5);  // Slower for better comprehension
  
  // Try to set better voice engine (Android-specific)
  try {
    // Set shared instance for better performance
    await flutterTts.setSharedInstance(true);
    
    // Try to use a more natural voice engine on Android
    await flutterTts.setEngine('com.google.android.tts');  // Google TTS engine
  } catch (e) {
    // Ignore errors, fall back to default
  }
  
  // Load saved language and speech rate
  final prefs = await SharedPreferences.getInstance();
  final savedLang = prefs.getString('language') ?? 'English';
  final savedSpeechRate = prefs.getDouble('speech_rate') ?? 0.5;
  
  // Set TTS language (expanded Indian languages)
  final langMap = {
    'English': 'en-US',
    'Hindi': 'hi-IN',
    'Marathi': 'mr-IN',
    'Tamil': 'ta-IN',
    'Telugu': 'te-IN',
    'Bengali': 'bn-IN',
    'Kannada': 'kn-IN',
    'Malayalam': 'ml-IN',
    'Gujarati': 'gu-IN',
    'Punjabi': 'pa-IN',
  };
  flutterTts.setLanguage(langMap[savedLang] ?? 'en-US');
  
  // Set TTS speech rate from saved settings
  flutterTts.setSpeechRate(savedSpeechRate);

  Fx.speak = (text) async {
    // Apply current speech rate before speaking
    final prefs = await SharedPreferences.getInstance();
    final savedSpeechRate = prefs.getDouble('speech_rate') ?? 0.5;
    await flutterTts.setSpeechRate(savedSpeechRate);
    await flutterTts.speak(text);
  };

  // Earcon - use TTS for now (could be replaced with audio files)
  Fx.earcon = (name) async {
    // Simple earcon sounds using TTS
    final sounds = {
      'select': 'select',
      'success': 'success',
      'error': 'error',
      'danger': 'danger',
    };
    await flutterTts.speak(sounds[name] ?? name);
  };

  // Vibration - custom patterns (using HapticFeedback with delays)
  Fx.vibrate = (sig) async {
    switch (sig) {
      case Sig.tick:
      case Sig.back:
        await HapticFeedback.selectionClick();
        break;
      case Sig.primary:
      case Sig.on:
        await HapticFeedback.mediumImpact();
        break;
      case Sig.off:
        await HapticFeedback.lightImpact();
        break;
      case Sig.repeat: // 2 short pulses
        await HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 120));
        await HapticFeedback.lightImpact();
        break;
      case Sig.error: // 2 heavy impacts
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        await HapticFeedback.heavyImpact();
        break;
      case Sig.success: // 3 rising pulses
        await HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 120));
        await HapticFeedback.mediumImpact();
        await Future.delayed(const Duration(milliseconds: 120));
        await HapticFeedback.heavyImpact();
        break;
      case Sig.sos: // long-short-long
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 150));
        await HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 150));
        await HapticFeedback.heavyImpact();
        break;
    }
  };

  runApp(const WayzeApp());
}

class WayzeApp extends StatelessWidget {
  const WayzeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Wayze',
        debugShowCheckedModeBanner: false,
        theme: appTheme,
        initialRoute: '/',
      routes: {
        '/': (context) => const WelcomeLanguageScreen(),
        '/home': (context) => const HomeScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/camera': (context) => const CameraDetectionScreen(),
        '/destination': (context) => const ChooseDestinationScreen(),
        '/guiding': (context) => const LiveGuidingScreen(),
        '/sos': (context) => const SOSConfirmationScreen(),
        '/fall_detected': (context) => const FallDetectedScreen(),
        '/learn_signals': (context) => const LearnTheSignalsScreen(),
        '/demo': (context) => const DemoSimulationScreen(),
        '/about_model': (context) => const AboutModelInfoScreen(),
      },
      ),
    );
  }
}
