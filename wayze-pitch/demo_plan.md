# Wayze: 5-Minute Live Demo Run Sheet & Contingency Plan
**Format**: Live on-stage demonstration with real phone + projector/screen mirroring  
**Presenter**: Lead Engineer / Presenting Founder  
**Assistant**: Co-founder holding phone or pointing camera  
**Total Time**: Exactly 5 Minutes (including Airplane Mode proof)

---

## 1. Pre-Demo Setup Checklist (Do 15 Mins Before Pitch)

- [ ] **Device**: Android phone with at least 50% battery (Redmi / Realme / Samsung).
- [ ] **Screen Mirroring**: Wireless casting (scrcpy or HDMI capture card) connected and verified on projector.
- [ ] **Airplane Mode**: Mobile Data OFF, Wi-Fi OFF, Bluetooth ON (for presentation audio / cane simulation).
- [ ] **Volume**: Media volume set to 100% so judges clearly hear the spoken Hindi/English prompts.
- [ ] **Haptics**: Vibration motor verified functional.
- [ ] **Physical Props**:
  - 1 standard office chair or stool placed on stage.
  - White cane (held by co-founder to emphasize the supplement rule).
- [ ] **App State**: Launch Wayze, ensure first-launch disclaimer is already accepted. Start on **HomeScreen**.
- [ ] **Backup Offline Video**: 60-second 1080p MP4 screen recording with clear audio stored on desktop laptop, ready in VLC with 1-click spacebar play.

---

## 2. Timed 5-Minute Live Demo Run Sheet

```
┌────────────────────────────────────────────────────────────────────────┐
│                        STAGE TIMELINE (0:00 - 5:00)                    │
│  0:00 - 0:45  Airplane Mode Proof & Offline Speech Verification        │
│  0:45 - 2:00  Scene 1: Chair Detection, Zone Math & 3s Cooldown        │
│  2:00 - 3:15  Scene 2: Left vs Center vs Right Zone Demonstration      │
│  3:15 - 4:15  Scene 3: Mock Cane 40cm P0 Preemption (Vibration Buzz)   │
│  4:15 - 5:00  Safe Mode Lockdown & Fail-safe Proof                     │
└────────────────────────────────────────────────────────────────────────┘
```

### 0:00 – 0:45 | Scene 0: Airplane Mode Proof
**Action**:
1. Swipe down Android notification shade on projector. Show clearly that **Wi-Fi is OFF** and **Mobile Data is OFF**.
2. Press hardware **Volume-Up** key (or tap *"YOLO Model Benchmark & Test"*).
3. Speak clearly: *"Bathroom le chalo"* (or *"Where am I"*).

**Spoken by Founder**:
> *"Notice kar sakte hain: Phone poori tarah Airplane mode mein hai — zero internet, zero cloud. Ab main volume button dabata hoon aur bolta hoon: 'Where am I'."*

**Expected System Output**:
- Phone speaks instantly: *"You are currently near the central corridor."*
- Proves offline Vosk grammar model runs 100% locally in under 150ms.

---

### 0:45 – 2:00 | Scene 1: Chair Detection, Area Growth & 3s Cooldown
**Action**:
1. Open the **"YOLO Model Benchmark & Test"** screen (`/model_test`).
2. Point camera at the stage chair 3 meters away.
3. Walk 2 steps closer so the chair bounding box expands.
4. Stop walking and stand still in front of the chair for 5 seconds.

**Visual on Screen**:
- Live green/orange bounding box locks onto chair: `chair 82%`.
- Live HUD displays: `FPS: 10.2`, `p50: 52 ms`, `p95: 68 ms`.
- Bounding box bottom-edge ($y_2$) moves from 0.45 to 0.78.

**Spoken by Founder**:
> *"Camera frame RAM mein analyse ho raha hai. Model ne chair detect ki 52 millisecond latency ke saath. Aur dekhiye: jab main paas aaya, area badha aur app ne bola 'Chair ahead, near'. 
> Ab main 5 second tak yahi khada hoon — notice kijiye app chup hai! Kyunki humara 3-second cooldown rule user ko repetitive spam alerts se bachata hai."*

---

### 2:00 – 3:15 | Scene 2: Left / Center / Right HFOV Zone Mapping
**Action**:
1. Pan the phone camera slowly from Left to Center to Right across the chair.
2. Watch the vertical white dashed zone lines on screen ($<-12^\circ$, $\pm 12^\circ$, $>+12^\circ$).

**Visual on Screen**:
- As chair crosses left divider, label indicator highlights `LEFT`.
- When centered, label indicator highlights `CENTER`.
- When panned right, label indicator highlights `RIGHT`.

**Spoken by Founder**:
> *"Visual zones dekhiye: hum screen ko teen bearings mein divide karte hain based on 65-degree horizontal field of view. Jab chair left mein hoti hai, alert aata hai 'Chair on your left'. Jab aage seedhi hoti hai, tab bolta hai 'Chair ahead'. User bina dekhe samajh jata hai ki body ko kis taraf turn karna hai."*

---

### 3:15 – 4:15 | Scene 3: Sensor Fusion & P0 Danger Preemption (The 40cm Test)
**Action**:
1. Tap **"Sensor & Vision Debugger"** (`/debug`).
2. Show the live **Front Distance Slider** (currently at 180cm, path clear).
3. While the phone is speaking a normal navigation sentence (e.g. *"Walk 5 steps straight..."*), **violently drag the Front Distance slider down to 35cm** (or tap *"Trigger Obstacle Ahead (<50cm)"*).

**Expected System Output**:
- **INSTANT CUT**: Active voice speech immediately stops mid-syllable!
- Phone gives a loud, heavy, continuous vibration buzz (400ms).
- Emergency audio fires: *"Obstacle 35cm ahead! Stop!"*

**Spoken by Founder**:
> *"Yeh dekhiye: navigation chal rahi thi, par jaise hi cane sensor ne 40 cm se kam distance report kiya — P0 Danger Alert ne current speech ko beech mein kaat diya, heavy vibration diya aur bola 'Obstacle ahead, stop!'. This is life-safety priority preemption."*

---

### 4:15 – 5:00 | Scene 4: Safe Mode & Graceful Degradation
**Action**:
1. Tap *"Trigger Stairs Down (Drop-Off)"*.
2. Downward distance jumps to 160cm (exceeds 145cm drop-off threshold for 2 samples).
3. Speaks immediately: *"Stairs down ahead. Stop."*
4. Show the Safe Mode trigger logic.

**Spoken by Founder**:
> *"Aur agar lighting kharab ho, ya sensor 3 baar fail ho jaye? System turant Safe Mode mein lock ho jata hai aur bolta hai: 'Wayze is in safe mode. Use your cane.'
> Kyunki Wayze ka ek hi rule hai: 'Silence never means safe'."*

---

## 3. Contingency & Glitch Protocols (If Things Go Wrong)

| What Broke On Stage | Why It Happened | Immediate 5-Second Recovery Script | Plan B Action |
| :--- | :--- | :--- | :--- |
| **Camera Feed is Black or Freezes** | Android OS camera driver locked by background app. | *"Watchdog timer ne freeze detect kiya aur camera auto-restart ho raha hai."* | Switch toggle on `/model_test` to **"Replay Mode"**. Live simulated test frames will flow instantly with full bounding boxes and metrics! |
| **Microphone doesn't pick up Hindi voice** | Stage acoustics, echo, or loud air-conditioner fan noise. | *"Dekhiye: speech unclear hone par humara repair ladder active ho gaya hai."* | App will speak: *"Did not understand. Say Bathroom or Stop."* Tap the physical **Volume-Down** button on the phone to repeat last action. |
| **Screen Mirroring / HDMI Disconnects** | Loose cable or Wi-Fi casting interference. | *"Mirroring cable lose ho gayi hai, par sound audio phone se chal raha hai."* | Hold phone up to microphone so judges hear the TTS alerts and haptics, while co-founder starts the 60-second backup video on the laptop. |
| **Complete App Crash / OS Kill** | Out of memory on low-end device. | *"Notice kijiye crash ke baad kya hota hai: 3 crashes par system safe mode lock kar leta hai."* | Launch app again. Show the crash-loop Safe Mode screen. Judges will appreciate seeing a real safety recovery mechanism in action! |

---

## 4. Backup Video Script & Cue
If live hardware fails completely, co-founder presses **Spacebar** on laptop to play:  
📁 `wayze-pitch/backup_demo_video.mp4`

> *"Judges, stage connectivity issue ke liye humne identical run sheet ka real-time screen capture pehle se record karke rakha hai. Yahan aap dekh sakte hain 52ms inference latency aur stairs drop-off ka immediate haptic response..."*
