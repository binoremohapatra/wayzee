# Wayze Deep Explainer: Everything Explained From First Principles
**A Complete Beginner-to-Expert Guide for Founders, Evaluators, and Engineers**

---

## 1. What is Wayze? (The Simple Analogy)

Imagine you are walking through a crowded, unfamiliar house in total pitch darkness. You have a long wooden stick in your hand. 
- The stick can tap the floor and tell you if there is a wall or table leg right in front of your toes. 
- But the stick **cannot** tell you if someone left an open cupboard door at head height. It **cannot** warn you that 3 steps ahead there is an open staircase going down. And it **cannot** guide you with directions like: *"Walk 5 meters straight, then turn left into the bathroom."*

**Wayze is your sighted co-pilot who walks right beside you.**
Wayze sits on your chest in your smartphone or connects to a smart cane. It watches the room using computer vision, measures distances, remembers the floor plan of the building, and speaks softly into your ear: *"Chair ahead, move slightly right"*, or taps your wrist with a heavy vibration: *"Stop! Stairs down."*

> [!IMPORTANT]
> **The Golden Rule**: Wayze is a **SUPPLEMENT** to the white cane, never a replacement. The white cane provides physical tactile ground truth that never runs out of battery. Wayze extends that awareness to 3 to 5 meters ahead and across 3 dimensions.

---

## 2. The Ravi Acceptance Scenario (Bed to Bathroom Timed Walkthrough)

Here is a real-world demonstration of how Wayze behaves second-by-second when a visually impaired user named Ravi walks from his bed to the bathroom in the morning:

| Time | User Action / Physical Reality | Component Working | What Wayze Does (Spoken & Haptic) | Behind the Scenes Engineering Logic |
| :--- | :--- | :--- | :--- | :--- |
| **0.0s** | Ravi long-presses Volume-Up key while getting out of bed. | Android Native `MainActivity.kt` key interceptor | Phone vibrates once (`tick`), state shifts from `Idle` to `Listening`. | Screen remains completely OFF. Hardware key triggers Flutter EventChannel without waking display. |
| **1.0s** | Ravi listens for the prompt. | SpeechCenter + Native Android TTS | Phone speaks: *"Bol, kahan jaana hai?"* (or English *"Where to go?"*). | TTS output is routed through ambient speaker; speech recognition session activates. |
| **2.2s** | Ravi speaks in Hindi: *"Bathroom le chalo."* | Offline Vosk STT engine | Intent Matcher identifies `Intent.startNavigation` with destination `bathroom`. | Vosk runs local acoustic + grammar matching in RAM. Zero audio leaves the phone. |
| **3.0s** | System confirms destination. | AppStateMachine | Speaks: *"Theek hai, bathroom. Chalo."* State shifts to `Navigating`. | Foreground Service acquires `PARTIAL_WAKE_LOCK`. Native CameraX starts streaming at 30 FPS. |
| **4.0s** | Ravi takes his first step. | In-Memory Dijkstra + SQLite Map | Speaks: *"Bed se door, 3 meter seedha."* | Dijkstra calculates shortest topological path from `node_bed` to `node_door` avoiding known hazard zones. |
| **7.5s** | A dining chair has been placed in the hallway path. | CameraX + YOLOv8n INT8 | YOLO detects `chair` in Center Zone. Bounding box area = 0.09. | CameraX converts YUV to RGB letterbox in direct buffer. Model infers in ~55ms. |
| **8.0s** | Ravi continues moving forward. | VisionTracker + Temporal Filter | 3 consecutive confirming frames show chair growing (area = 0.16, bottomY = 0.78). Threat score exceeds threshold. | Temporal filter ensures single-frame flickering shadows do not cause false alarms. |
| **8.3s** | Wayze alerts Ravi. | AlertQueue + TTS | Speaks: *"Kursi seedha, paas hai."* Phone gives double short haptic pulse. | AlertQueue assigns P1 Navigation priority. Speaks because queue is idle. Cooldown timer started for `(chair, center)`. |
| **9.5s** | Ravi pauses and tilts his cane to locate the chair. | Cooldown Logic | **Silence.** App does NOT repeat *"Kursi seedha"*. | 3-second cooldown rule suppresses chatter. Prevents audio fatigue. |
| **12.0s** | Ravi taps forward; white cane / smart cane sensor gets within 40cm. | Cane Sensor / `MockCaneSource` | **P0 PREEMPTION**: Speech interrupted! Heavy long buzz (400ms)! Speaks: *"Obstacle 40cm ahead."* | Any hazard $<50$cm triggers P0 Danger. P0 immediately flushes lower queue, cuts active TTS, and buzzes heavy. |
| **15.0s** | Ravi steps around chair to his left. | CameraX + Tracker | Chair moves to Right Zone, area shrinks. Hazard clears. | Kalman filter tracks bounding box centroid across frames. |
| **21.0s** | Ravi reaches the bedroom doorway. | Dijkstra Router + Map Graph | Speaks: *"Door aa gaya. Left mudo, hall hai."* | Proximity check registers arrival at `node_door`, fetches next route step edge. |
| **32.0s** | Ravi reaches the bathroom door. | Dijkstra Router | Speaks: *"Bathroom reached."* State returns to `Idle`. Long soft vibration. | Navigation completes cleanly. Camera analysis throttles down to idle rate. |

---

## 3. Frontend vs. On-Device Backend vs. Optional Cloud

```
┌────────────────────────────────────────────────────────────────────────┐
│                        FLUTTER FRONTEND (UI & AUDIO)                   │
│  - TalkBack Accessibility Semantics   - High-contrast OLED Theme       │
│  - Big Tactile Buttons (min 64dp)     - Native Android TTS Wrapper     │
│  - Voice Session Repair Ladder        - Multi-level Haptic Motor Engine│
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ MethodChannel & EventChannel
┌───────────────────────────────────▼────────────────────────────────────┐
│                  ON-DEVICE BACKEND (NO INTERNET NEEDED)                │
│  - CameraX ImageAnalysis (30 FPS)     - YOLOv8n INT8 TFLite (XNNPACK)  │
│  - Direct ByteBuffer YUV->RGB         - HFOV Bearing Angle Zone Math   │
│  - Kalman Tracker + Threat Scoring    - Priority Alert Queue (P0/P1/P2)│
│  - Sensor Fusion Engine               - SQLite Indoor Navigation Graph │
│  - Offline Vosk STT (Hindi/English)   - Heartbeat & Thermal Governors  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ (Feature-flagged, OFF by default)
┌───────────────────────────────────▼────────────────────────────────────┐
│                    OPTIONAL MINIMAL CLOUD LAYER (CDN)                  │
│  - Static CDN for Model & Map-Pack updates (SHA-256 + auto-rollback)   │
│  - User-initiated manual map backup export                             │
│  - Opt-in text-only crash stack traces (ZERO images, ZERO voice audio) │
└────────────────────────────────────────────────────────────────────────┘
```

### Why Cloud Inference Was Rejected:
1. **Network Latency Kills**: Sending video frames to AWS/GCP and waiting for bounding boxes takes **250ms to 800ms** on 4G networks in India. At walking speed, a user travels 0.5 to 1 meter in that time — meaning they hit the obstacle before the voice alert arrives.
2. **Data Bandwidth**: 30 FPS camera streaming consumes **~0.9 GB per hour**. For a blind user on a 1.5 GB/day mobile plan, their entire daily data limit would be exhausted in 90 minutes.
3. **Server Costs**: Cloud GPU instances (AWS g4dn/g5) cost **$2 to $5 per active user per month**. Our on-device architecture has a cloud inference cost of **$0.00**.

---

## 4. Deterministic Component Fallback Matrix

In life-safety systems, every single component must have a predictable fallback. When something breaks, Wayze tells the user immediately:

| Component | Normal Function | Failure Mode / Trigger | Exact System Recovery Action | Spoken / Tactile Feedback to User |
| :--- | :--- | :--- | :--- | :--- |
| **CameraX / YOLO Engine** | Detects obstacles, stairs, doors at 10 FPS. | Camera hangs, driver crashes, or no frames for 2000ms. | `VisionWatchdog` detects freeze; attempts native restart up to 3 times. If all 3 fail: switches permanently to Sensor + Map mode. | *"Vision stopped. Sensor and map mode active."* |
| **Smart Cane (BLE)** | Reports high-precision ultrasonic / ToF distance in cm. | Cane battery dies, user drops cane, or Bluetooth drops. | `BleCaneSource` detects disconnect; immediately delegates to `PhoneSensorSource`. Suppresses cm numbers; switches to "near/far" floor contact estimate. Auto-reconnects in background. | *"Cane disconnected. Phone-only mode."* |
| **Vosk Offline STT** | Recognizes voice commands in Hindi & English. | Ambient noise, fan sound, or unclear accent. | **Repair Ladder**: <br/>1. Soft retry (*"Sunayi nahi diya, fir se bolo"*).<br/>2. Guided retry (*"Bol sakte hain: Bathroom, Kitchen, ya Stop"*).<br/>3. Confirmation of best guess (*"Bathroom jaana hai? Haan ya na bolein"*).<br/>4. List mode & Big Button fallback. | Spoken repair prompt; never repeats the exact same sentence twice. |
| **Android TTS Engine** | Speaks navigation steps and obstacle warnings. | Audio server dies, Bluetooth headset disconnects, or TTS throws exception. | System intercepts TTS failure and immediately falls back to distinct tactile vibration patterns: P0 = 400ms heavy continuous buzz; P1 = 80ms double pulse. | Tactile vibration patterns (no speech). |
| **Map Storage (SQLite)** | Stores room graph, node coordinates, and hazard tags. | Sudden battery pull or crash during map write. | Startup validation detects missing nodes or broken edges. Automatically restores backup file `wayze_map.json.bak`. | *"Map restored from backup."* |
| **Phone Placement** | User hangs phone on chest via lanyard. | Phone slips into pocket (pitch > 75°) or tilts up to ceiling (pitch < 15°). | `OrientationGuard` reads phone IMU accelerometer. Detects camera is blocked or pointed away from walking path. | *"Place phone on your chest."* (or Hindi *"Phone ko seene pe seedha rakho."*) |
| **App Runtime** | Manages entire state machine. | 3 app crashes within 5 minutes. | **SAFE MODE ACTIVATION**: Kills camera, kills YOLO, kills voice recognition. Screen turns solid high-contrast red with one giant emergency button. Only simple vibration and cane alerts remain active. | Spoken aloud: *"Wayze is in safe mode. Use your cane."* |
| **Process Liveness** | Background navigation while phone screen is off. | Android OS aggressively kills background service. | **HEARTBEAT**: Subtle haptic tick every 25 seconds while navigating. If the ticks stop, user instantly knows the app died! | If ticks stop, user reverts to white cane immediately. |

---

## 5. Data Privacy & Storage Architecture

Wayze follows the strictest **zero-knowledge privacy** model:

```
┌────────────────────────────────────────────────────────┐
│                      DEVICE RAM                        │
│  [Camera Frame YUV] ──> [320x320 RGB] ──> [YOLO INT8]  │
│         ▲                                      │       │
│         │                                      ▼       │
│  Overwritten each tick                 Discarded in RAM│
│  (Never hits storage)                  (Zero persistence)
└────────────────────────────────────────────────────────┘
```

1. **Camera Frames**: Transformed into RGB byte buffers in volatile RAM, passed to TFLite, and immediately garbage collected. **No image is ever saved to flash storage or transmitted over the network.**
2. **Room Maps**: Saved locally in the app's sandboxed private SQLite database (`/data/user/0/com.wayze.app.wayze/databases/wayze_map.db`). Cannot be accessed by other apps.
3. **Settings**: Stored in standard `SharedPreferences` (voice speed, language, heartbeat on/off).
4. **Local Logs**: Circular text-only log ring limited to **5 MB or 7 days maximum**. Stores timestamps, error codes, and latency measurements. Contains zero camera frames or audio recordings.
5. **Opt-In Telemetry**: An explicit toggle *"Help improve Wayze"* is disabled by default. If enabled by user, it only sends anonymous text crash stack traces.

---

## 6. Target Device Requirements & Sensor Specifications

### Target Smartphone Hardware Profile:
- **Operating System**: Android 8.0 (API 26) through Android 14 (API 34).
- **RAM**: Minimum 3 GB (Target: 4 GB budget phones like Redmi 10, Realme Narzo, Samsung Galaxy M13).
- **SoC Tested**: Qualcomm Snapdragon 680 / MediaTek Helio G85.
- **Camera**: Standard back camera with $\ge 60^\circ$ Horizontal Field of View (HFOV).
- **Permissions Required**: 
  - `CAMERA` (for real-time RAM obstacle analysis)
  - `FOREGROUND_SERVICE` & `FOREGROUND_SERVICE_CAMERA` (for screen-off background navigation)
  - `WAKE_LOCK` (prevents CPU deep sleep while walking)
  - `VIBRATE` (for tactile emergency cues)
  - `BLUETOOTH_SCAN` & `BLUETOOTH_CONNECT` (for future BLE Smart Cane)

### Recommended Wearing Pose:
The phone is worn on an adjustable chest lanyard or shirt pocket mount at a **$70^\circ$ to $80^\circ$ angle** pointing slightly downwards towards the ground 2 to 4 meters ahead.

---

## 7. Why GPU Is NOT Needed at Inference

A common question from venture investors is: *"Don't you need an expensive NPU or GPU to run YOLO computer vision in real time?"*

The answer is **NO**, for three clear technical reasons:
1. **INT8 Quantization**: Full float32 weights (32 bits per parameter) are quantized to 8-bit integers (INT8). The model shrinks from 12.7 MB to ~3.5 MB, and complex floating-point multiplications become ultra-fast integer arithmetic.
2. **XNNPACK Engine**: Google’s XNNPACK library is specifically hand-optimized in ARM assembly for Cortex-A53, A55, and A73 CPU cores found in every budget Indian phone. It executes quantized $320\times 320$ convolutions in **40 to 70 milliseconds**.
3. **Thermal Envelope**: Running mobile GPUs causes thermal saturation within 10 minutes, triggering aggressive thermal throttling down to 1 FPS. 2-threaded CPU execution with stationary frame-rate throttling keeps the phone cool indefinitely.

---

## 8. How Simulated Components Work (MockCaneSource & Replay Harness)

Because the physical smart cane hardware is scheduled for manufacturing in Phase 3, Wayze was built with a clean hardware abstraction layer (`SensorSource`):

```dart
abstract class SensorSource {
  Stream<SensorReading> get readingStream;
  bool get isCaneConnected;
  void start();
  void stop();
}
```

1. **`PhoneSensorSource` (Active Today)**: Reads phone accelerometer and gyroscope. In phone-only mode, it projects the camera tilt angle to estimate floor contact, speaking *"near"* or *"far"* without claiming false centimeter accuracy.
2. **`MockCaneSource` (Active in Debug & Test)**: Features interactive UI sliders in the app's Debug screen (front distance 20-400cm, downward ground distance 50-300cm) and pre-recorded scenario buttons (`stairsDownAhead`, `obstacleClose`, `normalWalking`).
3. **`BleCaneSource` (Production Stub)**: Implements the exact 14-byte binary GATT packet parser (`seq`, `timestamp`, `dist_front_cm`, `dist_down_cm`, `pitch_tilt`, `flags`, `battery_pct`). When physical cane hardware arrives, pairing requires zero code changes to the app's business logic.
4. **`ReplayHarness`**: Feeds recorded CSV sensor streams and asserts that alert ordering, priority preemption, and 3-second cooldowns execute with 100% mathematical fidelity.
