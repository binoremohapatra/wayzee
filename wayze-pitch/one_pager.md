# WAYZE: Executive Summary (One-Pager)
**Offline-First Indoor Navigation & Hazard Alert Ecosystem for Visually Impaired Users**  
*Motto: "A supplement to the white cane, never a replacement."*

---

### 1. The Problem
Over **1.5 Crore (15M) visually impaired people in India** rely on the traditional white cane. While the cane is unbeatable at detecting immediate floor-level contact (1 meter radius), it leaves users vulnerable to:
- **Chest & Head-Level Obstacles**: Open cupboards, low signs, hanging wires, moving people.
- **Directional Void**: No indoor GPS exists. Canes cannot provide room-to-room navigation (*"Walk 5m straight, turn left into bathroom"*).
- **Cloud Latency Risk**: Existing AI apps (Seeing AI, Be My Eyes) stream frames to cloud servers with **250–800 ms latency**, requiring high-speed data and draining battery. A 0.5s network lag causes staircase falls.

### 2. The Solution: Wayze
Wayze is an **offline-first Android runtime + plug-and-play smart cane ecosystem** running real-time edge AI on budget smartphones (4GB RAM, Snapdragon 680 / Helio G85):
- **100% On-Device Edge AI**: Custom-trained INT8 Quantized **YOLOv8n** running on phone CPU via ARM XNNPACK (40–70 ms target latency). **$0 cloud bill, zero GPU needed.**
- **Screen-Off Background Guidance**: Runs as an Android Foreground Service with Partial WakeLock. Phone stays on chest lanyard; user navigates with screen OFF.
- **Sensor Fusion & Drop-Off Protection**: Fuses vision with downward cane range. If downward distance exceeds 145cm for $\ge 2$ samples $\rightarrow$ instant **P0 Danger Alert** (*"Stairs down ahead. Stop."*).
- **Phone-Only Mode Today**: Works without any smart cane hardware right now. Plugs into future BLE cane with zero code changes.
- **Voice & Priority Audio**: Offline Hindi + English Vosk grammar with repair ladder. Priority queue preempts speech for emergency hazards; 3-second cooldown suppresses annoying chatter.

---

### 3. Architecture & Reliability At A Glance
```
[CameraX 30 FPS] ──> [RAM YUV->RGB Letterbox 320x320] ──> [YOLOv8n INT8 CPU] ──> [NMS]
                                                                                   │
[Smart Cane / IMU] ──> [Sensor Fusion Engine] <── [HFOV Zone Math (-12°/0°/+12°)] ◄┘
                              │
[SQLite Room Map] ──> [Dijkstra Router] ──> [Priority Queue: P0 Danger | P1 Nav | P2 Info]
                                                    │
                                                    ▼
                                    [TTS Voice & Multi-level Haptics]
```
- **Privacy By Design**: Video frames processed strictly in volatile RAM, immediately discarded. Zero images saved or sent.
- **Deterministic Fail-Safes**: 2000ms vision watchdog auto-recovery; 25s periodic heartbeat tick (silence never means safe); 3 crashes in 5 min $\rightarrow$ **Safe Mode** lockdown.

---

### 4. Unit Economics & Competitive Landscape
| Metric | WeWALK Smart Cane | SmartCane (IIT Delhi) | Seeing AI / Lookout | **Wayze** |
| :--- | :--- | :--- | :--- | :--- |
| **User Upfront Price** | ₹55,000+ ($600) | ₹3,500 – ₹10,000 | Free (Software Only) | **App: FREE / Cane Target BOM: ₹1,800 ($22)** |
| **Object AI Vision** | None | None | Cloud Vision (Photos) | **On-Device YOLOv8n (10 FPS Continuous)** |
| **Indoor Navigation**| Poor (GPS dependent) | None | None | **In-Memory Dijkstra + SQLite Room Graph** |
| **Connectivity** | Cloud App Required | Offline Ultrasonic | Requires 4G/5G Cloud | **100% Offline-First (Airplane Mode Proof)** |
| **Inference Cost** | Subscription / Cloud | None | High AWS Cloud OpEx | **$0.00 / Month Cloud Inference Bill** |

- **BOM at Scale (10,000 units)**: **$19.20 (~₹1,600)** (ESP32-S3 + ToF Laser + Ultrasonic + IMU + Li-ion battery).
- **Infra OpEx**: **$0.05 to $0.40 per user/month** (static CDN map-packs & text crashlytics only).

---

### 5. Current Status: Verified vs. Targets
- **VERIFIED NOW (Code & Unit Suite)**: 109 automated unit/integration tests passing; full offline intent parser; P0 priority interrupt logic; 3s cooldown; atomic SQLite `.tmp` writes with `.bak` preservation; simulated MockCane sliders & scenario runner; Model Benchmark screen with live HUD & CSV export.
- **TARGETS (To Be Empirically Measured on Real Hardware)**: Snapdragon 680 real-world p50/p95 latency (target 40–70 ms); battery drain over 60 mins continuous walk; mAP and per-class recall across Indian home lighting variations.
- **PLANNED**: Phase 2 field trials with 50 visually impaired students; Phase 3 physical cane PCB fabrication.

---

### 6. The Ask: ₹15 Lakhs ($18,000) Non-Dilutive Grant
1. **₹6 Lakhs (40%)**: 100 prototype Smart Cane units fabrication & injection-molding tooling.
2. **₹5 Lakhs (33%)**: 50-user Blind School field trial program (travel stipends, testing oversight, localized voice sampling).
3. **₹4 Lakhs (27%)**: WPC / BIS Indian wireless & battery safety certification and benchmark validation.

**Contact**: [founder@wayze.in](mailto:founder@wayze.in) | GitHub: `https://github.com/binoremohapatra/wayzee.git`
