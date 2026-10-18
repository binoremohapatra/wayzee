# Wayze YOLOv8n INT8 Model Training, Quantization & Deployment Guide

This runbook specifies the end-to-end procedure for curating indoor navigation datasets, fine-tuning YOLOv8n, performing INT8 Post-Training Quantization (PTQ) with representative dataset calibration, and deploying models to the Wayze Android application.

---

## 1. Dataset Collection & Annotation Standards

Indoor hazard perception for blind users has unique geometry and safety constraints compared to general object detection:

### 1.1 Camera Angle and Mounting Height
- **Mounting Position:** Lanyard or chest mount (approximately 1.1m – 1.4m above the ground).
- **Pitch Angle:** $15^\circ$ to $25^\circ$ downward tilt. The horizon line is near the upper third of the frame, with the ground plane occupying the center and lower two-thirds.
- **Lighting Diversity:** Include daylight, dim hallway (5 – 15 lux), warm incandescent, fluorescent tube lighting, and specular floor reflections (polished granite/marble).

### 1.2 Annotation Rules
| Class | Annotation Guideline | Critical Safety Note |
| :--- | :--- | :--- |
| `stairs_down` | Encompasses the edge of the top step through the visible bottom landing. | **P0 Critical:** Missing a downward drop-off is a catastrophic fall risk. |
| `stairs_up` | Encompasses the base riser up to the visible top handrail/step. | P1 Warning: Must warn user before foot collision. |
| `door` | Encompasses the full door slab and frame. | Guides approach to handles and entrances. |
| `drop_off` | Unprotected platform edge or curb. | Treat with identical P0 priority to `stairs_down`. |
| `person` | Full body or torso. | P2 Dynamic obstacle. |
| `chair` / `table` | Ground contact legs through seat/tabletop. | Head-height and low-shin collisions. |

> [!IMPORTANT]
> **Gravity Orientation Constraint:** NEVER enable vertical flip augmentation (`flipud = 0.0`). Inverted stairs do not exist in the physical world and degrade downward drop-off classification weights.

---

## 2. Dataset Curation & Leakage Auditing

Before training, run the dataset validation script:
```bash
python scripts/curate_and_validate_dataset.py \
    --dataset_dir path/to/dataset \
    --classes door,stairs \
    --generate_yaml
```

### What the script audits:
1. **Coordinate Normalization:** Verifies all coordinates $(cx, cy, w, h)$ are strictly bounded in $[0.0, 1.0]$.
2. **Corrupted Images:** Detects truncated JPEG/PNG binaries.
3. **Class Balance:** Alerts if hazard classes (`stairs`, `drop_off`) have under 200 instances.
4. **Data Contamination (Leakage):** Computes SHA-256 hashes of every frame across `train/`, `val/`, and `test/` splits. Emits a high-severity warning if identical or near-duplicate frames exist in both training and test sets.

---

## 3. Training Pipeline

Training is executed at $320\times 320$ resolution to fit within budget phone RAM and memory-bandwidth constraints.

### 3.1 Local or Cloud Execution (Google Colab T4)
```bash
python scripts/train_and_export_yolov8.py \
    --data door_stairs_dataset/data.yaml \
    --epochs 50 \
    --batch 16 \
    --imgsz 320 \
    --base yolov8n.pt \
    --output_dir android/app/src/main/assets/models \
    --device 0
```

### 3.2 Recommended Hyperparameters for Mobile Deployment
- **Input Size:** `320` (optimal latency/accuracy trade-off for Cortex-A53 / Snapdragon 680).
- **Optimizer:** `AdamW` with cosine learning rate schedule (`cos_lr=True`).
- **Mosaic Augmentation:** `0.5` (reduced from 1.0 to preserve small indoor hazard geometry).
- **Mixup:** `0.0` (disabled to preserve crisp high-frequency step edges).

---

## 4. INT8 Post-Training Quantization (PTQ)

Budget Android phones (e.g., Helio G85, Snapdragon 680) lack dedicated NPUs. Running FP32 models on mobile CPU requires 4 bytes per weight and results in severe thermal throttling. Full INT8 quantization reduces model size by $\sim 75\%$ ($12.7\text{ MB} \to 3.2\text{ MB}$) and enables ARM NEON integer vector acceleration via XNNPACK.

### 4.1 Calibration Loop
Quantization requires a representative dataset (typically 100–200 diverse indoor frames) to calculate tensor activation ranges $(\text{scale}, \text{zero\_point})$:

```python
from ultralytics import YOLO

model = YOLO("runs/detect/train/weights/best.pt")
# Export INT8 with validation dataset calibration
model.export(
    format="tflite",
    imgsz=320,
    int8=True,
    data="door_stairs_dataset/data.yaml"
)
```

---

## 5. Shape Parity & Inspection

### 5.1 Inspecting with Netron
Open [Netron](https://netron.app) and drag in `wayze_v1.tflite`:
- **Input Node:** Should be `[1, 320, 320, 3]` (NHWC) or `[1, 3, 320, 320]` (NCHW), datatype `INT8` or `FLOAT32`.
- **Output Node:** Standard raw YOLOv8 output is `[1, 4 + nc, 2100]` where $nc$ is the number of classes.
  - For 2 classes (`door`, `stairs`): `[1, 6, 2100]`.
  - For 10 classes: `[1, 14, 2100]`.

### 5.2 Automated Parity Verification
Run the parity script:
```bash
python scripts/inspect_tflite_model.py \
    --model android/app/src/main/assets/models/wayze_v1.tflite \
    --labels android/app/src/main/assets/models/labels.txt
```

This verifies:
1. Output tensor channel count $(4 + nc)$ matches line count of `labels.txt`.
2. Tensor shape is compatible with [YoloV8Inference.kt](file:///d:/wayze/android/app/src/main/kotlin/com/wayze/app/wayze/YoloV8Inference.kt).
3. Executes a test dry-run invocation.

---

## 6. Deployment into the Android App

1. Copy the exported `.tflite` model:
   ```bash
   cp runs/detect/train/weights/best_int8.tflite android/app/src/main/assets/models/wayze_v1.tflite
   ```
2. Verify `labels.txt` matches training class order:
   ```
   door
   stairs
   ```
3. Launch the **Model Test & Benchmark** screen inside Wayze to run a 5-minute real-device soak test.

---

## 7. Metrics & Hardware Disclosures

| Parameter | Current Measured Value | Verification Status |
| :--- | :--- | :--- |
| Model Size (FP32 TFLite) | 12.69 MB | **VERIFIED** (Disk storage measurement) |
| Model Size (INT8 TFLite) | ~3.3 MB | **VERIFIED** (Disk storage measurement) |
| mAP@0.50 (door, stairs) | 0.7552 | **VERIFIED** (Offline validation split) |
| mAP@0.50:0.95 | 0.4963 | **VERIFIED** (Offline validation split) |
| Real-Device Latency on Snapdragon 680 | ~45ms – 65ms | **[UNVERIFIED]** (Needs physical phone test) |
| 30-Minute Thermal Throttling Drop ($\Delta$ FPS) | Unknown | **[UNVERIFIED]** (Needs physical soak run) |
| Real-World False Alarm Frequency | Unknown | **[UNVERIFIED]** (Needs user pilot data) |
