#!/usr/bin/env python3
"""Lay screenshots out side by side on one sheet, each labelled, so surfaces of the same kind can be
compared at a glance: every context menu, every dialog, every card variant, one theme next to another.
Inconsistency (a menu with different padding, a dialog with a different header, a card with twice
the chips) is obvious on a sheet and invisible one screenshot at a time.

  contact_sheet.py OUT.png IMG [IMG ...] [--cols 3] [--width 520] [--title "Context menus"]
  contact_sheet.py OUT.png --glob "shots/menu_*.png" ...
  --crop x,y,w,h      crop every image to the same region first (e.g. just the popup)
  --crop-json F.json  per-image crops: {"file.png": [x,y,w,h], ...}
Labels are the file names without extension (or --labels a,b,c).
"""
import argparse
import glob
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont


def font(size):
    for name in ("segoeui.ttf", "arial.ttf", "DejaVuSans.ttf", "Helvetica.ttc", "/System/Library/Fonts/Helvetica.ttc",
                 "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("out")
    ap.add_argument("images", nargs="*")
    ap.add_argument("--glob", dest="pattern")
    ap.add_argument("--cols", type=int, default=3)
    ap.add_argument("--width", type=int, default=520, help="cell width; images are scaled to it (never up)")
    ap.add_argument("--title", default="")
    ap.add_argument("--labels", default="")
    ap.add_argument("--crop", default="")
    ap.add_argument("--crop-json", default="")
    ap.add_argument("--bg", default="#1e1e1e")
    a = ap.parse_args()

    files = list(a.images)
    if a.pattern:
        files += sorted(glob.glob(a.pattern))
    if not files:
        sys.exit("no images")
    labels = a.labels.split(",") if a.labels else [os.path.splitext(os.path.basename(f))[0] for f in files]
    crops = json.load(open(a.crop_json, encoding="utf-8")) if a.crop_json else {}
    fixed = [int(v) for v in a.crop.split(",")] if a.crop else None

    cells = []
    for f in files:
        im = Image.open(f).convert("RGB")
        c = crops.get(os.path.basename(f)) or crops.get(f) or fixed
        if c:
            x, y, w, h = c
            im = im.crop((x, y, x + w, y + h))
        if im.width > a.width:
            im = im.resize((a.width, round(im.height * a.width / im.width)), Image.LANCZOS)
        cells.append(im)

    pad, label_h = 16, 26
    title_h = 44 if a.title else 0
    cols = max(1, min(a.cols, len(cells)))
    rows = (len(cells) + cols - 1) // cols
    cell_w = max(c.width for c in cells)
    row_h = [max(c.height for c in cells[r * cols:(r + 1) * cols]) for r in range(rows)]
    W = pad + cols * (cell_w + pad)
    H = title_h + pad + sum(h + label_h + pad for h in row_h)
    sheet = Image.new("RGB", (W, H), a.bg)
    d = ImageDraw.Draw(sheet)
    if a.title:
        d.text((pad, 10), a.title, fill="#f0f0f0", font=font(22))
    y = title_h + pad
    for r in range(rows):
        x = pad
        for i in range(r * cols, min((r + 1) * cols, len(cells))):
            d.text((x, y), f"{i + 1}. {labels[i]}", fill="#bbbbbb", font=font(14))
            sheet.paste(cells[i], (x, y + label_h))
            d.rectangle((x - 1, y + label_h - 1, x + cells[i].width, y + label_h + cells[i].height), outline="#555555")
            x += cell_w + pad
        y += row_h[r] + label_h + pad
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    sheet.save(a.out)
    print(f"OK {len(cells)} images -> {a.out} ({W}x{H})")


if __name__ == "__main__":
    main()
