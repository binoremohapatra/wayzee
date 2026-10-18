# Wayze: Engineering Truth & Verification Checklist
**Honesty Policy**: Nothing is claimed as a "verified result" unless measured empirically on real physical hardware.

---

## 1. Classification of Claims

| Item / Claim | Classification | Evidence / Source of Truth | Presenting Guideline |
| :--- | :--- | :--- | :--- |
| **Alert Priority Queue (P0 Preemption)** | `VERIFIED` | Unit tested in `test/unit/alert_queue_test.dart` (P0 interrupts speech, clears queue). | State confidently as proven code logic. |
| **3-Second Cooldown per (Class, Zone)** | `VERIFIED` | Unit tested in `test/unit/alert_queue_test.dart` (suppresses repeats unless distance overrides). | State confidently as proven code logic. |
| **Drop-Off / Stairs-Down Trigger Rule** | `VERIFIED` | Tested in `test/unit/fusion_engine_test.dart` ($\ge 2$ consecutive downward samples $>145$cm). | State confidently as proven code logic. |
| **Topological Dijkstra Spoken Guidance** | `VERIFIED` | Tested in `test/unit/dijkstra_test.dart` (calculates steps, turns, avoids hazard nodes). | State confidently as proven code logic. |
| **Atomic Map Storage & Backup (.bak)** | `VERIFIED` | Tested in `test/unit/atomic_map_storage_test.dart` (temp file write, rename, backup restore). | State confidently as proven code logic. |
| **Safe Mode Crash-Loop Lockdown** | `VERIFIED` | Tested in `test/unit/safety_fallback_test.dart` (3 crashes in 5 mins locks camera/voice). | State confidently as proven code logic. |
| **Offline Vosk Voice & Repair Ladder** | `VERIFIED` | Tested in `test/voice/voice_session_test.dart` (65 passing tests; non-repeating prompts). | State confidently as proven code logic. |
| **Phone-Only Wording Rule** | `VERIFIED` | Tested in `test/unit/fusion_engine_test.dart` (metric cm suppressed to "near/far"). | State confidently as proven code logic. |
| **YOLOv8n Inference Latency (40-70 ms)** | `TARGET` | Estimated based on XNNPACK INT8 benchmarks on ARM Cortex-A55 cores. | Label as **TARGET**, never claim measured until tested on real phone. |
| **CameraX Frame Rate (10 FPS Analysis)** | `TARGET` | Throttle timing logic implemented; real camera sensor throttling depends on device thermal status. | Label as **TARGET / DESIGN SPEC**. |
| **Validation Dataset Accuracy (75.5% mAP)** | `ESTIMATE` | Measured in Google Colab validation split of Roboflow indoor dataset (`model_facts.json`). | State as **Lab Validation Dataset Result**; not tested with blind users. |
| **Battery Consumption (8-14% per hour)** | `ESTIMATE` | Theoretical power model of 2 ARM threads + CameraX image stream. | Label as **ESTIMATE** until 60-min battery drain test is logged. |
| **Smart Cane BOM ($19.20 @ 10k units)** | `ESTIMATE` | Component distributor pricing quotes (LCSC / JLCPCB / Mouser at volume). | Label as **ENGINEERING BOM ESTIMATE**. |
| **Smart Cane Hardware (ESP32-S3)** | `SIMULATED` | Simulated via `MockCaneSource` & Wokwi. Physical PCB NOT yet fabricated. | **Never claim cane is built.** Always state "Hardware architecture ready, simulated in app". |
| **Real Blind-User Trials / Feedback** | `NOT DONE` | Zero clinical or formal blind-user testing completed to date. | **Never claim blind user trials.** Say: "Phase 2 milestone is a 50-user pilot." |
| **Competitor Pricing & Features** | `VERIFY` | WeWALK ($600), UltraCane ($800), SmartCane (₹3.5k) compiled from market memory. | **Verify before presenting to external investors.** |

---

## 2. Real-Device Hardware Measurement Board
*(The team must run these tests on a physical device and write the real measured values here before stepping on stage)*

### Test Device Profile:
- **Phone Brand & Model**: `________________________` (e.g. Redmi 10 / Samsung Galaxy M13)
- **SoC / Chipset**: `________________________` (e.g. MediaTek Helio G85 / Snapdragon 680)
- **RAM / Storage**: `________________________` (e.g. 4GB RAM / 64GB Storage)
- **Android OS Version**: `________________________` (e.g. Android 13, OneUI 5.1 / MIUI 14)

---

### Empirical Benchmark Fill-In Fields:

| Metric | Target / Claim | Blank: Fill Real Measured Value | How to Measure with Wayze App |
| :--- | :--- | :--- | :--- |
| **Actual Inference Frame Rate (FPS)** | 10.0 FPS | `_______ FPS` | Open `/model_test`, read top HUD `FPS` counter during live preview. |
| **Inference Latency p50 (Median)** | $40 - 70\text{ ms}$ | `_______ ms` | Open `/model_test`, let camera run for 60 seconds, record `p50`. |
| **Inference Latency p95 (95th Percentile)**| $<80\text{ ms}$ | `_______ ms` | Open `/model_test`, record `p95` after 60 seconds. |
| **Model Disk Size (.tflite file)** | $\approx 3.5\text{ MB}$ (INT8) | `_______ MB` | Check `assets/models/wayze.tflite` exact file size in file explorer. |
| **False Alarms in Empty Room (5 mins)** | $\le 1\text{ alarm}$ | `_______ alarms` | Place phone in empty room on `/debug`, count false alerts over 5 mins. |
| **Battery Drain over 30 Mins Walk** | $5 - 8\%$ | `_______ %` | Charge to 100%, run camera navigation for 30 minutes, measure drop. |
| **Thermal Rise after 20 Mins Continuous**| Status: Nominal | Status: `_______` | Check `/model_test` HUD `Heat` indicator after 20 mins. |
| **Stairs Down Drop-Off Detection Range** | $>145\text{ cm}$ | `_______ cm` | Test at real staircase with MockCane / ToF sensor slider. |
| **Speech-to-Intent Latency (Vosk)** | $<250\text{ ms}$ | `_______ ms` | Time between phrase completion and state transition. |

---

### Per-Class Precision & Recall Lab Results (`assets/models/model_facts.json`):
- **Dataset Images (Train)**: 4,829 images
- **Dataset Images (Validation)**: 1,536 images
- **Overall mAP@50**: `0.7552` (75.5%)
- **Overall mAP@50-95**: `0.4963` (49.6%)
- **Overall Precision**: `0.7919` (79.2%)
- **Overall Recall**: `0.6708` (67.1%)
- **Recommended Confidence Threshold**: `0.45`
- **Class Breakdown**:
  - `door`: Precision `0.812`, Recall `0.704`
  - `stairs`: Precision `0.771`, Recall `0.638`
- **Classes Dropped Due to Low Training Data**: `glass_door`, `pillar`, `wet_floor_sign`.
