"""
Generate sample dataset for Wayze YOLOv8 training
Creates placeholder images and labels for testing
"""

import os
import json
from PIL import Image, ImageDraw
import yaml

# Dataset path
DATASET_PATH = r"D:\wayze_dataset"

# Classes for Wayze
CLASSES = {
    0: "door",
    1: "stairs",
    2: "glass_door",
    3: "pillar",
    4: "wet_floor_sign"
}

# Create sample images with colored rectangles
def create_sample_image(image_path, class_id, label_id):
    """Create a sample image with a colored rectangle"""
    img = Image.new('RGB', (320, 320), color='black')
    draw = ImageDraw.Draw(img)

    # Color per class
    colors = {
        0: (255, 0, 0),      # door - red
        1: (0, 255, 0),      # stairs - green
        2: (0, 0, 255),      # glass_door - blue
        3: (255, 255, 0),    # pillar - yellow
        4: (255, 0, 255),    # wet_floor_sign - magenta
    }

    color = colors.get(class_id, (255, 255, 255))

    # Draw rectangle in center
    x1, y1 = 80, 80
    x2, y2 = 240, 240
    draw.rectangle([x1, y1, x2, y2], fill=color, outline='white', width=2)

    # Save image
    img.save(image_path)

    # Create YOLO format label (normalized coordinates)
    label_path = image_path.replace('.jpg', '.txt').replace('images', 'labels')

    # Normalize coordinates (0-1)
    x_center = (x1 + x2) / 2 / 320
    y_center = (y1 + y2) / 2 / 320
    width = (x2 - x1) / 320
    height = (y2 - y1) / 320

    with open(label_path, 'w') as f:
        f.write(f"{class_id} {x_center} {y_center} {width} {height}\n")

# Generate training images
print("Generating training images...")
for i in range(50):  # 50 training images
    class_id = i % len(CLASSES)
    image_path = os.path.join(DATASET_PATH, 'train', 'images', f'train_{i:03d}.jpg')
    create_sample_image(image_path, class_id, i)

print(f"[OK] Created 50 training images")

# Generate validation images
print("Generating validation images...")
for i in range(10):  # 10 validation images
    class_id = i % len(CLASSES)
    image_path = os.path.join(DATASET_PATH, 'val', 'images', f'val_{i:03d}.jpg')
    create_sample_image(image_path, class_id, i)

print(f"[OK] Created 10 validation images")

# Create data.yaml
print("Creating data.yaml...")
data_yaml = {
    'path': DATASET_PATH,
    'train': os.path.join(DATASET_PATH, 'train', 'images'),
    'val': os.path.join(DATASET_PATH, 'val', 'images'),
    'names': CLASSES
}

with open(os.path.join(DATASET_PATH, 'data.yaml'), 'w') as f:
    yaml.dump(data_yaml, f)

print(f"[OK] Created data.yaml")

print("\n" + "=" * 60)
print("Sample Dataset Created!")
print("=" * 60)
print(f"Location: {DATASET_PATH}")
print(f"Train images: 50")
print(f"Val images: 10")
print(f"Classes: {list(CLASSES.values())}")
print("\nNow update train_local.py:")
print(f'DATASET_PATH = r"{DATASET_PATH}"')
print("\nThen run: python train_local.py")
print("=" * 60)
