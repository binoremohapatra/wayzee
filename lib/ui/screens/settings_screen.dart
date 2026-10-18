import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../widgets/bottom_action_bar.dart';
import '../widgets/chips_cards_rows.dart';
import '../widgets/screen_scaffold.dart';
import '../widgets/big_button.dart';
import '../feedback.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _speechRate = 0.5;  // Default: 0.5x (0.5 internal rate = 1.0x displayed)
  bool _hapticsEnabled = true;
  bool _fallDetectionEnabled = true;
  bool _soundEffectsEnabled = true;
  bool _heartbeatEnabled = true;
  int _heartbeatIntervalSec = 25;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _speechRate = prefs.getDouble('speech_rate') ?? 0.5;
      _hapticsEnabled = prefs.getBool('haptics_enabled') ?? true;
      _fallDetectionEnabled = prefs.getBool('fall_detection_enabled') ?? true;
      _soundEffectsEnabled = prefs.getBool('sound_effects_enabled') ?? true;
      _heartbeatEnabled = prefs.getBool('heartbeat_enabled') ?? true;
      _heartbeatIntervalSec = prefs.getInt('heartbeat_interval_sec') ?? 25;
    });
    // Update TTS rate immediately when loading
    final flutterTts = FlutterTts();
    await flutterTts.setSpeechRate(_speechRate);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('speech_rate', _speechRate);
    await prefs.setBool('haptics_enabled', _hapticsEnabled);
    await prefs.setBool('fall_detection_enabled', _fallDetectionEnabled);
    await prefs.setBool('sound_effects_enabled', _soundEffectsEnabled);
    await prefs.setBool('heartbeat_enabled', _heartbeatEnabled);
    await prefs.setInt('heartbeat_interval_sec', _heartbeatIntervalSec);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Settings',
      spokenIntro: 'Settings. Adjust voice speed, haptics, and safety features.',
      body: [
        StepperRow(
          label: 'Speech Speed',
          valueText: '${_speechRate.toStringAsFixed(1)}x',
          onMinus: () {
            setState(() {
              _speechRate = (_speechRate - 0.1).clamp(0.1, 1.0);
            });
            _saveSettings();
            final flutterTts = FlutterTts();
            flutterTts.setSpeechRate(_speechRate);
            Fx.speak?.call('Speech speed ${_speechRate.toStringAsFixed(1)} times');
          },
          onPlus: () {
            setState(() {
              _speechRate = (_speechRate + 0.1).clamp(0.1, 1.0);
            });
            _saveSettings();
            final flutterTts = FlutterTts();
            flutterTts.setSpeechRate(_speechRate);
            Fx.speak?.call('Speech speed ${_speechRate.toStringAsFixed(1)} times');
          },
          description: 'Slower for easier listening',
        ),
        const SizedBox(height: 16),
        SwitchRow(
          label: 'Haptics',
          value: _hapticsEnabled,
          onChanged: (value) {
            setState(() {
              _hapticsEnabled = value;
            });
            _saveSettings();
            if (value) {
              Fx.haptic(Sig.on);
              Fx.speak?.call('Haptics enabled');
            } else {
              Fx.haptic(Sig.off);
              Fx.speak?.call('Haptics disabled');
            }
          },
          description: 'Vibration feedback for taps and navigation',
        ),
        const SizedBox(height: 16),
        SwitchRow(
          label: 'Fall Detection',
          value: _fallDetectionEnabled,
          onChanged: (value) {
            setState(() {
              _fallDetectionEnabled = value;
            });
            _saveSettings();
            if (value) {
              Fx.haptic(Sig.on);
              Fx.speak?.call('Fall detection enabled');
            } else {
              Fx.haptic(Sig.off);
              Fx.speak?.call('Fall detection disabled');
            }
          },
          description: 'Send SOS if a fall is detected',
        ),
        const SizedBox(height: 16),
        SwitchRow(
          label: 'Sound Effects',
          value: _soundEffectsEnabled,
          onChanged: (value) {
            setState(() {
              _soundEffectsEnabled = value;
            });
            _saveSettings();
            if (value) {
              Fx.haptic(Sig.on);
              Fx.speak?.call('Sound effects enabled');
            } else {
              Fx.haptic(Sig.off);
              Fx.speak?.call('Sound effects disabled');
            }
          },
          description: 'Earcon sounds for events',
        ),
        const SizedBox(height: 16),
        SwitchRow(
          label: 'Haptic Heartbeat',
          value: _heartbeatEnabled,
          onChanged: (value) {
            setState(() {
              _heartbeatEnabled = value;
            });
            _saveSettings();
            if (value) {
              Fx.haptic(Sig.on);
              Fx.speak?.call('Heartbeat vibration enabled');
            } else {
              Fx.haptic(Sig.off);
              Fx.speak?.call('Heartbeat vibration disabled');
            }
          },
          description: 'Periodic pulse so you know the app is running',
        ),
        if (_heartbeatEnabled) ...[
          const SizedBox(height: 16),
          StepperRow(
            label: 'Heartbeat Interval',
            valueText: '${_heartbeatIntervalSec}s',
            onMinus: () {
              setState(() {
                _heartbeatIntervalSec = (_heartbeatIntervalSec - 5).clamp(10, 60);
              });
              _saveSettings();
              Fx.speak?.call('Heartbeat interval $_heartbeatIntervalSec seconds');
            },
            onPlus: () {
              setState(() {
                _heartbeatIntervalSec = (_heartbeatIntervalSec + 5).clamp(10, 60);
              });
              _saveSettings();
              Fx.speak?.call('Heartbeat interval $_heartbeatIntervalSec seconds');
            },
            description: 'Time between status pulses',
          ),
        ],
        const SizedBox(height: 16),
        BigButton(
          label: 'Learn the Signals',
          icon: Icons.school_rounded,
          onPressed: () {
            Fx.haptic(Sig.primary);
            Navigator.pushNamed(context, '/learn_signals');
          },
        ),
        const SizedBox(height: 16),
        BigButton(
          label: 'About the Model',
          icon: Icons.info_rounded,
          onPressed: () {
            Fx.haptic(Sig.primary);
            Navigator.pushNamed(context, '/about_model');
          },
        ),
      ],
      bottom: BottomActionBar(
        onBack: () => Navigator.pop(context),
        primaryLabel: 'Go Home',
        onPrimary: () {
          Fx.haptic(Sig.primary);
          Navigator.pushReplacementNamed(context, '/home');
        },
      ),
    );
  }
}
