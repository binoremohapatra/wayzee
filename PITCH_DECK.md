# Wayze - Hackathon Pitch Deck
**Tagline:** See the way. Feel the way.
**Domain:** IoT, Robotics and Hardware - PS4: Indoor Navigation Aid for the Visually Impaired

---

## Slide 1: Title

**Title:** Wayze
**Subtitle:** See the way. Feel the way.
**Team:** [Team Name] | [College Name]

**Bullets:**
- Indoor navigation aid for visually impaired
- Works WITH white cane, doesn't replace it
- Offline-first, privacy-focused

**Visual Idea:**
Split screen - left: person with white cane, right: phone/raspberry pi with Wayze UI showing direction arrow and navigation.

**Speaker Notes (30-45 sec, Hinglish):**
Namaste judges. Aaj hum aapko Wayze introduce kar rahe hain - ek indoor navigation aid jo visually impaired logon ke liye designed hai. Wayze white cane ko replace nahi karta, uske saath kaam karta hai. Sab kuch offline hota hai, koi data bahar nahi jata. Chaliye dekhte hain ki problem kya hai.

---

## Slide 2: The Problem

**Title:** Problem: Indoor Navigation is Hard

**Bullets:**
- GPS doesn't work indoors
- 6.2 million blind people in India* (source to verify)
- Existing aids are expensive or offline-only

**Visual Idea:**
Person with cane standing confused in a building corridor with multiple doors, no signage, GPS signal icon with "X".

**Speaker Notes (30-45 sec, Hinglish):**
Indoor mein GPS kaam nahi karta. India mein lagbhag 62 lakh blind log hain - ye figure NPCBVI website se verify karna hai. Jo existing solutions hain, ya toh bahut mehange hain ya fir sirf offline hain. Kisi ko guidance nahi milti ki ab kya karna hai.

---

## Slide 3: Our Solution

**Title:** Wayze: Complete Indoor Navigation

**Bullets:**
- Cane module + compute unit (phone or Pi 5)
- Vision + sensors + beacons + AI
- Hindi, Marathi, English TTS (offline)

**Visual Idea:**
Three components: (1) ESP32 cane with sensors, (2) Phone/Pi with camera, (3) BLE beacon. Arrows showing data flow between them.

**Speaker Notes (30-45 sec, Hinglish):**
Wayze do parts mein kaam karta hai - pehla cane module jisme ESP32 hai, ultrasonic sensor aur downward ToF sensor stairs detect karne ke liye. Dusra compute unit - ya toh Android phone ya Raspberry Pi 5 with camera. Camera bata ta hai ki object kya hai, sensors bata ta hai kitni door hai. BLE beacons decision points par navigation guide karte hain. Sab kuch offline - Hindi, Marathi, English mein bolta hai.

---

## Slide 4: How It Works

**Title:** How Wayze Guides

**Bullets:**
- Camera sees WHAT (YOLO nano detection)
- Sensors tell HOW FAR (ultrasonic + ToF)
- Zone matching: left/centre/right fusion

**Visual Idea:**
Flow diagram: Camera image → YOLO → "Chair detected" + Ultrasonic → "80cm left" → Fusion → "Chair ahead, 80 centimetres, left."

**Speaker Notes (30-45 sec, Hinglish):**
Working simple hai. Camera dekhta hai ki object kya hai - YOLO nano detection use karte hain. Ultrasonic aur ToF sensors bata te hain ki object kitni door hai. Phir hum zone matching karte hain - left, centre ya right. Jaise "Chair ahead, 80 centimetres, left" - pura sentence banta hai. Haptics pehle aate hain, phir voice.

---

## Slide 5: Architecture

**Title:** System Architecture

**Bullets:**
- Cane: ESP32, ultrasonic, VL53L0X ToF, haptics, BLE
- Compute: Pi 5 or Android phone, camera, YOLO (NCNN)
- Navigation: BLE beacons + Dijkstra + dead-reckoning

**Visual Idea:**
Architecture diagram with three layers: Hardware Layer (cane sensors), Compute Layer (YOLO, TTS, Dijkstra), Navigation Layer (beacons, graph).

**Speaker Notes (30-45 sec, Hinglish):**
Architecture three-layer hai. Hardware layer mein ESP32 cane module - forward ultrasonic, downward ToF for stairs, 2 haptic motors left/right indication ke liye, BLE beacon scanning. Compute layer mein Pi 5 ya Android phone with camera, YOLO nano running on NCNN for fast inference. Navigation layer mein BLE beacons sirf decision points par hote hain, Dijkstra algorithm shortest path ke liye, aur agar beacon fail ho jaye toh dead-reckoning fallback hai.

---

## Slide 6: Live Demo

**Title:** Live Demo: Wayze in Action

**Bullets:**
- On-device detection on phone
- TTS speaking instructions
- Haptics + navigation
- Dijkstra pathfinding

**Visual Idea:**
Screen recording of the app showing camera preview with detection boxes, direction arrow, and "Go straight" instruction text.

**Speaker Notes (30-45 sec, Hinglish):**
Ab live demo dekhte hain. App phone par chal raha hai. Camera object detect kar raha hai. TTS bol raha hai instructions. Haptic motors vibrate hote hain pehle, phir voice aati hai. Dijkstra algorithm shortest path nikal raha hai. Ye sab offline ho raha hai, koi internet nahi chahiye.

---

## Slide 7: Tech Stack

**Title:** Technology Stack

**Bullets:**
- Hardware: ESP32, Raspberry Pi 5, Pi Camera, VL53L0X ToF
- AI: YOLO nano (Ultralytics AGPL, licensed)
- Software: Flutter (Android), Python (Pi), NCNN inference

**Visual Idea:**
Tech stack icons arranged in columns: Hardware (ESP32, Pi), AI (YOLO), Software (Flutter, Python, NCNN).

**Speaker Notes (30-45 sec, Hinglish):**
Tech stack dekhte hain. Hardware mein ESP32 for cane module, Raspberry Pi 5 for compute, Pi Camera, VL53L0X ToF sensor. AI mein YOLO nano use karte hain - Ultralytics AGPL licensed. Software mein Flutter for Android app, Python for Pi, NCNN for fast inference on Pi 5. Sab kuch open source hai.

---

## Slide 8: What's Real vs Simulated

**Title:** Honest Status for This Demo

**Bullets:**
- ✅ REAL: On-device detection, TTS, haptics, Dijkstra
- 🔮 SIMULATED: Cane sensor, BLE beacons (sliders in app)
- ❌ NOT BUILT: Real hardware link, voice commands, multi-floor

**Visual Idea:**
Three-column table with checkmarks (✅), warning emoji (🔮), and X marks (❌) for each feature.

**Speaker Notes (30-45 sec, Hinglish):**
Honest batata hu ki demo mein kya real hai aur kya simulated. Real hai - on-device detection phone par, TTS working hai, haptics working hai, Dijkstra pathfinding working hai. Simulated hai - cane sensor data app mein slider se de rahe hain, BLE beacons bhi simulated hain. Abhi tak nahi banaya - real hardware link, voice commands, multi-floor support. Ye next phase mein aayega.

---

## Slide 9: Impact + Cost

**Title:** Impact & Estimated Cost

**Bullets:**
- 6.2 million blind people in India* (source to verify)
- Compute unit: Rs 10,000-12,000 (estimate)
- Cane module: ~Rs 2,500 (estimate)

**Visual Idea:**
Infographic showing user impact with icons, cost breakdown with two bars for compute unit and cane module.

**Speaker Notes (30-45 sec, Hinglish):**
Impact bahut bada hai - India mein 62 lakh blind log hain, ye figure government website se verify karna hai. Cost dekhte hain - compute unit (Pi 5 with camera) estimated 10-12 thousand rupees. Cane module estimated 2,500 rupees. Total bahut affordable hai compared to existing solutions jo 50-60 thousand ya usse zyada hote hain.

---

## Slide 10: Roadmap & Ask

**Title:** Roadmap & Next Steps

**Bullets:**
- Next: Real hardware integration, real beacon testing
- Validation: Test with real blind users
- Scale: Multi-floor, voice commands, cloud backup

**Visual Idea:**
Timeline with three phases: Phase 1 (now) = simulated demo, Phase 2 = hardware integration, Phase 3 = user testing + scale.

**Speaker Notes (30-45 sec, Hinglish):**
Roadmap dekhte hain. Abhi hum phase 1 mein hain - simulated demo. Next phase mein real hardware integration karenge, real beacons test karenge. Uske baad real blind users ke saath validation karenge. Phase 3 mein multi-floor support, voice commands, aur cloud backup aayega. Hum aapke support expect karte hain isko real product banaane ke liye.

---

## Team

**Title:** [Team Name]
**Subtitle:** [College Name]

**Bullets:**
- [Team Member 1] - [Role]
- [Team Member 2] - [Role]
- [Team Member 3] - [Role]

**Visual Idea:**
Team photos with names and roles.

**Speaker Notes (30-45 sec, Hinglish):**
Finally, humari team. [Team Member 1] ne [role] handle kiya. [Team Member 2] ne [role] kiya. [Team Member 3] ne [role] kiya. Hum sab [College Name] ke students hain. Thank you judges, koi sawaal?

---

## Design Notes

**Colors:**
- Background: #000000 (true black)
- Accent: #FFC83D (tactile yellow)
- Text: #EDEDED
- Secondary: #9A9A9A

**Font:** Inter, large sizes, bold weights for emphasis

**Style:** Minimal, no clutter, high contrast
