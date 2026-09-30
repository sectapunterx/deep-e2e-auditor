#!/usr/bin/env python3
"""Draw numbered boxes on a screenshot, so a finding points at the exact pixels it is about.

  annotate.py IN.png OUT.png --box x,y,w,h[:label] [--box ...] [--color "#ff3b30"]
  annotate.py --findings findings.jsonl --shots DIR --out DIR
      annotates every evidence image of every finding that has "boxes": [{"img": "a.png",
      "x":..,"y":..,"w":..,"h":..,"label":".."}]; writes <out>/<finding-id>__<img>.
"""
import argparse
import json
import os

from PIL import Image, ImageDraw, ImageFont


def font(size):
    for name in ("segoeuib.ttf", "arialbd.ttf", "DejaVuSans-Bold.ttf", "/System/Library/Fonts/Helvetica.ttc",
                 "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def draw(im, boxes, color):
    im = im.convert("RGB")
    over = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    f = font(16)
    for n, b in enumerate(boxes, 1):
        x, y, w, h = int(b["x"]), int(b["y"]), int(b["w"]), int(b["h"])
        d.rectangle((x, y, x + w, y + h), outline=color, width=3)
        d.rectangle((x, y, x + w, y + h), fill=color + "22" if len(color) == 7 else None)
        tag = f"{n}" + (f" {b['label']}" if b.get("label") else "")
        tw = d.textlength(tag, font=f)
        ty = y - 24 if y >= 24 else y + h + 2
        d.rectangle((x, ty, x + tw + 10, ty + 22), fill=color)
        d.text((x + 5, ty + 2), tag, fill="white", font=f)
    return Image.alpha_composite(im.convert("RGBA"), over).convert("RGB")


def parse_box(s):
    geom, _, label = s.partition(":")
    x, y, w, h = (int(v) for v in geom.split(","))
    return {"x": x, "y": y, "w": w, "h": h, "label": label}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("inp", nargs="?")
    ap.add_argument("out", nargs="?")
    ap.add_argument("--box", action="append", default=[])
    ap.add_argument("--color", default="#ff3b30")
    ap.add_argument("--findings")
    ap.add_argument("--shots", default=".")
    ap.add_argument("--outdir", "--out-dir", dest="outdir", default="annotated")
    a = ap.parse_args()

    if a.findings:
        os.makedirs(a.outdir, exist_ok=True)
        count = 0
        for line in open(a.findings, encoding="utf-8"):
            line = line.strip()
            if not line:
                continue
            fd = json.loads(line)
            by_img = {}
            for b in fd.get("boxes", []):
                by_img.setdefault(b["img"], []).append(b)
            for img, boxes in by_img.items():
                src = img if os.path.isabs(img) else os.path.join(a.shots, img)
                if not os.path.exists(src):
                    print(f"missing {src} ({fd.get('id')})")
                    continue
                out = os.path.join(a.outdir, f"{fd['id']}__{os.path.basename(img)}")
                draw(Image.open(src), boxes, a.color).save(out)
                count += 1
        print(f"OK {count} annotated images -> {a.outdir}")
        return
    if not (a.inp and a.out and a.box):
        ap.error("give IN OUT --box ... or --findings")
    draw(Image.open(a.inp), [parse_box(b) for b in a.box], a.color).save(a.out)
    print(f"OK -> {a.out}")


if __name__ == "__main__":
    main()
