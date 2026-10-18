"""
Organize Kaggle Door/Windows/Stairs dataset into YOLOv8 format
"""

import os
import shutil
import random
from pathlib import Path

# Dataset path
dataset_path = Path("D:/wayze/images")
output_path = Path("D:/wayze/door_stairs_dataset")

# Create output directories
train_images = output_path / "train" / "images"
train_labels = output_path / "train" / "labels"
val_images = output_path / "val" / "images"
val_labels = output_path / "val" / "labels"

for path in [train_images, train_labels, val_images, val_labels]:
    path.mkdir(parents=True, exist_ok=True)

# Get all image files
image_files = list(dataset_path.glob("*.jpg"))
print(f"Found {len(image_files)} images")

# Shuffle and split (80% train, 20% val)
random.shuffle(image_files)
split_idx = int(len(image_files) * 0.8)
train_files = image_files[:split_idx]
val_files = image_files[split_idx:]

print(f"Train: {len(train_files)} images")
print(f"Val: {len(val_files)} images")

# Copy files
print("Copying train files...")
for img_file in train_files:
    # Copy image
    shutil.copy2(img_file, train_images / img_file.name)
    
    # Copy label if exists
    label_file = img_file.with_suffix('.txt')
    if label_file.exists():
        shutil.copy2(label_file, train_labels / label_file.name)

print("Copying val files...")
for img_file in val_files:
    # Copy image
    shutil.copy2(img_file, val_images / img_file.name)
    
    # Copy label if exists
    label_file = img_file.with_suffix('.txt')
    if label_file.exists():
        shutil.copy2(label_file, val_labels / label_file.name)

print("Dataset organized!")
print(f"Output: {output_path}")

# Create data.yaml
yaml_content = f"""path: {output_path}
train: train/images
val: val/images

names:
  0: door
  1: stairs
  2: window
"""

yaml_path = output_path / "data.yaml"
with open(yaml_path, 'w') as f:
    f.write(yaml_content)

print(f"data.yaml created: {yaml_path}")
