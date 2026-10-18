import sys
import os
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.enum.text import PP_ALIGN
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE

def create_deck():
    prs = Presentation()
    # 16:9 widescreen dimensions (13.333 x 7.5 inches)
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)
    blank_layout = prs.slide_layouts[6]

    # Premium high-contrast dark theme colors
    BG_COLOR = RGBColor(15, 17, 23)        # Deep dark slate #0F1117
    CARD_BG = RGBColor(26, 31, 44)         # Elevated surface #1A1F2C
    BORDER_COLOR = RGBColor(45, 55, 75)    # Subtle boundary
    ACCENT_AMBER = RGBColor(255, 170, 0)   # High-visibility amber #FFAA00
    ACCENT_CYAN = RGBColor(0, 220, 255)    # Electric cyan #00DCFF
    ACCENT_GREEN = RGBColor(0, 230, 118)   # Alert safe green #00E676
    ACCENT_RED = RGBColor(255, 82, 82)     # P0 danger red #FF5252
    ACCENT_MUTED = RGBColor(120, 140, 165) # Neutral grey #788CA5
    TEXT_WHITE = RGBColor(255, 255, 255)   # Primary text
    TEXT_MUTED = RGBColor(160, 175, 200)   # Secondary text

    slides_data = [
        # Slide 1: Title
        {
            "title": "WAYZE",
            "subtitle": "Offline-First Indoor Navigation & Hazard Alert for Visually Impaired Users",
            "category": "PROJECT VISION & PITCH",
            "cards": [
                {
                    "title": "Core Mission",
                    "text": "A supplement to the white cane, never a replacement.\nReal-time edge AI navigation that works completely offline with the screen OFF.",
                    "accent": ACCENT_AMBER
                },
                {
                    "title": "Key Innovation",
                    "text": "Quantized YOLOv8n running directly on budget phone CPU (XNNPACK).\nZero cloud bill. Zero image storage. Sub-70ms target latency.",
                    "accent": ACCENT_CYAN
                },
                {
                    "title": "Founding Team",
                    "text": "Student Builders & Embedded Engineers | India\nContact: founder@wayze.in | Open-source Core",
                    "accent": ACCENT_GREEN
                }
            ],
            "hinglish": "Namaste judges. Humne banaya hai Wayze: 100% offline indoor navigation jo white cane ka sahayak hai, uska badal nahi."
        },
        # Slide 2: Problem
        {
            "title": "The Indoor Blind Mobility Gap",
            "subtitle": "Why the white cane and cloud AI both leave users vulnerable",
            "category": "THE PROBLEM",
            "cards": [
                {
                    "title": "White Cane Limit: 1 Meter Ground Only",
                    "text": "• Cannot detect chest/head-height hazards: open cupboards, signs, hanging wires.\n• Zero directional guidance: cannot tell 'door is 3m straight, then turn left'.",
                    "accent": ACCENT_RED
                },
                {
                    "title": "Cloud Vision AI is Too Slow & Expensive",
                    "text": "• 250ms - 800ms network lag causes staircase falls.\n• 0.9 GB data/hour exhausts budget mobile plans in 90 minutes.\n• $2-5/month server fees make it unaffordable for Indian users.",
                    "accent": ACCENT_AMBER
                },
                {
                    "title": "No Indoor GPS Exists",
                    "text": "• Satellite GPS signals do not penetrate concrete roofs.\n• Indoor beacons/tags are absent in 99% of Indian homes and public spaces.",
                    "accent": ACCENT_CYAN
                }
            ],
            "hinglish": "White cane zameen ke liye best hai par head-level hazards nahi dekhta. Aur cloud AI 500ms lag karta hai jo indoor safety mein dangerous hai."
        },
        # Slide 3: Target User & Constraints
        {
            "title": "The Reality of Budget Indian Smartphones",
            "subtitle": "Designing for the bottom 95% of visually impaired users",
            "category": "WHO IT'S FOR",
            "cards": [
                {
                    "title": "Target Device Profile",
                    "text": "• Sub-₹12,000 Android phones ($140).\n• 3GB to 4GB RAM total.\n• MediaTek Helio G85 / Snapdragon 680.\n• Cortex-A55 efficiency CPU cores.",
                    "accent": ACCENT_AMBER
                },
                {
                    "title": "Interaction Reality",
                    "text": "• Users cannot stare at screens or tap tiny buttons.\n• Phone is worn on a chest lanyard.\n• Screen must stay completely OFF.\n• Audio via earbud + heavy tactile haptics.",
                    "accent": ACCENT_CYAN
                },
                {
                    "title": "Hardware Constraint",
                    "text": "• User has NO smart cane today.\n• App MUST function in 'Phone-Only Mode' now.\n• Future BLE cane must connect with zero app logic changes.",
                    "accent": ACCENT_GREEN
                }
            ],
            "hinglish": "India ke majority blind users budget 4GB RAM phones use karte hain. Unke liye humne screen-off, phone-only offline navigation banayi hai."
        },
        # Slide 4: The Solution
        {
            "title": "Wayze: Offline Edge AI Co-Pilot",
            "subtitle": "An intelligent situational awareness layer that respects the white cane",
            "category": "THE SOLUTION",
            "cards": [
                {
                    "title": "100% On-Device Edge AI",
                    "text": "YOLOv8n quantized to INT8 running locally on ARM CPU via XNNPACK.\nTarget 40-70ms inference. $0 cloud bill. Airplane-mode operational.",
                    "accent": ACCENT_CYAN
                },
                {
                    "title": "Room Graph Dijkstra",
                    "text": "Pre-mapped topological room graph in private SQLite storage.\nCalculates step-by-step spoken instructions: '5 steps straight, turn left'.",
                    "accent": ACCENT_AMBER
                },
                {
                    "title": "Sensor Fusion & Drop-Off Protection",
                    "text": "Fuses vision threat scores with downward range sensors.\nDetects staircase drop-offs in <100ms with P0 preemption.",
                    "accent": ACCENT_GREEN
                }
            ],
            "hinglish": "Wayze local CPU pe chalta hai, room graph se rasta batata hai, aur seedhi ya obstacle aane par turant heavy vibration alert deta hai."
        },
        # Slide 5: System Architecture
        {
            "title": "Production Architecture: Kotlin + Flutter",
            "subtitle": "Separation of real-time camera memory from high-level state logic",
            "category": "SYSTEM ARCHITECTURE",
            "cards": [
                {
                    "title": "Native Android Layer (Kotlin)",
                    "text": "• CameraX 30 FPS with STRATEGY_KEEP_ONLY_LATEST.\n• Direct ByteBuffer zero-alloc YUV to RGB letterbox 320x320.\n• TFLite with 2-thread XNNPACK delegate.\n• Foreground Service with PARTIAL_WAKE_LOCK.",
                    "accent": ACCENT_CYAN
                },
                {
                    "title": "Flutter Domain Layer (Dart)",
                    "text": "• IoU + Kalman Tracker across frames.\n• Horizontal Field of View (HFOV) Zone Mapping.\n• Sensor Fusion Engine (Vision + Phone IMU + Cane).\n• In-Memory Dijkstra Navigation Graph in SQLite.",
                    "accent": ACCENT_AMBER
                },
                {
                    "title": "User Experience Layer",
                    "text": "• Offline Vosk Hindi + English Speech Recognition.\n• Alert Priority Queue (P0 Danger, P1 Nav, P2 Info).\n• Multi-modal outputs: Android TTS + Haptic feedback patterns.",
                    "accent": ACCENT_GREEN
                }
            ],
            "hinglish": "Camera aur ML native Kotlin mein RAM ke andar chalte hain, aur state machine, alerts, aur graph routing Flutter Dart mein handle hoti hai."
        },
        # Slide 6: Image-to-Alert Pipeline
        {
            "title": "Image-to-Alert: 6-Stage Processing",
            "subtitle": "From raw camera frame in RAM to spoken prompt in <100 milliseconds",
            "category": "VISION PIPELINE",
            "cards": [
                {
                    "title": "1. Zero-Allocation Capture",
                    "text": "CameraX captures YUV420 frame -> directly letterboxed into preallocated 320x320 buffer in RAM. Never saved to flash.",
                    "accent": ACCENT_MUTED
                },
                {
                    "title": "2. INT8 Inference & NMS",
                    "text": "TFLite runs on CPU via XNNPACK (40-70ms target) -> produces [1, 4+nc, 2100] tensor -> class-wise NMS at IoU 0.45.",
                    "accent": ACCENT_CYAN
                },
                {
                    "title": "3. Zone & Threat Scoring",
                    "text": "HFOV bearing angle: Left (<-12°), Center (±12°), Right (>+12°).\nThreat Score = Zone + Area Growth + Bottom-Y floor position.",
                    "accent": ACCENT_AMBER
                },
                {
                    "title": "4. Temporal Confirmation",
                    "text": "2-3 consecutive confirming frames required before alert fires. Prevents false alarms from camera jitter.",
                    "accent": ACCENT_GREEN
                }
            ],
            "hinglish": "Frame RAM mein preprocess hota hai, model infer karta hai, zone math lagta hai, aur 2-3 frame confirm hone ke baad hi alert bolta hai."
        },
        # Slide 7: Sensor Fusion & Smart Cane
        {
            "title": "Sensor Fusion & The Smart Cane",
            "subtitle": "Combining optical vision with direct distance measurements",
            "category": "HARDWARE & FUSION",
            "cards": [
                {
                    "title": "The Glass Door Rule",
                    "text": "Cameras see clear path, but cane ultrasonic detects solid barrier <50cm.\nFusion Engine overrides vision -> Fires immediate P0 Alert: 'Obstacle 40cm ahead'.",
                    "accent": ACCENT_RED
                },
                {
                    "title": "Stairs Down Drop-Off Rule",
                    "text": "Downward ground range normal = 110cm.\nIf downward distance > 145cm for >= 2 consecutive samples:\nTriggers P0 Emergency: 'Stairs down ahead. Stop.'",
                    "accent": ACCENT_AMBER
                },
                {
                    "title": "Smart Cane Hardware (Simulated)",
                    "text": "• ESP32-S3 microcontroller with BLE 5.0.\n• VL53L1X ToF (downward) + Ultrasonic (front).\n• Haptic grip motor + 18650 Li-ion battery.\n• Target BOM: $19.20 @ 10,000 units (~₹1,600).",
                    "accent": ACCENT_CYAN
                }
            ],
            "hinglish": "Kaanch ke darwaze pe camera dhokha kha sakta hai, par cane ka sensor pakad leta hai. Downward sensor 145cm se zyada hote hi seedhi ka alert deta hai."
        },
        # Slide 8: Alert Priority Queue & Voice
        {
            "title": "Voice Engine & Alert Prioritization",
            "subtitle": "Delivering critical cues without fatiguing the blind user",
            "category": "AUDIO & VOICE INTELLIGENCE",
            "cards": [
                {
                    "title": "P0 Danger (Emergency)",
                    "text": "Drop-off, stairs down, obstacle <50cm.\nFlushes lower queue, INTERRUPTS active TTS speech mid-word, fires 400ms heavy vibration.",
                    "accent": ACCENT_RED
                },
                {
                    "title": "P1 Navigation (Turn Guidance)",
                    "text": "'Turn left in 3 meters'. Expires after 2 seconds if delayed. Double short vibration pulse (80ms + 80ms).",
                    "accent": ACCENT_AMBER
                },
                {
                    "title": "P2 Info & Cooldown",
                    "text": "'Table on your right'. Spoken ONLY when system is fully idle.\n3-second cooldown per (class, zone) prevents repetitive spam.",
                    "accent": ACCENT_GREEN
                },
                {
                    "title": "Offline Vosk Voice Assistant",
                    "text": "Offline Hindi + English restricted grammar. 4-step repair ladder:\nSoft retry -> Guided options -> Yes/No confirm -> Hardware button fallback.",
                    "accent": ACCENT_CYAN
                }
            ],
            "hinglish": "P0 alert aate hi active speech beech mein rukti hai aur heavy vibration bajta hai. 3 second cooldown faltu chatter rokta hai."
        },
        # Slide 9: Privacy Architecture
        {
            "title": "Privacy By Design: Zero Cloud, Zero Photos",
            "subtitle": "Blind users have absolute right to private home surroundings",
            "category": "DATA PRIVACY & STORAGE",
            "cards": [
                {
                    "title": "Camera Frames: RAM Only",
                    "text": "Video frames exist only in volatile RAM buffers for ~33ms.\nFrames are immediately overwritten and discarded.\nZero images saved to disk. Zero images sent to any server.",
                    "accent": ACCENT_GREEN
                },
                {
                    "title": "Local Sandboxed Storage",
                    "text": "• Room Maps: Private SQLite database in app sandbox.\n• Settings: SharedPreferences (voice rate, language).\n• Logs: 5MB text-only rotating circular buffer (7 days max).",
                    "accent": ACCENT_CYAN
                },
                {
                    "title": "Optional Telemetry: Off by Default",
                    "text": "No automatic cloud sync. User must explicitly opt-in to 'Improve the App'.\nTelemetry sends only text crash stack traces—never audio or video.",
                    "accent": ACCENT_AMBER
                }
            ],
            "hinglish": "Koi bhi photo ya video phone memory mein save nahi hoti aur na internet pe jati hai. Sab kuch private local database mein rehta hai."
        },
        # Slide 10: Why No GPU? Edge Compute
        {
            "title": "Edge Compute: Why CPU Beats Mobile GPU",
            "subtitle": "Avoiding thermal collapse and driver fragmentation on budget devices",
            "category": "ENGINEERING TRADE-OFFS",
            "cards": [
                {
                    "title": "The Mobile GPU/NNAPI Trap",
                    "text": "Budget Helio G85 & Snapdragon 680 chips have fragmented, buggy NNAPI drivers.\nMobile GPUs cause severe thermal throttling within 10 minutes.",
                    "accent": ACCENT_RED
                },
                {
                    "title": "ARM CPU + XNNPACK Solution",
                    "text": "Pinned to 2 Cortex-A55 efficiency cores with hand-tuned ARM assembly.\nDeterministic execution, zero driver crashes, highly stable 40-70ms latency.",
                    "accent": ACCENT_GREEN
                },
                {
                    "title": "Stationary Adaptive Throttling",
                    "text": "Phone IMU senses when the user stops walking.\nInference drops automatically from 10 FPS to 4 FPS, cutting battery & heat by 60%.",
                    "accent": ACCENT_CYAN
                }
            ],
            "hinglish": "Budget phones pe GPU aur NNAPI overheat hoke crash kar dete hain. Humne CPU XNNPACK chuna jo 100% stable rehta hai aur battery bachata hai."
        },
        # Slide 11: Reliability & Safe Mode
        {
            "title": "Life-Safety Reliability & Safe Mode",
            "subtitle": "Core Rule: 'Silence never means safe'",
            "category": "FAIL-SAFE ENGINEERING",
            "cards": [
                {
                    "title": "2000ms Vision Watchdog",
                    "text": "If camera freezes for >2s, automatically restarts vision pipeline up to 3x.\nIf restarts fail: 'Vision stopped. Sensor and map mode active.'",
                    "accent": ACCENT_AMBER
                },
                {
                    "title": "25-Second Heartbeat Tick",
                    "text": "Periodic subtle haptic tick every 25 seconds while navigating.\nIf the ticks stop, user immediately knows the app or phone has died.",
                    "accent": ACCENT_CYAN
                },
                {
                    "title": "Crash-Loop SAFE MODE",
                    "text": "3 crashes in 5 minutes triggers permanent Safe Mode lockdown.\nCamera/voice killed. Giant tactile button. 'Wayze is in safe mode. Use your cane.'",
                    "accent": ACCENT_RED
                }
            ],
            "hinglish": "Agar app shaant ho jaye toh user ko lag sakta hai rasta clear hai. Isiliye heartbeat tick aur 3-crash Safe Mode user ko protect karte hain."
        },
        # Slide 12: Competitor Comparison
        {
            "title": "Market Comparison: Assistive Navigation",
            "subtitle": "Why existing tools leave a massive accessibility gap",
            "category": "COMPETITIVE LANDSCAPE",
            "cards": [
                {
                    "title": "WeWALK Smart Cane",
                    "text": "Price: ₹55,000+ ($600) [Verify before presenting].\nHigh-end ultrasonic handle, but NO on-device computer vision, no room graph, requires cloud.",
                    "accent": ACCENT_MUTED
                },
                {
                    "title": "IIT Delhi SmartCane / UltraCane",
                    "text": "Price: ₹3,500 - ₹10,000 [Verify before presenting].\nSimple ultrasonic beeper on cane. No object recognition, no spoken turn directions.",
                    "accent": ACCENT_MUTED
                },
                {
                    "title": "Seeing AI / Be My Eyes",
                    "text": "Price: Free (Software).\nCloud scene description apps. Requires 4G/5G, 2-3s delay, photo taking. Not for real-time walking guidance.",
                    "accent": ACCENT_MUTED
                },
                {
                    "title": "WAYZE (Our Edge)",
                    "text": "Price: App FREE / Future Cane Target BOM: ₹1,800 ($22).\n100% Offline-first, on-device YOLOv8, Dijkstra room graph, drop-off fusion, screen-off operation.",
                    "accent": ACCENT_GREEN
                }
            ],
            "hinglish": "WeWALK ₹55,000 ki hai aur Seeing AI cloud pe chalta hai. Wayze offline phone app free deta hai aur future cane sirf ₹1,800 target karti hai."
        },
        # Slide 13: Honesty Board
        {
            "title": "The Honesty Board: Verified vs Targets",
            "subtitle": "Engineering transparency: Separating proven code from hardware goals",
            "category": "VERIFICATION MATRIX",
            "cards": [
                {
                    "title": "VERIFIED & WORKING NOW",
                    "text": "• 109 automated unit & integration tests passing.\n• Alert priority preemption, 3s cooldown, drop-off rule logic.\n• Offline Vosk Hindi/English intent matcher & repair ladder.\n• SQLite atomic map writes with .bak restoration.",
                    "accent": ACCENT_GREEN
                },
                {
                    "title": "TARGETS & ESTIMATES (To Be Measured on Hardware)",
                    "text": "• Inference latency target: 40-70 ms on Snapdragon 680.\n• Battery drain estimate: ~8-14% per hour continuous analysis.\n• Smart cane BOM estimate: $19.20 @ 10,000 units.\n• Lab validation accuracy: 75.5% mAP@50 (model_facts.json).",
                    "accent": ACCENT_AMBER
                },
                {
                    "title": "WHAT IS NOT DONE YET",
                    "text": "• NO physical smart cane fabricated yet (architecture simulated).\n• NO clinical blind-user field trials conducted yet.\n• Phase 2 milestone: 50 visually impaired student pilot.",
                    "accent": ACCENT_RED
                }
            ],
            "hinglish": "109 tests passing hain, software pipeline ready hai. Par humne abhi tak cane fabricate nahi ki hai aur blind user testing Phase 2 mein honi hai."
        },
        # Slide 14: Live Demo Plan
        {
            "title": "Live Demonstration Architecture",
            "subtitle": "5-minute offline verification using real Android phone",
            "category": "LIVE DEMONSTRATION",
            "cards": [
                {
                    "title": "1. Airplane Mode Verification",
                    "text": "Wi-Fi & Data OFF. Hardware Volume-Up pressed -> speaks 'Where am I' instantly using offline Vosk engine.",
                    "accent": ACCENT_CYAN
                },
                {
                    "title": "2. Real-Time Vision & Zones",
                    "text": "Camera points at chair -> Live bounding box overlay -> p50 latency counter -> Left/Center/Right zone pan.",
                    "accent": ACCENT_AMBER
                },
                {
                    "title": "3. P0 Danger Preemption Test",
                    "text": "Navigation speaks -> Mock cane distance pulled to 35cm -> Immediate voice cut, heavy 400ms buzz, 'Obstacle ahead stop!'.",
                    "accent": ACCENT_RED
                }
            ],
            "hinglish": "Demo mein hum airplane mode show karenge, live chair bounding box dekhenge, aur 40cm pe speech cut hoke heavy vibration prove karenge."
        },
        # Slide 15: Unit Economics & Roadmap
        {
            "title": "Unit Economics & 4-Phase Roadmap",
            "subtitle": "From open-source software to institutional subsidized hardware",
            "category": "COMMERCIAL SCALABILITY",
            "cards": [
                {
                    "title": "Unit Economics @ Scale",
                    "text": "• Cloud Inference Bill: $0.00 / month.\n• Static Map CDN / Crashlytics: $0.05 - $0.40 / user / month.\n• Smart Cane BOM: $19.20 (~₹1,600) @ 10k units.",
                    "accent": ACCENT_GREEN
                },
                {
                    "title": "Phase 1 & 2 (Now - Month 4)",
                    "text": "• Phase 1: Complete offline Android app & test harness (DONE).\n• Phase 2: 50-user Blind School pilot (NAB Delhi / BPA Ahmedabad).",
                    "accent": ACCENT_CYAN
                },
                {
                    "title": "Phase 3 & 4 (Month 5 - 12)",
                    "text": "• Phase 3: 100 prototype canes fabrication, WPC/BIS safety certification.\n• Phase 4: B2G ADIP Scheme subsidy & transit hub indoor map packs.",
                    "accent": ACCENT_AMBER
                }
            ],
            "hinglish": "Inference bill zero hai. Phase 2 mein 50 blind students ke saath pilot karenge, aur Phase 3 mein 100 cane prototypes fabricate karenge."
        },
        # Slide 16: The Ask & Call to Action
        {
            "title": "The Ask: Empowering Independence",
            "subtitle": "Assisting blind mobility with dignity, speed, and safety",
            "category": "THE ASK",
            "cards": [
                {
                    "title": "Grant Funding: ₹15 Lakhs ($18,000)",
                    "text": "• ₹6 Lakhs (40%): 100 Smart Cane prototype fabrication & tooling.\n• ₹5 Lakhs (33%): 50-user Blind School trials & localized voice datasets.\n• ₹4 Lakhs (27%): WPC / BIS wireless certification & ground truth testing.",
                    "accent": ACCENT_AMBER
                },
                {
                    "title": "Mentorship & Institutional Access",
                    "text": "Seeking connections with National Association for the Blind (NAB),\nrehabilitation clinics, and assistive hardware manufacturing mentors.",
                    "accent": ACCENT_CYAN
                },
                {
                    "title": "Our Closing Commitment",
                    "text": "White canes taught them to walk.\nWayze will teach them to walk without fear.\nThank you! We are ready for your questions.",
                    "accent": ACCENT_GREEN
                }
            ],
            "hinglish": "Hume ₹15 Lakhs ka grant aur Blind Schools ke saath pilot connects chahiye. Safed chhadi ne unhe chalna sikhaya, Wayze unhe aazadi dega."
        }
    ]

    for idx, data in enumerate(slides_data):
        slide = prs.slides.add_slide(blank_layout)

        # 1. Dark Background fill
        bg_shape = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, Inches(13.333), Inches(7.5))
        bg_shape.fill.solid()
        bg_shape.fill.fore_color.rgb = BG_COLOR
        bg_shape.line.fill.background()

        # 2. Header Category Badge
        cat_box = slide.shapes.add_textbox(Inches(0.8), Inches(0.4), Inches(11.7), Inches(0.4))
        cat_tf = cat_box.text_frame
        cat_tf.word_wrap = True
        p_cat = cat_tf.paragraphs[0]
        p_cat.text = f"SLIDE {idx+1:02d} // {data['category']}"
        p_cat.font.size = Pt(11)
        p_cat.font.bold = True
        p_cat.font.color.rgb = ACCENT_AMBER

        # 3. Slide Title & Subtitle
        title_box = slide.shapes.add_textbox(Inches(0.8), Inches(0.7), Inches(11.7), Inches(1.1))
        title_tf = title_box.text_frame
        title_tf.word_wrap = True
        p_title = title_tf.paragraphs[0]
        p_title.text = data["title"]
        p_title.font.size = Pt(28)
        p_title.font.bold = True
        p_title.font.color.rgb = TEXT_WHITE

        p_sub = title_tf.add_paragraph()
        p_sub.text = data["subtitle"]
        p_sub.font.size = Pt(14)
        p_sub.font.color.rgb = TEXT_MUTED

        # 4. Content Cards Layout
        cards = data["cards"]
        num_cards = len(cards)
        total_width = 11.733 # 13.333 - 1.6
        gap = 0.3
        card_w = (total_width - (gap * (num_cards - 1))) / num_cards
        card_h = 4.4
        card_top = Inches(2.0)

        for c_idx, card in enumerate(cards):
            card_left = Inches(0.8 + c_idx * (card_w + gap))
            
            # Card background
            card_shape = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, card_left, card_top, Inches(card_w), Inches(card_h))
            card_shape.fill.solid()
            card_shape.fill.fore_color.rgb = CARD_BG
            card_shape.line.color.rgb = card.get("accent", BORDER_COLOR)
            card_shape.line.width = Pt(1.5)

            # Card Header Color Bar
            top_bar = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, card_left + Inches(0.05), card_top + Inches(0.05), Inches(card_w - 0.1), Inches(0.08))
            top_bar.fill.solid()
            top_bar.fill.fore_color.rgb = card.get("accent", ACCENT_CYAN)
            top_bar.line.fill.background()

            # Card Text Box
            c_box = slide.shapes.add_textbox(card_left + Inches(0.2), card_top + Inches(0.25), Inches(card_w - 0.4), Inches(card_h - 0.5))
            c_tf = c_box.text_frame
            c_tf.word_wrap = True

            p_ctitle = c_tf.paragraphs[0]
            p_ctitle.text = card["title"]
            p_ctitle.font.size = Pt(16)
            p_ctitle.font.bold = True
            p_ctitle.font.color.rgb = card.get("accent", TEXT_WHITE)

            p_ctext = c_tf.add_paragraph()
            p_ctext.text = "\n" + card["text"]
            p_ctext.font.size = Pt(12)
            p_ctext.font.color.rgb = TEXT_WHITE

        # 5. Bottom Speaker Hinglish Prompt Bar
        spk_box = slide.shapes.add_textbox(Inches(0.8), Inches(6.6), Inches(11.733), Inches(0.6))
        spk_tf = spk_box.text_frame
        spk_tf.word_wrap = True
        p_spk = spk_tf.paragraphs[0]
        p_spk.text = f"🗣️ SPEAKER HINGLISH CUE: \"{data['hinglish']}\""
        p_spk.font.size = Pt(10)
        p_spk.font.italic = True
        p_spk.font.color.rgb = ACCENT_AMBER

        # 6. Speaker Notes in PPTX
        notes_slide = slide.notes_slide
        text_frame = notes_slide.notes_text_frame
        text_frame.text = f"SPEAKER SCRIPT:\n{data['hinglish']}\n\nSLIDE OBJECTIVE:\n{data['subtitle']}"

    output_path = os.path.join("wayze-pitch", "pitch_deck.pptx")
    prs.save(output_path)
    print(f"Successfully generated {output_path} with {len(slides_data)} slides.")

if __name__ == "__main__":
    create_deck()
