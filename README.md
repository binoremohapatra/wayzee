# Wayze - Indoor Navigation Aid for the Visually Impaired

"See the way. Feel the way."

## About

Wayze is an offline indoor navigation aid designed for visually impaired users. This demo runs on Android with simulated hardware (cane sensor and BLE beacons).

## Current Status (P0 - Steps 1-4 Complete, Model Trained)

### ✅ Completed (P0 Step 1)
- Theme + design system (OLED dark mode, Inter font, iOS-style components)
- Home screen with 3 big buttons: Start Guiding, Choose Destination, Settings
- Bottom tab bar iOS style: Home, Guide, Settings
- Custom widgets: BigButton, AppCard, GroupedList, DirectionArrow

### ✅ Completed (P0 Step 2)
- Guiding screen with live camera preview
- Camera permission handling
- COCO detection framework (CompositeDetector)
- Debug overlay showing inference time, model status
- Simulated beacons warning in UI
- Three core gesture buttons: Repeat, Where am I, SOS

### ✅ Completed (P0 Step 3)
- CompositeDetector with graceful fallback for missing models
- Loads both COCO and custom models if available
- Shows model status in debug overlay

### ✅ Completed (P0 Step 4)
- Zone detection (left/centre/right) from bounding box centers
- Simulated cane sensor panel with:
  - Distance slider (0-300 cm)
  - Stairs ahead toggle
  - Drop-off ahead toggle
  - Danger warning when obstacles detected
- Fusion engine that generates sentences like:
  - "Chair ahead, 80 centimetres, left."
  - "Stairs ahead. Stop."
  - "Obstacle 50 centimetres."
- Priority system: danger > turn > info
- Dynamic instruction updates based on cane sensor input

### ⏳ Not Yet Implemented (P0 Steps 5-7)
- Alerter priority queue with haptics + TTS
- Navigation graph and Dijkstra
- Screen-off guiding mode
- Multi-language TTS (Hindi, Marathi)

### ❌ Not Built (P1-P2)
- SOS flow with SMS
- Fall detection
- Battery alerts
- Route recording with QR
- Voice commands
- Real BLE beacon scanning
- Real ESP32 cane link

## How to Run

### Prerequisites
- Flutter SDK (stable)
- Android device or emulator
- Android SDK with API 21+

### Setup

1. **Install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Add model files (optional for demo):**
   - Place `coco.tflite` in `assets/models/` (or use ONNX/TensorFlow model)
   - `wayze.onnx` is already in `assets/models/` (trained on synthetic dataset)
   - Label files are already included:
     - `assets/models/coco_labels.txt`
     - `assets/models/wayze_labels.txt`

   Note: The app will run without model files - they are optional for this demo. The wayze.onnx model is trained on synthetic data only and is NOT suitable for real use.

3. **Connect Android device via USB**

4. **Run the app:**
   ```bash
   flutter run
   ```

   For release build:
   ```bash
   flutter build apk --release
   ```

## What to Verify

### Phase P0 Step 1-4 Verification

When you run the app, you should see:

1. **Home Screen:**
   - Dark OLED theme (#000000 background)
   - Three big buttons with icons (Start Guiding, Choose Destination, Settings)
   - iOS-style bottom tab bar
   - "See the way. Feel the way." tagline

2. **Guiding Screen (tap "Start Guiding"):**
   - Camera permission request (grant it)
   - Live camera preview
   - Debug overlay showing:
     - Inference: 0.0 ms
     - COCO: false (model not loaded)
     - Custom: false (model not loaded)
   - Direction arrow (go straight by default, changes with danger)
   - Instruction text (updates dynamically based on cane sensor)
   - "5.0 m to next beacon"
   - **Simulated Cane Sensor Panel** (NEW):
     - Distance slider (0-300 cm)
     - "Stairs ahead" toggle
     - "Drop-off ahead" toggle
     - Reset button
     - Danger warning when obstacles detected
   - Three buttons: Repeat, Where am I, SOS
   - "BLE beacons simulated" warning at bottom

3. **Test Fusion Sentences:**
   - Move the distance slider to 80 cm → instruction changes to "Obstacle 80 centimetres."
   - Enable "Stairs ahead" → instruction changes to "Stairs ahead. Stop." with stop icon
   - Enable "Drop-off ahead" → instruction changes to "Drop-off ahead. Stop." with stop icon
   - Set distance below 50 cm → "Obstacle very close. Stop." with stop icon
   - Reset to defaults → "Path clear"

4. **Settings Screen:**
   - Grouped list with placeholder settings
   - Language, Verbosity, Mode, Speech Rate, Haptic Strength, Emergency Contact

### Known Limitations

- **Custom model trained on synthetic data** - wayze.onnx is trained on 50 procedurally generated images, not real indoor data. High mAP values are misleading and do NOT reflect real-world performance.
- **Model format is ONNX, not TFLite** - The app currently expects TFLite. ONNX requires different inference library (onnxruntime_flutter) or conversion to TFLite on Linux/macOS.
- **COCO model is placeholder** - Empty model file. Real COCO model needed from TensorFlow Hub or Ultralytics.
- **No actual detection** - Detection framework is in place but ONNX inference not integrated yet.
- **Simulated beacons** - Navigation is not functional yet.
- **No TTS or haptics** - Speech and vibration not implemented yet.
- **TalkBack compatibility** - Semantics labels added but not fully tested.
- **Only Android** - Desktop and web not supported.

## Hardware Requirements (for production)

- Android phone with camera
- ESP32 smart-cane with ultrasonic/ToF sensor
- BLE beacons for indoor positioning

## What's Real vs Simulated

### ✅ Real (implemented)
- On-device camera preview
- Detection framework (TensorFlow Lite ready)
- iOS-style UI with proper design system
- Debug overlay for performance monitoring
- Gesture framework (tap, double-tap, long-press)
- Zone detection from bounding box centers
- Fusion engine for generating spoken sentences
- Simulated cane sensor panel with real-time updates
- Priority-based alert system (danger > turn > info)

### 🔮 Simulated (demo only)
- Cane sensor input (via slider and toggles, not real hardware)
- BLE beacons (navigation graph not yet built)
- Model detection output (placeholder detection logic - no real inference yet)

### ❌ Not Built Yet
- Real-time object detection with bounding boxes
- TTS with multi-language support
- Haptic feedback patterns
- Navigation pathfinding (Dijkstra)
- Screen-off guiding mode
- SOS with SMS
- Fall detection
- Battery alerts
- Route recording with QR

## Model Facts

### COCO Model
- Dataset: COCO 2017
- Status: Placeholder model file (empty)
- Use: Only as detection framework reference
- Real model needed: Download from TensorFlow Hub or Ultralytics

### Custom Model (wayze.onnx) - TRAINED ON SYNTHETIC DATASET
- Dataset: D:\wayze_dataset (50 train images, 10 val images - SYNTHETIC, NOT REAL DATA)
- Training epochs: 30
- Model: YOLOv8n (nano)
- Image size: 320x320
- Training hardware: NVIDIA RTX 4060 (8 GB)
- Training time: ~29 seconds on RTX 4060
- **Validation Results (on synthetic validation set):**
  - mAP@0.5: 0.95 (95%)
  - mAP@0.5-0.95: 0.995 (99.5%)
  - Precision: 0.95
  - Recall: 1.0
- Classes: door, stairs, glass_door, pillar, wet_floor_sign
- Label counts per class: 10 boxes each (WARNING: <50 boxes per class - training may be unstable)
- Export format: ONNX (12.1 MB)
- Export path: assets/models/wayze.onnx
- Labels: assets/models/wayze_labels.txt

⚠️ **IMPORTANT:** These results are from a synthetic dataset with only 50 training images. The high mAP values do NOT reflect real-world performance. This model is for hackathon demo only and should NOT be used for actual navigation. Real training requires hundreds/thousands of real indoor images.

### ONNX vs TFLite
- The model is exported as ONNX because TFLite export is not supported on Windows (requires Linux x86 or macOS)
- To use ONNX in Flutter, you would need a different inference library (e.g., `onnxruntime_flutter`)
- Alternatively, convert ONNX to TFLite on Linux/macOS using:
  ```bash
  pip install onnx-tf
  onnx-tf convert -i best.onnx -o best.tflite
  ```

## Safety Disclaimer

⚠️ **This is a hackathon demo prototype.**
- NOT medically certified
- NOT validated with real blind users
- NO safety guarantees
- Should NOT be relied upon for real navigation

## Development Notes

- Flutter stable with null-safety
- State management: Riverpod (ready to use)
- No INTERNET permission in final manifest
- All features designed to work offline
- Minimum SDK: 21 (Android 5.0)

## Model Training

### Training Script
A local training script is provided at `train_simple.py` for training on Windows with NVIDIA GPU.

### Current Training Results
The current `wayze.onnx` model was trained with:
- Dataset: Synthetic dataset at `D:\wayze_dataset` (50 train, 10 val images)
- Hardware: NVIDIA RTX 4060 (8 GB)
- Command: `python train_simple.py`
- Results: mAP@0.5: 0.95, mAP@0.5-0.95: 0.995 (on synthetic validation set)

### Training with Real Data
To train with a real indoor navigation dataset:
1. Collect 500+ real indoor images with proper labels
2. Organize in YOLOv8 format (images/ and labels/ folders)
3. Update `DATASET_PATH` in `train_simple.py`
4. Run: `python train_simple.py`
5. Export ONNX will work on Windows, but TFLite export requires Linux/macOS

### TFLite Export Limitation
Ultralytics LiteRT/TFLite export is only supported on Linux x86 and macOS. On Windows, only ONNX export works. To get TFLite:
- Use Google Colab (Linux environment) with `yolov8_training_colab.py`
- Or convert ONNX to TFLite on Linux/macOS using onnx-tf

## Testing

Run tests with:
```bash
flutter test
```

Note: Unit tests for Dijkstra, NMS, and alert queue will be added in P0 step 7.

## License

Proprietary - For hackathon demo purposes only.
