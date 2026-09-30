#!/usr/bin/env python3
"""Measurements a reviewer's eye estimates badly: exact contrast, the colours a surface really uses,
and whether two surfaces of the same kind use the same ones.

  pixels.py contrast IMG x,y x2,y2            WCAG ratio between two sampled pixels (fg bg)
  pixels.py contrast-hex "#aaaaaa" "#1e1e1e"  WCAG ratio between two colours
  pixels.py palette IMG [--region x,y,w,h] [--top 12]
      dominant colours with their share of the area (quantised), so "the menu uses a different
      background than every other popup" is a number, not an impression
  pixels.py compare IMG_A IMG_B [--region-a x,y,w,h] [--region-b x,y,w,h]
      palette distance between two surfaces that should look alike (two context menus, two dialogs);
      prints the colours one uses that the other does not
  pixels.py edges IMG [--region x,y,w,h]
      visual density: share of edge pixels + distinct text-ish rows. A card at 2x the density of its
      siblings is overloaded; compare cards of the same kind
  pixels.py diff IMG_A IMG_B OUT.png [--threshold 24]
      pixel diff (before/after, theme A/B, run N/N-1) with changed regions boxed
"""
import argparse
import math
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter


def lum(rgb):
    def ch(c):
        c = c / 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = rgb[:3]
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)


def ratio(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def hexrgb(h):
    h = h.lstrip("#")
    if len(h) == 8:
        h = h[2:]
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def region(im, spec):
    if not spec:
        return im
    x, y, w, h = (int(v) for v in spec.split(","))
    return im.crop((x, y, x + w, y + h))


def palette(im, top=12, step=8):
    im = im.convert("RGB")
    if im.width * im.height > 600_000:
        k = math.sqrt(im.width * im.height / 600_000)
        im = im.resize((int(im.width / k), int(im.height / k)))
    counts = {}
    for px in im.getdata():
        q = tuple((c // step) * step for c in px)
        counts[q] = counts.get(q, 0) + 1
    total = sum(counts.values())
    return [(c, n / total) for c, n in sorted(counts.items(), key=lambda kv: -kv[1])[:top]]


def fmt(c):
    return "#%02x%02x%02x" % c


def near(c, others, tol=24):
    return any(sum(abs(a - b) for a, b in zip(c, o)) <= tol for o in others)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("contrast"); p.add_argument("img"); p.add_argument("fg"); p.add_argument("bg")
    p = sub.add_parser("contrast-hex"); p.add_argument("fg"); p.add_argument("bg")
    p = sub.add_parser("palette"); p.add_argument("img"); p.add_argument("--region"); p.add_argument("--top", type=int, default=12)
    p = sub.add_parser("compare"); p.add_argument("a"); p.add_argument("b"); p.add_argument("--region-a"); p.add_argument("--region-b")
    p = sub.add_parser("edges"); p.add_argument("img"); p.add_argument("--region")
    p = sub.add_parser("diff"); p.add_argument("a"); p.add_argument("b"); p.add_argument("out"); p.add_argument("--threshold", type=int, default=24)
    a = ap.parse_args()

    if a.cmd == "contrast":
        im = Image.open(a.img).convert("RGB")
        fg = im.getpixel(tuple(int(v) for v in a.fg.split(",")))
        bg = im.getpixel(tuple(int(v) for v in a.bg.split(",")))
        r = ratio(fg, bg)
        print(f"{fmt(fg)} on {fmt(bg)}: {r:.2f}:1  AA text {'ok' if r >= 4.5 else 'FAIL'}  AA large/UI {'ok' if r >= 3 else 'FAIL'}")
    elif a.cmd == "contrast-hex":
        r = ratio(hexrgb(a.fg), hexrgb(a.bg))
        print(f"{a.fg} on {a.bg}: {r:.2f}:1  AA text {'ok' if r >= 4.5 else 'FAIL'}  AA large/UI {'ok' if r >= 3 else 'FAIL'}")
    elif a.cmd == "palette":
        for c, share in palette(region(Image.open(a.img), a.region), a.top):
            print(f"{fmt(c)}  {share * 100:5.1f}%")
    elif a.cmd == "compare":
        pa = palette(region(Image.open(a.a), a.region_a), 10)
        pb = palette(region(Image.open(a.b), a.region_b), 10)
        ca = [c for c, s in pa if s > 0.01]
        cb = [c for c, s in pb if s > 0.01]
        only_a = [fmt(c) for c in ca if not near(c, cb)]
        only_b = [fmt(c) for c in cb if not near(c, ca)]
        bg_a, bg_b = pa[0][0], pb[0][0]
        d = sum(abs(x - y) for x, y in zip(bg_a, bg_b))
        print(f"dominant: A {fmt(bg_a)} vs B {fmt(bg_b)} (distance {d}{' - DIFFERENT background' if d > 24 else ''})")
        print("only in A:", ", ".join(only_a) or "-")
        print("only in B:", ", ".join(only_b) or "-")
    elif a.cmd == "edges":
        im = region(Image.open(a.img), a.region).convert("L")
        e = im.filter(ImageFilter.FIND_EDGES).point(lambda v: 255 if v > 40 else 0)
        px = list(e.getdata())
        share = sum(1 for v in px if v) / len(px)
        rows = 0
        w = e.width
        prev = False
        for y in range(e.height):
            on = sum(1 for v in px[y * w:(y + 1) * w] if v) > w * 0.02
            if on and not prev:
                rows += 1
            prev = on
        print(f"edge density {share * 100:.1f}%  text-ish bands {rows}  size {im.width}x{im.height}")
    elif a.cmd == "diff":
        ia, ib = Image.open(a.a).convert("RGB"), Image.open(a.b).convert("RGB")
        if ia.size != ib.size:
            ib = ib.resize(ia.size)
        d = ImageChops.difference(ia, ib).convert("L").point(lambda v: 255 if v > a.threshold else 0)
        box = d.getbbox()
        out = ib.copy()
        if box:
            ImageDraw.Draw(out).rectangle(box, outline="#ff3b30", width=3)
        out.save(a.out)
        changed = sum(1 for v in d.getdata() if v) / (d.width * d.height)
        print(f"changed {changed * 100:.2f}% bbox {box} -> {a.out}")


if __name__ == "__main__":
    sys.exit(main())
