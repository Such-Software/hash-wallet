#!/usr/bin/env python3
"""
storeshots_play.py -- Google Play phone screenshots (1290x2580, exactly 2:1).

Play caps phone screenshots at a 2:1 aspect ratio; the App Store set (1290x2796,
~2.17:1) is too tall. This composes the same funded captures onto the website-dark
brand background at a Play-legal 2:1 canvas, matching storeshots.py visually.

Usage:
  python3 tools/demo/storeshots_play.py \
      --srcdir ~/Build/hash-wallet/demo/screenshots-funded \
      --outdir ~/Build/hash-wallet/demo/play-phone
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1290, 2580  # exactly 2:1

FONT_DIR = "/usr/share/fonts/opentype/inter"
F_HEAD = f"{FONT_DIR}/InterDisplay-Bold.otf"
F_SUB = f"{FONT_DIR}/Inter-SemiBold.otf"

CROP_FULLSCREEN = 66
CROP_MODAL = 128

SHOTS = [
    ("01-dashboard.png",
     [("Your bags.", False), ("Your keys.", True)],
     "Wownero · Monero · Bitcoin & more", CROP_FULLSCREEN),
    ("02-receive.png",
     [("Get paid", False), ("in a tap.", True)],
     "Scan, share, done", CROP_MODAL),
    ("03-send.png",
     [("Send anywhere,", False), ("ask no one.", True)],
     "Non-custodial by design", CROP_MODAL),
    ("04-swap.png",
     [("Swap coins,", False), ("skip the signup.", True)],
     "No account required", CROP_MODAL),
]
FOOTER = "Open-source · Non-custodial"

WEB_BG = "#0a0b0c"
WEB_BG_EDGE = "#050708"
WEB_GLOW = "#1f7d4d"
WEB_INK = "#e8efe9"
WEB_MINT = "#86d3a6"
WEB_GREY = "#9aa3a0"


def rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def gradient_bg() -> Image.Image:
    bg = Image.new("RGB", (W, H), rgb(WEB_BG))
    vig = Image.new("L", (W, H), 0)
    ImageDraw.Draw(vig).ellipse([-W * 0.25, -H * 0.15, W * 1.25, H * 1.05], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(230))
    bg = Image.composite(bg, Image.new("RGB", (W, H), rgb(WEB_BG_EDGE)), vig)
    glow = Image.new("L", (W, H), 0)
    cx, cy, r = int(W * 0.5), int(H * 0.52), int(W * 0.62)
    ImageDraw.Draw(glow).ellipse([cx - r, cy - r, cx + r, cy + r], fill=48)
    glow = glow.filter(ImageFilter.GaussianBlur(250))
    return Image.composite(Image.new("RGB", (W, H), rgb(WEB_GLOW)), bg, glow)


def rounded(im: Image.Image, rad: int) -> Image.Image:
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.size[0], im.size[1]], rad, fill=255)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(im, (0, 0), mask)
    return out


def build(srcdir: Path, src: str, headline, subhead: str, top_crop: int, out: Path) -> None:
    bg = gradient_bg().convert("RGBA")
    d = ImageDraw.Draw(bg)

    fh = ImageFont.truetype(F_HEAD, 108)
    y = 150
    for text, accent in headline:
        col = rgb(WEB_MINT) if accent else rgb(WEB_INK)
        w = d.textlength(text, font=fh)
        d.text(((W - w) / 2, y), text, font=fh, fill=col)
        y += 124

    fs = ImageFont.truetype(F_SUB, 44)
    w = d.textlength(subhead, font=fs)
    d.text(((W - w) / 2, y + 18), subhead, font=fs, fill=rgb(WEB_GREY))

    im = Image.open(srcdir / src).convert("RGB")
    im = im.crop((0, top_crop, im.width, im.height))
    sw = 980
    sh = int(im.height * sw / im.width)
    im = im.resize((sw, sh), Image.LANCZOS)
    im = rounded(im, 52)
    ImageDraw.Draw(im).rounded_rectangle([1, 1, sw - 2, sh - 2], 52,
                                         outline=rgb(WEB_MINT) + (235,), width=3)

    px_x = (W - sw) // 2
    px_y = 600

    shadow = Image.new("RGBA", (sw + 120, sh + 120), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([60, 60, sw + 60, sh + 60], 66, fill=(0, 0, 0, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(46))
    sh_layer = Image.new("RGBA", bg.size, (0, 0, 0, 0))
    sh_layer.paste(shadow, (px_x - 60, px_y - 40), shadow)
    bg = Image.alpha_composite(bg, sh_layer)
    bg.paste(im, (px_x, px_y), im)

    d = ImageDraw.Draw(bg)
    w = d.textlength(FOOTER, font=fs)
    d.text(((W - w) / 2, H - 120), FOOTER, font=fs, fill=rgb(WEB_MINT))

    out.parent.mkdir(parents=True, exist_ok=True)
    bg.convert("RGB").save(out)
    print(f"wrote {out}  ({W}x{H})")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--srcdir", required=True)
    ap.add_argument("--outdir", required=True)
    args = ap.parse_args()
    srcdir = Path(os.path.expanduser(args.srcdir))
    outdir = Path(os.path.expanduser(args.outdir))
    for i, (src, headline, subhead, top_crop) in enumerate(SHOTS, 1):
        if not (srcdir / src).exists():
            print(f"skip {src}: not found")
            continue
        build(srcdir, src, headline, subhead, top_crop, outdir / f"play-{i:02d}.png")


if __name__ == "__main__":
    main()
