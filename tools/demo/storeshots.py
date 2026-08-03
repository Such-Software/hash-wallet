#!/usr/bin/env python3
"""
storeshots.py -- compose App Store-ready screenshots from raw app captures.

Takes the 1080x1920 captures from the demo harness, crops the mobile status
bar, frames each on a Hash Bags brand gradient with rounded corners + a soft
shadow, and burns a headline + subhead. Output is 1290x2796 (Apple's 6.9"
iPhone size), drop-in for App Store Connect.

Copy is deliberately factual and benefit-driven -- no price talk, no return or
"investment" claims, no guarantees -- so it stays inside App Store Review
guideline 3.1.5 (crypto) and the general "no misleading claims" rules.

Needs Pillow (pip install pillow). Reads brand colors/fonts from
packs/hash/pack.json. Edit SHOTS[] to change sources or copy.

Usage:
  python3 tools/demo/storeshots.py \
      --srcdir ~/Build/hash-wallet/demo/screenshots-funded \
      --outdir ~/Build/hash-wallet/demo/appstore
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = Path(__file__).resolve().parent
PACK = json.loads((HERE / "packs" / "hash" / "pack.json").read_text())
PAL = PACK["palette"]

# App Store 6.9" iPhone (16 Pro Max class). Also an accepted 6.9" size is
# 1320x2868; 1290x2796 is the widely-accepted one.
W, H = 1290, 2796

FONT_DIR = "/usr/share/fonts/opentype/inter"
F_HEAD = f"{FONT_DIR}/InterDisplay-Bold.otf"
F_SUB = f"{FONT_DIR}/Inter-SemiBold.otf"

# Pixels to crop off the top of the 1080-wide capture. Full-screen pages
# (dashboard) only need the status bar gone (~66). Bottom-sheet modals
# (receive/send/swap) also carry a dark scrim above the sheet, so they crop
# deeper (~128) to start cleanly at the sheet's rounded top.
CROP_FULLSCREEN = 66
CROP_MODAL = 128

# (source filename, headline [(text, is_accent), ...], subhead, top_crop)
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


def rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def gradient_bg() -> Image.Image:
    """Vertical brand gradient + a soft accent glow top-right (matches the
    Play feature graphic)."""
    top, bot = rgb(PAL["bg"]), rgb(PAL["bg_hi"])
    bg = Image.new("RGB", (W, H))
    px = bg.load()
    for y in range(H):
        t = y / (H - 1)
        row = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        for x in range(W):
            px[x, y] = row
    glow = Image.new("L", (W, H), 0)
    gd = ImageDraw.Draw(glow)
    cx, cy, r = int(W * 0.80), int(H * 0.15), int(W * 0.55)
    gd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=70)
    glow = glow.filter(ImageFilter.GaussianBlur(190))
    acc = Image.new("RGB", (W, H), rgb(PAL["accent"]))
    return Image.composite(acc, bg, glow)


def rounded(im: Image.Image, rad: int) -> Image.Image:
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, im.size[0], im.size[1]], rad, fill=255)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(im, (0, 0), mask)
    return out


def build(srcdir: Path, src: str, headline, subhead: str, top_crop: int,
          out: Path) -> None:
    bg = gradient_bg().convert("RGBA")
    d = ImageDraw.Draw(bg)

    # ---- headline ----
    fh = ImageFont.truetype(F_HEAD, 112)
    y = 170
    for text, accent in headline:
        col = rgb(PAL["accent_hi"]) if accent else rgb(PAL["ink"])
        w = d.textlength(text, font=fh)
        d.text(((W - w) / 2, y), text, font=fh, fill=col)
        y += 128

    # ---- subhead ----
    fs = ImageFont.truetype(F_SUB, 46)
    w = d.textlength(subhead, font=fs)
    d.text(((W - w) / 2, y + 22), subhead, font=fs, fill=rgb(PAL["muted"]))

    # ---- framed app screenshot ----
    im = Image.open(srcdir / src).convert("RGB")
    im = im.crop((0, top_crop, im.width, im.height))
    sw = 1040
    sh = int(im.height * sw / im.width)
    im = im.resize((sw, sh), Image.LANCZOS)
    im = rounded(im, 54)
    ImageDraw.Draw(im).rounded_rectangle(
        [1, 1, sw - 2, sh - 2], 54, outline=rgb(PAL["accent"]) + (235,), width=3)

    px_x = (W - sw) // 2
    px_y = 650

    # soft drop shadow
    shadow = Image.new("RGBA", (sw + 120, sh + 120), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [60, 60, sw + 60, sh + 60], 70, fill=(0, 0, 0, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(46))
    sh_layer = Image.new("RGBA", bg.size, (0, 0, 0, 0))
    sh_layer.paste(shadow, (px_x - 60, px_y - 40), shadow)
    bg = Image.alpha_composite(bg, sh_layer)

    bg.paste(im, (px_x, px_y), im)

    # ---- footer ----
    d = ImageDraw.Draw(bg)
    w = d.textlength(FOOTER, font=fs)
    d.text(((W - w) / 2, H - 130), FOOTER, font=fs, fill=rgb(PAL["accent_hi"]))

    out.parent.mkdir(parents=True, exist_ok=True)
    bg.convert("RGB").save(out)
    print(f"wrote {out}  ({W}x{H})")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--srcdir", required=True)
    ap.add_argument("--outdir", required=True)
    args = ap.parse_args()
    srcdir = Path(os.path.expanduser(args.srcdir))
    outdir = Path(os.path.expanduser(args.outdir))
    for i, (src, headline, subhead, top_crop) in enumerate(SHOTS, 1):
        if not (srcdir / src).exists():
            print(f"skip {src}: not found in {srcdir}")
            continue
        build(srcdir, src, headline, subhead, top_crop, outdir / f"appstore-{i:02d}.png")


if __name__ == "__main__":
    main()
