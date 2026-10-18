# Wayze Demo Video Script (2 minutes)

| Time | What is on screen | What I say |
|------|------------------|------------|
| 0:00-0:10 | Black screen with "Wayze" title in yellow, "See the way. Feel the way." subtitle fades in. Music: gentle, calm. | Namaste. Aaj aapko Wayze ka demo dikha raha hu - ek indoor navigation aid visually impaired logon ke liye. |
| 0:10-0:20 | Split screen: Left shows person with white cane in building corridor. Right shows phone screen with Wayze app open. | Wayze white cane ke saath kaam karta hai, usko replace nahi karta. Camera dekhta hai object kya hai, sensors bata te hain kitni door hai. |
| 0:20-0:35 | Phone screen close-up: Camera preview showing corridor. Debug overlay shows "Inference: 0.0 ms", "COCO: false", "Custom: false". | Dekhiye app phone par chal raha hai. Camera on hai. Right now detection models loaded nahi hain, isliye false dikh raha hai. Lekin framework ready hai. |
| 0:35-0:50 | Zoom in on simulated cane sensor panel at bottom of screen. User drags distance slider to 80cm. | Ab cane sensor simulated dekhte hain. Main distance slider ko 80cm par move kar raha hu. Ye ultrasonic sensor ki jagah hai real hardware mein. |
| 0:50-1:00 | Instruction text changes from "Path clear" to "Obstacle 80 centimetres." Direction arrow remains straight. | Dekha? Instruction badal gaya - "Obstacle 80 centimetres." Fusion engine ye sentence bana raha hai cane sensor data se. |
| 1:00-1:10 | User enables "Stairs ahead" toggle. Instruction changes to "Stairs ahead. Stop." Direction arrow changes to stop icon (red). | Ab stairs toggle on kar raha hu. Instruction ab "Stairs ahead. Stop." ho gaya. Arrow bhi stop icon ban gaya. Ye urgent alert hai. |
| 1:10-1:20 | User taps "Repeat" button. TTS speaks "Stairs ahead. Stop." Haptic vibration shown with ripple effect. | Repeat button dabaya. Pehle haptic aaya, phir TTS bola. Danger alerts kabhi bhi nahi wait karte, turant aate hain. |
| 1:20-1:30 | User resets all sliders. Instruction changes back to "Path clear." Arrow back to straight. | Reset kar diya. Wapas "Path clear." Path safe hai, aage badh sakte hain. |
| 1:30-1:40 | Screen shows "Choose Destination" screen with list of places: "Entrance", "Corridor", "Lift", "Room 101", "Washroom", "Exit". User taps "Room 101". | Navigation feature dekhte hain. Destination choose karte hain - Room 101. Dijkstra algorithm shortest path nikalta hai. |
| 1:40-1:50 | Navigation screen shows "Navigating to Room 101", big arrow pointing right, instruction "Turn right in 5 metres." | Navigation shuru. Arrow right point kar raha hai. "Turn right in 5 metres." bol raha hai. Ye BLE beacons se hota hai real mein. |
| 1:50-2:00 | Fade to black with "Cane sensor and beacons simulated. Hardware next phase." in yellow text. Wayze logo. | Demo khatam. Yaad rakhiye - cane sensor aur beacons simulated hain is demo mein. Real hardware integration next phase mein aayega. Thank you. |

---

## On-Screen Captions (add as overlay)

Throughout the video, keep this caption visible in bottom-right corner:
```
Cane sensor and beacons simulated.
Hardware next phase.
```

---

## Technical Notes for Recording

1. **Screen Recording:** Use phone emulator or real device with high contrast theme
2. **Audio:** Clear voiceover, add subtle background music (calm, ambient)
3. **Transitions:** Smooth fades between scenes (0.5s)
4. **Text Overlays:** Yellow (#FFC83D) on black (#000000), large font (Inter)
5. **Zoom Effects:** Use zoom to highlight UI elements (cane panel, buttons)
6. **TTS Audio:** Record actual TTS output from the app
7. **Haptic Visual:** Show ripple animation when haptic fires

---

## File Structure for Video Editor

- `demo_intro.mp4` (0:00-0:10)
- `demo_split_screen.mp4` (0:10-0:20)
- `demo_app_closeup.mp4` (0:20-0:35)
- `demo_cane_slider.mp4` (0:35-0:50)
- `demo_instruction_change.mp4` (0:50-1:00)
- `demo_stairs_toggle.mp4` (1:00-1:10)
- `demo_repeat_button.mp4` (1:10-1:20)
- `demo_reset.mp4` (1:20-1:30)
- `demo_destination_select.mp4` (1:30-1:40)
- `demo_navigation.mp4` (1:40-1:50)
- `demo_outro.mp4` (1:50-2:00)

---

## Total Duration: 2 minutes exactly
