# Wayze: 10-Minute Pitch Script (Hinglish)
**Target Audience**: Judges, Angels, Tech Evaluators, Accessibility Experts  
**Speakers**: Founders (Indian Students / Early-Stage Builders)  
**Tone**: Confident, technically deep, transparent, and grounded in real engineering honesty.  
**Core Motto**: *"Wayze safed chhadi (white cane) ka sahayak hai, uska badal nahi." (Supplement, never a replacement).*

---

## ⚡ 30-Second Elevator Pitch Version
*(Use for quick judge rounds, expo tables, or intro remarks)*

> "Namaste! India mein over 1.5 crore visually impaired log hain. White cane zameen ke obstacles pakad leti hai, par chest-level hazards, hanging wires, ya unmapped rooms mein turn-by-turn rasta nahi bata sakti. 
> 
> Humne banaya hai **Wayze**: ek 100% offline-first Android app jo phone ke camera aur CPU pe quantized YOLOv8 AI chalata hai — bina kisi cloud bill ya GPU ke. Phone screen band hone par bhi background mein chalta hai, pocket-level budget phones pe 40-70 ms latency deliver karta hai, aur stairs ya drop-off aane par split-second mein heavy vibration aur audio alert deta hai. 
> 
> Aaj app phone-only mode mein fully functional hai, aur humne future BLE smart cane ke liye architecture plug-and-play rakha hai. Wayze safed chhadi ka sahayak hai, uska badal nahi."

---

## ⏱️ Detailed 10-Minute Word-by-Word Script with Timestamps

### Minute 0:00 – 1:00 | Slide 1 & 2: Title & The Core Problem
**Visual**: Slide 1 (Title) -> Slide 2 (The Problem: White Cane Limits & Navigation Gap)  
**Speaker**:
> "Good morning judges and mentors. Mera naam [Founder Name] hai, aur mere co-founder hain [Co-founder Name]. 
> 
> Ek visually impaired insaan jab subah apne bistar se bathroom ya kitchen ki taraf nikalta hai, toh uska sabse bharosemand saathi hota hai uska **White Cane** — safed chhadi. White cane pav ke paas ke obstacles aur zameen ke texture ko mehsoos karne ke liye bemisaal hai. 
> 
> Lekin white cane ke do bade limitations hain:
> 1. Yeh sirf physical touch radius (lagbhag 1 meter zameen par) cover karta hai. Chest-level hanging boards, open cabinet doors, ya aage se aate hue logon ko door se nahi dekh sakta.
> 2. Yeh direction nahi deta — yeh nahi batata ki 'Door 3 meter aage hai, wahan se left mudna hai'.
> 
> Aur sabse badi baat: indoor GPS kaam nahi karta, aur cloud-based AI apps jaise Be My Eyes ya Seeing AI har frame internet pe bhejte hain, jisme 300 se 800 ms ka delay hota hai aur mobile data lagta hai. Indoor safety mein aadhe second ka delay ka matlab hai seedhi se girna."

**Transition Phrases (Choose 1)**:
- *"Isi gap ko fill karne ke liye humne build kiya hai Wayze."*
- *"Isiliye humne socha: kyu na phone ke local hardware ko hi unki aankh aur guide bana diya jaye?"*
- *"White cane ko replace kiye bina, usse supercharge kaise karein? Yehi hai Wayze ka foundation."*

---

### Minute 1:00 – 2:00 | Slide 3 & 4: Who It's For & The Solution
**Visual**: Slide 3 (Target User: Budget Android Reality) -> Slide 4 (Solution: Offline Edge AI)  
**Speaker**:
> "Target audience kaun hai? India mein majority blind users 10,000 se 15,000 rupaye wale budget Android phones use karte hain — jaise Snapdragon 680 ya Helio G85 jisme sirf 4GB RAM hoti hai. Unke paas high-end iPhone ya dedicated smart glasses khareedne ka budget nahi hota.
> 
> Humara solution hai **Wayze**: Ek 100% offline indoor navigation aur hazard-alert ecosystem.
> 
> **Wayze ke teen core pillars hain:**
> 1. **Complete Offline-First**: Ek bhi byte internet pe nahi jata. Camera frames RAM mein process hote hain aur wahi discard ho jaate hain — zero privacy risk.
> 2. **Screen-Off Operation**: User ko screen khol kar chalne ki zaroorat nahi hai. Phone seene ke lanyard pe tanga rahega, screen band rahegi, aur foreground service background mein haptics aur voice guidance deti rahegi.
> 3. **Hardware Agnostic**: Aaj kisi user ke paas smart cane nahi hai, toh Wayze **Phone-Only Mode** mein floor-contact heuristic se 'near/far' bolkar guide karega. Kal jab humari $25 BLE smart cane ready hogi, toh bina kisi app update ke Bluetooth se plug-and-play connect ho jayegi."

**Transition Phrases (Choose 1)**:
- *"Ab main aapko dikhata hoon ki yeh sab actually kaam kaise karta hai under the hood."*
- *"Chaliye dekhte hain phone ke CPU ke andar har millisecond mein kya chal raha hai."*
- *"Architecture ki baat karein toh humne system ko 2 layers mein divide kiya hai: Native Kotlin aur Flutter Dart."*

---

### Minute 2:00 – 3:30 | Slide 5 & 6: How It Works & Image-to-Alert Pipeline
**Visual**: Slide 5 (System Architecture) -> Slide 6 (Vision Pipeline Diagram)  
**Speaker**:
> "Architecture strict production-grade hai:
> Heavy lifting hum **Native Kotlin** mein karte hain, aur high-level logic, alert queue, Dijkstra graph navigation, aur Riverpod state machine **Flutter (Dart)** mein chalate hain.
> 
> **Camera se Alert tak ka flow dekhiye:**
> 1. CameraX hardware stream se 30 FPS pe `YUV_420_888` frame uthata hai `STRATEGY_KEEP_ONLY_LATEST` ke saath.
> 2. Frame ko zero-allocation direct `ByteBuffer` ke andar 320x320 RGB letterbox mein convert kiya jata hai. Frame kabhi flash memory ya storage mein save nahi hota.
> 3. **Model**: Custom-trained INT8 Quantized **YOLOv8n** model direct phone CPU pe ARM Cortex XNNPACK delegate ke saath 2 threads pe chalta hai. Target latency hai **40 se 70 ms**.
> 4. Model output deta hai `[1, 4+nc, 2100]` raw tensor. Ispe class-wise NMS chalta hai IoU threshold 0.45 pe.
> 5. Phir Dart mein **HFOV Zone Mapping** hoti hai. Bounding box center angle calculate karta hai: Left zone agar <-12 degree hai, Center zone agar -12 se +12 degree hai, aur Right zone agar >+12 degree hai.
> 6. **Temporal Filter**: False alarm se bachne ke liye, model ek frame dekh kar nahi chilata! Jab 2 se 3 consecutive confirming frames mein hazard confirm hota hai, tabhi threat score badhta hai."

**Transition Phrases (Choose 1)**:
- *"Lekin agar sirf camera pe bharosa karein, toh kaanch ke darwaze ka kya hoga? Yehi par Sensor Fusion aata hai."*
- *"Vision akele complete safety nahi de sakti, isiliye humne vision ko distance sensor ke saath fuse kiya hai."*
- *"Ab aate hain sabse critical safety feature pe: Drop-off aur stairs detection."*

---

### Minute 3:30 – 5:00 | Slide 7 & 8: Sensor Fusion + Cane (Simulated) & Voice Priority
**Visual**: Slide 7 (Sensor Fusion & Drop-off Rules) -> Slide 8 (Alert Priority Queue & Vosk Voice)  
**Speaker**:
> "Humare system ka dimaag hai **Fusion Engine**.
> 
> Maan lijiye samne transparent kaanch ka darwaza (glass door) hai. Camera ko laga rasta saaf hai. Lekin cane ka ultrasonic ya ToF sensor aage 40 cm pe solid reflection detect karta hai. Fusion Engine immediately cane data ko priority dega aur alert bajayega: *'Obstacle 40 centimeters ahead.'*
> 
> **Drop-off / Stairs Down Rule:**
> Cane ka downward sensor normal chalte waqt zameen ko 110 cm pe dekhta hai. Agar downward range achanak 145 cm se zyada ho jaye लगातार 2 samples ke liye — iska matlab aage seedhi utar rahi hai ya platform khatam ho raha hai. Yeh **P0 Danger Alert** trigger karta hai:
> *'Stairs down ahead. Stop.'*
> 
> **Alert Priority Queue (P0, P1, P2):**
> Ek blind user ko har second faltu bol kar pareshan nahi kar sakte. Isiliye humne 3 priority tiers banaye hain:
> - **P0 Danger**: Seedhi, gaddha, ya <50cm hazard. Yeh active speech ko beech mein kaat deta hai (interrupt karta hai), queue clear karta hai, aur 400ms ka heavy vibration deta hai.
> - **P1 Navigation**: 'Turn left in 3 meters'. Yeh 2 second mein expire ho jata hai agar bol nahi paaye, taaki purana direction na bole.
> - **P2 Info**: 'Table on your right'. Yeh sirf tab bola jata hai jab system poori tarah idle ho.
> - **Cooldown Rule**: Same object same zone mein 3 second tak repeat nahi hota, jab tak distance 20% se zyada paas na aa jaye!
> 
> **Voice Engine**: Hum cloud Google STT use nahi karte. Offline **Vosk** small model hai Hindi aur English grammar ke saath, jisme repair ladder hai: Agar nahi samjha toh soft retry -> guided example -> confirm guess -> tactile buttons."

**Transition Phrases (Choose 1)**:
- *"Aap pooch sakte hain: bina cloud aur bina GPU ke budget phone pe itna sab chal kaise raha hai?"*
- *"Ab aate hain software architecture ke sabse bade cost aur performance decision par: Why No GPU?"*
- *"Iska cloud bill kitna aata hai? The answer is ZERO."*

---

### Minute 5:00 – 6:15 | Slide 9 & 10: Why No GPU, Device Target & Data Privacy
**Visual**: Slide 9 (Edge Compute & Battery Reality) -> Slide 10 (Privacy Architecture)  
**Speaker**:
> "Bahut log puchte hain: *'Aap mobile GPU ya NNAPI kyu nahi use kar rahe?'*
> 
> Yahan humara embedded background kaam aata hai:
> Budget Android phones (MediaTek Helio G85 aur low-end Snapdragons) ke NNAPI aur GPU vendor drivers extremly buggy aur fragmented hote hain. Real-world test mein NNAPI random native crash kar deta hai.
> 
> Isiliye humne **CPU + XNNPACK** chuna hai:
> - 2 threads ARM Cortex A55 cores pe pinned hain.
> - Deterministic floating-point / INT8 math milta hai, zero native crash.
> - GPU power draw nahi hota, isiliye battery bachti hai.
> - Stationary mode: jab IMU dekhta hai user khada hai, toh inference 10 FPS se drop ho kar 4 FPS ho jati hai, jisse heat aur battery consumption 60% tak kam ho jati hai.
> 
> **Cloud Inference Kyu Reject Kiya?**
> Har ghante 30 FPS camera stream bhejna matlab **0.9 GB data per hour**! Aur har user ka monthly AWS server cost $2 se $5 hota. Blind users se monthly ₹400 subscription maangna unviable hai. Humara on-device model $0 cloud cost pe chalta hai!
> 
> **Privacy Architecture**:
> Privacy by design: Camera frame sirf RAM mein rehta hai aur 33 millisecond baad garbage-collect ho jata hai. Disk pe sirf 2MB circular text log banta hai. Koi photo kabhi save nahi hoti."

**Transition Phrases (Choose 1)**:
- *"Lekin software kabhi bhi crash ho sakta hai. Agar software crash ho gaya toh user ka kya hoga?"*
- *"Safety engineering ka sabse bada rule: 'Silence never means safe'."*
- *"Chaliye dekhte hain humari fail-safe matrix kaise kaam karti hai."*

---

### Minute 6:15 – 7:30 | Slide 11 & 12: Reliability, Safe Mode & Competitor Comparison
**Visual**: Slide 11 (Reliability & Safe Mode Matrix) -> Slide 12 (Competitor Comparison Table)  
**Speaker**:
> "Humara golden rule hai: **Silence never means safe.**
> Agar camera band ho gaya aur app shaant raha, toh user sochega aage sab clear hai aur takra jayega!
> 
> Isiliye humne banaya hai **Deterministic Fallback Table**:
> 1. **Camera/YOLO Freeze**: 2000ms watchdog frame na aane par vision ko auto-restart karta hai. Agar 3 baar restart fail hua, toh app bolti hai: *'Vision stopped. Sensor and map mode active.'*
> 2. **TTS Failure**: Agar audio engine fail hua, toh P0 heavy buzz aur P1 double tick vibration pattern se communicate hota hai.
> 3. **Crash Loop (3 crashes in 5 mins)**: System turant **SAFE MODE** mein lock ho jata hai. Camera aur heavy models kill ho jate hain, screen red ho jati hai, aur app vibrate karke bolti hai: *'Wayze is in safe mode. Use your cane.'*
> 4. **Heartbeat**: Har 25 second mein ek halka haptic tick bajta hai. Agar yeh tick aana band hua, user turant samajh jata hai ki phone band ho chuka hai.
> 
> **Competitors ke muqablay hum kahan khade hain?**
> - **WeWALK Smart Cane**: Bahut acchi cane hai, par price ₹50,000+ ($600) hai aur outdoor navigation ke liye phone GPS pe dependent hai.
> - **UltraCane / SmartCane (IIT Delhi)**: Yeh sirf ultrasonic beeps dete hain (₹3,000–₹10,000), par inme AI object recognition, stairs drop-off distinction, ya indoor room navigation nahi hai.
> - **Seeing AI / Be My Eyes**: Cloud-dependent hain, real-time walking hazard ke liye nahi bane hain (reading text/objects ke liye hain).
> - **Wayze**: Phone-only mode **FREE** hai, aur future BLE cane ka target BOM sirf **$19 se $25 (approx ₹1,600-₹2,100)** hai!"

**Transition Phrases (Choose 1)**:
- *"Hum numbers hawa mein claim nahi karte. Chaliye dekhte hain humara Measured vs Target board."*
- *"Ek engineer ke taur par hum transparency mein vishwas rakhte hain."*
- *"Ab main aapko live testing aur validation ke numbers dikhata hoon."*

---

### Minute 7:30 – 8:30 | Slide 13 & 14: Measured vs Not-Yet-Measured & Live Demo Plan
**Visual**: Slide 13 (Honesty Board: Verified vs Target) -> Slide 14 (Demo Architecture)  
**Speaker**:
> "Hum kisi bhi judge ko misguide nahi karenge. Yahan humara **Honesty Board** hai:
> 
> **VERIFIED & WORKING NOW (Tested in Code & Unit Suites):**
> - 109 passing automated tests (Dijkstra navigation, P0 queue preemption, 3s cooldown, atomic map storage).
> - Offline Vosk intent matching with non-repeating repair ladder.
> - SQLite atomic map save (.bak preservation) and graph integrity validation.
> - Sensor fusion logic with simulated Cane packets.
> - Model Test Screen with live overlay, confidence sliders, and CSV logging.
> 
> **TARGET / ESTIMATE (Field Testing Pending on Real Blind Users):**
> - Inference latency target: 40-70 ms on Snapdragon 680 (Hardware measurement in progress).
> - Battery consumption estimate: ~8-12% per hour under continuous camera analysis.
> - Cane hardware: Currently SIMULATED via `MockCaneSource` (ESP32-S3 hardware layout finalized, firmware testing on Wokwi, fabrication planned in Phase 2).
> - Safety disclaimer: We clearly state on first launch: *Wayze is a supplement to the white cane, never a replacement.*"

**Transition Phrases (Choose 1)**:
- *"Yeh tha humara system. Ab humara aage ka roadmap aur unit economics kya hain?"*
- *"Ek scalable assistive-tech venture banane ke liye humari planning kya hai?"*
- *"Aakhir mein baat karte hain cost, roadmap aur humare ask ki."*

---

### Minute 8:30 – 10:00 | Slide 15 & 16: Roadmap, Cost & The Ask
**Visual**: Slide 15 (4-Phase Roadmap & Unit Economics) -> Slide 16 (The Ask & Vision)  
**Speaker**:
> "**Unit Economics & Cost:**
> - Inference Cloud Bill: **$0.00**
> - App Maintenance / CDN Map Pack: **$0.05 to $0.40 per active user/month**
> - Smart Cane Target BOM: **$19.50 @ 10,000 units** (ESP32-S3 + ToF Sensor + Ultrasonic + Haptic Motor + 18650 Li-ion battery).
> 
> **4-Phase Roadmap:**
> - **Phase 1 (Current - Completed)**: Android App, Native CameraX + YOLOv8n INT8 pipeline, Offline Vosk, AlertQueue, Map Setup, MockCane simulation.
> - **Phase 2 (Next 4 Months)**: 50 Visually Impaired user pilot with Blind Schools (NAB Delhi / Blind People's Association). Real latency and false-alarm dataset collection.
> - **Phase 3 (Month 5-8)**: First 100 prototype BLE smart canes fabrication. Indian WPC / BIS wireless certification.
> - **Phase 4 (Month 9-12)**: B2G / CSR distribution (ADIP Scheme integration) and open-source map packs for major Indian transit hubs and universities.
> 
> **The Ask:**
> Hum seek kar rahe hain:
> 1. **Mentorship & Blind School Connects**: 50 blind users ke saath structured testing protocol chalane ke liye guidance.
> 2. **Grant Funding of ₹15 Lakhs ($18,000)**: 
>    - ₹6 Lakhs: 100 Smart Cane prototype fabrication & testing.
>    - ₹5 Lakhs: Field trials, user travel stipends, and accessible localized voice recording.
>    - ₹4 Lakhs: Tooling, calibration sensors, and WPC/BIS certification.
> 
> Independence har insaan ka basic adhikaar hai. White cane ne unhe chalna sikhaya, Wayze unhe bina darr ke aage badhna sikhayega. 
> 
> Dhanyawad. We are now open for your questions!"

---

## 📋 Speaker Transition & Emergency Cheat Sheet

| Time | Slide | Section | If You Are Running Behind Time (Cut This) | If Demo Glitches (Say This) |
| :--- | :--- | :--- | :--- | :--- |
| **0:00** | 1-2 | Problem | Skip personal intro, jump to white cane 1m limit | - |
| **2:00** | 5-6 | Vision Pipeline | Don't explain raw tensor shape `[1, 4+nc, 2100]` | - |
| **3:30** | 7-8 | Fusion & Alerts | Focus only on Stairs Drop-off rule | - |
| **5:00** | 9-10 | Why No GPU | Skip stationary IMU frame-rate drop detail | - |
| **6:15** | 11-12 | Fail-safes | Skip watchdog restart counts, focus on Safe Mode | *"Notice that even if hardware hangs, heartbeat and safe mode protect the user."* |
| **7:30** | 13-14 | Honesty / Demo | Skip code test counts, show the live bounding box | *"We have pre-recorded replay harness logs right here in Airplane mode."* |
| **8:30** | 15-16 | Ask & Vision | Focus on ₹15L ask and 50-user pilot | - |
