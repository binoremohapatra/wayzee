# Wayze: 25 Tough Judge & Investor Q&A Bank
**Category**: Technical, Clinical, Regulatory, Commercial & Safety  
**Tone**: Honest, uncompromising on safety facts, zero bluffing, deeply technical.

---

### Category 1: Technical & AI/ML Architecture

#### Q1: "What is your real model accuracy? Have you tested this on real blind users?"
**Answer**:
> "Hum honest rahenge: humara current model validation dataset (Roboflow Universe indoor sets) par **75.5% mAP@50** aur **67.1% Recall** deliver karta hai. 
> **Humne abhi tak real blind users ke saath live field trials conduct nahi kiye hain.** Humara validation abhi synthetic lab datasets, replay harness logs aur scripted simulation par verified hai. Phase 2 ka core purpose hi 50 visually impaired users ke saath Blind Schools mein real-world trials karna hai."

#### Q2: "Why YOLOv8n instead of a specialized lightweight model like MobileNet-SSD or EfficientDet?"
**Answer**:
> "Humne YOLOv8n isliye chuna kyunki iska anchor-free architecture chhote aur overlapping indoor objects (jaise chair legs, table edges, half-open doors) par MobileNet-SSD ke anchor boxes se behtar spatial recall deta hai. Saath hi, YOLOv8n ka PyTorch export seamless INT8 quantization aur XNNPACK per-channel quantization support karta hai, jo 320x320 resolution par Cortex-A55 cores par 40-70ms mein execute ho jata hai."

#### Q3: "What if the room is completely dark or dimly lit?"
**Answer**:
> "Standard RGB camera sensors andhere mein fail ho jate hain — this is physics. Wayze isme do tareeqon se handle karta hai:
> 1. Frame analysis mein agar mean pixel brightness threshold se neeche chali jaye, toh app bolti hai: *'Lighting is too low for camera. Rely on your white cane.'*
> 2. Jab future smart cane connect hogi, toh cane ka **Ultrasonic aur Time-of-Flight (ToF)** active laser sensor andhere se affect nahi hota. Lekin phone-only mode mein, andhere mein camera alerts suspend ho jate hain."

#### Q4: "How do you detect transparent glass doors or mirrors that fool cameras?"
**Answer**:
> "Cameras cannot reliably see clear glass. This is exactly why we built **Sensor Fusion**:
> - Camera ko rasta clear dikhta hai.
> - Lekin Smart Cane ka ultrasonic/ToF sensor optical transparency par depend nahi karta — ultrasonic sound waves glass se physically bounce hoti hain aur 40 cm par solid reflection report karti hain.
> - Fusion Engine cane reading ko camera par absolute priority deta hai aur P0 emergency alert bajata hai."

#### Q5: "What is your false alarm rate? Won't the app drive the user crazy with constant alerts?"
**Answer**:
> "Constant audio chattering is the #1 reason blind users uninstall assistive apps. Humne isko solve karne ke liye 3 mathematical layers lagaye hain:
> 1. **Temporal Confirmation**: 1 single frame detection alert trigger nahi karta; model ko 2 se 3 consecutive frames mein hazard confirm karna padta hai.
> 2. **3-Second Cooldown**: Ek baar agar center zone mein 'Chair' bol diya, toh agle 3 second tak repeat alert suppressed rehta hai.
> 3. **Distance-Delta Override**: Sirf tabhi cooldown toot-ta hai agar user obstacle ke 20% ya 30cm se zyada paas aa jaye."

---

### Category 2: Hardware & Embedded Systems

#### Q6: "Where is the smart cane hardware? Why hasn't it been built yet?"
**Answer**:
> "Humne intentionally software-first aur phone-only architecture chuna:
> Hardware tooling aur injection molding mein ₹5-10 lakh lagte hain. Pehle hume vision pipeline, alert priority queue, aur room graph routing ko phone par 100% bug-free karna tha.
> Cane ka architecture already locked hai: ESP32-S3, VL53L1X ToF sensor, HC-SR04 ultrasonic, MPU6050 IMU, aur ERM coin vibration motor. Humara app `MockCaneSource` se simulate hota hai aur `BleCaneSource` binary GATT packet format pehle se defined hai. Phase 3 mein hum 100 prototype canes fabricate karenge."

#### Q7: "What is your estimated Bill of Materials (BOM) for the Smart Cane?"
**Answer**:
> "Component-level breakdown at volume:
> - ESP32-S3-WROOM-1 (BLE 5.0 + Dual Core): $2.40 (₹200)
> - VL53L1X Time-of-Flight Laser Sensor (Downward Drop-Off): $2.80 (₹230)
> - Ultrasonic Transducer Pair (Front Obstacle): $1.20 (₹100)
> - MPU6050 6-Axis IMU (Tilt/Drop): $0.80 (₹65)
> - Haptic ERM Vibration Driver + Coin Motor: $0.60 (₹50)
> - 18650 Li-ion Cell (2600mAh) + TP4056 BMS + USB-C: $2.10 (₹175)
> - Custom 2-Layer PCB + Passive components: $1.80 (₹150)
> - IP54 Polycarbonate Enclosure & Cane Clamp: $3.50 (₹290)
> - Assembly & Testing: $4.00 (₹330)
> **Total BOM: $19.20 @ 10,000 units (approx ₹1,600) | $32.00 @ 500 prototype units (approx ₹2,650).**"

#### Q8: "How long will the phone battery last running continuous camera inference?"
**Answer**:
> "Humne synthetic benchmark mein calculate kiya hai ki continuous 10 FPS inference budget phones par lagbhag **14% to 18% battery per hour** consume karti hai.
> Isko reduce karne ke liye humne do governors lagaye hain:
> 1. **Stationary Throttling**: Jab phone IMU detect karta hai ki user khada hai ya baitha hai, FPS 10 se 4 par drop ho jata hai (saves ~60% compute).
> 2. **Battery Governor**: Battery <15% hone par camera automatically band ho jata hai aur app sirf sensor/cane haptics aur map audio chalu rakhti hai."

#### Q9: "Why not use specialized smart glasses instead of mounting a phone on the chest?"
**Answer**:
> "Cost and social accessibility. Smart glasses like Envision or Ray-Ban Meta cost ₹35,000 to ₹1,50,000 ($400 - $2,000), unme battery life sirf 1.5 ghante hoti hai, aur wo dhoop mein severe thermal throttle karte hain. Phone blind users ke paas already hota hai. Zero extra purchase cost se shuruat karna India ke 95% visually impaired users ke liye reality hai."

---

### Category 3: Safety, Reliability & Liability

#### Q10: "If a blind user falls down the stairs while using Wayze, are you legally liable?"
**Answer**:
> "Humari safety policy teen layered hai:
> 1. **Legal Positioning**: First launch disclaimer clearly states: *'Wayze is a SUPPLEMENT to the white cane, never a replacement. You must always use your primary white cane.'* App kabhi 'safe' hone ka promise nahi karti, yeh sirf 'reduces risk' aur situational awareness assist karti hai.
> 2. **Engineering Reality**: App kabhi centimeters ki false accuracy claim nahi karti jab tak calibrated sensor connected na ho.
> 3. **Silence Never Means Safe Rule**: Har failure mode (camera freeze, crash loop, bad tilt) verbally ya haptically communicate hota hai. Final message hamesha hota hai: *'Wayze has stopped. Use your cane.'*"

#### Q11: "What happens if the Android operating system kills your background process while the screen is off?"
**Answer**:
> "Humne isko tackle karne ke liye Android **Foreground Service** with `PARTIAL_WAKE_LOCK` implement kiya hai, jo status bar notification ke saath running rehta hai. 
> Aur silent crash protection ke liye humara **Heartbeat Service** har 25 second mein ek gentle haptic tick deta hai. Agar OS ne app kill kar di, toh 25 second ke andar ticks band ho jayenge aur user ko pata chal jayega ki software chalna band ho gaya hai."

#### Q12: "How do you handle crash loops? What if the app keeps crashing on startup?"
**Answer**:
> "Humne **Safe Mode Manager** implement kiya hai. App har crash ka timestamp SharedPreferences mein record karti hai. Agar 5 minute ke andar 3 crashes detect hote hain, toh app turant **SAFE MODE** mein lock ho jati hai:
> - Camera, TFLite models, aur Voice engine kill ho jate hain.
> - Screen solid red high-contrast display karti hai.
> - Phone bolta hai: *'Wayze is in safe mode. Use your cane.'*
> - Sirf physical cane sensor aur vibration alerts chalte hain."

---

### Category 4: Localization, Speech & Accessibility

#### Q13: "How robust is your offline Hindi voice recognition with regional Indian accents?"
**Answer**:
> "Hum cloud Google STT use nahi karte kyunki wo offline kaam nahi karta. Hum **offline Vosk** small model use karte hain with a strictly **restricted grammar set** (navigate, stop, repeat, where am i, battery).
> Restricted grammar hone ki wajah se vocabulary space chhota hota hai, jisse accent sensitivity significantly kam ho jati hai. Aur agar user ka pronunciation match nahi hota, toh humara **4-step Repair Ladder** activate hota hai: Soft retry -> Guided options -> Yes/No confirmation -> Tactile volume keys."

#### Q14: "Why did you build both Flutter and Native Kotlin? Why not 100% Flutter or 100% Native Android?"
**Answer**:
> "Yeh performance aur developer speed ka optimal trade-off hai:
> - **Native Kotlin**: CameraX high-speed YUV frame buffers, TFLite direct memory allocation, aur foreground partial wakelock Flutter Dart garbage collection ke saath stutter karte hain. Kotlin memory efficiency aur native threads guarantee karta hai.
> - **Flutter Dart**: UI screen reader accessibility (TalkBack Semantics), high-contrast OLED components, SQLite relational Dijkstra mapping, aur Riverpod state machines Flutter mein 5x तेजी se cross-compile aur test hote hain."

---

### Category 5: Business, Competition & Scale

#### Q15: "How are you different from WeWALK Smart Cane?"
**Answer**:
> "| Parameter | WeWALK | Wayze |
> | :--- | :--- | :--- |
> | **Price** | ₹55,000+ ($600) | Phone App: FREE / Cane Target BOM: ₹1,800 ($22) |
> | **Vision AI** | No on-board camera/object AI | On-device quantized YOLOv8 (detects chairs, doors, stairs) |
> | **Indoor Navigation**| Limited (relies on outdoor GPS) | SQLite Topological Room Graph + Dijkstra routing |
> | **Connectivity** | Requires Cloud smartphone app | 100% Offline-First |"

#### Q16: "How are you different from Seeing AI or Be My Eyes?"
**Answer**:
> "Seeing AI aur Be My Eyes **scene understanding / document reading** tools hain. Wo tab use hote hain jab user khada hokar kisi cheez ki photo leta hai aur 2 second wait karta hai.
> Wayze **real-time mobility co-pilot** hai. Yeh chalte waqt 10 FPS par continuous drop-off aur obstacles monitor karta hai screen-off mode mein, jisme zero photos save ya transmit hoti hain."

#### Q17: "What is your business model? If the app is offline and free, how do you make money?"
**Answer**:
> "Three-pillar revenue strategy:
> 1. **B2G / CSR Distribution (Subsidized Hardware)**: India mein Ministry of Social Justice ki **ADIP Scheme** (Assistance to Disabled Persons) assistive devices subsidize karti hai. Hum apni ₹2,500 smart cane ko ALIMCO aur CSR initiatives ke through supply karenge.
> 2. **Institutional Indoor Mapping (B2B SaaS)**: Airports, railway stations (IRCTC), universities, aur hospitals ko accessible indoor maps banane ke liye platform licensing fee.
> 3. **Enterprise Accessibility SDK**: Retail aur transit companies ko humara offline barrier-detection SDK license karna."

#### Q18: "What regulatory certifications are required for the Smart Cane in India?"
**Answer**:
> "Do primary certifications required hain:
> 1. **WPC (Wireless Planning & Coordination) ETA**: For Bluetooth Low Energy (BLE 2.4 GHz) compliance.
> 2. **BIS (Bureau of Indian Standards) IS 13252**: For electronics and Li-ion battery safety (IEC 62133).
> Humne Phase 3 budget mein ₹4 Lakhs specifically in testing aur certification lab fees ke liye allocate kiye hain."

---

### Category 6: The Ask & Execution

#### Q19: "Why do you need ₹15 Lakhs ($18,000)? Give an exact breakdown."
**Answer**:
> "- **₹6.0 Lakhs (40%)**: 100 Smart Cane prototype fabrication (PCB fabrication, components, 3D printing molds, Li-ion testing).
> - **₹5.0 Lakhs (33%)**: 50-user Blind School field trial program (participant travel stipends, user compensation, accessibility researcher oversight, native voice sample collection).
> - **₹4.0 Lakhs (27%)**: WPC/BIS certification fees, calibrated ground-truth laser sensors for benchmark validation, and pilot deployment logistics."

#### Q20: "What happens if a user is in an unmapped building where no map exists?"
**Answer**:
> "Wayze automatically switches to **Live-Obstacle-Only Mode**. App verbally announce karti hai: *'No map for this room. Live obstacle alerts only.'* Dijkstra routing band ho jati hai, lekin camera aur cane sensors aage aane wali chairs, doors, stairs, aur drop-offs ko normal tarike se alert karte rehte hain."

#### Q21: "Can family members easily map a new room? How complex is the setup?"
**Answer**:
> "Bilkul simple hai: Humne app mein **'Mark Landmark Here'** voice-driven setup flow banaya hai. Helper phone leke bed par khada hota hai aur bolta hai *'Mark Bed'*, phir darwaze par chal kar bolta hai *'Mark Door'*. SQLite database automatically inke beech coordinate edge aur distance save kar leta hai. Map ko JSON mein export ya backup kiya ja sakta hai."

#### Q22: "What is your defensibility / moat against Google or Apple copying this?"
**Answer**:
> "Humara moat teen cheezon mein hai:
> 1. **Hyper-localized Indian Context**: Indian homes mein floor textures (chamakdaar tiles, rugs, wet bathrooms) aur Hindi dialect accent parsing mein global tech giants focus nahi karte.
> 2. **Low-end Hardware Optimization**: Google aur Apple premium devices ($800+) par focus karte hain jahan high compute hota hai. Humara core IP ultra-low-end budget Cortex-A55 phones aur $19 cane sensor fusion par focused hai.
> 3. **Grassroots Distribution**: National Association for the Blind (NAB) aur Indian disability rehabilitation centers ke saath institutional relationships."

#### Q23: "What if the YOLO model misclassifies a table as a chair? Does it cause an accident?"
**Answer**:
> "In indoor mobility safety, whether an obstacle is a chair or a table is secondary — **what matters is spatial presence, bearing angle, and distance!**
> Wayze ka alert prioritization class category par based hai: Furniture (chair/table) dono middle-tier threat hain. System user ko alert deta hai: *'Obstacle ahead, near'*. Even if label swaps between table and chair, user pauses, sweeps their white cane, and safely navigates around it."

#### Q24: "Why should we back student / early-stage founders for a high-risk assistive project?"
**Answer**:
> "Kyunki humne problem ko theoretical paper ki tarah nahi dekha:
> Humne day one se production-grade architecture khada kiya hai: 109 automated unit tests passing hain, zero-allocation native CameraX buffer chal raha hai, deterministic fallback table aur Safe Mode code mein implemented hai. Hum committed hain, grounded hain, aur hum transparency ke saath limitations openly accept karte hain."

#### Q25: "What is your vision for Wayze 3 years from today?"
**Answer**:
> "3 saal baad, hum chahte hain ki India ke har blind student aur professional ke paas ek aisi cane ho jo unhe kisi par depend hue bina apne college campus, office, ya metro station mein confidently chalne de. 
> Wayze unki aankhein nahi banega — unka hamesha saathi rahega. White cane ne unhe chalna sikhaya, Wayze unhe aazadi dega."
