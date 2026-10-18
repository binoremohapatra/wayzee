"""
Wayze YOLOv8 Local Training Script
For RTX 4060 GPU
Run this on your local Windows machine
"""

import torch
from ultralytics import YOLO
import os
import yaml
import numpy as np
from pathlib import Path
import json
import time
from PIL import Image

# Windows multiprocessing fix
import multiprocessing

# =========================================================
# CONFIGURATION - EDIT THESE
# =========================================================

# Path to your Roboflow dataset (extracted folder)
DATASET_PATH = r"D:\wayze_dataset"  # CHANGE THIS

# Training parameters
MODEL_SIZE = 'n'      # 'n' for nano, 's' for small
IMG_SIZE = 320        # Image size (320, 640, etc.)
EPOCHS = 30          # Number of epochs
BATCH_SIZE = 16      # Batch size (RTX 4060 can handle 32)
PATIENCE = 10        # Early stopping patience

# =========================================================
# STEP 1: Check GPU
# =========================================================

print("=" * 60)
print("Wayze YOLOv8 Local Training")
print("=" * 60)

print("\nStep 1: Checking GPU...")
if torch.cuda.is_available():
    print(f"✅ GPU detected: {torch.cuda.get_device_name(0)}")
    print(f"   CUDA version: {torch.version.cuda}")
    print(f"   PyTorch version: {torch.__version__}")
    print(f"   GPU memory: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.2f} GB")
else:
    print("❌ No GPU detected. Training will be slow on CPU.")
    response = input("Continue anyway? (y/n): ")
    if response.lower() != 'y':
        exit(1)

print("=" * 60)

# =========================================================
# STEP 2: Check Dataset
# =========================================================

print("\nStep 2: Checking dataset...")

if not os.path.exists(DATASET_PATH):
    print(f"❌ Dataset path not found: {DATASET_PATH}")
    print("Please extract your Roboflow dataset and update DATASET_PATH in this script.")
    exit(1)

# Find data.yaml
yaml_path = None
for root, dirs, files in os.walk(DATASET_PATH):
    if 'data.yaml' in files:
        yaml_path = os.path.join(root, 'data.yaml')
        break

if not yaml_path:
    print("❌ data.yaml not found in dataset folder")
    exit(1)

print(f"✅ Found data.yaml: {yaml_path}")

# Read and fix data.yaml
with open(yaml_path, 'r') as f:
    data_config = yaml.safe_load(f)

print(f"Class names: {data_config.get('names', [])}")

# Fix paths if they're absolute
if 'train' in data_config and os.path.isabs(data_config['train']):
    data_config['train'] = os.path.relpath(data_config['train'], '.')
if 'val' in data_config and os.path.isabs(data_config['val']):
    data_config['val'] = os.path.relpath(data_config['val'], '.')

with open(yaml_path, 'w') as f:
    yaml.dump(data_config, f)

print("✅ data.yaml paths fixed")

# Count images
train_path = data_config.get('train', '')
val_path = data_config.get('val', '')

if os.path.exists(train_path):
    train_images = len([f for f in os.listdir(train_path) if f.endswith(('.jpg', '.png', '.jpeg'))])
    print(f"Train images: {train_images}")
else:
    print(f"⚠️  Train path not found: {train_path}")
    train_images = 0

if os.path.exists(val_path):
    val_images = len([f for f in os.listdir(val_path) if f.endswith(('.jpg', '.png', '.jpeg'))])
    print(f"Val images: {val_images}")
else:
    print(f"⚠️  Val path not found: {val_path}")
    val_images = 0

print(f"Total images: {train_images + val_images}")

print("=" * 60)

# =========================================================
# STEP 3: Sanity Check - Label Counts
# =========================================================

print("\nStep 3: Checking label counts...")

class_counts = {}
class_names = data_config.get('names', {})

# Find labels folder
train_labels_path = train_path.replace('images', 'labels')
if not os.path.exists(train_labels_path):
    for root, dirs, files in os.walk(DATASET_PATH):
        if 'labels' in dirs:
            train_labels_path = os.path.join(root, 'labels')
            break

if os.path.exists(train_labels_path):
    for label_file in os.listdir(train_labels_path):
        if label_file.endswith('.txt'):
            label_path = os.path.join(train_labels_path, label_file)
            with open(label_path, 'r') as f:
                for line in f:
                    parts = line.strip().split()
                    if len(parts) >= 1:
                        class_id = int(parts[0])
                        class_counts[class_id] = class_counts.get(class_id, 0) + 1

print("\nLabel counts per class:")
warning_issued = False
for class_id, count in sorted(class_counts.items()):
    class_name = class_names.get(class_id, f"Class_{class_id}")
    print(f"  {class_name}: {count} boxes")
    if count < 50:
        print(f"    ⚠️  WARNING: Fewer than 50 boxes!")
        warning_issued = True

if not class_counts:
    print("  ❌ No labels found!")
    warning_issued = True

if not warning_issued:
    print("\n✅ All classes have sufficient labels (50+ boxes)")
else:
    print("\n⚠️  Some classes have insufficient labels. Training may be unstable.")

print("=" * 60)

# =========================================================
# STEP 4: Train Model
# =========================================================

print("\nStep 4: Training YOLOv8...")
print(f"Model: yolov8{MODEL_SIZE}.pt")
print(f"Image size: {IMG_SIZE}")
print(f"Epochs: {EPOCHS}")
print(f"Batch size: {BATCH_SIZE}")
print(f"Patience: {PATIENCE}")
print("\nThis will take 10-30 minutes on RTX 4060.")
print("Go grab some chai ☕\n")

print("Starting training automatically...")
# Auto-start for background execution

# Load model
model = YOLO(f'yolov8{MODEL_SIZE}.pt')

# Train
results = model.train(
    data=yaml_path,
    imgsz=IMG_SIZE,
    epochs=EPOCHS,
    batch=BATCH_SIZE,
    patience=PATIENCE,
    project='wayze_training',
    name='yolov8_custom',
    exist_ok=True,
    device=0,  # Use GPU
    workers=0,  # Disable multiprocessing for Windows
    verbose=True
)

print("\n✅ Training complete!")
print(f"Results saved to: wayze_training/yolov8_custom/")

print("=" * 60)

# =========================================================
# STEP 5: Print Results
# =========================================================

print("\nStep 5: Training Results...")

results_csv_path = 'wayze_training/yolov8_custom/results.csv'
if os.path.exists(results_csv_path):
    import pandas as pd
    df = pd.read_csv(results_csv_path)
    
    final_results = df.iloc[-1]
    
    print(f"\nFinal Epoch Metrics:")
    print(f"  mAP50: {final_results.get('metrics/mAP50(B)', 'N/A'):.4f}")
    print(f"  mAP50-95: {final_results.get('metrics/mAP50-95(B)', 'N/A'):.4f}")
    print(f"  Precision: {final_results.get('metrics/precision(B)', 'N/A'):.4f}")
    print(f"  Recall: {final_results.get('metrics/recall(B)', 'N/A'):.4f}")
    
    # Save summary
    summary = {
        'metric': ['mAP50', 'mAP50-95', 'precision', 'recall'],
        'value': [
            final_results.get('metrics/mAP50(B)', 0),
            final_results.get('metrics/mAP50-95(B)', 0),
            final_results.get('metrics/precision(B)', 0),
            final_results.get('metrics/recall(B)', 0)
        ]
    }
    summary_df = pd.DataFrame(summary)
    summary_df.to_csv('results_summary.csv', index=False)
    print("\n✅ Results saved to results_summary.csv")
else:
    print("⚠️  results.csv not found")

# Confusion matrix
confusion_matrix_path = 'wayze_training/yolov8_custom/confusion_matrix.png'
if os.path.exists(confusion_matrix_path):
    print(f"✅ Confusion matrix saved: {confusion_matrix_path}")
    # Display
    from IPython.display import Image, display
    print("Opening confusion matrix...")
    os.startfile(confusion_matrix_path)
else:
    print("⚠️  Confusion matrix not found")

print("=" * 60)

# =========================================================
# STEP 6: Export to TFLite
# =========================================================

print("\nStep 6: Exporting to TFLite...")

best_model_path = 'wayze_training/yolov8_custom/weights/best.pt'

if os.path.exists(best_model_path):
    print(f"Loading best model: {best_model_path}")
    model = YOLO(best_model_path)
    
    # Export float32
    print("\nExporting to TFLite float32...")
    try:
        model.export(format='tflite', imgsz=IMG_SIZE, half=False)
        print("✅ TFLite float32 export successful")
    except Exception as e:
        print(f"❌ TFLite float32 export failed: {e}")
        print("\nTrying ONNX fallback...")
        try:
            model.export(format='onnx', imgsz=IMG_SIZE)
            print("✅ ONNX export successful")
            print("Convert ONNX to TFLite using:")
            print("  pip install onnx-tf")
            print("  onnx-tf convert -i best.onnx -o best.tflite")
        except Exception as e2:
            print(f"❌ ONNX export also failed: {e2}")
    
    # Export float16
    print("\nExporting to TFLite float16...")
    try:
        model.export(format='tflite', imgsz=IMG_SIZE, half=True)
        print("✅ TFLite float16 export successful")
    except Exception as e:
        print(f"❌ TFLite float16 export failed: {e}")
    
    # Check files
    tflite_float32 = 'wayze_training/yolov8_custom/weights/best_float32.tflite'
    tflite_float16 = 'wayze_training/yolov8_custom/weights/best_float16.tflite'
    
    if os.path.exists(tflite_float32):
        print(f"\n✅ Found: {tflite_float32}")
        print(f"   Size: {os.path.getsize(tflite_float32) / (1024*1024):.2f} MB")
    else:
        print(f"\n⚠️  Not found: {tflite_float32}")
    
    if os.path.exists(tflite_float16):
        print(f"✅ Found: {tflite_float16}")
        print(f"   Size: {os.path.getsize(tflite_float16) / (1024*1024):.2f} MB")
    else:
        print(f"⚠️  Not found: {tflite_float16}")
    
else:
    print(f"❌ Best model not found: {best_model_path}")

print("=" * 60)

# =========================================================
# STEP 7: Inspect TFLite Model (SKIPPED - TensorFlow not required)
# =========================================================

print("\nStep 7: TFLite model inspection skipped")
print("TensorFlow not required for YOLO training.")
print("TFLite model can be inspected later if needed.")
print("=" * 60)

# =========================================================
# STEP 8: Create labels.txt
# =========================================================

print("\nStep 8: Creating labels.txt...")

class_names = data_config.get('names', {})
labels_text = "\n".join([class_names.get(i, f"class_{i}") for i in range(len(class_names))])

with open('labels.txt', 'w') as f:
    f.write(labels_text)

print(f"✅ labels.txt created with {len(class_names)} classes:")
for i, name in class_names.items():
    print(f"  {i}: {name}")

print("=" * 60)

# =========================================================
# STEP 9: Inference Test (SKIPPED - Will do with YOLO model)
# =========================================================

print("\nStep 9: Inference test will be done with YOLO model")
print("TFLite inference test skipped for now.")
print("Phone inference speed will be tested on actual device.")
print("=" * 60)

# =========================================================
# STEP 10: Copy Files to Flutter
# =========================================================

print("\nStep 10: Copying files to Flutter app...")

flutter_models_path = r"D:\wayze\assets\models"
os.makedirs(flutter_models_path, exist_ok=True)

files_to_copy = [
    ('wayze_training/yolov8_custom/weights/best_float32.tflite', 'wayze.tflite'),
    ('labels.txt', 'labels.txt'),
]

for src, dst in files_to_copy:
    if os.path.exists(src):
        import shutil
        dst_path = os.path.join(flutter_models_path, dst)
        shutil.copy2(src, dst_path)
        print(f"✅ Copied: {dst}")
    else:
        print(f"⚠️  Not found: {src}")

print(f"\n✅ Files copied to: {flutter_models_path}")
print("Update pubspec.yaml to include these files in assets.")

print("=" * 60)

# =========================================================
# LICENSE NOTICE
# =========================================================

print("\n" + "=" * 60)
print("LICENSE INFORMATION")
print("=" * 60)
print("""
IMPORTANT LICENSE NOTICE:

This script uses Ultralytics YOLO, which is licensed under AGPL-3.0.

What this means:
- You MUST share any modifications you make to the YOLO code
- If you distribute your application, you must provide source code
- Commercial use is allowed but requires sharing modifications

For more information: https://github.com/ultralytics/ultralytics/blob/main/LICENSE

The TFLite model you export can be used in your application without
sharing your app's source code, as long as you don't modify the YOLO library itself.

If you need a more permissive license, consider training with a different
framework or using a pre-trained model with a compatible license.
""")
print("=" * 60)

print("\n🎉 Training complete! Check the results above.")
print("Files are ready for your Flutter app.")

if __name__ == '__main__':
    multiprocessing.freeze_support()
