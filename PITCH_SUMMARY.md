# Wayze Hackathon Pitch Materials - Summary

## Files Created

1. **PITCH_DECK.md** - 10-slide outline with speaker notes
2. **DEMO_SCRIPT.md** - 2-minute demo video script as table
3. **JUDGE_QA.md** - 12 likely judge questions with honest answers
4. **DO_NOT_SAY.md** - Claims we cannot back up

---

## Quick Reference for Pitch

### Slide Order (3-4 minutes total)

1. **Title** (30 sec) - Wayze: See the way. Feel the way.
2. **Problem** (30 sec) - GPS doesn't work indoors, 6.2M blind people in India
3. **Solution** (30 sec) - Cane + compute unit, vision + sensors + beacons
4. **How It Works** (30 sec) - Camera sees WHAT, sensors tell HOW FAR, zone fusion
5. **Architecture** (30 sec) - ESP32 cane, Pi 5/phone, BLE beacons, Dijkstra
6. **Live Demo** (30 sec) - Show app running with detection, TTS, haptics
7. **Tech Stack** (30 sec) - Hardware (ESP32, Pi), AI (YOLO), Software (Flutter, Python)
8. **Real vs Simulated** (30 sec) - Honest status table
9. **Impact + Cost** (30 sec) - 6.2M users, Rs 12,500-14,500 estimated
10. **Roadmap** (30 sec) - Hardware integration → user testing → scale

**Total: ~5 minutes** (adjust by skipping slides if needed)

---

## Key Talking Points (Memorize These)

- "Works WITH white cane, doesn't replace it"
- "All core functions work offline"
- "Camera tells WHAT, sensors tell HOW FAR"
- "Haptics always fire before speech"
- "6.2 million blind people in India (source to verify)"
- "Estimated cost Rs 12,500-14,500"
- "This is a hackathon prototype"
- "Not tested with real users yet"

---

## Demo Script Highlights (2 minutes)

0:00-0:20 - Intro, show app
0:20-0:50 - Cane sensor simulation (slider, stairs toggle)
0:50-1:20 - Repeat button, haptics, TTS
1:20-1:50 - Navigation destination selection
1:50-2:00 - Outro with "simulated" caption

---

## Judge Q&A - Top 3 to Prepare

1. **Why not GPS?** - Doesn't work indoors, use BLE beacons
2. **Why hardware if phone can do it?** - Sensors give precise distance, phone can't
3. **Tested with blind users?** - No, not yet, in roadmap Phase 3

---

## What to Emphasize

✅ Offline-first design
✅ Privacy (no data leaves device)
✅ Multi-language (Hindi, Marathi, English)
✅ Affordable (vs existing solutions)
✅ Open source stack
✅ Honest about prototype status

---

## What to Downplay

❌ Accuracy (not tested)
❌ User testing (not done)
❌ Battery life (not tested)
❌ Safety claims (prototype only)
❌ Timeline (no commitment)
❌ Market size (no research)

---

## Design Specs (for PowerPoint)

**Colors:**
- Background: #000000 (true black)
- Accent: #FFC83D (tactile yellow)
- Text: #EDEDED (off-white)
- Secondary: #9A9A9A (gray)

**Font:** Inter (or system sans-serif)

**Sizes:**
- Title: 48-60pt
- Subtitle: 32-40pt
- Body: 24-28pt
- Notes: 18-20pt

**Style:**
- Minimal, no clutter
- High contrast
- Big text
- Yellow accents only for key points
- True black background (OLED-friendly)

---

## Creating PowerPoint from This

If you have PowerPoint or Google Slides:

1. Create 10 slides
2. Use black background (#000000)
3. Use yellow (#FFC83D) for titles and accents
4. Use white (#EDEDED) for body text
5. Copy content from PITCH_DECK.md
6. Add visuals as described
7. Practice with speaker notes

If using Google Slides:
- File → Import → Upload PITCH_DECK.md (or copy-paste)
- Apply theme colors
- Add images from Unsplash or icons

---

## Recording Demo Video

### Equipment Needed
- Phone with Wayze app installed
- Screen recording software (OBS, phone built-in recorder)
- Microphone for voiceover (or phone mic)
- Video editing software (CapCut, DaVinci, iMovie)

### Steps
1. Record phone screen while using app
2. Record voiceover separately (or live during screen recording)
3. Edit video to match DEMO_SCRIPT.md timing
4. Add "Cane sensor and beacons simulated" caption
5. Add yellow-on-black title card at start and end
6. Export as MP4 (1080p recommended)

### Tips
- Keep camera steady
- Use good lighting
- Speak clearly, at moderate pace
- Show UI clearly (zoom if needed)
- Add subtle background music (optional)

---

## Day Before Checklist

- [ ] Practice pitch 3 times (aim for 5 minutes)
- [ ] Practice demo on actual device
- [ ] Test TTS audio clarity
- [ ] Prepare demo video (2 minutes)
- [ ] Export PowerPoint as PDF (backup)
- [ ] Load app on demo phone
- [ ] Charge phone + power bank
- [ ] Print Q&A sheet (optional)
- [ ] Practice answering judge questions
- [ ] Check internet (if needed for video)

---

## During Pitch

- Start strong: "Namaste judges, today I present Wayze..."
- Show confidence: "This is a prototype, here's what we built"
- Be honest: "Not tested with real users yet"
- End with ask: "We need your support to take this forward"
- Thank judges

---

## After Pitch

- Listen to feedback
- Take notes on questions
- Connect with interested judges
- Share contact info
- Follow up if requested

---

## Important: Source Verification

**6.2 million blind people in India**
- Source: NPCBVI (National Programme for Control of Blindness & Visual Impairment)
- Website: npcbvi.mohfw.gov.in
- Verify before final pitch
- If unsure, say "approximately 6 million" or "millions of blind people"

---

## Final Note

Remember: This is a hackathon. Honesty > hype. Show what you built, acknowledge what you haven't, and focus on the problem-solution fit. Judges appreciate honesty and realistic roadmaps.

Good luck! 🚀
