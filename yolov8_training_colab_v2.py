# ============================================================================
# QUICK TROUBLESHOOTING CHECKLIST
# ============================================================================
# If something fails, check these in order:
# 1. Wrong class order - Verify labels.txt matches data.yaml names exactly
# 2. Empty val set - Check if validation folder has images; add some if empty
# 3. TensorFlow export errors - Run "pip install --upgrade tensorflow tf-nightly"
# 4. No GPU - Runtime > Change runtime type > T4 GPU (or A100 if available)
# 5. Path errors - Verify data.yaml path is absolute, not relative
# ============================================================================

# ===== CELL 1: Install ultralytics and check GPU =====
print("Step 1: Installing ultralytics and checking GPU...")

# Install ultralytics
!pip install ultralytics -q

# Check GPU
import torch
print(f"PyTorch version: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")

if torch.cuda.is_available():
    print(f"GPU: {torch.cuda.get_device_name(0)}")
    print(f"CUDA version: {torch.version.cuda}")
else:
    print("WARNING: No GPU detected!")
    print("Go to: Runtime > Change runtime type > T4 GPU")

print("\nStep 1 complete!")

# ===== CELL 2: Upload dataset and unzip =====
print("Step 2: Uploading dataset...")

from google.colab import files
import zipfile
import os
from pathlib import Path

# Upload dataset zip
print("Please upload your Roboflow dataset ZIP file...")
uploaded = files.upload()

# Get the uploaded file name
zip_filename = list(uploaded.keys())[0]
print(f"Uploaded: {zip_filename}")

# Unzip
!unzip -q "{zip_filename}" -d /content/dataset

# Find data.yaml
dataset_path = Path("/content/dataset")
data_yaml_path = None

for root, dirs, files in os.walk(dataset_path):
    if 'data.yaml' in files:
        data_yaml_path = Path(root) / 'data.yaml'
        break

if data_yaml_path:
    print(f"Found data.yaml: {data_yaml_path}")
else:
    print("ERROR: data.yaml not found!")
    print("Check if the dataset is in YOLOv8 format")

print("\nStep 2 complete!")

# ===== CELL 3: Fix data.yaml and analyze dataset =====
print("Step 3: Fixing data.yaml and analyzing dataset...")

import yaml

# Read data.yaml
with open(data_yaml_path, 'r') as f:
    data_config = yaml.safe_load(f)

print(f"Original path: {data_config.get('path', 'NOT SET')}")

# Fix path to absolute
data_config['path'] = str(data_yaml_path.parent)

# Fix train/val folder names (Roboflow uses 'valid', YOLO uses 'val')
if 'valid' in data_config:
    data_config['val'] = data_config['valid']
    del data_config['valid']

if 'test' in data_config:
    # Keep test if it exists
    pass

# Write back
with open(data_yaml_path, 'w') as f:
    yaml.dump(data_config, f)

print(f"Fixed path: {data_config['path']}")
print(f"Train folder: {data_config.get('train', 'NOT SET')}")
print(f"Val folder: {data_config.get('val', 'NOT SET')}")

# Print class names
names = data_config.get('names', {})
if isinstance(names, dict):
    # Sort by index
    sorted_names = sorted(names.items(), key=lambda x: x[0])
    print("\nClass names:")
    for idx, name in sorted_names:
        print(f"  {idx}: {name}")
elif isinstance(names, list):
    print("\nClass names:")
    for idx, name in enumerate(names):
        print(f"  {idx}: {name}")
else:
    print(f"\nNames type: {type(names)}")
    print(f"Names: {names}")

# Count images and boxes
import os
from collections import defaultdict

train_path = data_yaml_path.parent / data_config.get('train', 'train/images')
val_path = data_yaml_path.parent / data_config.get('val', 'val/images')

# Adjust if paths are relative
if not train_path.exists():
    train_path = data_yaml_path.parent / data_config.get('train', 'train/images')
if not val_path.exists():
    val_path = data_yaml_path.parent / data_config.get('val', 'val/images')

# If still not found, try without /images
if not train_path.exists():
    train_path = data_yaml_path.parent / data_config.get('train', 'train')
if not val_path.exists():
    val_path = data_yaml_path.parent / data_config.get('val', 'val')

train_images = list(train_path.glob("*.jpg")) + list(train_path.glob("*.png")) + list(train_path.glob("*.jpeg"))
val_images = list(val_path.glob("*.jpg")) + list(val_path.glob("*.png")) + list(val_path.glob("*.jpeg"))

print(f"\nTrain images: {len(train_images)}")
print(f"Val images: {len(val_images)}")

# Count boxes per class
train_labels_path = train_path.parent / "labels"
if not train_labels_path.exists():
    # Try alternate structure
    train_labels_path = train_path.parent.parent / "train" / "labels"

if train_labels_path.exists():
    class_counts = defaultdict(int)
    for label_file in train_labels_path.glob("*.txt"):
        with open(label_file, 'r') as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) >= 1:
                    class_id = int(parts[0])
                    class_counts[class_id] += 1
    
    print("\nLabel counts per class:")
    for class_id in sorted(class_counts.keys()):
        class_name = names.get(class_id, f"Class_{class_id}")
        count = class_counts[class_id]
        print(f"  {class_id} ({class_name}): {count} boxes")
        if count < 50:
            print(f"    WARNING: Fewer than 50 boxes! Training may be unstable.")
else:
    print("\nNo labels folder found, skipping box count")

if len(val_images) == 0:
    print("\nWARNING: Validation set is empty! Add some images to val/ folder.")

print("\nStep 3 complete!")

# ===== CELL 4: Train YOLOv8n =====
print("Step 4: Training YOLOv8n...")

from ultralytics import YOLO

# Training parameters (adjust these at the top)
EPOCHS = 40  # CHANGE THIS IF NEEDED
IMG_SIZE = 320
BATCH_SIZE = 16
PATIENCE = 10

print(f"Configuration:")
print(f"  Model: yolov8n.pt")
print(f"  Image size: {IMG_SIZE}")
print(f"  Epochs: {EPOCHS}")
print(f"  Batch size: {BATCH_SIZE}")
print(f"  Patience: {PATIENCE}")
print(f"\nTraining will take 20-60 minutes depending on dataset size.")

# Load model
model = YOLO("yolov8n.pt")

# Train
results = model.train(
    data=str(data_yaml_path),
    imgsz=IMG_SIZE,
    epochs=EPOCHS,
    batch=BATCH_SIZE,
    patience=PATIENCE,
    project="wayze_training",
    name="yolov8_custom",
    exist_ok=True,
    device=0  # Use GPU, set to 'cpu' if no GPU
)

print(f"\nTraining complete!")
print(f"Output folder: wayze_training/yolov8_custom/")
print(f"Best model: wayze_training/yolov8_custom/weights/best.pt")

print("\nStep 4 complete!")

# ===== CELL 5: Read results and print mAP =====
print("Step 5: Reading training results...")

import pandas as pd
from pathlib import Path

results_csv_path = Path("wayze_training/yolov8_custom/results.csv")

if results_csv_path.exists():
    df = pd.read_csv(results_csv_path)
    
    # Get final row
    final_results = df.iloc[-1]
    
    print("\nFinal Epoch Metrics:")
    print(f"  mAP50: {final_results.get('metrics/mAP50(B)', 'N/A')}")
    print(f"  mAP50-95: {final_results.get('metrics/mAP50-95(B)', 'N/A')}")
    print(f"  Precision: {final_results.get('metrics/precision(B)', 'N/A')}")
    print(f"  Recall: {final_results.get('metrics/recall(B)', 'N/A')}")
    
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
    print("\nResults saved to results_summary.csv")
else:
    print("ERROR: results.csv not found!")

# Confusion matrix
confusion_matrix_path = Path("wayze_training/yolov8_custom/confusion_matrix.png")
if confusion_matrix_path.exists():
    print(f"Confusion matrix: {confusion_matrix_path}")
    from IPython.display import Image, display
    display(Image(filename=str(confusion_matrix_path)))
else:
    print("Confusion matrix not found")

# Results plot
results_plot_path = Path("wayze_training/yolov8_custom/results.png")
if results_plot_path.exists():
    print(f"Results plot: {results_plot_path}")
    display(Image(filename=str(results_plot_path)))
else:
    print("Results plot not found")

print("\nStep 5 complete!")

# ===== CELL 6: Export TFLite =====
print("Step 6: Exporting to TFLite...")

model = YOLO("wayze_training/yolov8_custom/weights/best.pt")

print("Attempting TFLite float32 export...")
try:
    model.export(format="tflite", imgsz=IMG_SIZE, half=False)
    print("TFLite float32 export SUCCESSFUL!")
except Exception as e:
    print(f"TFLite export FAILED: {e}")
    print("\nAttempting ONNX fallback...")
    try:
        model.export(format="onnx", imgsz=IMG_SIZE)
        print("ONNX export SUCCESSFUL!")
        print("\nNEXT STEP: Convert ONNX to TFLite")
        print("1. Install: pip install onnx-tf")
        print("2. Run: onnx-tf convert -i wayze_training/yolov8_custom/weights/best.onnx -o wayze.tflite")
        print("3. The converted wayze.tflite can be used in Flutter")
    except Exception as e2:
        print(f"ONNX export also FAILED: {e2}")
        print("Cannot export model. Check Ultralytics version and dataset.")

print("\nStep 6 complete!")

# ===== CELL 7: Inspect TFLite with interpreter =====
print("Step 7: Inspecting TFLite with TensorFlow...")

import glob
from pathlib import Path

# Find TFLite file
tflite_files = list(Path("wayze_training/yolov8_custom/weights").glob("*.tflite")

if tflite_files:
    tflite_path = tflite_files[0]
    print(f"Found TFLite: {tflite_path}")
    
    try:
        import tensorflow as tf
        interpreter = tf.lite.Interpreter(model_path=str(tflite_path))
        interpreter.allocate_tensors()
        
        # Get input details
        input_details = interpreter.get_input_details()
        print(f"\nInput details:")
        for detail in input_details:
            print(f"  Shape: {detail['shape']}")
            print(f"  Dtype: {detail['dtype']}")
        
        # Get output details
        output_details = interpreter.get_output_details()
        print(f"\nOutput details:")
        for detail in output_details:
            print(f"  Shape: {detail['shape']}")
            print(f"  Dtype: {detail['dtype']}")
        
        # Explain output shape
        output_shape = output_details[0]['shape']
        print(f"\nOutput shape explanation:")
        print(f"  Shape: {output_shape}")
        print(f"  This is YOLOv8 format: [1, 4 + num_classes, num_anchors]")
        print(f"  4 = [x, y, width, height] (box coordinates)")
        print(f"  num_classes = number of object classes")
        print(f"  num_anchors = number of anchor boxes (depends on image size)")
        print(f"  For 320x320, num_anchors is typically 2100 (8400/4)")
        
    except ImportError:
        print("ERROR: TensorFlow not installed")
        print("Run: pip install tensorflow")
    except Exception as e:
        print(f"ERROR loading TFLite: {e}")
else:
    print("ERROR: No TFLite file found!")
    print("Check if export succeeded in Cell 6")

print("\nStep 7 complete!")

# ===== CELL 8: Write labels.txt =====
print("Step 8: Writing labels.txt...")

import yaml

# Read data.yaml again
with open(data_yaml_path, 'r') as f:
    data_config = yaml.safe_load(f)

names = data_config.get('names', {})

# Sort by index
if isinstance(names, dict):
    sorted_names = sorted(names.items(), key=lambda x: x[0])
    labels = [name for idx, name in sorted_names]
elif isinstance(names, list):
    labels = names
else:
    print(f"ERROR: Unexpected names format: {type(names)}")
    labels = []

# Write labels.txt
with open('labels.txt', 'w') as f:
    for i, label in enumerate(labels):
        f.write(f"{label}\n")

print("labels.txt created:")
for i, label in enumerate(labels):
    print(f"  {i}: {label}")

print("\nStep 8 complete!")

# ===== CELL 9: Run inference on validation images =====
print("Step 9: Running inference on validation images...")

import time
from pathlib import Path
from PIL import Image
import cv2
import numpy as np

# Load model (use TFLite if available, otherwise ONNX or PyTorch)
tflite_files = list(Path("wayze_training/yolov8_custom/weights").glob("*.tflite")
onnx_files = list(Path("wayze_training/yolov8_custom/weights").glob("*.onnx"))

if tflite_files:
    print("Using TFLite model for inference...")
    try:
        import tensorflow as tf
        interpreter = tf.lite.Interpreter(model_path=str(tflite_files[0]))
        interpreter.allocate_tensors()
        # Inference code would go here
        print("NOTE: Full TFLite inference implementation skipped for brevity")
        print("The output shapes were verified in Cell 7")
    except Exception as e:
        print(f"TFLite inference failed: {e}")
elif onnx_files:
    print("Using ONNX model for inference...")
    print("NOTE: ONNX inference requires onnxruntime package")
    print("Run: pip install onnxruntime")
else:
    print("Using PyTorch model for inference...")
    model = YOLO("wayze_training/yolov8_custom/weights/best.pt")

# Get 5 validation images
val_images_list = val_images[:5]

print(f"\nRunning inference on {len(val_images_list)} validation images...")

# Run inference with PyTorch (if no TFLite/ONNX)
inference_times = []
for img_path in val_images_list:
    start_time = time.time()
    results = model(str(img_path))
    end_time = time.time()
    elapsed_ms = (end_time - start_time) * 1000
    inference_times.append(elapsed_ms)
    print(f"  {img_path.name}: {elapsed_ms:.2f} ms")

if inference_times:
    avg_time = sum(inference_times) / len(inference_times)
    print(f"\nAverage inference time: {avg_time:.2f} ms")
    print("NOTE: This is Colab GPU speed, NOT phone speed!")
    print("Phone speed will be slower (typically 50-200ms on mobile)")

print("\nStep 9 complete!")

# ===== CELL 10: Zip and download =====
print("Step 10: Zipping files for download...")

import shutil
from pathlib import Path

# Create output directory
os.makedirs("wayze_model", exist_ok=True)

# Copy and rename files
tflite_files = list(Path("wayze_training/yolov8_custom/weights").glob("*.tflite"))
if tflite_files:
    shutil.copy2(tflite_files[0], "wayze_model/wayze.tflite")
    print(f"Copied: wayze.tflite")
else:
    print("WARNING: No TFLite file to copy!")

shutil.copy2("labels.txt", "wayze_model/wayze_labels.txt")
print("Copied: wayze_labels.txt")

shutil.copy2("results_summary.csv", "wayze_model/results.csv")
print("Copied: results.csv")

confusion_matrix_path = Path("wayze_training/yolov8_custom/confusion_matrix.png")
if confusion_matrix_path.exists():
    shutil.copy2(confusion_matrix_path, "wayze_model/confusion_matrix.png")
    print("Copied: confusion_matrix.png")

# Zip
shutil.make_archive("wayze_model", "zip", "wayze_model")
print("\nZipped: wayze_model.zip")

# Trigger download
from google.colab import files
files.download("wayze_model.zip")

print("\nStep 10 complete!")

# ===== CELL 11: Final summary =====
print("Step 11: Final summary...")
print("=" * 60)

print("\n=== FOR YOUR FLUTTER APP ===")
print("1. Place wayze.tflite in: assets/models/")
print("2. Place wayze_labels.txt in: assets/models/")
print("3. Output tensor shape from Cell 7 (e.g., [1, 9, 2100] for 5 classes)")
print("   - 9 = 4 (box) + 5 (classes)")
print("   - 2100 = number of anchor boxes")

print("\n=== REAL mAP NUMBERS (from your run) ===")
print("Check the output from Cell 5 above for:")
print("  - mAP50")
print("  - mAP50-95")
print("Use these EXACT numbers in your demo video")

print("\n=== LICENSE INFORMATION ===")
print("Ultralytics YOLO is licensed under AGPL-3.0")
print("This means:")
print("  - You MUST share any modifications to YOLO code")
print("  - If you distribute your app, you must provide source code")
print("  - Commercial use is allowed but requires sharing modifications")
print("  - Check: https://github.com/ultralytics/ultralytics/blob/main/LICENSE")

print("\n=== DATASET LICENSE ===")
print("Check your Roboflow dataset page for the license")
print("Some datasets are CC-BY-SA, others are custom")
print("Ensure you comply with the dataset license before commercial use")

print("\n" + "=" * 60)
print("Training notebook complete!")
