"""
Wayze YOLOv8 Local Training Script
For RTX 4060 GPU
Run this on your local Windows machine
"""

# Windows multiprocessing fix - MUST be at top
import multiprocessing
if __name__ == '__main__':
    multiprocessing.freeze_support()

import torch
from ultralytics import YOLO
import os
import yaml
import numpy as np
from pathlib import Path
import json
import time
from PIL import Image
