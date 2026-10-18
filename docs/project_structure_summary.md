# Wayze Project Structure Summary

## Current Architecture

### Core
- **main.dart** - App entry point, TTS initialization, theme setup, routing
- **ui/feedback.dart** - Fx hooks (speak, earcon, vibrate/haptics)

### Theme
- **core/theme/app_colors.dart** - WC color constants (dark theme)
- **core/theme/app_text.dart** - WT typography constants
- **core/theme/app_theme.dart** - appTheme instance
- **core/theme/theme.dart** - buildWayzeTheme function

### Detection
- **detector/detector.dart** - Detector abstract class, Detection model
- **detector/composite_detector.dart** - TFLite detector implementation (wayze.tflite, door/stairs classes)
- **detector/onnx_detector.dart** - ONNX detector (currently disabled)
- **detector/zone.dart** - Zone management

### Safety
- **safety/cane_sensor.dart** - Cane sensor simulation

### Services
- **services/sensor_fusion_service.dart** - Sensor fusion (ESP32 + AI), AlertLevel enum, FusedDetection model

### UI Screens
- **ui/screens/welcome_language_screen.dart** - Language selection (English, Hindi, Marathi + 7 more)
- **ui/screens/home_screen.dart** - Main home screen
- **ui/screens/settings_screen.dart** - Settings (speech speed, haptics, fall detection, etc.)
- **ui/screens/camera_detection_screen.dart** - Camera + AI detection + sensor fusion
- **ui/screens/choose_destination_screen.dart** - Destination selection
- **ui/screens/live_guiding_screen.dart** - Live navigation (simulated)
- **ui/screens/sos_confirmation_screen.dart** - SOS confirmation
- **ui/screens/fall_detected_screen.dart** - Fall detection
- **ui/screens/learn_the_signals_screen.dart** - Signal learning
- **ui/screens/demo_simulation_screen.dart** - Demo/simulation
- **ui/screens/about_model_info_screen.dart** - Model info

### UI Widgets
- **ui/widgets/big_button.dart** - Large accessible button
- **ui/widgets/screen_scaffold.dart** - Standard screen layout
- **ui/widgets/bottom_action_bar.dart** - Bottom action bar
- **ui/widgets/cane_sensor_panel.dart** - Cane sensor display
- **ui/widgets/chips_cards_rows.dart** - Various UI components
- **ui/widgets/direction_arrow.dart** - Direction indicator
- **ui/widgets/guiding_widgets.dart** - Navigation widgets
- **ui/widgets/grouped_list.dart** - Grouped list
- **ui/widgets/app_card.dart** - App card

## Current Features
- ✅ TTS (flutter_tts) with 10 Indian languages
- ✅ Camera detection with TFLite (wayze.tflite, door/stairs)
- ✅ Sensor fusion (ESP32 + AI)
- ✅ Multi-modal alerts (TTS + Haptics)
- ✅ All navigation screens
- ✅ Settings persistence
- ✅ TalkBack accessibility
- ✅ Dark blind-first UI

## Missing Features (to be added)
- ✅ Voice commands intent matching (IntentMatcher - English, Hindi)
- ✅ Voice phrase packs (VoicePhrases - English, Hindi, Marathi)
- ❌ STT (Speech-to-Text) - Vosk integration pending
- ❌ Hands-free triggers (cane button, headset button, volume shortcut)
- ❌ Foreground service for navigation
- ❌ BLE protocol with ESP32
- ❌ "Ask for help" feature
- ❌ OCR text recognition
- ❌ Favourites
- ❌ Route preferences
- ❌ Wake word detection
