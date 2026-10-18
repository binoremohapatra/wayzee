# Wiring Diagram for Wayze ESP32 Smart Cane

## Hardware Components

1. ESP32 DevKit
2. HC-SR04 Ultrasonic Sensor
3. VL53L0X ToF Sensor
4. MPU6050 Gyroscope/Accelerometer
5. 2 Vibration Motors
6. 3 Push Buttons
7. Transistors (2x) + Diodes (2x) for motor control
8. Resistors for voltage divider and pull-ups

## Pin Connections

### ESP32 to HC-SR04 Ultrasonic Sensor
```
ESP32          HC-SR04
------------------------
GPIO 5    -->   Trig
GPIO 18   <--   Echo (via voltage divider)
GND      -->   GND
5V       -->   VCC
```

**CRITICAL: Voltage Divider for Echo Pin**
The HC-SR04 Echo pin outputs 5V, which will damage ESP32 (3.3V max).
Use this voltage divider:
```
Echo pin (5V) --[1kΩ]-- GPIO 18 --[2kΩ]-- GND
                       |
                  (3.3V to ESP32)
```

This divides 5V to approximately 3.3V: 5V * (2k / (1k + 2k)) = 3.33V

### ESP32 to VL53L0X ToF Sensor (I2C)
```
ESP32          VL53L0X
------------------------
GPIO 21   -->   SDA
GPIO 22   -->   SCL
GPIO 19   -->   XSHUT (optional)
3.3V     -->   VIN
GND      -->   GND
```

### ESP32 to MPU6050 (I2C, shared with VL53L0X)
```
ESP32          MPU6050
------------------------
GPIO 21   -->   SDA (shared with VL53L0X)
GPIO 22   -->   SCL (shared with VL53L0X)
3.3V     -->   VCC
GND      -->   GND
```

### ESP32 to Vibration Motors (PWM via Transistor)
```
ESP32          Motor Left          Motor Right
-------------------------------------------------
GPIO 16   -->   Transistor Base    Transistor Base
GND      -->   Transistor Emitter  Transistor Emitter
5V       -->   Motor (+)          Motor (+)
Motor (-) -->   Transistor Collector Transistor Collector
                 (with flyback diode) (with flyback diode)
```

**Motor Control Circuit (per motor):**
```
ESP32 GPIO --[1kΩ]-- NPN Transistor Base
                      |
NPN Transistor Emitter -- GND
NPN Transistor Collector -- Motor (-) -- 5V
                      |
Flyback Diode (cathode to 5V, anode to collector)
```

Recommended transistor: 2N2222 or BC547
Recommended diode: 1N4007 or 1N4148

### ESP32 to Buttons (INPUT_PULLUP)
```
ESP32          Button Repeat       Button Where Am I    Button SOS
--------------------------------------------------------------------
GPIO 26   <--   Button Pin        Button Pin          Button Pin
GND      -->   Other Side         Other Side          Other Side
```

Each button connects between GPIO and GND.
No external resistor needed (uses internal pull-up).

### Power Supply
```
5V Source    ESP32           Sensors          Motors
-------------------------------------------------
5V        -->   VIN             VCC              5V
GND       -->   GND             GND              GND
          -->   (shared ground)
```

Note: ESP32 can be powered via USB (5V) or external 5V supply.
Ensure common ground between all components.

## Summary Table

| Component | ESP32 Pin | Connection Type | Notes |
|-----------|-----------|-----------------|-------|
| HC-SR04 Trig | GPIO 5 | Output | 5V tolerant |
| HC-SR04 Echo | GPIO 18 | Input | **Voltage divider required** |
| VL53L0X SDA | GPIO 21 | I2C | Shared with MPU6050 |
| VL53L0X SCL | GPIO 22 | I2C | Shared with MPU6050 |
| VL53L0X XSHUT | GPIO 19 | Output | Optional reset |
| MPU6050 SDA | GPIO 21 | I2C | Shared with VL53L0X |
| MPU6050 SCL | GPIO 22 | I2C | Shared with VL53L0X |
| Motor Left | GPIO 16 | PWM | Via transistor |
| Motor Right | GPIO 17 | PWM | Via transistor |
| Button Repeat | GPIO 26 | Input | INPUT_PULLUP |
| Button Where Am I | GPIO 27 | Input | INPUT_PULLUP |
| Button SOS | GPIO 33 | Input | INPUT_PULLUP |
| LED Status | GPIO 2 | Output | Built-in LED |

## Component Specifications

### HC-SR04 Ultrasonic Sensor
- Operating voltage: 5V
- Range: 2cm to 400cm
- Accuracy: 3mm
- Trigger pulse: 10μs minimum
- Echo pulse duration: proportional to distance

### VL53L0X ToF Sensor
- Operating voltage: 2.6V to 3.5V
- Range: up to 2m (depending on target)
- I2C address: 0x29 (default)
- Accuracy: ±3%

### MPU6050 Gyroscope
- Operating voltage: 3.3V to 5V
- Gyro range: ±250°/s to ±2000°/s
- I2C address: 0x68 (default)
- Accelerometer range: ±2g to ±16g

### Vibration Motors
- Operating voltage: 3V to 5V
- Current: 50-100mA typical
- PWM frequency: 200Hz (configurable)

## Assembly Notes

1. **Voltage Divider is Critical**: Do not connect HC-SR04 Echo directly to ESP32. It will damage the pin.

2. **I2C Pull-up Resistors**: VL53L0X and MPU6050 have built-in pull-ups. If using long wires (>20cm), add external 4.7kΩ pull-ups to 3.3V.

3. **Motor Power**: Motors can draw significant current. Use a separate 5V supply if ESP32 5V pin cannot provide enough current.

4. **Decoupling Capacitors**: Add 100nF capacitors near sensor power pins for noise reduction.

5. **Button Debouncing**: Software debounce implemented (50ms). Hardware debouncing (0.1μF capacitor) optional but recommended.

## Testing Order

1. **Power Test**: Apply 5V, check LED turns on
2. **Serial Test**: Open Serial monitor (115200 baud), verify startup message
3. **Sensor Test**: Move hand in front of ultrasonic, verify distance changes
4. **ToF Test**: Move hand under ToF, verify distance changes
5. **Motor Test**: Trigger haptic patterns, verify motors vibrate
6. **Button Test**: Press buttons, verify Serial output
7. **BLE Test**: Use nRF Connect app, verify connection and data

## Troubleshooting

### HC-SR04 not working
- Check voltage divider on Echo pin
- Verify Trig pulse timing (10μs minimum)
- Check if Echo timeout is too short (increase in config.h)

### VL53L0X not detected
- Check I2C wiring (SDA/SCL)
- Verify I2C address (0x29)
- Check if XSHUT pin is low (should be high or floating)

### Motors not vibrating
- Check transistor wiring
- Verify PWM frequency (200Hz)
- Check motor voltage (3-5V)
- Test motor directly with 5V

### BLE not connecting
- Check phone BLE is enabled
- Verify device name "WayzeCane"
- Check if ESP32 is already connected to another device
- Restart ESP32 and phone

### MPU6050 not working
- Check I2C wiring (shared with VL53L0X)
- Verify I2C address (0x68)
- Check if sensor is receiving power (3.3V)
