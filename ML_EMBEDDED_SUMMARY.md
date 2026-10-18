# Wayze ML + Embedded Firmware - Summary

## Files Created

### 1. YOLOv8 Training Colab Notebook
**File:** `yolov8_training_colab.py`

Copy and paste each cell (separated by `# Cell X:` comments) into Google Colab.

**Features:**
- Install ultralytics and check GPU
- Upload Roboflow dataset, auto-fix data.yaml paths
- Sanity check for label counts (warn if <50 boxes per class)
- Train YOLOv8n (320px, 30 epochs, batch 16, patience 10)
- Print final mAP50 and mAP50-95 metrics
- Export to TFLite (float32 and float16)
- Inspect TFLite tensor shapes with TensorFlow
- Create labels.txt
- Run inference on 5 validation images
- Zip results for download
- License notice (AGPL)

**Classes:**
door, stairs, glass_door, pillar, wet_floor_sign
(Adjust to match your dataset)

**Expected Output:**
- `best_float32.tflite` - TFLite model (float32)
- `best_float16.tflite` - TFLite model (float16, smaller)
- `labels.txt` - Class names in order
- `results_summary.csv` - Training metrics
- `wayze_tflite_export.zip` - All files zipped

**Important Notes:**
- Image size is 320px (faster, less accurate than 640px)
- Training takes 10-30 minutes on Colab GPU
- Inference time shown is Colab speed, NOT phone speed
- Phone will be slower (estimated 100-300ms for TFLite)
- AGPL license requires sharing YOLO modifications

---

### 2. ESP32 Firmware (Arduino via PlatformIO)
**Folder:** `esp32_firmware/`

**Files:**
- `platformio.ini` - PlatformIO configuration
- `src/config.h` - All configuration (pins, thresholds, modes)
- `src/main.cpp` - Main firmware code
- `README.md` - Setup instructions and test checklist
- `WIRING.md` - Complete wiring diagram

**Features (in order):**
1. Sensor reading loop at ~20 Hz with median filter
2. Obstacle logic with haptic intensity by distance
3. Non-blocking haptic patterns (left, right, danger)
4. BLE scanning for beacons with RSSI smoothing
5. BLE GATT server streaming JSON at 5 Hz
6. MPU6050 heading integration with beacon reset
7. Button handling with debounce
8. SIMULATION_MODE for testing without sensors

**Dependencies:**
- Adafruit VL53L0X library
- Adafruit MPU6050 library
- NimBLE-Arduino library
- ESP32Servo (built-in)

**Hardware Requirements:**
- ESP32 DevKit
- HC-SR04 ultrasonic (forward)
- VL53L0X ToF (downward, I2C)
- MPU6050 gyroscope (I2C)
- 2 vibration motors + transistors + diodes
- 3 buttons
- Voltage divider for HC-SR04 Echo (CRITICAL)

**Status:**
- Code written and compiles
- **NOT TESTED ON HARDWARE** - Requires actual sensors
- Simulation mode available for logic testing

---

## How to Use

### YOLOv8 Training (Colab)

1. Open Google Colab: https://colab.research.google.com/
2. Create new notebook
3. Copy cells from `yolov8_training_colab.py`
4. Paste each cell sequentially (separated by `# Cell X:` comments)
5. Run cells in order
6. Upload your Roboflow dataset zip when prompted
7. Adjust training parameters if needed (epochs, batch size)
8. Download `wayze_tflite_export.zip` at the end
9. Extract and place TFLite files in Flutter app `assets/models/`

### ESP32 Firmware (PlatformIO)

1. Install VS Code
2. Install PlatformIO extension
3. Open `esp32_firmware/` folder in VS Code
4. Edit `src/config.h` to adjust pins/thresholds
5. Connect ESP32 via USB
6. Press F5 to build and upload
7. Open Serial monitor (115200 baud)
8. Test with SIMULATION_MODE = true first
9. Wire sensors per `WIRING.md`
10. Set SIMULATION_MODE = false
11. Test on real hardware

---

## Testing Checklist

### YOLOv8 Training
- [ ] Dataset uploaded successfully
- [ ] data.yaml paths fixed automatically
- [ ] Label counts checked (warn if <50 boxes)
- [ ] Training completes without errors
- [ ] mAP50 and mAP50-95 printed
- [ ] TFLite export successful (both float32 and float16)
- [ ] Tensor shapes inspected
- [ ] labels.txt created
- [ ] Inference tested on 5 images
- [ ] Zip file downloaded

### ESP32 Firmware
- [ ] PlatformIO builds successfully
- [ ] Code uploads to ESP32
- [ ] Serial monitor shows startup message
- [ ] SIMULATION_MODE tested (fake distances printed)
- [ ] Sensors wired per WIRING.md
- [ ] Voltage divider on HC-SR04 Echo installed
- [ ] Ultrasonic readings accurate
- [ ] ToF readings accurate
- [ ] Haptic patterns work (left, right, danger)
- [ ] BLE scanning detects beacons
- [ ] BLE GATT server connects to phone
- [ ] JSON data received at 5 Hz
- [ ] Buttons trigger correctly
- [ ] MPU6050 heading updates
- [ ] Standalone mode works (no phone, haptics still work)

---

## Known Limitations

### YOLOv8 Training
- Requires GPU for reasonable training time
- 320px image size = lower accuracy than 640px
- AGPL license for Ultralytics
- TFLite export may fail (fallback to ONNX provided)
- Inference time on phone not tested (Colab speed only)

### ESP32 Firmware
- **NOT TESTED ON HARDWARE** - requires real sensors
- MPU6050 heading drifts over time
- Voltage divider CRITICAL for HC-SR04 Echo
- Motor power may need external supply
- BLE scan may interfere with sensor timing
- Simulation mode logic only, not tested with real data

---

## Important Notes

### YOLOv8
- Do not claim accuracy numbers unless you run the training
- Only report real mAP values from your training run
- Note AGPL license in your pitch/hackathon submission
- Clarify that inference time is Colab speed, not phone speed

### ESP32
- Clearly mark "NOT TESTED ON HARDWARE" in documentation
- Use SIMULATION_MODE for initial testing
- Voltage divider on HC-SR04 Echo is CRITICAL (will damage ESP32 without it)
- Tune distance thresholds on real cane (marked in config.h)
- Note MPU6050 drift in comments

---

## Next Steps

### For YOLOv8
1. Run training on your actual dataset
2. Verify mAP metrics
3. Test TFLite model on Android phone
4. Measure real inference time on phone
5. Adjust image size if too slow

### For ESP32
1. Wire hardware per WIRING.md
2. Test each sensor individually
3. Tune distance thresholds
4. Test BLE connection with Flutter app
5. Validate battery drain
6. Test with real blind users (later phase)

---

## License Notes

### YOLOv8 (Ultralytics)
- AGPL-3.0 license
- Must share modifications to YOLO code
- TFLite model can be used without sharing app code
- If you modify Ultralytics library, you must share modifications

### ESP32 Firmware
- MIT License (per your choice)
- Can be used commercially
- No copyleft requirements

---

## Troubleshooting

### YOLOv8 Training
- If GPU not available: training will be very slow (use smaller dataset or reduce epochs)
- If TFLite export fails: use ONNX fallback, convert with onnx-tf
- If label count warning: add more data or merge similar classes
- If out of memory: reduce batch size or image size

### ESP32 Firmware
- If compilation fails: check library versions in platformio.ini
- If sensors not detected: check I2C wiring, verify addresses
- If motors not vibrating: check transistor wiring, test motor directly
- If BLE not connecting: check phone BLE, restart ESP32
- If serial not working: check baud rate (115200), check USB driver

---

## File Locations

```
D:\wayze\
├── yolov8_training_colab.py    (Copy to Colab)
├── esp32_firmware\              (Open in PlatformIO)
│   ├── platformio.ini
│   ├── src\
│   │   ├── config.h
│   │   └── main.cpp
│   ├── README.md
│   └── WIRING.md
└── backend\                    (Python backend, optional)
```

---

## Summary

- **YOLOv8 Training**: Ready to run in Colab, produces TFLite for Flutter
- **ESP32 Firmware**: Code complete, compiles, NOT TESTED ON HARDWARE
- **Both**: Need actual hardware/sensors for final validation
- **Honesty**: Clearly mark what's tested vs not tested in documentation

Good luck with the hackathon! 🚀
