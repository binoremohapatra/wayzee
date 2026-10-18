import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../widgets/chips_cards_rows.dart';
import '../widgets/screen_scaffold.dart';
import '../widgets/big_button.dart';
import '../feedback.dart';

class WelcomeLanguageScreen extends StatefulWidget {
  const WelcomeLanguageScreen({super.key});

  @override
  State<WelcomeLanguageScreen> createState() => _WelcomeLanguageScreenState();
}

class _WelcomeLanguageScreenState extends State<WelcomeLanguageScreen> {
  String _selectedLanguage = 'English';
  final FlutterTts _flutterTts = FlutterTts();
  
  // Expanded language list with Indian languages
  final List<Map<String, String>> _languages = [
    {'name': 'English', 'code': 'en-US', 'sub': 'English'},
    {'name': 'Hindi', 'code': 'hi-IN', 'sub': 'हिन्दी'},
    {'name': 'Marathi', 'code': 'mr-IN', 'sub': 'मराठी'},
    {'name': 'Tamil', 'code': 'ta-IN', 'sub': 'தமிழ்'},
    {'name': 'Telugu', 'code': 'te-IN', 'sub': 'తెలుగు'},
    {'name': 'Bengali', 'code': 'bn-IN', 'sub': 'বাংলা'},
    {'name': 'Kannada', 'code': 'kn-IN', 'sub': 'ಕನ್ನಡ'},
    {'name': 'Malayalam', 'code': 'ml-IN', 'sub': 'മലയാളം'},
    {'name': 'Gujarati', 'code': 'gu-IN', 'sub': 'ગુજરાતી'},
    {'name': 'Punjabi', 'code': 'pa-IN', 'sub': 'ਪੰਜਾਬੀ'},
  ];

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('language') ?? 'English';
    });
  }

  Future<void> _saveLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
    setState(() {
      _selectedLanguage = lang;
    });
    
    // Find language code from list
    final langData = _languages.firstWhere((l) => l['name'] == lang);
    await _flutterTts.setLanguage(langData['code'] ?? 'en-US');
    
    // Load and apply saved speech rate
    final savedSpeechRate = prefs.getDouble('speech_rate') ?? 0.5;
    await _flutterTts.setSpeechRate(savedSpeechRate);
    
    // Speak language selected in that language
    await _flutterTts.speak('$lang selected');
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Wayze',
      subtitle: 'See the way. Feel the way.',
      spokenIntro: 'Wayze. See the way. Feel the way. Works with your white cane, and works offline.',
      body: _languages.map((lang) => SelectableRow(
        label: lang['name']!,
        sub: lang['sub']!,
        selected: _selectedLanguage == lang['name'],
        onTap: () => _saveLanguage(lang['name']!),
      )).toList(),
      bottom: BigButton(
        label: 'Get Started',
        icon: Icons.arrow_forward_rounded,
        kind: BigButtonKind.primary,
        onPressed: () {
          Fx.haptic(Sig.primary);
          Navigator.pushReplacementNamed(context, '/home');
        },
      ),
    );
  }
}
