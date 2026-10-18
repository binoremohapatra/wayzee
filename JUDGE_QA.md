# Judge Q&A Preparation Sheet

## Q1: Why not GPS for indoor navigation?

**Answer:** GPS doesn't work indoors - buildings block satellite signals. Accuracy indoors is 10-50 meters vs 3-5 meters outdoors. We use BLE beacons at decision points for precise indoor positioning.

---

## Q2: Why do you need a backend if everything is offline?

**Answer:** Backend is OPTIONAL. Core navigation works fully offline. Backend is only for extras: sharing maps via QR, caregiver SOS history, model updates. App functions 100% without backend.

---

## Q3: Why not just a phone app? Why the hardware?

**Answer:** Phone alone can't measure distance to obstacles accurately. Ultrasonic + ToF sensors give precise distance (up to 300cm). Phone camera only sees "what", sensors tell "how far". Hardware enables hands-free operation too.

---

## Q4: What is the accuracy of your object detection?

**Answer:** We haven't measured accuracy yet - this is a hackathon prototype. YOLO nano on Pi 5 does inference in 85-106ms per 640px image (published benchmark). Real accuracy will need validation with real users and real environments.

---

## Q5: What about battery life?

**Answer:** Not tested on real hardware yet. Raspberry Pi 5 draws ~5-10W, battery life would be 2-4 hours with power bank. Phone running Wayze will have similar battery impact to camera apps. We plan spoken low-battery alerts at 30%, 15%, 5%.

---

## Q6: How much will the final product cost?

**Answer:** Estimates only: Compute unit (Pi 5 + camera) ~Rs 10,000-12,000. Cane module (ESP32 + sensors) ~Rs 2,500. Total ~Rs 12,500-14,500. Much cheaper than existing commercial aids (Rs 50,000+). These are estimates, actual costs may vary.

---

## Q7: What about privacy? Do you collect data?

**Answer:** All core functions work offline. Camera frames never leave the device. Audio never leaves the device. Optional backend (for map sharing, caregiver alerts) is opt-in only. No personal data required for maps. No GPS tracking.

---

## Q8: What licenses are you using?

**Answer:** YOLO from Ultralytics is AGPL-licensed (we must share modifications). Piper TTS is GPL-licensed. MMS TTS is non-commercial license. We are complying with these licenses - open source code will be shared.

---

## Q9: What if a BLE beacon dies or is missing?

**Answer:** Dead-reckoning fallback using accelerometer and gyroscope (MPU6050 in cane). Phone last-known position is used. Navigation continues with reduced accuracy. Map indicates where beacons should be.

---

## Q10: Have you tested with real blind users?

**Answer:** No, not yet. This is a hackathon prototype. Validation with real blind users is in our roadmap (Phase 3). We need feedback on real-world usability, voice clarity, haptic patterns.

---

## Q11: How is this different from existing aids like SmartCanes?

**Answer:** Wayze works WITH white cane, doesn't replace it. Multi-sensor fusion (vision + distance). Offline-first, no subscription. Multi-language TTS (Hindi, Marathi, English). Map-based navigation with pathfinding. Open source stack.

---

## Q12: What are your next steps after this hackathon?

**Answer:** Real hardware integration (ESP32 cane + Pi 5). Real BLE beacon deployment. Testing with real blind users. Multi-floor support. Voice commands (Vosk). Battery optimization. Cost reduction for mass production.

---

## Bonus Questions

### Q13: Why Raspberry Pi 5 and not Pi 4?

**Answer:** Pi 5 has better CPU (2-3x faster) for YOLO inference. Better camera support. More RAM. But Pi 4 could work with reduced performance. We chose Pi 5 for smoother experience.

### Q14: What happens if phone battery dies?

**Answer:** Cane module works independently - has haptic motors, sensors, BLE scanning. User can still get obstacle alerts without phone. Navigation limited without compute unit.

### Q15: How do you handle multi-floor buildings?

**Answer:** Not implemented yet. Roadmap includes floor detection via barometric pressure or beacon floor ID. Separate maps per floor. Floor transition at elevators/stairs.

---

## Notes for Judges

- Be honest about what's tested vs not tested
- Emphasize "prototype" and "hackathon" nature
- Focus on the problem-solution fit
- Highlight offline-first design
- Acknowledge limitations openly
