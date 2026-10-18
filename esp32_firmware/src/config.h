#ifndef CONFIG_H
#define CONFIG_H

// =========================================================
// PIN CONFIGURATION - EDIT THESE AS NEEDED
// =========================================================

// Ultrasonic Sensor (HC-SR04)
#define PIN_ULTRASONIC_TRIG     5
#define PIN_ULTRASONIC_ECHO     18  // NOTE: Requires voltage divider (5V -> 3.3V)

// VL53L0X ToF Sensor (I2C)
#define PIN_VL53L0X_SDA        21
#define PIN_VL53L0X_SCL        22
#define PIN_VL53L0X_XSHUT      19  // Optional reset pin

// MPU6050 Gyroscope (I2C, shared with VL53L0X)
#define PIN_MPU6050_SDA        21  // Shared
#define PIN_MPU6050_SCL        22  // Shared

// Vibration Motors (PWM)
#define PIN_MOTOR_LEFT         16
#define PIN_MOTOR_RIGHT        17

// Buttons (INPUT_PULLUP)
#define PIN_BTN_REPEAT         26
#define PIN_BTN_WHERE_AM_I     27
#define PIN_BTN_SOS            33

// Status LED
#define PIN_LED                2  // Built-in LED

// =========================================================
// DISTANCE THRESHOLDS (in cm) - TUNE ON REAL CANE
// =========================================================

// Forward ultrasonic distance thresholds
#define DISTANCE_FAR_CM        150  // >150cm: no haptic
#define DISTANCE_MID_CM        100  // 100-150cm: weak haptic
#define DISTANCE_NEAR_CM       50   // 50-100cm: medium haptic
#define DISTANCE_DANGER_CM     30   // <30cm: strong haptic (danger)

// Downward ToF distance thresholds (for stairs/drop-off)
#define DISTANCE_DOWN_NORMAL_CM    100  // Normal floor distance
#define DISTANCE_DOWN_DROP_CM      150  // >150cm indicates drop-off/stairs
#define DISTANCE_DOWN_DROP_HYST    120  // Hysteresis to prevent flickering

// =========================================================
// HAPTIC CONFIGURATION
// =========================================================

// PWM frequency for motors (Hz)
#define HAPTIC_PWM_FREQ       200

// Haptic intensity (0-255)
#define HAPTIC_INTENSITY_WEAK    100
#define HAPTIC_INTENSITY_MID     180
#define HAPTIC_INTENSITY_STRONG  255

// Haptic pattern timings (ms)
#define HAPTIC_PULSE_SHORT      100
#define HAPTIC_PULSE_LONG       300
#define HAPTIC_PATTERN_GAP      150

// =========================================================
// SENSOR CONFIGURATION
// =========================================================

// Sensor reading frequency (Hz)
#define SENSOR_READ_FREQ_HZ     20

// Median filter window size (odd number)
#define MEDIAN_FILTER_SIZE      3

// Sensor timeout (ms)
#define ULTRASONIC_TIMEOUT_MS   30

// =========================================================
// BLE CONFIGURATION
// =========================================================

// Device name
#define BLE_DEVICE_NAME         "WayzeCane"

// Beacon filter (name prefix to match)
#define BEACON_NAME_PREFIX      "WAYZE"

// RSSI smoothing (EMA alpha: 0-1, lower = more smoothing)
#define RSSI_EMA_ALPHA          0.3

// BLE data transmission frequency (Hz)
#define BLE_DATA_FREQ_HZ        5

// =========================================================
// MPU6050 CONFIGURATION
// =========================================================

// Gyro sensitivity (degrees per second)
#define GYRO_SENSITIVITY_DPS    250

// Heading reset threshold (degrees change on beacon event)
#define HEADING_RESET_THRESHOLD 10

// =========================================================
// BUTTON CONFIGURATION
// =========================================================

// Debounce time (ms)
#define BUTTON_DEBOUNCE_MS      50

// Button long press time (ms) for SOS
#define BUTTON_LONG_PRESS_MS    2000

// =========================================================
// SIMULATION MODE
// =========================================================

// Set to true to test without sensors (fake distances)
// Set to false for real hardware
#define SIMULATION_MODE         false

// Simulated distances (cm) when SIMULATION_MODE is true
#define SIM_FWD_CM              150
#define SIM_DOWN_CM             100

// =========================================================
// DEBUG CONFIGURATION
// =========================================================

// Print debug messages to Serial
#define DEBUG_ENABLED           true

// Print sensor readings
#define DEBUG_SENSORS           true

// Print BLE information
#define DEBUG_BLE               true

// Print button events
#define DEBUG_BUTTONS           true

// Print haptic events
#define DEBUG_HAPTICS           true

#endif // CONFIG_H
