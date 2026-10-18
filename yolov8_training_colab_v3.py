# ==============================================================================
# YOLOv8n TRAINING NOTEBOOK FOR INDOOR NAVIGATION
# Classes: door, stairs, glass_door, pillar, wet_floor_sign
# ==============================================================================

# IF SOMETHING FAILS CHECKLIST:
# - No GPU: Runtime > Change runtime type > T4 GPU
# - Wrong class order: Edit MAPPING dict in CELL 3
# - Empty val set: Check split ratios in CELL 3
# - TFLite export/TensorFlow errors: Try ONNX fallback in CELL 8
# - Labels out of range: CELL 4 will warn you
# - Drive path errors: Check mounting in CELL 1

# ==============================================================================
# ===== CELL 1: SETUP
# ==============================================================================
# Can fail if: No internet, insufficient storage, runtime crashes

!pip install ultralytics
import ultralytics
print(f"Ultralytics version: {ultralytics.__version__}")

import torch
print(f"PyTorch version: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"GPU name: {torch.cuda.get_device_name(0)}")
else:
    print("WARNING: No GPU detected. Runtime > Change runtime type > T4 GPU")

# Set fixed output directory
import os
OUT_DIR = "/content/yolov8_train"
os.makedirs(OUT_DIR, exist_ok=True)
print(f"Output directory: {OUT_DIR}")

# ==============================================================================
# ===== CELL 2: UPLOAD DATASETS
# ==============================================================================
# Can fail if: User doesn't upload files, zip files are corrupted, insufficient storage

from google.colab import files
import zipfile
import os

# Upload 1-3 Roboflow YOLOv8 zips
print("Upload 1 to 3 Roboflow YOLOv8 zips (one can be your own photos)")
uploaded = files.upload()

# Unzip each into ds_1, ds_2, ds_3
datasets = []
for i, (filename, content) in enumerate(uploaded.items(), 1):
    ds_path = f"/content/ds_{i}"
    os.makedirs(ds_path, exist_ok=True)
    with open(f"/content/{filename}", 'wb') as f:
        f.write(content)
    with zipfile.ZipFile(f"/content/{filename}", 'r') as zip_ref:
        zip_ref.extractall(ds_path)
    datasets.append(ds_path)
    print(f"Extracted {filename} to {ds_path}")

# Find and print each data.yaml
import yaml
for ds in datasets:
    for root, dirs, files in os.walk(ds):
        if "data.yaml" in files:
            yaml_path = os.path.join(root, "data.yaml")
            with open(yaml_path, 'r') as f:
                data = yaml.safe_load(f)
            print(f"\nDataset: {ds}")
            print(f"data.yaml location: {yaml_path}")
            print(f"Class names: {data.get('names', [])}")

# ==============================================================================
# ===== CELL 3: MERGE + REMAP
# ==============================================================================
# Can fail if: Invalid class names in mapping, disk full, file permission errors

import shutil
import yaml
from pathlib import Path

# EDITABLE MAPPING: Map dataset class names to final class list
# Drop unmapped classes automatically
FINAL_CLASSES = ["door", "stairs", "glass_door", "pillar", "wet_floor_sign"]

# Example mapping - EDIT THIS BASED ON YOUR DATASET CLASS NAMES
MAPPING = {
    # Dataset 1 mapping (example - edit based on your actual class names)
    "Door": "door",
    "door": "door",
    "staircase": "stairs",
    "stairs": "stairs",
    "glass door": "glass_door",
    "glass_door": "glass_door",
    "pillar": "pillar",
    "wet floor sign": "wet_floor_sign",
    "wet_floor_sign": "wet_floor_sign",
    # Add more mappings as needed
}

# Create merged directory structure
merged_dir = "/content/merged"
for split in ["train", "val"]:
    os.makedirs(f"{merged_dir}/{split}/images", exist_ok=True)
    os.makedirs(f"{merged_dir}/{split}/labels", exist_ok=True)

# Track which dataset is "own photos" (last uploaded by convention)
own_photos_ds = datasets[-1] if len(datasets) > 0 else None

def remap_label(label_path, new_label_path):
    """Remap class indices in label file"""
    with open(label_path, 'r') as f:
        lines = f.readlines()
    
    new_lines = []
    for line in lines:
        parts = line.strip().split()
        if len(parts) >= 5:
            old_class = int(parts[0])
            # Skip if class index too large for original dataset
            # (we rely on mapping being complete)
            if old_class < len(data.get('names', [])):
                old_name = data['names'][old_class]
                if old_name in MAPPING:
                    new_name = MAPPING[old_name]
                    if new_name in FINAL_CLASSES:
                        new_class = FINAL_CLASSES.index(new_name)
                        new_line = f"{new_class} " + " ".join(parts[1:]) + "\n"
                        new_lines.append(new_line)
    
    if new_lines:
        with open(new_label_path, 'w') as f:
            f.writelines(new_lines)
        return True
    return False

# Process each dataset
for ds_idx, ds in enumerate(datasets):
    for root, dirs, files in os.walk(ds):
        if "data.yaml" in files:
            yaml_path = os.path.join(root, "data.yaml")
            with open(yaml_path, 'r') as f:
                data = yaml.safe_load(f)
            
            # Process train and val
            for split in ["train", "val"]:
                split_key = "val" if split == "val" else "train"
                if split_key not in data:
                    print(f"Warning: {split_key} not found in {ds}")
                    continue
                
                # Handle both relative and absolute paths
                if data[split_key].startswith('/'):
                    split_path = data[split_key]
                else:
                    split_path = os.path.join(os.path.dirname(yaml_path), data[split_key])
                
                if not os.path.exists(split_path):
                    print(f"Warning: {split_path} does not exist")
                    continue
                
                # Find images and labels
                images_dir = os.path.join(split_path, "images")
                labels_dir = os.path.join(split_path, "labels")
                
                if not os.path.exists(images_dir) or not os.path.exists(labels_dir):
                    print(f"Warning: images or labels not found in {split_path}")
                    continue
                
                # For own photos, ensure 20% go to val
                if ds == own_photos_ds and split == "train":
                    import random
                    random.seed(42)
                    all_images = sorted(os.listdir(images_dir))
                    val_count = max(1, int(len(all_images) * 0.2))
                    val_images = random.sample(all_images, val_count)
                    train_images = [img for img in all_images if img not in val_images]
                    
                    # Copy train images
                    for img in train_images:
                        shutil.copy(os.path.join(images_dir, img), f"{merged_dir}/train/images/{img}")
                        label_file = img.rsplit('.', 1)[0] + '.txt'
                        label_path = os.path.join(labels_dir, label_file)
                        if os.path.exists(label_path):
                            remap_label(label_path, f"{merged_dir}/train/labels/{label_file}")
                    
                    # Copy val images
                    for img in val_images:
                        shutil.copy(os.path.join(images_dir, img), f"{merged_dir}/val/images/{img}")
                        label_file = img.rsplit('.', 1)[0] + '.txt'
                        label_path = os.path.join(labels_dir, label_file)
                        if os.path.exists(label_path):
                            remap_label(label_path, f"{merged_dir}/val/labels/{label_file}")
                    
                    print(f"Own photos: {len(train_images)} train, {len(val_images)} val")
                else:
                    # Copy all images for this split
                    for img in os.listdir(images_dir):
                        shutil.copy(os.path.join(images_dir, img), f"{merged_dir}/{split}/images/{img}")
                        label_file = img.rsplit('.', 1)[0] + '.txt'
                        label_path = os.path.join(labels_dir, label_file)
                        if os.path.exists(label_path):
                            remap_label(label_path, f"{merged_dir}/{split}/labels/{label_file}")

# Count images with empty labels removed
empty_removed = 0
for split in ["train", "val"]:
    labels_dir = f"{merged_dir}/{split}/labels"
    for label_file in os.listdir(labels_dir):
        label_path = os.path.join(labels_dir, label_file)
        if os.path.getsize(label_path) == 0:
            os.remove(label_path)
            empty_removed += 1

print(f"Removed {empty_removed} empty label files")

# Write merged data.yaml
merged_data = {
    'path': merged_dir,
    'train': f"{merged_dir}/train",
    'val': f"{merged_dir}/val",
    'names': {i: name for i, name in enumerate(FINAL_CLASSES)},
    'nc': len(FINAL_CLASSES)
}

with open(f"{merged_dir}/data.yaml", 'w') as f:
    yaml.dump(merged_data, f)

print(f"\nMerged data.yaml written to {merged_dir}/data.yaml")
print(f"Final classes: {FINAL_CLASSES}")

# ==============================================================================
# ===== CELL 4: AUDIT
# ==============================================================================
# Can fail if: Corrupt images, malformed label files, memory issues

import matplotlib.pyplot as plt
import matplotlib.patches as patches
from PIL import Image
import random

# Count images and boxes
def count_boxes(split_dir):
    image_count = 0
    class_counts = {name: 0 for name in FINAL_CLASSES}
    
    labels_dir = f"{split_dir}/labels"
    if not os.path.exists(labels_dir):
        return image_count, class_counts
    
    for label_file in os.listdir(labels_dir):
        label_path = os.path.join(labels_dir, label_file)
        if os.path.getsize(label_path) == 0:
            continue
        
        image_count += 1
        with open(label_path, 'r') as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) >= 5:
                    class_idx = int(parts[0])
                    if 0 <= class_idx < len(FINAL_CLASSES):
                        class_name = FINAL_CLASSES[class_idx]
                        class_counts[class_name] += 1
    
    return image_count, class_counts

train_count, train_boxes = count_boxes(f"{merged_dir}/train")
val_count, val_boxes = count_boxes(f"{merged_dir}/val")

print(f"\nTRAIN SET:")
print(f"  Images: {train_count}")
print(f"  Boxes per class:")
for name in FINAL_CLASSES:
    print(f"    {name}: {train_boxes[name]}")

print(f"\nVAL SET:")
print(f"  Images: {val_count}")
print(f"  Boxes per class:")
for name in FINAL_CLASSES:
    print(f"    {name}: {val_boxes[name]}")

# Check for duplicate filenames
all_images = []
for split in ["train", "val"]:
    all_images.extend(os.listdir(f"{merged_dir}/{split}/images"))
duplicates = [img for img in set(all_images) if all_images.count(img) > 1]
if duplicates:
    print(f"\nWARNING: {len(duplicates)} duplicate image filenames found")
else:
    print("\nNo duplicate image filenames")

# Check for labels with coordinates outside 0-1
out_of_range = 0
for split in ["train", "val"]:
    labels_dir = f"{merged_dir}/{split}/labels"
    for label_file in os.listdir(labels_dir):
        label_path = os.path.join(labels_dir, label_file)
        with open(label_path, 'r') as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) >= 5:
                    x, y, w, h = map(float, parts[1:5])
                    if not (0 <= x <= 1 and 0 <= y <= 1 and 0 <= w <= 1 and 0 <= h <= 1):
                        out_of_range += 1

if out_of_range > 0:
    print(f"\nWARNING: {out_of_range} boxes have coordinates outside 0-1 range")
else:
    print("\nAll box coordinates in valid range")

# Check for boxes smaller than 1% of image
tiny_boxes = 0
for split in ["train", "val"]:
    labels_dir = f"{merged_dir}/{split}/labels"
    for label_file in os.listdir(labels_dir):
        label_path = os.path.join(labels_dir, label_file)
        with open(label_path, 'r') as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) >= 5:
                    w, h = map(float, parts[3:5])
                    if w < 0.01 or h < 0.01:
                        tiny_boxes += 1

if tiny_boxes > 0:
    print(f"WARNING: {tiny_boxes} boxes are smaller than 1% of image")
else:
    print("No tiny boxes (< 1% of image)")

# Warn if class has too few boxes
print("\nCLASS BALANCE WARNINGS:")
for name in FINAL_CLASSES:
    if train_boxes[name] < 80:
        print(f"  CRITICAL: {name} has only {train_boxes[name]} train boxes (< 80)")
    elif train_boxes[name] < 150:
        print(f"  WARNING: {name} has only {train_boxes[name]} train boxes (< 150)")
    
    if val_boxes[name] < 15:
        print(f"  CRITICAL: {name} has only {val_boxes[name]} val boxes (< 15)")
    elif val_boxes[name] < 30:
        print(f"  WARNING: {name} has only {val_boxes[name]} val boxes (< 30)")

# Plot class balance
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))
ax1.bar(FINAL_CLASSES, [train_boxes[name] for name in FINAL_CLASSES])
ax1.set_title('Train Boxes per Class')
ax1.set_ylabel('Box Count')
plt.setp(ax1.xaxis.get_majorticklabels(), rotation=45, ha='right')

ax2.bar(FINAL_CLASSES, [val_boxes[name] for name in FINAL_CLASSES])
ax2.set_title('Val Boxes per Class')
ax2.set_ylabel('Box Count')
plt.setp(ax2.xaxis.get_majorticklabels(), rotation=45, ha='right')

plt.tight_layout()
plt.savefig(f"{OUT_DIR}/class_balance.png")
plt.show()

# Show 12 random images with boxes
def draw_boxes(image_path, label_path):
    img = Image.open(image_path)
    w, h = img.size
    
    fig, ax = plt.subplots(1)
    ax.imshow(img)
    
    if os.path.exists(label_path):
        with open(label_path, 'r') as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) >= 5:
                    class_idx = int(parts[0])
                    x, y, bw, bh = map(float, parts[1:5])
                    
                    # Convert from center format to corner format
                    x1 = (x - bw/2) * w
                    y1 = (y - bh/2) * h
                    x2 = (x + bw/2) * w
                    y2 = (y + bh/2) * h
                    
                    rect = patches.Rectangle((x1, y1), x2-x1, y2-y1, 
                                           linewidth=2, edgecolor='red', facecolor='none')
                    ax.add_patch(rect)
                    ax.text(x1, y1, FINAL_CLASSES[class_idx] if class_idx < len(FINAL_CLASSES) else str(class_idx),
                           color='red', fontsize=8)
    
    ax.axis('off')
    return fig

# Sample 12 random images
sample_images = random.sample(os.listdir(f"{merged_dir}/train/images"), min(12, len(os.listdir(f"{merged_dir}/train/images"))))
fig, axes = plt.subplots(3, 4, figsize=(16, 12))
axes = axes.flatten()

for i, img_file in enumerate(sample_images):
    img_path = os.path.join(f"{merged_dir}/train/images", img_file)
    label_file = img_file.rsplit('.', 1)[0] + '.txt'
    label_path = os.path.join(f"{merged_dir}/train/labels", label_file)
    
    img = Image.open(img_path)
    w, h = img.size
    axes[i].imshow(img)
    
    if os.path.exists(label_path):
        with open(label_path, 'r') as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) >= 5:
                    class_idx = int(parts[0])
                    x, y, bw, bh = map(float, parts[1:5])
                    x1 = (x - bw/2) * w
                    y1 = (y - bh/2) * h
                    x2 = (x + bw/2) * w
                    y2 = (y + bh/2) * h
                    rect = patches.Rectangle((x1, y1), x2-x1, y2-y1, 
                                           linewidth=2, edgecolor='red', facecolor='none')
                    axes[i].add_patch(rect)
    
    axes[i].axis('off')
    axes[i].set_title(img_file[:20])

plt.tight_layout()
plt.savefig(f"{OUT_DIR}/sample_labels.png")
plt.show()

# ==============================================================================
# ===== CELL 5: TRAIN
# ==============================================================================
# Can fail if: Out of memory, dataset not found, Ultralytics version conflict

from ultralytics import YOLO

# EDITABLE PARAMETERS
EPOCHS = 60  # Change if needed
BATCH = 16
PATIENCE = 15
IMG_SIZE = 320

print(f"Training YOLOv8n for {EPOCHS} epochs...")
print(f"Batch size: {BATCH}, Image size: {IMG_SIZE}")
print(f"Patience: {PATIENCE}")

# Load model
model = YOLO("yolov8n.pt")

# Train
results = model.train(
    data=f"{merged_dir}/data.yaml",
    epochs=EPOCHS,
    imgsz=IMG_SIZE,
    batch=BATCH,
    patience=PATIENCE,
    project=OUT_DIR,
    name="train",
    augment=True,
    mosaic=True,
    hsv_h=0.015,
    hsv_s=0.7,
    hsv_v=0.4,
    fliplr=0.5,
    flipud=0.0,  # Stairs/doors never upside down
    degrees=5.0,  # Small rotation
    cos_lr=True,
    seed=42,
    plots=True,
    save=True,
    device=0 if torch.cuda.is_available() else "cpu"
)

print(f"\nTraining complete!")
print(f"Output folder: {OUT_DIR}/train")

# Check for overfitting (if val loss rises while train loss falls)
print("\nCheck the results plot in {OUT_DIR}/train/results.png")
print("If val loss rises while train loss falls, it is overfitting.")
print("Fix: Reduce epochs, increase data augmentation, or add more data.")

# ==============================================================================
# ===== CELL 6: EVALUATE
# ==============================================================================
# Can fail if: Model file not found, corrupt best.pt

print("Loading best model for evaluation...")
best_model = YOLO(f"{OUT_DIR}/train/weights/best.pt")

# Evaluate on full val set
print("\nEvaluating on full validation set...")
metrics = best_model.val(split="val")

print(f"\nOVERALL METRICS:")
print(f"  mAP50: {metrics.box.map50:.4f}")
print(f"  mAP50-95: {metrics.box.map:.4f}")
print(f"  Precision: {metrics.box.mp:.4f}")
print(f"  Recall: {metrics.box.mr:.4f}")

print(f"\nPER-CLASS METRICS:")
for i, name in enumerate(FINAL_CLASSES):
    if i < len(metrics.box.maps):
        print(f"  {name}: mAP50 = {metrics.box.maps[i]:.4f}")
    else:
        print(f"  {name}: No data")

# Save confusion matrix and PR curve
print(f"\nConfusion matrix saved to: {OUT_DIR}/train/confusion_matrix.png")
print(f"PR curve saved to: {OUT_DIR}/train/PR_curve.png")

# Evaluate on own photos val subset only (if possible)
print("\nEvaluating on own photos val subset...")
# Note: This requires tracking which images came from own photos during merge
# If you need this, add tracking in CELL 3

# Verdict per class
print("\nCLASS VERDICTS:")
for i, name in enumerate(FINAL_CLASSES):
    if i < len(metrics.box.maps):
        map50 = metrics.box.maps[i]
        if map50 >= 0.8:
            verdict = "GOOD"
        elif map50 >= 0.5:
            verdict = "WEAK"
        else:
            verdict = "UNUSABLE"
        print(f"  {name}: {verdict} (mAP50 = {map50:.4f}, threshold: 0.8 good, 0.5 weak)")
    else:
        print(f"  {name}: No data")

# ==============================================================================
# ===== CELL 7: CONFIDENCE THRESHOLD SWEEP
# ==============================================================================
# Can fail if: Model file not found, evaluation takes too long

print("Sweeping confidence threshold from 0.15 to 0.6...")

thresholds = [0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60]
results_dict = {}

for conf in thresholds:
    metrics = best_model.val(conf=conf, split="val")
    results_dict[conf] = {
        'precision': metrics.box.mp,
        'recall': metrics.box.mr,
        'f1': 2 * metrics.box.mp * metrics.box.mr / (metrics.box.mp + metrics.box.mr + 1e-6)
    }
    print(f"  conf={conf:.2f}: precision={metrics.box.mp:.4f}, recall={metrics.box.mr:.4f}, f1={results_dict[conf]['f1']:.4f}")

# Recommend threshold that favors fewer false alarms
# Higher confidence = fewer false alarms (better precision)
best_conf = max(results_dict.keys(), key=lambda k: results_dict[k]['precision'])
print(f"\nRECOMMENDED CONFIDENCE THRESHOLD: {best_conf}")
print(f"This threshold gives precision={results_dict[best_conf]['precision']:.4f}")
print(f"Put this value in your Flutter code as the detection confidence threshold.")

# ==============================================================================
# ===== CELL 8: EXPORT
# ==============================================================================
# Can fail if: TensorFlow not installed, Ultralytics export error, insufficient memory

print("Exporting to TFLite float32...")

try:
    tflite_path = best_model.export(format="tflite", imgsz=IMG_SIZE, dynamic=False, half=False)
    print(f"TFLite export SUCCESS: {tflite_path}")
except Exception as e:
    print(f"TFLite export FAILED: {e}")
    print("\nFALLBACK: Exporting to ONNX...")
    try:
        onnx_path = best_model.export(format="onnx", imgsz=IMG_SIZE, dynamic=False, half=False)
        print(f"ONNX export SUCCESS: {onnx_path}")
        print("\nNext step to convert ONNX to TFLite:")
        print("1. Install TensorFlow: pip install tensorflow")
        print("2. Use tf.lite.TFLiteConverter.from_saved_model() or similar")
        print("3. Or use onnx-tf library: pip install onnx-tf")
    except Exception as e2:
        print(f"ONNX export also FAILED: {e2}")

# Optional float16 export
print("\nAttempting float16 export...")
try:
    tflite_fp16_path = best_model.export(format="tflite", imgsz=IMG_SIZE, dynamic=False, half=True)
    print(f"TFLite float16 export SUCCESS: {tflite_fp16_path}")
except Exception as e:
    print(f"TFLite float16 export FAILED: {e}")

# ==============================================================================
# ===== CELL 9: INSPECT TFLITE
# ==============================================================================
# Can fail if: TFLite file not found, TensorFlow not installed

import glob
import tensorflow as tf

# Find exported TFLite file
tflite_files = glob.glob(f"{OUT_DIR}/train/*.tflite")
if not tflite_files:
    tflite_files = glob.glob(f"{OUT_DIR}/**/*.tflite", recursive=True)

if tflite_files:
    tflite_path = tflite_files[0]
    print(f"Found TFLite file: {tflite_path}")
    
    # Load and inspect
    interpreter = tf.lite.Interpreter(model_path=tflite_path)
    interpreter.allocate_tensors()
    
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    print(f"\nINPUT DETAILS:")
    for detail in input_details:
        print(f"  Shape: {detail['shape']}")
        print(f"  Dtype: {detail['dtype']}")
        print(f"  Name: {detail['name']}")
    
    print(f"\nOUTPUT DETAILS:")
    for detail in output_details:
        print(f"  Shape: {detail['shape']}")
        print(f"  Dtype: {detail['dtype']}")
        print(f"  Name: {detail['name']}")
    
    # Explain output layout
    output_shape = output_details[0]['shape']
    print(f"\nOUTPUT LAYOUT EXPLANATION:")
    print(f"Output shape: {output_shape}")
    print(f"This is YOLOv8 format: [1, 4 + num_classes, num_anchors]")
    print(f"  - First 4 values: box coordinates (x, y, w, h)")
    print(f"  - Next {len(FINAL_CLASSES)} values: class scores for each class")
    print(f"  - Total channels: 4 + {len(FINAL_CLASSES)} = {4 + len(FINAL_CLASSES)}")
    print(f"  - Box format: Center-normalized (0-1), NOT pixels")
    print(f"  - Normalization: Input is 0-1 float, RGB order")
    print(f"  - Objectness: Included in YOLOv8 (no separate column)")
else:
    print("No TFLite file found to inspect")

# ==============================================================================
# ===== CELL 10: PARITY CHECK
# ==============================================================================
# Can fail if: Model file not found, TensorFlow not installed, out of memory

print("Running parity check between PyTorch and TFLite on 10 val images...")

if tflite_files:
    tflite_path = tflite_files[0]
    interpreter = tf.lite.Interpreter(model_path=tflite_path)
    interpreter.allocate_tensors()
    
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    # Get 10 random val images
    val_images = os.listdir(f"{merged_dir}/val/images")
    sample_images = random.sample(val_images, min(10, len(val_images)))
    
    # Use recommended confidence threshold
    conf_thres = best_conf
    
    mismatch_count = 0
    
    for img_file in sample_images:
        img_path = os.path.join(f"{merged_dir}/val/images", img_file)
        
        # PyTorch inference
        pytorch_results = best_model(img_path, conf=conf_thres)
        pytorch_count = len(pytorch_results[0].boxes)
        
        # TFLite inference (simplified - actual implementation requires preprocessing)
        # For now, just compare counts
        print(f"  {img_file}: PyTorch detections = {pytorch_count}")
        
        # Note: Full parity check requires:
        # 1. Preprocess image to match model input (resize, normalize)
        # 2. Run TFLite interpreter
        # 3. Postprocess output (NMS, decode boxes)
        # 4. Compare class and box coordinates
    
    print("\nNote: Full parity check requires implementing TFLite preprocessing/postprocessing")
    print("The counts above show PyTorch detections. Implement TFLite inference in Flutter to verify.")
else:
    print("No TFLite file found for parity check")

# ==============================================================================
# ===== CELL 11: SPEED TEST
# ==============================================================================
# Can fail if: TFLite file not found, TensorFlow not installed

if tflite_files:
    print("Testing TFLite inference speed on Colab CPU...")
    
    import time
    
    # Load a test image
    test_img_path = os.path.join(f"{merged_dir}/val/images", sample_images[0])
    img = Image.open(test_img_path)
    img = img.resize((IMG_SIZE, IMG_SIZE))
    img_array = tf.cast(img, tf.float32) / 255.0
    img_array = tf.expand_dims(img_array, axis=0)
    
    # Warm up
    for _ in range(5):
        interpreter.set_tensor(input_details[0]['index'], img_array)
        interpreter.invoke()
    
    # Time inference
    start = time.time()
    for _ in range(10):
        interpreter.set_tensor(input_details[0]['index'], img_array)
        interpreter.invoke()
    end = time.time()
    
    avg_time_ms = ((end - start) / 10) * 1000
    print(f"Average inference time: {avg_time_ms:.2f} ms per image")
    print("\nTHIS IS COLAB CPU SPEED, NOT PHONE SPEED!")
    print("Phone speed will be different (usually faster with GPU/NNAPI)")
else:
    print("No TFLite file found for speed test")

# ==============================================================================
# ===== CELL 12: FLUTTER HANDOFF
# ==============================================================================
# Can fail if: Insufficient storage, file permission errors

print("Creating Flutter handoff files...")

# Write labels.txt
labels_path = f"{OUT_DIR}/wayze_labels.txt"
with open(labels_path, 'w') as f:
    for i, name in enumerate(FINAL_CLASSES):
        f.write(f"{name}\n")

print(f"\nwayze_labels.txt:")
with open(labels_path, 'r') as f:
    content = f.read()
    print(content)

# Write model_facts.json
import json
model_facts = {
    "dataset_images_train": train_count,
    "dataset_images_val": val_count,
    "classes": FINAL_CLASSES,
    "epochs_run": EPOCHS,
    "map50": float(metrics.box.map50),
    "map50_95": float(metrics.box.map),
    "conf_threshold": float(best_conf),
    "input_size": IMG_SIZE,
    "trained_on": "Roboflow Universe + own photos",
    "note": "not tested with blind users"
}

facts_path = f"{OUT_DIR}/model_facts.json"
with open(facts_path, 'w') as f:
    json.dump(model_facts, f, indent=2)

print(f"\nmodel_facts.json:")
with open(facts_path, 'r') as f:
    print(f.read())

# Write decode_spec.md
decode_spec = f"""# YOLOv8n TFLite Decode Specification

## Output Tensor Shape
{output_shape}

## Output Layout
- Format: [1, 4 + num_classes, num_anchors]
- Channels: 4 + {len(FINAL_CLASSES)} = {4 + len(FINAL_CLASSES)}
- First 4 values: box coordinates (x, y, w, h) in CENTER-NORMALIZED format (0-1)
- Next {len(FINAL_CLASSES)} values: class scores for each class
- Objectness: Included in YOLOv8 (integrated into class scores)

## Box Format
- x, y: Center coordinates (normalized 0-1)
- w, h: Width and height (normalized 0-1)
- To convert to pixel coordinates:
  - x1 = (x - w/2) * image_width
  - y1 = (y - h/2) * image_height
  - x2 = (x + w/2) * image_width
  - y2 = (y + h/2) * image_height

## Normalization
- Input: 0-1 float, RGB order
- Preprocess: Resize to {IMG_SIZE}x{IMG_SIZE}, divide by 255

## Class Count
{len(FINAL_CLASSES)} classes: {FINAL_CLASSES}

## Recommended Thresholds
- Confidence: {best_conf}
- NMS IoU: 0.45 (standard for YOLO)
- Max detections: 300

## Class Order (same as labels.txt)
{FINAL_CLASSES}
"""

spec_path = f"{OUT_DIR}/decode_spec.md"
with open(spec_path, 'w') as f:
    f.write(decode_spec)

print(f"\ndecode_spec.md:")
with open(spec_path, 'r') as f:
    print(f.read())

# ==============================================================================
# ===== CELL 13: PACKAGE
# ==============================================================================
# Can fail if: Insufficient storage, file permission errors

print("Packaging files for download...")

# Rename TFLite to wayze.tflite
if tflite_files:
    import shutil
    shutil.copy(tflite_files[0], f"{OUT_DIR}/wayze.tflite")
    print(f"Copied TFLite to {OUT_DIR}/wayze.tflite")

# Create zip
import zipfile
zip_path = f"{OUT_DIR}/wayze_model.zip"
with zipfile.ZipFile(zip_path, 'w') as zipf:
    zipf.write(f"{OUT_DIR}/wayze.tflite", "wayze.tflite")
    zipf.write(labels_path, "wayze_labels.txt")
    zipf.write(facts_path, "model_facts.json")
    zipf.write(spec_path, "decode_spec.md")
    
    # Add results.csv if exists
    if os.path.exists(f"{OUT_DIR}/train/results.csv"):
        zipf.write(f"{OUT_DIR}/train/results.csv", "results.csv")
    
    # Add confusion matrix if exists
    cm_files = glob.glob(f"{OUT_DIR}/train/*confusion_matrix.png")
    if cm_files:
        zipf.write(cm_files[0], "confusion_matrix.png")
    
    # Add PR curve if exists
    pr_files = glob.glob(f"{OUT_DIR}/train/*PR_curve.png")
    if pr_files:
        zipf.write(pr_files[0], "PR_curve.png")

print(f"\nZip file created: {zip_path}")

# Trigger download
files.download(zip_path)

# ==============================================================================
# ===== CELL 14: FINAL SUMMARY
# ==============================================================================

print("""
================================================================================
FINAL SUMMARY FOR FLUTTER INTEGRATION
================================================================================

FILES TO COPY TO D:\\wayze\\assets\\models\\:
1. wayze.tflite (rename from wayze.tflite in the zip)
2. wayze_labels.txt (from the zip)
3. model_facts.json (from the zip)
4. decode_spec.md (from the zip - keep for reference)

WHAT TO TELL JUDGES (use ONLY real numbers from your run):
- Dataset size: """ + str(train_count + val_count) + """ images (""" + str(train_count) + """ train, """ + str(val_count) + """ val)
- Classes trained: """ + str(len(FINAL_CLASSES)) + """ (""" + ", ".join(FINAL_CLASSES) + """)
- Epochs run: """ + str(EPOCHS) + """
- mAP50: """ + str(f"{metrics.box.map50:.4f}") + """
- mAP50-95: """ + str(f"{metrics.box.map:.4f}") + """
- Recommended confidence threshold: """ + str(best_conf) + """
- Input size: """ + str(IMG_SIZE) + """x""" + str(IMG_SIZE) + """

KNOWN LIMITATIONS (be honest):
- Small dataset size (may overfit)
- Not tested in low-light conditions
- Trained on specific environments (may not generalize)
- Not tested with blind users (this is a hackathon prototype)
- Single floor only (no multi-floor navigation)

LICENCES:
- Ultralytics YOLOv8: AGPL-3.0 license
  - If you distribute your app, you must open-source your modifications
  - Check: https://github.com/ultralytics/ultralytics/blob/main/LICENSE
- Each Roboflow dataset has its own license
  - Check the license on each Roboflow Universe page before commercial use
  - Some datasets are CC-BY, some are CC0, some have restrictions

SAFETY DISCLAIMER:
This is a hackathon prototype. It is NOT:
- Medically certified
- Validated with blind users
- Production-ready for real navigation
Use it only for demonstration purposes.
================================================================================
""")
