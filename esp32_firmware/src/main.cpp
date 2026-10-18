#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_VL53L0X.h>
#include <Adafruit_MPU6050.h>
#include <NimBLEDevice.h>
#include "config.h"

// =========================================================
// GLOBAL VARIABLES
// =========================================================

// Sensor readings
float fwd_cm = 0.0f;
float down_cm = 0.0f;
float heading_deg = 0.0f;

// Filter buffers
float fwd_buffer[MEDIAN_FILTER_SIZE];
float down_buffer[MEDIAN_FILTER_SIZE];
int buffer_index = 0;

// Timing
unsigned long last_sensor_read = 0;
unsigned long last_ble_send = 0;
unsigned long last_button_read = 0;

// BLE
NimBLEServer *pServer;
NimBLECharacteristic *pDataCharacteristic;
String current_beacon = "";
int current_rssi = -100;
bool phone_connected = false;

// MPU6050
Adafruit_MPU6050 mpu;
float heading_offset = 0.0f;

// Buttons
unsigned long btn_repeat_last = 0;
unsigned long btn_where_last = 0;
unsigned long btn_sos_last = 0;
bool btn_sos_long_press = false;

// Haptic patterns
enum HapticPattern {
  HAPTIC_NONE,
  HAPTIC_LEFT,
  HAPTIC_RIGHT,
  HAPTIC_DANGER
};
HapticPattern current_pattern = HAPTIC_NONE;
unsigned long haptic_start_time = 0;
int haptic_step = 0;

// =========================================================
// SENSOR READING FUNCTIONS
// =========================================================

// Read ultrasonic sensor (HC-SR04)
float readUltrasonic() {
#if SIMULATION_MODE
  return SIM_FWD_CM;
#else
  digitalWrite(PIN_ULTRASONIC_TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(PIN_ULTRASONIC_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(PIN_ULTRASONIC_TRIG, LOW);

  long duration = pulseIn(PIN_ULTRASONIC_ECHO, HIGH, ULTRASONIC_TIMEOUT_MS * 1000);
  float distance = duration * 0.0343 / 2.0;  // Convert to cm

  if (distance == 0 || distance > 400) {
    return -1;  // Error or out of range
  }
  return distance;
#endif
}

// Read VL53L0X ToF sensor
float readToF() {
#if SIMULATION_MODE
  return SIM_DOWN_CM;
#else
  static Adafruit_VL53L0X lox = Adafruit_VL53L0X();
  static bool initialized = false;

  if (!initialized) {
    Wire.begin(PIN_VL53L0X_SDA, PIN_VL53L0X_SCL);
    if (lox.begin()) {
      initialized = true;
      lox.startRangeContinuous();
    } else {
#if DEBUG_ENABLED
      Serial.println("Failed to initialize VL53L0X");
#endif
      return -1;
    }
  }

  if (lox.isRangeComplete()) {
    float distance = lox.readRangeResult();
    lox.startRangeContinuous();
    return distance;
  }
  return -1;  // No new data
#endif
}

// Median filter for smoothing
float medianFilter(float *buffer, int size) {
  // Simple bubble sort (small size, so OK)
  for (int i = 0; i < size - 1; i++) {
    for (int j = 0; j < size - i - 1; j++) {
      if (buffer[j] > buffer[j + 1]) {
        float temp = buffer[j];
        buffer[j] = buffer[j + 1];
        buffer[j + 1] = temp;
      }
    }
  }
  return buffer[size / 2];
}

// Update sensor readings
void updateSensors() {
  // Read raw values
  float raw_fwd = readUltrasonic();
  float raw_down = readToF();

  // Update filter buffers
  if (raw_fwd >= 0) {
    fwd_buffer[buffer_index] = raw_fwd;
  }
  if (raw_down >= 0) {
    down_buffer[buffer_index] = raw_down;
  }

  buffer_index = (buffer_index + 1) % MEDIAN_FILTER_SIZE;

  // Apply median filter (only if buffer is full)
  static int samples_count = 0;
  if (samples_count < MEDIAN_FILTER_SIZE) {
    samples_count++;
  } else {
    fwd_cm = medianFilter(fwd_buffer, MEDIAN_FILTER_SIZE);
    down_cm = medianFilter(down_buffer, MEDIAN_FILTER_SIZE);
  }

#if DEBUG_SENSORS
  Serial.print("Fwd: ");
  Serial.print(fwd_cm);
  Serial.print(" cm, Down: ");
  Serial.print(down_cm);
  Serial.println(" cm");
#endif
}

// =========================================================
// MPU6050 HEADING
// =========================================================

void initMPU6050() {
#if !SIMULATION_MODE
  Wire.begin(PIN_MPU6050_SDA, PIN_MPU6050_SCL);
  if (mpu.begin()) {
    mpu.setGyroRange(MPU6050_RANGE_250_DEG);
    mpu.setAccelerometerRange(MPU6050_RANGE_2_G);
#if DEBUG_ENABLED
    Serial.println("MPU6050 initialized");
#endif
  } else {
#if DEBUG_ENABLED
    Serial.println("Failed to initialize MPU6050");
#endif
  }
#endif
}

void updateHeading() {
#if !SIMULATION_MODE
  sensors_event_t a, g, temp;
  mpu.getEvent(&a, &g, &temp);

  // Integrate gyro (simplified - will drift over time)
  // NOTE: This is a rough estimate. Real implementation needs complementary filter with accelerometer
  static unsigned long last_heading_update = 0;
  float dt = (millis() - last_heading_update) / 1000.0;
  last_heading_update = millis();

  heading_deg += g.gyro.z * dt;  // Z-axis is yaw
  heading_deg = fmod(heading_deg, 360.0);
  if (heading_deg < 0) heading_deg += 360.0;

#if DEBUG_SENSORS
  Serial.print("Heading: ");
  Serial.print(heading_deg);
  Serial.println(" deg");
#endif
#endif
}

void resetHeading() {
  heading_offset = heading_deg;
  heading_deg = 0.0;
#if DEBUG_ENABLED
  Serial.println("Heading reset at beacon");
#endif
}

// =========================================================
// HAPTIC FUNCTIONS
// =========================================================

void initHaptics() {
  pinMode(PIN_MOTOR_LEFT, OUTPUT);
  pinMode(PIN_MOTOR_RIGHT, OUTPUT);
  ledcSetup(0, HAPTIC_PWM_FREQ, 8);  // Channel 0, left motor
  ledcSetup(1, HAPTIC_PWM_FREQ, 8);  // Channel 1, right motor
  ledcAttachPin(PIN_MOTOR_LEFT, 0);
  ledcAttachPin(PIN_MOTOR_RIGHT, 1);
}

void setHaptic(int left_intensity, int right_intensity) {
  ledcWrite(0, left_intensity);
  ledcWrite(1, right_intensity);
}

void stopHaptics() {
  setHaptic(0, 0);
}

void triggerHapticPattern(HapticPattern pattern) {
  current_pattern = pattern;
  haptic_start_time = millis();
  haptic_step = 0;
}

void updateHaptics() {
  if (current_pattern == HAPTIC_NONE) {
    stopHaptics();
    return;
  }

  unsigned long elapsed = millis() - haptic_start_time;

  switch (current_pattern) {
    case HAPTIC_LEFT:
      // 2 short pulses on left motor
      if (haptic_step == 0 && elapsed < HAPTIC_PULSE_SHORT) {
        setHaptic(HAPTIC_INTENSITY_MID, 0);
      } else if (haptic_step == 0 && elapsed >= HAPTIC_PULSE_SHORT) {
        stopHaptics();
        haptic_step = 1;
        haptic_start_time = millis();
      } else if (haptic_step == 1 && elapsed < HAPTIC_PATTERN_GAP) {
        // Gap
      } else if (haptic_step == 1 && elapsed >= HAPTIC_PATTERN_GAP) {
        haptic_step = 2;
        haptic_start_time = millis();
      } else if (haptic_step == 2 && elapsed < HAPTIC_PULSE_SHORT) {
        setHaptic(HAPTIC_INTENSITY_MID, 0);
      } else if (haptic_step == 2 && elapsed >= HAPTIC_PULSE_SHORT) {
        stopHaptics();
        current_pattern = HAPTIC_NONE;
      }
      break;

    case HAPTIC_RIGHT:
      // 3 short pulses on right motor
      if (haptic_step < 3) {
        int pulse_start = haptic_step * (HAPTIC_PULSE_SHORT + HAPTIC_PATTERN_GAP);
        int pulse_end = pulse_start + HAPTIC_PULSE_SHORT;
        if (elapsed >= pulse_start && elapsed < pulse_end) {
          setHaptic(0, HAPTIC_INTENSITY_MID);
        } else if (elapsed >= pulse_end && elapsed < pulse_start + HAPTIC_PATTERN_GAP) {
          stopHaptics();
        } else if (elapsed >= pulse_start + HAPTIC_PATTERN_GAP * 2) {
          haptic_step++;
        }
      } else {
        current_pattern = HAPTIC_NONE;
      }
      break;

    case HAPTIC_DANGER:
      // Long-short-long on both motors
      if (haptic_step == 0 && elapsed < HAPTIC_PULSE_LONG) {
        setHaptic(HAPTIC_INTENSITY_STRONG, HAPTIC_INTENSITY_STRONG);
      } else if (haptic_step == 0 && elapsed >= HAPTIC_PULSE_LONG) {
        stopHaptics();
        haptic_step = 1;
        haptic_start_time = millis();
      } else if (haptic_step == 1 && elapsed < HAPTIC_PULSE_SHORT) {
        // Gap
      } else if (haptic_step == 1 && elapsed >= HAPTIC_PULSE_SHORT) {
        haptic_step = 2;
        haptic_start_time = millis();
      } else if (haptic_step == 2 && elapsed < HAPTIC_PULSE_LONG) {
        setHaptic(HAPTIC_INTENSITY_STRONG, HAPTIC_INTENSITY_STRONG);
      } else if (haptic_step == 2 && elapsed >= HAPTIC_PULSE_LONG) {
        stopHaptics();
        current_pattern = HAPTIC_NONE;
      }
      break;

    default:
      current_pattern = HAPTIC_NONE;
      break;
  }
}

// =========================================================
// OBSTACLE LOGIC
// =========================================================

void updateObstacleLogic() {
  // Forward obstacle detection
  if (fwd_cm < DISTANCE_DANGER_CM) {
    // Danger zone - strong haptic
    // Continuous vibration for danger
    setHaptic(HAPTIC_INTENSITY_STRONG, HAPTIC_INTENSITY_STRONG);
  } else if (fwd_cm < DISTANCE_NEAR_CM) {
    // Near - medium haptic
    setHaptic(HAPTIC_INTENSITY_MID, HAPTIC_INTENSITY_MID);
  } else if (fwd_cm < DISTANCE_MID_CM) {
    // Mid - weak haptic
    setHaptic(HAPTIC_INTENSITY_WEAK, HAPTIC_INTENSITY_WEAK);
  } else {
    // Far - no haptic (unless pattern triggered)
    if (current_pattern == HAPTIC_NONE) {
      stopHaptics();
    }
  }

  // Drop-off / stairs detection
  static bool drop_detected = false;
  if (down_cm > DISTANCE_DOWN_DROP_CM && !drop_detected) {
    drop_detected = true;
    triggerHapticPattern(HAPTIC_DANGER);
#if DEBUG_HAPTICS
    Serial.println("Drop-off detected - danger pattern");
#endif
  } else if (down_cm < DISTANCE_DOWN_DROP_HYST && drop_detected) {
    drop_detected = false;
  }
}

// =========================================================
// BLE SCAN CALLBACK
// =========================================================

class ScanCallbacks: public NimBLEScanCallbacks {
  void onResult(NimBLEAdvertisedDevice* advertisedDevice) {
    String name = advertisedDevice->getName().c_str();
    if (name.startsWith(BEACON_NAME_PREFIX)) {
      int rssi = advertisedDevice->getRSSI();
      
      // Smooth RSSI with EMA
      static float smoothed_rssi = -100;
      smoothed_rssi = RSSI_EMA_ALPHA * rssi + (1 - RSSI_EMA_ALPHA) * smoothed_rssi;
      
      // Update if stronger
      if (smoothed_rssi > current_rssi) {
        current_rssi = smoothed_rssi;
        current_beacon = name;
        resetHeading();  // Reset heading at beacon
        
#if DEBUG_BLE
        Serial.print("Beacon: ");
        Serial.print(name);
        Serial.print(", RSSI: ");
        Serial.println(current_rssi);
#endif
      }
    }
  }
};

// =========================================================
// BLE SERVER CALLBACKS
// =========================================================

class ServerCallbacks: public NimBLEServerCallbacks {
  void onConnect(NimBLEServer* pServer) {
    phone_connected = true;
    digitalWrite(PIN_LED, HIGH);
#if DEBUG_BLE
    Serial.println("Phone connected");
#endif
  };

  void onDisconnect(NimBLEServer* pServer) {
    phone_connected = false;
    digitalWrite(PIN_LED, LOW);
#if DEBUG_BLE
    Serial.println("Phone disconnected");
#endif
  };
};

// =========================================================
// BLE INITIALIZATION
// =========================================================

void initBLE() {
  NimBLEDevice::init(BLE_DEVICE_NAME);
  NimBLEDevice::setPower(ESP_PWR_LVL_P9);  // Max power

  // Setup scan
  NimBLEScan* pScan = NimBLEDevice::getScan();
  pScan->setScanCallbacks(new ScanCallbacks());
  pScan->setActiveScan(true);
  pScan->setInterval(100);
  pScan->setWindow(99);
  pScan->start(0, false);  // Continuous scan

  // Setup server
  pServer = NimBLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  NimBLEService* pService = pServer->createService("181A");  // Environmental Sensing service

  // Data characteristic (notify)
  pDataCharacteristic = pService->createCharacteristic(
    "2A6E",
    NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY
  );

  pService->start();

  // Start advertising
  NimBLEAdvertising* pAdvertising = pServer->getAdvertising();
  pAdvertising->addServiceUUID(pService->getUUID());
  pAdvertising->start();

#if DEBUG_BLE
  Serial.println("BLE initialized");
#endif
}

// =========================================================
// BUTTON HANDLING
// =========================================================

void initButtons() {
  pinMode(PIN_BTN_REPEAT, INPUT_PULLUP);
  pinMode(PIN_BTN_WHERE_AM_I, INPUT_PULLUP);
  pinMode(PIN_BTN_SOS, INPUT_PULLUP);
}

int readButtons() {
  int btn_state = 0;  // Bitmask: 1=Repeat, 2=Where, 4=SOS

  if (digitalRead(PIN_BTN_REPEAT) == LOW) {
    if (millis() - btn_repeat_last > BUTTON_DEBOUNCE_MS) {
      btn_state |= 1;
      btn_repeat_last = millis();
      triggerHapticPattern(HAPTIC_LEFT);  // Left pattern for repeat
#if DEBUG_BUTTONS
      Serial.println("Button: Repeat");
#endif
    }
  }

  if (digitalRead(PIN_BTN_WHERE_AM_I) == LOW) {
    if (millis() - btn_where_last > BUTTON_DEBOUNCE_MS) {
      btn_state |= 2;
      btn_where_last = millis();
      triggerHapticPattern(HAPTIC_RIGHT);  // Right pattern for where am I
#if DEBUG_BUTTONS
      Serial.println("Button: Where am I");
#endif
    }
  }

  if (digitalRead(PIN_BTN_SOS) == LOW) {
    if (millis() - btn_sos_last > BUTTON_DEBOUNCE_MS) {
      btn_state |= 4;
      btn_sos_last = millis();
      
      // Check for long press
      if (millis() - btn_sos_last > BUTTON_LONG_PRESS_MS && !btn_sos_long_press) {
        btn_sos_long_press = true;
        triggerHapticPattern(HAPTIC_DANGER);
#if DEBUG_BUTTONS
        Serial.println("Button: SOS long press");
#endif
      }
    }
  } else {
    btn_sos_long_press = false;
  }

  return btn_state;
}

// =========================================================
// SEND DATA OVER BLE
// =========================================================

void sendBLEData(int btn_state) {
  if (!phone_connected) {
    return;  // Standalone mode - don't send
  }

  // JSON format: {"beacon":"name","rssi":-60,"fwd_cm":150,"down_cm":200,"btn":0}
  String json = "{";
  json += "\"beacon\":\"" + current_beacon + "\",";
  json += "\"rssi\":" + String(current_rssi) + ",";
  json += "\"fwd_cm\":" + String(fwd_cm) + ",";
  json += "\"down_cm\":" + String(down_cm) + ",";
  json += "\"btn\":" + String(btn_state);
  json += "}";

  pDataCharacteristic->setValue(json);
  pDataCharacteristic->notify();
}

// =========================================================
// SETUP
// =========================================================

void setup() {
  Serial.begin(115200);
#if DEBUG_ENABLED
  Serial.println("Wayze Smart Cane - Starting up");
#endif

  // Initialize pins
  pinMode(PIN_ULTRASONIC_TRIG, OUTPUT);
  pinMode(PIN_ULTRASONIC_ECHO, INPUT);
  pinMode(PIN_LED, OUTPUT);
  digitalWrite(PIN_LED, LOW);

  // Initialize sensors
  initMPU6050();
  initHaptics();
  initButtons();
  initBLE();

#if DEBUG_ENABLED
  Serial.println("Initialization complete");
#endif
}

// =========================================================
// MAIN LOOP
// =========================================================

void loop() {
  unsigned long now = millis();

  // Sensor reading at 20 Hz
  if (now - last_sensor_read >= (1000 / SENSOR_READ_FREQ_HZ)) {
    last_sensor_read = now;
    updateSensors();
    updateHeading();
    updateObstacleLogic();
  }

  // Haptic pattern update (non-blocking)
  updateHaptics();

  // Button reading
  int btn_state = readButtons();

  // BLE data transmission at 5 Hz
  if (now - last_ble_send >= (1000 / BLE_DATA_FREQ_HZ)) {
    last_ble_send = now;
    sendBLEData(btn_state);
  }

  // Small delay to prevent watchdog
  delay(1);
}
