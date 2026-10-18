# Local Training Guide for RTX 4060

## Prerequisites

1. **Python 3.8+** installed
2. **CUDA** installed (for RTX 4060)
3. **PyTorch** with CUDA support

## Installation

```bash
# Install PyTorch with CUDA support (for RTX 4060)
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# Install ultralytics
pip install ultralytics

# Install TensorFlow (for TFLite inspection)
pip install tensorflow

# Install pandas (for results)
pip install pandas
```

## How to Use

1. **Download your Roboflow dataset** (YOLOv8 format)
2. **Extract it** to a folder, e.g., `D:\datasets\wayze_dataset`
3. **Edit `train_local.py`** and update this line:
   ```python
   DATASET_PATH = r"D:\datasets\wayze_dataset"  # CHANGE THIS
   ```
4. **Run the script:**
   ```bash
   python train_local.py
   ```

## What the Script Does

1. ✅ Checks RTX 4060 GPU
2. ✅ Loads and fixes dataset paths
3. ✅ Checks label counts (warns if <50 per class)
4. ✅ Trains YOLOv8n (320px, 30 epochs)
5. ✅ Prints mAP50 and mAP50-95
6. ✅ Exports to TFLite (float32 and float16)
7. ✅ Inspects TFLite tensor shapes
8. ✅ Creates labels.txt
9. ✅ Tests inference on 5 validation images
10. ✅ Copies files to Flutter `assets/models/`

## Training Time on RTX 4060

- **Small dataset (<100 images):** 5-10 minutes
- **Medium dataset (100-500 images):** 10-20 minutes
- **Large dataset (500+ images):** 20-40 minutes

## Configuration Options

Edit these in `train_local.py`:

```python
MODEL_SIZE = 'n'      # 'n' for nano, 's' for small
IMG_SIZE = 320        # 320 (faster) or 640 (more accurate)
EPOCHS = 30          # Increase for better results
BATCH_SIZE = 16      # RTX 4060 can handle 32
PATIENCE = 10        # Early stopping
```

## Expected Output

After training, you'll get:
- `wayze_training/yolov8_custom/weights/best_float32.tflite`
- `wayze_training/yolov8_custom/weights/best_float16.tflite`
- `labels.txt`
- `results_summary.csv`
- Files automatically copied to `D:\wayze\assets\models\`

## Troubleshooting

### "No GPU detected"
- Install CUDA: https://developer.nvidia.com/cuda-downloads
- Install PyTorch with CUDA (see installation above)
- Check `nvidia-smi` in command prompt

### "Dataset path not found"
- Extract Roboflow dataset first
- Update `DATASET_PATH` in script
- Make sure path uses raw string: `r"D:\path\to\dataset"`

### "TFLite export failed"
- Script tries ONNX fallback automatically
- If both fail, use command line:
  ```bash
  cd wayze_training/yolov8_custom/weights
  yolo export model=best.pt format=tflite imgsz=320
  ```

### "Out of memory"
- Reduce `BATCH_SIZE` to 8 or 4
- Reduce `IMG_SIZE` to 320 (if using 640)

## Speed Comparison

**RTX 4060 (local):**
- Training: 10-30x faster than Colab
- Inference: ~5-10ms per image (TensorFlow)

**Colab (free tier):**
- Training: Slower, time limits
- Inference: ~20-50ms per image

**Phone (Android):**
- Inference: ~100-300ms per image (TFLite)
- Much slower than RTX 4060

## License

AGPL-3.0 for Ultralytics YOLO (must share modifications)
