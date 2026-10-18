import numpy as np
from PIL import Image

def letterbox(img, size):
    """PIL RGB image -> float32 NCHW [1,3,size,size] in 0-1, plus (scale, pad_x, pad_y)."""
    w, h = img.size
    s = size / max(w, h)
    nw, nh = int(round(w * s)), int(round(h * s))
    canvas = Image.new("RGB", (size, size), (114, 114, 114))
    px, py = (size - nw) // 2, (size - nh) // 2
    canvas.paste(img.resize((nw, nh), Image.BILINEAR), (px, py))
    a = np.asarray(canvas, dtype=np.float32) / 255.0
    return a.transpose(2, 0, 1)[None], s, px, py

def _iou(a, b):
    x1, y1 = max(a[0], b[0]), max(a[1], b[1])
    x2, y2 = min(a[2], b[2]), min(a[3], b[3])
    inter = max(0.0, x2 - x1) * max(0.0, y2 - y1)
    u = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter
    return inter / u if u > 0 else 0.0

def decode(raw, nc, conf, size, scale, px, py, orig_w, orig_h, iou=0.45):
    """raw: model output [1, 4+nc, N] (channels-first) or [1, N, 4+nc].
    Returns list of (class_id, score, x1, y1, x2, y2) in ORIGINAL image pixels."""
    r = np.asarray(raw)[0]
    if r.shape[0] != 4 + nc:
        r = r.T                                   # -> [4+nc, N]
    r = r.T                                       # -> [N, 4+nc]
    boxes, scores = r[:, :4].copy(), r[:, 4:]
    if np.abs(boxes).max() <= 2.0:                # normalised 0-1 -> pixels of the input square
        boxes *= size
    cls = scores.argmax(1)
    sc = scores.max(1)
    keep = sc >= conf
    boxes, cls, sc = boxes[keep], cls[keep], sc[keep]
    out = []
    for c in np.unique(cls):
        idx = np.where(cls == c)[0]
        order = idx[np.argsort(-sc[idx])]
        chosen = []
        for i in order:
            cx, cy, w, h = boxes[i]
            b = (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)
            if all(_iou(b, boxes_xyxy) < iou for boxes_xyxy in chosen):
                chosen.append(b)
                x1 = min(max((b[0] - px) / scale, 0), orig_w)
                y1 = min(max((b[1] - py) / scale, 0), orig_h)
                x2 = min(max((b[2] - px) / scale, 0), orig_w)
                y2 = min(max((b[3] - py) / scale, 0), orig_h)
                out.append((int(c), float(sc[i]), x1, y1, x2, y2))
    return sorted(out, key=lambda t: -t[1])
