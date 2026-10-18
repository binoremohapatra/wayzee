# Cell 1: Install ultralytics and check GPU
# =========================================================
# This cell installs the ultralytics package and checks if GPU is available

!pip install ultralytics

import torch
from ultralytics import YOLO
import os
import shutil
import yaml
import numpy as np
from pathlib import Path
import json
import time
from PIL import Image, ImageDraw, ImageFont
import matplotlib.pyplot as plt

# Check GPU availability
print("=" * 60)
print("GPU Check")
print("=" * 60)
if torch.cuda.is_available():
    print(f"✅ GPU available: {torch.cuda.get_device_name(0)}")
    print(f"   CUDA version: {torch.version.cuda}")
    print(f"   PyTorch version: {torch.__version__}")
else:
    print("⚠️  No GPU available. Training will be slow on CPU.")
print("=" * 60)


# Cell 2: Upload dataset and setup
# =========================================================
# Upload your Roboflow YOLOv8-format dataset zip here
# The script will unzip it and fix the data.yaml paths automatically

from google.colab import files

print("Please upload your Roboflow dataset zip file...")
uploaded = files.upload()

# Get the uploaded file name
dataset_zip = list(uploaded.keys())[0]
print(f"\n✅ Uploaded: {dataset_zip}")

# Unzip the dataset
print("\nUnzipping dataset...")
!unzip -q {dataset_zip}

# Find the extracted folder (usually the zip name without .zip)
dataset_folder = dataset_zip.replace('.zip', '')
print(f"✅ Dataset extracted to: {dataset_folder}")

# List contents
print("\nDataset structure:")
for root, dirs, files in os.walk(dataset_folder):
    level = root.replace(dataset_folder, '').count(os.sep)
    indent = ' ' * 2 * level
    print(f'{indent}{os.path.basename(root)}/')
    subindent = ' ' * 2 * (level + 1)
    for file in files[:5]:  # Show first 5 files
        print(f'{subindent}{file}')
    if len(files) > 5:
        print(f'{subindent}... and {len(files) - 5} more files')

# Find and fix data.yaml
print("\n" + "=" * 60)
print("Fixing data.yaml paths")
print("=" * 60)

yaml_path = None
for root, dirs, files in os.walk(dataset_folder):
    if 'data.yaml' in files:
        yaml_path = os.path.join(root, 'data.yaml')
        break

if yaml_path:
    print(f"Found data.yaml at: {yaml_path}")
    
    # Read the yaml
    with open(yaml_path, 'r') as f:
        data_config = yaml.safe_load(f)
    
    print(f"\nOriginal class names: {data_config.get('names', [])}")
    
    # Fix paths to be relative to the current directory
    if 'train' in data_config:
        original_train = data_config['train']
        if os.path.isabs(original_train):
            # If absolute path, make it relative
            data_config['train'] = os.path.relpath(original_train, '.')
        print(f"Train path: {data_config['train']}")
    
    if 'val' in data_config:
        original_val = data_config['val']
        if os.path.isabs(original_val):
            data_config['val'] = os.path.relpath(original_val, '.')
        print(f"Val path: {data_config['val']}")
    
    # Write back
    with open(yaml_path, 'w') as f:
        yaml.dump(data_config, f)
    
    print("✅ data.yaml paths fixed")
else:
    print("⚠️  data.yaml not found!")

# Count images in train and val
print("\n" + "=" * 60)
print("Dataset Statistics")
print("=" * 60)

train_path = data_config.get('train', '')
val_path = data_config.get('val', '')

if os.path.exists(train_path):
    train_images = len([f for f in os.listdir(train_path) if f.endswith(('.jpg', '.png', '.jpeg'))])
    print(f"Train images: {train_images}")
else:
    print(f"Train path not found: {train_path}")
    train_images = 0

if os.path.exists(val_path):
    val_images = len([f for f in os.listdir(val_path) if f.endswith(('.jpg', '.png', '.jpeg'))])
    print(f"Val images: {val_images}")
else:
    print(f"Val path not found: {val_path}")
    val_images = 0

print(f"Total images: {train_images + val_images}")
print(f"Class names: {data_config.get('names', [])}")
print("=" * 60)


# Cell 3: Sanity check - warn if any class has fewer than 50 boxes
# =========================================================
# This checks if your dataset has enough labels per class

print("=" * 60)
print("Label Count Sanity Check")
print("=" * 60)

# Count labels per class
class_counts = {}
class_names = data_config.get('names', {})

# Count from train labels
train_labels_path = train_path.replace('images', 'labels').replace('train', 'train')
if not os.path.exists(train_labels_path):
    # Try to find labels folder
    for root, dirs, files in os.walk(dataset_folder):
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
        print(f"    ⚠️  WARNING: Fewer than 50 boxes! Consider adding more data.")
        warning_issued = True

if not class_counts:
    print("  No labels found!")
    warning_issued = True

if not warning_issued:
    print("\n✅ All classes have sufficient labels (50+ boxes)")
else:
    print("\n⚠️  Some classes have insufficient labels. Training may be unstable.")

print("=" * 60)


# Cell 4: Train YOLOv8n
# =========================================================
# Training parameters - you can adjust these
# model: yolov8n.pt (nano model for speed)
# imgsz: 320 (smaller = faster, less accurate)
# epochs: 30 (can increase for better results)
# batch: 16 (adjust based on GPU memory)
# patience: 10 (early stopping if no improvement)

# Training parameters (YOU CAN EDIT THESE)
MODEL_SIZE = 'n'  # 'n' for nano, 's' for small, 'm' for medium
IMG_SIZE = 320    # Image size (320, 640, etc.)
EPOCHS = 30       # Number of training epochs
BATCH_SIZE = 16   # Batch size
PATIENCE = 10     # Early stopping patience

print("=" * 60)
print("Training Configuration")
print("=" * 60)
print(f"Model: yolov8{MODEL_SIZE}.pt")
print(f"Image size: {IMG_SIZE}")
print(f"Epochs: {EPOCHS}")
print(f"Batch size: {BATCH_SIZE}")
print(f"Patience: {PATIENCE}")
print(f"Dataset: {yaml_path}")
print("=" * 60)

# Load the model
model = YOLO(f'yolov8{MODEL_SIZE}.pt')

# Train
print("\nStarting training...")
print("This may take 10-30 minutes depending on GPU and dataset size.\n")

results = model.train(
    data=yaml_path,
    imgsz=IMG_SIZE,
    epochs=EPOCHS,
    batch=BATCH_SIZE,
    patience=PATIENCE,
    project='wayze_training',
    name='yolov8_custom',
    exist_ok=True,
    verbose=True
)

print("\n✅ Training complete!")
print(f"Results saved to: wayze_training/yolov8_custom/")


# Cell 5: Print final metrics and save results
# =========================================================
# This extracts the final mAP metrics and saves them to CSV

print("=" * 60)
print("Training Results")
print("=" * 60)

# Load the results.csv
results_csv_path = 'wayze_training/yolov8_custom/results.csv'
if os.path.exists(results_csv_path):
    import pandas as pd
    df = pd.read_csv(results_csv_path)
    
    # Get the last row (final epoch)
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

# Save confusion matrix if available
confusion_matrix_path = 'wayze_training/yolov8_custom/confusion_matrix.png'
if os.path.exists(confusion_matrix_path):
    print(f"✅ Confusion matrix saved to: {confusion_matrix_path}")
    # Display it
    from IPython.display import Image, display
    display(Image(filename=confusion_matrix_path))
else:
    print("⚠️  Confusion matrix not found")

print("=" * 60)


# Cell 6: Export to TFLite (float32 and float16)
# =========================================================
# This exports the trained model to TFLite format for Flutter

print("=" * 60)
print("TFLite Export")
print("=" * 60)

# Path to the best model
best_model_path = 'wayze_training/yolov8_custom/weights/best.pt'

if os.path.exists(best_model_path):
    print(f"Loading best model: {best_model_path}")
    model = YOLO(best_model_path)
    
    # Export to TFLite float32
    print("\nExporting to TFLite float32...")
    try:
        model.export(format='tflite', imgsz=IMG_SIZE, half=False)
        print("✅ TFLite float32 export successful")
    except Exception as e:
        print(f"❌ TFLite float32 export failed: {e}")
        print("\nFallback: Exporting to ONNX first...")
        try:
            model.export(format='onnx', imgsz=IMG_SIZE)
            print("✅ ONNX export successful")
            print("You can convert ONNX to TFLite using:")
            print("  onnx-tf convert -i best.onnx -o best.tflite")
        except Exception as e2:
            print(f"❌ ONNX export also failed: {e2}")
    
    # Export to TFLite float16
    print("\nExporting to TFLite float16...")
    try:
        model.export(format='tflite', imgsz=IMG_SIZE, half=True)
        print("✅ TFLite float16 export successful")
    except Exception as e:
        print(f"❌ TFLite float16 export failed: {e}")
    
    # Check if files were created
    tflite_float32 = 'wayze_training/yolov8_custom/weights/best_float32.tflite'
    tflite_float16 = 'wayze_training/yolov8_custom/weights/best_float16.tflite'
    
    if os.path.exists(tflite_float32):
        print(f"\n✅ Found: {tflite_float32}")
    else:
        print(f"\n⚠️  Not found: {tflite_float32}")
    
    if os.path.exists(tflite_float16):
        print(f"✅ Found: {tflite_float16}")
    else:
        print(f"⚠️  Not found: {tflite_float16}")
    
else:
    print(f"❌ Best model not found: {best_model_path}")

print("=" * 60)


# Cell 7: Inspect TFLite model and print tensor shapes
# =========================================================
# This loads the TFLite model and prints input/output shapes

print("=" * 60)
print("TFLite Model Inspection")
print("=" * 60)

import tensorflow as tf

# Try to load float32 model
tflite_path = 'wayze_training/yolov8_custom/weights/best_float32.tflite'
if not os.path.exists(tflite_path):
    tflite_path = 'wayze_training/yolov8_custom/weights/best.tflite'

if os.path.exists(tflite_path):
    print(f"Loading: {tflite_path}")
    
    # Load the TFLite model
    interpreter = tf.lite.Interpreter(model_path=tflite_path)
    interpreter.allocate_tensors()
    
    # Get input details
    print("\nInput Details:")
    for i, input_detail in enumerate(interpreter.get_input_details()):
        print(f"  Input {i}:")
        print(f"    Name: {input_detail['name']}")
        print(f"    Shape: {input_detail['shape']}")
        print(f"    Dtype: {input_detail['dtype']}")
        print(f"    Quantization: {input_detail.get('quantization', None)}")
    
    # Get output details
    print("\nOutput Details:")
    for i, output_detail in enumerate(interpreter.get_output_details()):
        print(f"  Output {i}:")
        print(f"    Name: {output_detail['name']}")
        print(f"    Shape: {output_detail['shape']}")
        print(f"    Dtype: {output_detail['dtype']}")
        print(f"    Quantization: {output_detail.get('quantization', None)}")
    
    print("\n✅ Model inspection complete")
else:
    print(f"❌ TFLite model not found: {tflite_path}")

print("=" * 60)


# Cell 8: Create labels.txt
# =========================================================
# This creates a labels.txt file with class names in order

print("=" * 60)
print("Creating labels.txt")
print("=" * 60)

class_names = data_config.get('names', {})
labels_text = "\n".join([class_names.get(i, f"class_{i}") for i in range(len(class_names))])

with open('labels.txt', 'w') as f:
    f.write(labels_text)

print(f"✅ labels.txt created with {len(class_names)} classes:")
for i, name in class_names.items():
    print(f"  {i}: {name}")

print("=" * 60)


# Cell 9: Run inference on validation images with TFLite
# =========================================================
# This tests the exported TFLite model on 5 validation images

print("=" * 60)
print("TFLite Inference Test")
print("=" * 60)

# Load TFLite model
tflite_path = 'wayze_training/yolov8_custom/weights/best_float32.tflite'
if not os.path.exists(tflite_path):
    tflite_path = 'wayze_training/yolov8_custom/weights/best.tflite'

if os.path.exists(tflite_path):
    interpreter = tf.lite.Interpreter(model_path=tflite_path)
    interpreter.allocate_tensors()
    
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    input_shape = input_details[0]['shape']
    print(f"Input shape: {input_shape}")
    print(f"Input dtype: {input_details[0]['dtype']}")
    
    # Get 5 validation images
    val_images = []
    if os.path.exists(val_path):
        all_images = [f for f in os.listdir(val_path) if f.endswith(('.jpg', '.png', '.jpeg'))]
        val_images = all_images[:5]
    
    if not val_images:
        print("⚠️  No validation images found")
    else:
        print(f"\nTesting on {len(val_images)} validation images...")
        print("Running on Colab CPU/GPU (NOT phone speed)")
        print("-" * 60)
        
        inference_times = []
        
        for img_name in val_images:
            img_path = os.path.join(val_path, img_name)
            
            # Load and preprocess image
            img = Image.open(img_path).convert('RGB')
            img_resized = img.resize((input_shape[1], input_shape[2]))
            img_array = np.array(img_resized, dtype=np.float32) / 255.0
            img_array = np.expand_dims(img_array, axis=0)
            
            # Run inference
            start_time = time.time()
            interpreter.set_tensor(input_details[0]['index'], img_array)
            interpreter.invoke()
            output_data = interpreter.get_tensor(output_details[0]['index'])
            end_time = time.time()
            
            inference_time = (end_time - start_time) * 1000  # Convert to ms
            inference_times.append(inference_time)
            
            print(f"{img_name}: {inference_time:.2f} ms")
        
        if inference_times:
            avg_time = np.mean(inference_times)
            print("-" * 60)
            print(f"Average inference time: {avg_time:.2f} ms")
            print(f"Min: {min(inference_times):.2f} ms, Max: {max(inference_times):.2f} ms")
            print("\nNote: This is Colab CPU/GPU speed, NOT phone speed.")
            print("Phone will be slower (estimated 100-300ms for TFLite on Android)")
        
        print("\n✅ Inference test complete")
else:
    print(f"❌ TFLite model not found: {tflite_path}")

print("=" * 60)


# Cell 10: Zip files for download
# =========================================================
# This zips the TFLite models, labels, and results for download

print("=" * 60)
print("Zipping Files for Download")
print("=" * 60)

# Files to zip
files_to_zip = [
    'wayze_training/yolov8_custom/weights/best_float32.tflite',
    'wayze_training/yolov8_custom/weights/best_float16.tflite',
    'labels.txt',
    'results_summary.csv'
]

# Filter existing files
existing_files = [f for f in files_to_zip if os.path.exists(f)]

if not existing_files:
    print("❌ No files found to zip")
else:
    print(f"Zipping {len(existing_files)} files...")
    
    import zipfile
    zip_filename = 'wayze_tflite_export.zip'
    
    with zipfile.ZipFile(zip_filename, 'w') as zipf:
        for file in existing_files:
            if os.path.exists(file):
                zipf.write(file, os.path.basename(file))
                print(f"  Added: {os.path.basename(file)}")
    
    print(f"\n✅ Created: {zip_filename}")
    print(f"Size: {os.path.getsize(zip_filename) / (1024*1024):.2f} MB")
    
    # Download
    from google.colab import files
    files.download(zip_filename)

print("=" * 60)


# Cell 11: License Information
# =========================================================
print("=" * 60)
print("License Information")
print("=" * 60)
print("""
IMPORTANT LICENSE NOTICE:

This notebook uses Ultralytics YOLO, which is licensed under AGPL-3.0.

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
