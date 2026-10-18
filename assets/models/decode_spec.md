# Decode spec (measured in this Colab run)
- file: wayze.tflite (LiteRT/TFLite, float32)
- input: [1, 3, 320, 320] float32 -> layout NCHW, RGB, value/255, size 320x320
- preprocessing: LETTERBOX (keep aspect ratio, pad with gray 114, centred). Plain resize gives shifted boxes.
- output: [1, 6, 2100] -> channels-first [1, 4+nc, N]; box = cx, cy, w, h; values normalised 0-1 (multiply by input size)
- classes (2) in order: ['door', 'stairs']
- no objectness column; score = max class score; confidence threshold 0.45; class-wise NMS IoU 0.45
- map boxes back: x_orig = (x - pad_x) / scale, y_orig = (y - pad_y) / scale
- decode_reference.py in this zip is the decoder used for the parity check above. Port it line by line.
- NCHW note: some mobile TFLite wrappers expect NHWC. If your wrapper cannot feed NCHW, use the ONNX file with ONNX Runtime Mobile, or re-export.
