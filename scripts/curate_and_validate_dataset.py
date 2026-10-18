#!/usr/bin/env python3
"""
Wayze Dataset Curation & Validation Script
==========================================
Audits and validates YOLO format datasets for the Wayze obstacle & hazard detection model.
Performs:
1. File integrity checks (corrupted JPEGs/PNGs, missing label files).
2. Annotation boundary validation (normalized [0, 1] ranges, non-empty boxes).
3. Class distribution analysis (identifies underrepresented hazard classes like stairs/drop-off).
4. Data Contamination / Leakage Audit: Identifies identical images (by SHA-256 hash)
   shared between train, val, and test splits.
5. Auto-generates clean data.yaml.

Usage:
    python scripts/curate_and_validate_dataset.py --dataset_dir /path/to/dataset --classes door,stairs,person,obstacle
"""

import os
import sys
import argparse
import hashlib
import json
from pathlib import Path
from collections import defaultdict
from typing import Dict, List, Set, Tuple

try:
    from PIL import Image
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

def compute_file_hash(filepath: Path) -> str:
    """Computes SHA-256 hash of a file."""
    hasher = hashlib.sha256()
    with open(filepath, 'rb') as f:
        while chunk := f.read(65536):
            hasher.update(chunk)
    return hasher.hexdigest()

def validate_bbox(line: str, line_no: int, num_classes: int) -> Tuple[bool, str]:
    """Validates a single YOLO bounding box line."""
    parts = line.strip().split()
    if len(parts) < 5:
        return False, f"Line {line_no}: Invalid format, expected >= 5 values, got {len(parts)}"
    
    try:
        class_idx = int(parts[0])
        cx, cy, w, h = map(float, parts[1:5])
    except ValueError as e:
        return False, f"Line {line_no}: Non-numeric value in annotation: {e}"

    if class_idx < 0 or (num_classes > 0 and class_idx >= num_classes):
        return False, f"Line {line_no}: Class index {class_idx} out of range [0, {num_classes-1}]"

    if not (0.0 <= cx <= 1.0 and 0.0 <= cy <= 1.0):
        return False, f"Line {line_no}: Center coordinates ({cx}, {cy}) outside [0.0, 1.0]"

    if not (0.0 < w <= 1.0 and 0.0 < h <= 1.0):
        return False, f"Line {line_no}: Dimensions ({w}, {h}) invalid (must be in (0.0, 1.0])"

    return True, ""

def audit_dataset(dataset_dir: Path, class_names: List[str]) -> Dict:
    print(f"\n[*] Auditing dataset directory: {dataset_dir}")
    report = {
        "dataset_path": str(dataset_dir),
        "splits": {},
        "class_distribution": defaultdict(int),
        "split_class_distribution": defaultdict(lambda: defaultdict(int)),
        "data_leakage": {
            "train_val_overlap": [],
            "train_test_overlap": [],
            "val_test_overlap": []
        },
        "corrupted_images": [],
        "invalid_annotations": [],
        "missing_labels": [],
        "unlabeled_images": []
    }

    # Track file hashes per split: hash -> List[filepath]
    split_hashes: Dict[str, Dict[str, Path]] = {
        "train": {},
        "val": {},
        "test": {}
    }

    image_extensions = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}

    for split in ["train", "val", "test"]:
        split_dir = dataset_dir / split
        if not split_dir.exists():
            continue

        images_dir = split_dir / "images" if (split_dir / "images").exists() else split_dir
        labels_dir = split_dir / "labels" if (split_dir / "labels").exists() else split_dir

        image_files = [f for f in images_dir.rglob("*") if f.suffix.lower() in image_extensions]
        report["splits"][split] = {
            "image_count": len(image_files),
            "label_count": 0,
            "images_dir": str(images_dir),
            "labels_dir": str(labels_dir)
        }

        print(f"  --> Scanning split '{split}': {len(image_files)} images found...")

        for img_path in image_files:
            # 1. Verify image integrity
            if HAS_PIL:
                try:
                    with Image.open(img_path) as img:
                        img.verify()
                except Exception as e:
                    report["corrupted_images"].append({"file": str(img_path), "error": str(e)})
                    continue

            # 2. Compute hash for leakage check
            fhash = compute_file_hash(img_path)
            split_hashes[split][fhash] = img_path

            # 3. Locate corresponding label file
            rel_path = img_path.relative_to(images_dir)
            label_path = labels_dir / rel_path.with_suffix(".txt")

            if not label_path.exists():
                report["missing_labels"].append(str(img_path))
                continue

            # 4. Parse annotations
            try:
                with open(label_path, "r", encoding="utf-8") as lf:
                    lines = [line.strip() for line in lf if line.strip()]
            except Exception as e:
                report["invalid_annotations"].append({"file": str(label_path), "error": str(e)})
                continue

            if not lines:
                report["unlabeled_images"].append(str(img_path))
                continue

            report["splits"][split]["label_count"] += 1

            for idx, line in enumerate(lines, 1):
                valid, msg = validate_bbox(line, idx, len(class_names))
                if not valid:
                    report["invalid_annotations"].append({"file": str(label_path), "error": msg})
                else:
                    class_id = int(line.split()[0])
                    class_name = class_names[class_id] if class_id < len(class_names) else f"class_{class_id}"
                    report["class_distribution"][class_name] += 1
                    report["split_class_distribution"][split][class_name] += 1

    # 5. Cross-split data leakage detection
    train_hashes = set(split_hashes["train"].keys())
    val_hashes = set(split_hashes["val"].keys())
    test_hashes = set(split_hashes["test"].keys())

    train_val_overlap = train_hashes.intersection(val_hashes)
    for h in train_val_overlap:
        report["data_leakage"]["train_val_overlap"].append({
            "hash": h,
            "train_file": str(split_hashes["train"][h]),
            "val_file": str(split_hashes["val"][h])
        })

    train_test_overlap = train_hashes.intersection(test_hashes)
    for h in train_test_overlap:
        report["data_leakage"]["train_test_overlap"].append({
            "hash": h,
            "train_file": str(split_hashes["train"][h]),
            "test_file": str(split_hashes["test"][h])
        })

    val_test_overlap = val_hashes.intersection(test_hashes)
    for h in val_test_overlap:
        report["data_leakage"]["val_test_overlap"].append({
            "hash": h,
            "val_file": str(split_hashes["val"][h]),
            "test_file": str(split_hashes["test"][h])
        })

    return report

def print_audit_summary(report: Dict, class_names: List[str]):
    print("\n" + "=" * 65)
    print("           WAYZE DATASET AUDIT & HEALTH REPORT")
    print("=" * 65)

    print("\n[+] Split Overview:")
    for split, info in report["splits"].items():
        print(f"  • {split.upper():<6}: {info['image_count']:>5} images | {info['label_count']:>5} annotated labels")

    print("\n[+] Class Instance Distribution:")
    total_instances = sum(report["class_distribution"].values())
    for cname in class_names:
        count = report["class_distribution"].get(cname, 0)
        pct = (count / total_instances * 100) if total_instances > 0 else 0
        warning = " [!] LOW DATA RISK" if count < 100 else ""
        print(f"  • {cname:<18}: {count:>6} instances ({pct:>5.1f}%){warning}")

    print("\n[+] Data Contamination / Leakage Audit:")
    leak_tv = len(report["data_leakage"]["train_val_overlap"])
    leak_tt = len(report["data_leakage"]["train_test_overlap"])
    if leak_tv == 0 and leak_tt == 0:
        print("  ✓ PASS: Zero duplicate images between Train and Val/Test splits. Split is clean.")
    else:
        print(f"  ✗ CAUTION: Data contamination detected!")
        if leak_tv > 0:
            print(f"    - {leak_tv} exact duplicates between Train and Val!")
        if leak_tt > 0:
            print(f"    - {leak_tt} exact duplicates between Train and Test!")

    print("\n[+] File Integrity:")
    print(f"  • Corrupted Images:      {len(report['corrupted_images'])}")
    print(f"  • Invalid Annotations:   {len(report['invalid_annotations'])}")
    print(f"  • Missing Label Files:   {len(report['missing_labels'])}")
    print(f"  • Background/Unlabeled:  {len(report['unlabeled_images'])}")
    print("=" * 65)

def generate_data_yaml(dataset_dir: Path, class_names: List[str], output_path: Path):
    """Generates standard YOLOv8 data.yaml config."""
    yaml_content = f"""# Wayze Indoor Hazard Detection Dataset Config
path: {dataset_dir.as_posix()}
train: train/images
val: val/images
test: test/images

names:
"""
    for idx, name in enumerate(class_names):
        yaml_content += f"  {idx}: {name}\n"

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(yaml_content)
    print(f"[+] Generated data.yaml at: {output_path}")

def main():
    parser = argparse.ArgumentParser(description="Audit and curate YOLO dataset for Wayze.")
    parser.add_argument("--dataset_dir", type=str, default="door_stairs_dataset", help="Path to root dataset folder.")
    parser.add_argument("--classes", type=str, default="door,stairs", help="Comma-separated class names.")
    parser.add_argument("--report_json", type=str, default="dataset_audit_report.json", help="Path to write JSON report.")
    parser.add_argument("--generate_yaml", action="store_true", help="Generate data.yaml automatically.")
    args = parser.parse_args()

    dataset_path = Path(args.dataset_dir)
    if not dataset_path.exists():
        print(f"[!] Error: Directory {dataset_path} does not exist.")
        sys.exit(1)

    class_names = [c.strip() for c in args.classes.split(",") if c.strip()]
    report = audit_dataset(dataset_path, class_names)
    print_audit_summary(report, class_names)

    with open(args.report_json, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    print(f"\n[+] Full JSON report saved to: {args.report_json}")

    if args.generate_yaml or not (dataset_path / "data.yaml").exists():
        generate_data_yaml(dataset_path, class_names, dataset_path / "data.yaml")

if __name__ == "__main__":
    main()
