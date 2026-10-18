# Wayze ESP32 Smart Cane Firmware

ESP32 firmware for the Wayze smart-cane module using Arduino framework via PlatformIO.

## Hardware Components

- ESP32 DevKit
- HC-SR04 Ultrasonic sensor (forward)
- VL53L0X ToF sensor (I2C, downward)
- MPU6050 Gyroscope/Accelerometer (I2C)
- 2 Vibration motors (left/right)
- 3 Buttons (Repeat, Where am I, SOS)
- Transistors + flyback diodes for motor control

## Wiring Table

| Component | ESP32 Pin | Notes |
|-----------|-----------|-------|
| HC-SR04 Trig | GPIO 5 | Output |
| HC-SR04 Echo | GPIO 18 | Input with voltage divider to 3.3V |
| VL53L0X SDA | GPIO 21 | I2C SDA |
| VL53L0X SCL | GPIO 22 | I2C SCL |
| VL53L0X XSHUT | GPIO 19 | Optional reset pin |
| MPU6050 SDA | GPIO 21 | I2C SDA (shared with VL53L0X) |
| MPU6050 SCL | GPIO 22 | I2C SCL (shared with VL53L0X) |
| Motor Left PWM | GPIO 16 | PWM output |
| Motor Right PWM | GPIO 17 | PWM output |
| Button Repeat | GPIO 26 | INPUT_PULLUP |
| Button Where Am I | GPIO 27 | INPUT_PULLUP |
| Button SOS | GPIO 33 | INPUT_PULLUP |
| LED Status | GPIO 2 | Built-in LED |

### Voltage Divider for HC-SR04 Echo
The HC-SR04 Echo pin outputs 5V, which will damage ESP32. Use a voltage divider:
- Echo pin → 1kΩ resistor → GPIO 18
- GPIO 18 → 2kΩ resistor → GND
- This divides 5V to ~3.3V

## Installation

1. Install PlatformIO IDE extension in VS Code
2. Open this folder in VS Code
3. PlatformIO will automatically install dependencies
4. Connect ESP32 via USB
5. Upload firmware (F5 in PlatformIO)

## Configuration

Edit `config.h` to customize:
- Pin assignments
- Distance thresholds
- Haptic patterns
- BLE settings
- Simulation mode

## Features

### 1. Sensor Reading Loop
- Reads ultrasonic and ToF sensors at ~20 Hz
- Applies median filter (3 samples)
- Prints distances to Serial

### 2. Obstacle Logic
- Haptic intensity by distance bands
- Drop-off/stairs detection from downward ToF
- Configurable thresholds (marked "tune on real cane")

### 3. Non-blocking Haptic Patterns
- Left: 2 short pulses
- Right: 3 short pulses
- Danger: long-short-long pattern
- No delay() calls - uses millis()

### 4. BLE Scanning
- Scans for beacons with configured name/UUID prefix
- Smooths RSSI using EMA (Exponential Moving Average)
- Reports strongest beacon

### 5. BLE GATT Server
- Streams JSON data to phone at 5 Hz
- Standalone mode: haptics work without phone
- JSON format: `{"beacon":"name","rssi":-60,"fwd_cm":150,"down_cm":200,"btn":0}`

### 6. MPU6050 Heading
- Reads gyroscope for heading
- Resets at each beacon event
- Note: Drift over time, needs calibration

### 7. Button Handling
- Debounce logic (50ms)
- Sends events over BLE
- Buttons: Repeat, Where am I, SOS

### 8. Simulation Mode
- Set `SIMULATION_MODE` to true in config.h
- Fake distances for testing without sensors
- Test logic over Serial monitor

## Test Checklist

### Phase 1: Sensor Reading
- [ ] Upload firmware with SIMULATION_MODE = true
- [ ] Open Serial monitor (115200 baud)
- [ ] Verify fake distances printed
- [ ] Set SIMULATION_MODE = false
- [ ] Connect sensors
- [ ] Verify real distances printed
- [ ] Check ultrasonic range (2-400 cm)
- [ ] Check ToF range (up to 200 cm)

### Phase 2: Obstacle Logic
- [ ] Test haptic intensity at different distances
- [ ] Verify danger threshold triggers strong haptics
- [ ] Test drop-off detection (move hand under ToF)
- [ ] Tune thresholds in config.h (mark as "tuned")

### Phase 3: Haptic Patterns
- [ ] Test left pattern (2 short)
- [ ] Test right pattern (3 short)
- [ ] Test danger pattern (long-short-long)
- [ ] Verify no blocking (other sensors still read)

### Phase 4: BLE Scanning
- [ ] Set up BLE beacon with configured name
- [ ] Verify beacon detected
- [ ] Check RSSI smoothing
- [ ] Test multiple beacons (strongest reported)

### Phase 5: BLE GATT Server
- [ ] Install nRF Connect or LightBlue on phone
- [ ] Connect to ESP32 BLE
- [ ] Subscribe to notification characteristic
- [ ] Verify JSON data received at 5 Hz
- [ ] Test standalone mode (disconnect phone, haptics still work)

### Phase 6: MPU6050 Heading
- [ ] Verify MPU6050 detected
- [ ] Check heading output
- [ ] Test heading reset on beacon detection
- [ ] Note drift over time (add to config comments)

### Phase 7: Buttons
- [ ] Test each button press
- [ ] Verify debounce (no multiple triggers)
- [ ] Check button events sent over BLE
- [ ] Test all buttons simultaneously

### Phase 8: Integration
- [ ] Run all features together
- [ ] Monitor Serial for errors
- [ ] Test battery drain
- [ ] Verify no crashes over extended use

## Known Issues

- MPU6050 heading drifts over time (needs periodic calibration)
- BLE scan may interfere with sensor timing (tested, NOT TESTED ON HARDWARE)
- Voltage divider needed for HC-SR04 Echo pin (CRITICAL)
- Motor power may need external supply (NOT TESTED ON HARDWARE)

## Dependencies

- Wire library (I2C)
- Adafruit VL53L0X library
- Adafruit MPU6050 library
- NimBLE-Arduino library (BLE)
- ESP32Servo library (for PWM)

## License

MIT License - See LICENSE file for details

## Status

- Code written and compiles
- **NOT TESTED ON HARDWARE** - Requires actual sensors and ESP32
- Simulation mode tested via logic review only
