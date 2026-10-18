#!/usr/bin/env python3
"""
Wayze YOLOv8n Training & INT8 Post-Training Quantization (PTQ) Pipeline
======================================================================
Trains an INT8-quantized YOLOv8n model optimized for budget Android CPU (XNNPACK).

Pipeline:
1. Validates dataset config and class labels.
2. Fine-tunes YOLOv8n on 320x320 resolution with mobile-tuned augmentations.
3. Exports both FP32 and fully-quantized INT8 TFLite models using a representative
   dataset calibration loop.
4. Generates matching labels.txt with exact class ordering.
5. Emits model_summary.json recording all training metadata and validation metrics.

Requirements:
    pip install ultralytics torch torchvision

Usage:
    python scripts/train_and_export_yolov8.py --data door_stairs_dataset/data.yaml --epochs 50 --batch 16
"""

import os
import sys
import argparse
import json
import shutil
from pathlib import Path

def train_and_export(
    data_yaml: str,
    epochs: int = 50,
    batch_size: int = 16,
    img_size: int = 320,
    base_model: str = "yolov8n.pt",
    output_dir: str = "android/app/src/main/assets/models",
    device: str = "0"
):
    print("\n" + "=" * 65)
    print("      WAYZE YOLOV8n TRAINING & INT8 QUANTIZATION PIPELINE")
    print("=" * 65)

    try:
        from ultralytics import YOLO
    except ImportError:
        print("[!] Error: 'ultralytics' package not installed.")
        print("    Install via: pip install ultralytics torch torchvision")
        sys.exit(1)

    data_path = Path(data_yaml).resolve()
    if not data_path.exists():
        print(f"[!] Error: Data config not found: {data_path}")
        sys.exit(1)

    print(f"[*] Base Model:       {base_model}")
    print(f"[*] Dataset Config:   {data_path}")
    print(f"[*] Image Size:       {img_size}x{img_size}")
    print(f"[*] Epochs:           {epochs}")
    print(f"[*] Batch Size:       {batch_size}")
    print(f"[*] Output Target:    {output_dir}")

    # 1. Initialize Model
    model = YOLO(base_model)

    # 2. Train with mobile-tuned hyperparameters
    print("\n[*] Starting training loop...")
    results = model.train(
        data=str(data_path),
        epochs=epochs,
        batch=batch_size,
        imgsz=img_size,
        device=device,
        optimizer="AdamW",
        lr0=0.001,
        lrf=0.01,
        cos_lr=True,
        warmup_epochs=3,
        # Augmentation tuning for indoor navigation:
        mosaic=0.5,        # moderate mosaic
        mixup=0.0,         # disable mixup to maintain crisp hazard edges
        fliplr=0.5,        # horizontal flip
        flipud=0.0,        # NEVER flip upside down (stairs orientation is gravity-dependent!)
        save=True,
        verbose=True
    )

    # 3. Validation Metrics
    print("\n[*] Evaluating final weights on validation split...")
    metrics = model.val(data=str(data_path), imgsz=img_size)

    map50 = float(metrics.box.map50)
    map50_95 = float(metrics.box.map)
    mp = float(metrics.box.mp)
    mr = float(metrics.box.mr)

    print(f"\n[+] Validation Metrics:")
    print(f"  • mAP@0.50:       {map50:.4f}")
    print(f"  • mAP@0.50:0.95:  {map50_95:.4f}")
    print(f"  • Mean Precision: {mp:.4f}")
    print(f"  • Mean Recall:    {mr:.4f}")

    # 4. Export FP32 TFLite
    print("\n[*] Exporting FP32 TFLite...")
    fp32_path = model.export(format="tflite", imgsz=img_size, int8=False)
    print(f"  ✓ Exported FP32: {fp32_path}")

    # 5. Export INT8 Quantized TFLite (Post-Training Quantization with calibration)
    print("\n[*] Exporting INT8 Quantized TFLite (PTQ calibration)...")
    try:
        int8_path = model.export(
            format="tflite",
            imgsz=img_size,
            int8=True,
            data=str(data_path)
        )
        print(f"  ✓ Exported INT8: {int8_path}")
    except Exception as e:
        print(f"[!] Warning: INT8 export via ultralytics raised: {e}")
        print("    Falling back to standard export.")
        int8_path = fp32_path

    # 6. Deploy to Android assets target directory
    target_dir = Path(output_dir)
    target_dir.mkdir(parents=True, exist_ok=True)

    dest_model = target_dir / "wayze_v1.tflite"
    source_model = Path(int8_path) if Path(int8_path).exists() else Path(fp32_path)
    shutil.copyfile(source_model, dest_model)
    print(f"\n[+] Deployed model to: {dest_model} ({dest_model.stat().st_size / 1024 / 1024:.2f} MB)")

    # 7. Write exact labels.txt
    labels_file = target_dir / "labels.txt"
    class_names = [model.names[i] for i in sorted(model.names.keys())]
    with open(labels_file, "w", encoding="utf-8") as lf:
        for name in class_names:
            lf.write(f"{name}\n")
    print(f"[+] Written labels.txt to: {labels_file} ({len(class_names)} classes: {class_names})")

    # 8. Record model summary
    summary = {
        "model_file": str(dest_model.name),
        "input_size": img_size,
        "input_shape": [1, img_size, img_size, 3],
        "output_shape": [1, 4 + len(class_names), 2100],
        "classes": class_names,
        "epochs": epochs,
        "metrics": {
            "map50": map50,
            "map50_95": map50_95,
            "precision": mp,
            "recall": mr
        },
        "quantization": "INT8" if "int8" in str(source_model).lower() else "FP32",
        "recommended_confidence": 0.45,
        "recommended_nms_iou": 0.45,
        "verified_on_device": False,
        "note": "Metrics reflect offline validation split only. Real-device hardware latency and battery drain are UNVERIFIED."
    }

    summary_file = target_dir / "model_facts.json"
    with open(summary_file, "w", encoding="utf-8") as sf:
        json.dump(summary, sf, indent=2)
    print(f"[+] Written model facts to: {summary_file}")
    print("\n" + "=" * 65)
    print("      TRAINING & EXPORT PIPELINE COMPLETE")
    print("=" * 65)

def main():
    parser = argparse.ArgumentParser(description="Train and export INT8 YOLOv8 model for Wayze.")
    parser.add_argument("--data", type=str, default="door_stairs_dataset/data.yaml", help="Path to data.yaml")
    parser.add_argument("--epochs", type=int, default=50, help="Number of training epochs")
    parser.add_argument("--batch", type=int, default=16, help="Batch size")
    parser.add_argument("--imgsz", type=int, default=320, help="Image size (320 or 416)")
    parser.add_argument("--base", type=str, default="yolov8n.pt", help="Pretrained base model")
    parser.add_argument("--output_dir", type=str, default="android/app/src/main/assets/models", help="Target assets directory")
    parser.add_argument("--device", type=str, default="cpu", help="Device (cpu, 0, mps)")
    args = parser.parse_args()

    train_and_export(
        data_yaml=args.data,
        epochs=args.epochs,
        batch_size=args.batch,
        img_size=args.imgsz,
        base_model=args.base,
        output_dir=args.output_dir,
        device=args.device
    )

if __name__ == "__main__":
    main()
