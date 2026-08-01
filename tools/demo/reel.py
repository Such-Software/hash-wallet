#!/usr/bin/env python3
"""
reel.py -- assemble Hash Bags marketing video from recorded wallet captures.

Takes the raw screen recordings produced by capture.sh (one MP4 per scenario)
plus a manifest describing captions and pacing, and renders a finished master.

Profiles decide how much production sits on top of the raw capture:

  social        1080x1920 vertical. Title card, per-clip burned captions on a
                blurred fill, xfade transitions, CTA end card, optional music.
                This is the TikTok / Reels / Shorts deliverable.

  apple-preview App Store App Preview. DELIBERATELY BARE: no burned captions,
                no title/CTA cards, no tap overlay, no music bed. Apple wants
                the app itself on screen, and the recording is used as shot.
                Trimmed to Apple's 15-30s window and left at device pixels.

  play-listing  Google Play listing video. Same production as `social` but
                sized 1080x1920 and duration-capped at 30s.

  raw           Passthrough + QA only. Useful for eyeballing a capture.

The genuinely reusable pieces of ~/src/such-graphics (video_transitions for the
xfade preset table, video_qa for the "did this decode to black" gate) are
imported when that repo is checked out, and cleanly stubbed when it is not --
hash-wallet is public and must build without it.

Usage:
  python3 tools/demo/reel.py --manifest reel.json --profile social -o out.mp4
  python3 tools/demo/reel.py --manifest reel.json --profile apple-preview \
      -o preview.mp4

Manifest shape:
  {
    "title": "Hash Bags",            # optional, defaults from pack.json
    "subtitle": "You hold the keys.",
    "cta": "hash.boats",
    "transition": "cross_dissolve",  # optional
    "music": "/path/to/bed.mp3",     # optional; ignored by apple-preview
    "clips": [
      {"src": "captures/receive.mp4", "caption": "Receive in a tap",
       "seconds": 6, "start": 1.5}
    ]
  }
"""
from __future__ import annotations

import argparse
import json
import os
import random
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_PACK = HERE / "packs" / "hash" / "pack.json"

# ---------------------------------------------------------------------------
# such-graphics interop (optional)
# ---------------------------------------------------------------------------
SUCH_GRAPHICS_HOME = Path(
    os.environ.get("SUCH_GRAPHICS_HOME", Path.home() / "src" / "such-graphics")
)

_FALLBACK_TRANSITIONS = {
    "cross_dissolve": ("fade", 0.52),
    "blur_punch": ("hblur", 0.42),
    "black_dip": ("fadeblack", 0.34),
    "slide_up": ("slideup", 0.40),
    "zoom_punch": ("zoomin", 0.45),
    "whip_left": ("smoothleft", 0.38),
}


@dataclass(frozen=True)
class Transition:
    ffmpeg_name: str
    duration: float


def load_transition(name: str) -> Transition:
    """Prefer such-graphics' tuned preset table; fall back to a local subset."""
    if SUCH_GRAPHICS_HOME.is_dir():
        sys.path.insert(0, str(SUCH_GRAPHICS_HOME))
        try:
            from such_graphics.video_transitions import (  # noqa: E402
                get_video_transition,
            )

            t = get_video_transition(name)
            return Transition(t.ffmpeg_name, t.duration)
        except Exception:
            pass  # fall through to the local table
    ff, dur = _FALLBACK_TRANSITIONS.get(name, _FALLBACK_TRANSITIONS["cross_dissolve"])
    return Transition(ff, dur)


def run_video_qa(path: Path) -> str:
    """Decode-level QA. ffmpeg can emit a valid MP4 that is entirely black --
    a real hazard with headless emulator capture, so this gate matters."""
    if SUCH_GRAPHICS_HOME.is_dir():
        sys.path.insert(0, str(SUCH_GRAPHICS_HOME))
        try:
            from such_graphics.video_qa import verify_video  # noqa: E402

            verify_video(path)
            return "such_graphics.video_qa: PASS"
        except ImportError:
            pass
        except Exception as exc:  # QA genuinely failed -- surface it
            raise SystemExit(f"VIDEO QA FAILED for {path}: {exc}")
    return _local_black_check(path)


def _local_black_check(path: Path) -> str:
    """Minimal standalone equivalent: sample frames, fail if all are black."""
    dur = probe_duration(path)
    samples = [t for t in (0.5, dur * 0.25, dur * 0.5, dur * 0.75) if t < dur]
    brightest = 0.0
    for at in samples:
        r = subprocess.run(
            ["ffmpeg", "-v", "error", "-ss", f"{at}", "-i", str(path),
             "-frames:v", "1", "-vf", "scale=64:64,format=gray",
             "-f", "rawvideo", "-"],
            capture_output=True,
        )
        if r.stdout:
            brightest = max(brightest, sum(r.stdout) / len(r.stdout))
    if brightest < 4.0:
        raise SystemExit(
            f"VIDEO QA FAILED for {path}: decodes to black "
            f"(peak mean luma {brightest:.2f}). The capture likely raced the "
            f"app launch, or the emulator GPU produced no frames."
        )
    return f"local black-check: PASS (peak mean luma {brightest:.1f})"


# ---------------------------------------------------------------------------
# ffmpeg helpers
# ---------------------------------------------------------------------------
W, H, FPS = 1080, 1920, 30


def run(cmd: list[str]) -> None:
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        sys.stderr.write(r.stderr[-4000:])
        raise SystemExit(f"ffmpeg failed: {' '.join(str(c) for c in cmd[:8])} ...")


def probe_duration(path: str | Path) -> float:
    r = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nk=1:nw=1", str(path)],
        capture_output=True, text=True,
    )
    try:
        return float(r.stdout.strip())
    except ValueError:
        raise SystemExit(f"cannot probe duration of {path} -- is it a valid video?")


def esc(text: str) -> str:
    """Escape text for the ffmpeg drawtext filter."""
    return (
        text.replace("\\", "\\\\")
        .replace(":", "\\:")
        .replace("'", "’")
        .replace("%", "\\%")
    )


class Pack:
    def __init__(self, path: Path):
        self.data = json.loads(Path(path).read_text())
        self.palette = self.data["palette"]
        self.copy = self.data.get("copy", {})
        self.font = self._resolve_font("display")
        self.body_font = self._resolve_font("body")

    def _resolve_font(self, role: str) -> str:
        t = self.data.get("type", {})
        cand = [t.get("font_files", {}).get(role, "")]
        cand += t.get("font_fallbacks", [])
        for c in cand:
            if c and Path(c).exists():
                return c
        raise SystemExit(
            "no usable font found; install Inter or DejaVu, or edit "
            f"{DEFAULT_PACK} type.font_fallbacks"
        )

    def hexc(self, key: str) -> str:
        """pack.json stores #rrggbb; ffmpeg wants 0xrrggbb."""
        return "0x" + self.palette[key].lstrip("#")


def drawtext(pack: Pack, text: str, y: str, size: int, color: str,
             box: bool = True, font: str | None = None) -> str:
    parts = [
        f"fontfile={font or pack.font}",
        f"text='{esc(text)}'",
        "x=(w-text_w)/2",
        f"y={y}",
        f"fontsize={size}",
        f"fontcolor={color}",
    ]
    if box:
        parts += ["box=1", "boxcolor=black@0.55", "boxborderw=28"]
    return "drawtext=" + ":".join(parts)


# ---------------------------------------------------------------------------
# segment builders
# ---------------------------------------------------------------------------
def build_card(pack: Pack, lines: list[str], seconds: float, out: Path) -> None:
    """Brand card: centered lines, first line accent-coloured and larger."""
    draws = []
    n = len(lines)
    for i, line in enumerate(lines):
        big = i == 0
        color = pack.hexc("accent") if big else pack.hexc("ink")
        size = pack.data["type"]["scale"]["title"] if big else pack.data["type"]["scale"]["subhead"]
        yoff = int((i - (n - 1) / 2) * 150)
        draws.append(
            drawtext(pack, line, y=f"(h-text_h)/2+{yoff}", size=size,
                     color=color, box=False,
                     font=pack.font if big else pack.body_font)
        )
    # Flat brand field with a single lift pass. Deliberately plain: the card
    # exists to frame the wordmark, not to compete with the app footage.
    bg = (
        f"color=c={pack.hexc('bg')}:s={W}x{H}:d={seconds}:r={FPS}[base];"
        f"[base]drawbox=x=0:y=0:w={W}:h={H}:color={pack.hexc('bg_hi')}@0.35:t=fill[grad];"
        f"[grad]" + ",".join(draws) + ",format=yuv420p[v]"
    )
    run([
        "ffmpeg", "-y", "-f", "lavfi",
        "-i", f"color=c={pack.hexc('bg')}:s={W}x{H}:d={seconds}:r={FPS}",
        "-filter_complex", bg, "-map", "[v]", "-an",
        "-c:v", "libx264", "-preset", "medium", "-crf", "18", str(out),
    ])


def build_clip(pack: Pack, src: str, caption: str, seconds: float, out: Path,
               start: float = 0.0, captioned: bool = True) -> None:
    """Frame one capture on a blurred fill of itself, optionally caption it.

    `start` seeks into the clip before taking `seconds`. Use it to skip past
    the seed-entry frames of a restore recording so a mnemonic never lands on
    camera even if the scenario paused there.
    """
    chain = (
        f"[0:v]scale={W}:{H}:force_original_aspect_ratio=increase,"
        f"crop={W}:{H},boxblur=40:2,eq=brightness=-0.32:saturation=0.7[bg];"
        f"[0:v]scale=-2:1480,pad=iw+8:ih+8:4:4:{pack.hexc('accent')}@0.9[fg];"
        f"[bg][fg]overlay=(W-w)/2:(H-h)/2-60[cmp];"
    )
    tail = (
        f"fade=t=in:st=0:d=0.4,fade=t=out:st={max(seconds - 0.4, 0.1):.2f}:d=0.4,"
        f"setsar=1,fps={FPS},format=yuv420p[v]"
    )
    if captioned and caption:
        cap = drawtext(pack, caption, y="h-260",
                       size=pack.data["type"]["scale"]["caption"],
                       color=pack.hexc("accent_hi"))
        chain += f"[cmp]{cap},{tail}"
    else:
        chain += f"[cmp]{tail}"

    run([
        "ffmpeg", "-y", "-ss", f"{start}", "-t", f"{seconds}", "-i", src,
        "-filter_complex", chain, "-map", "[v]", "-an",
        "-c:v", "libx264", "-preset", "medium", "-crf", "18",
        "-t", f"{seconds}", str(out),
    ])


def build_bare_clip(src: str, seconds: float, out: Path, start: float = 0.0) -> None:
    """Apple App Preview path: re-encode only. No framing, no caption, no
    overlay -- the recording is the deliverable. Kept at source geometry so
    the device pixels Apple expects survive untouched."""
    run([
        "ffmpeg", "-y", "-ss", f"{start}", "-t", f"{seconds}", "-i", src,
        "-an", "-c:v", "libx264", "-preset", "slow", "-crf", "18",
        "-pix_fmt", "yuv420p", "-r", str(FPS),
        "-movflags", "+faststart", str(out),
    ])


def xfade_concat(segments: list[Path], transition: str, out: Path) -> None:
    """Chain N segments with a single xfade preset. Video only."""
    t = load_transition(transition)
    inputs: list[str] = []
    for s in segments:
        inputs += ["-i", str(s)]
    durs = [probe_duration(s) for s in segments]
    filt = []
    prev = "[0:v]"
    running = durs[0]
    for i in range(1, len(segments)):
        off = max(running - t.duration, 0.1)
        label = f"[x{i}]"
        filt.append(
            f"{prev}[{i}:v]xfade=transition={t.ffmpeg_name}:"
            f"duration={t.duration}:offset={off:.3f}{label}"
        )
        prev = label
        running = running + durs[i] - t.duration
    run([
        "ffmpeg", "-y", *inputs,
        "-filter_complex", ";".join(filt), "-map", prev,
        "-c:v", "libx264", "-preset", "slow", "-crf", "18",
        "-pix_fmt", "yuv420p", "-colorspace", "bt709", "-color_primaries", "bt709",
        "-movflags", "+faststart", str(out),
    ])


def concat_simple(segments: list[Path], out: Path, tmp: Path) -> None:
    """Straight concat, no transitions (apple-preview keeps cuts honest)."""
    listing = tmp / "concat.txt"
    listing.write_text("".join(f"file '{s}'\n" for s in segments))
    run([
        "ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(listing),
        "-c:v", "libx264", "-preset", "slow", "-crf", "18",
        "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(out),
    ])


def mix_music(video: Path, music: str, out: Path, seed: int | None = None) -> None:
    """Bake a random-offset slice of the bed under the master, with fades.

    Random offset means repeat uploads of the same variant do not feel
    identical -- lifted from the medusa marketing-video builder.
    """
    dur = probe_duration(video)
    bed_len = probe_duration(music)
    rng = random.Random(seed)
    max_off = max(bed_len - dur - 1.0, 0.0)
    off = rng.uniform(0, max_off) if max_off > 0 else 0.0
    run([
        "ffmpeg", "-y", "-i", str(video), "-ss", f"{off:.2f}", "-i", music,
        "-filter_complex",
        f"[1:a]atrim=0:{dur:.2f},afade=t=in:st=0:d=0.5,"
        f"afade=t=out:st={max(dur - 1.0, 0.1):.2f}:d=1.0,volume=0.35[a]",
        "-map", "0:v", "-map", "[a]",
        "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
        "-shortest", "-movflags", "+faststart", str(out),
    ])


# ---------------------------------------------------------------------------
# profiles
# ---------------------------------------------------------------------------
APPLE_MIN, APPLE_MAX = 15.0, 30.0
PLAY_MAX = 30.0


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--manifest", required=True)
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("--profile", default="social",
                    choices=["social", "apple-preview", "play-listing", "raw"])
    ap.add_argument("--pack", default=str(DEFAULT_PACK))
    ap.add_argument("--transition", default=None)
    ap.add_argument("--music", default=None, help="override manifest music bed")
    ap.add_argument("--seed", type=int, default=None,
                    help="deterministic music offset (for reproducible renders)")
    ap.add_argument("--keep-work", action="store_true")
    args = ap.parse_args()

    if not shutil.which("ffmpeg"):
        raise SystemExit("ffmpeg not found on PATH")

    pack = Pack(Path(args.pack))
    m = json.loads(Path(args.manifest).read_text())
    clips = m.get("clips", [])
    if not clips:
        raise SystemExit(f"{args.manifest} has no clips")
    for c in clips:
        if not Path(c["src"]).exists():
            raise SystemExit(f"clip source missing: {c['src']}")

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = Path(tempfile.mkdtemp(prefix="hashbags-reel-"))
    segs: list[Path] = []

    apple = args.profile == "apple-preview"
    branded = args.profile in ("social", "play-listing")

    try:
        if branded:
            title = m.get("title", pack.copy.get("title", "Hash Bags"))
            subtitle = m.get("subtitle", pack.copy.get("subtitle", ""))
            seg = tmp / "00-title.mp4"
            build_card(pack, [title, subtitle], 2.5, seg)
            segs.append(seg)

        for i, clip in enumerate(clips):
            seg = tmp / f"{i + 1:02d}-clip.mp4"
            seconds = float(clip.get("seconds", 5))
            start = float(clip.get("start", 0))
            if apple or args.profile == "raw":
                build_bare_clip(clip["src"], seconds, seg, start=start)
            else:
                build_clip(pack, clip["src"], clip.get("caption", ""),
                           seconds, seg, start=start, captioned=True)
            segs.append(seg)

        if branded:
            cta = m.get("cta", pack.copy.get("cta", "hash.boats"))
            cta_sub = m.get("cta_sub", pack.copy.get("cta_sub", ""))
            seg = tmp / "99-cta.mp4"
            build_card(pack, [cta, cta_sub], 2.5, seg)
            segs.append(seg)

        silent = tmp / "master-silent.mp4"
        if apple or args.profile == "raw":
            # Honest cuts, no transition sugar, geometry preserved.
            concat_simple(segs, silent, tmp)
        else:
            transition = (args.transition or m.get("transition")
                          or pack.data["motion"]["transition_default"])
            xfade_concat(segs, transition, silent)

        dur = probe_duration(silent)

        # ---- profile duration gates ------------------------------------
        if apple:
            if dur > APPLE_MAX:
                raise SystemExit(
                    f"apple-preview is {dur:.1f}s; Apple accepts {APPLE_MIN:.0f}-"
                    f"{APPLE_MAX:.0f}s. Trim clip `seconds` in {args.manifest}."
                )
            if dur < APPLE_MIN:
                raise SystemExit(
                    f"apple-preview is {dur:.1f}s; Apple requires at least "
                    f"{APPLE_MIN:.0f}s. Lengthen clip `seconds` in {args.manifest}."
                )
        if args.profile == "play-listing" and dur > PLAY_MAX:
            print(f"WARNING: {dur:.1f}s exceeds the {PLAY_MAX:.0f}s Play "
                  f"listing-video guidance", file=sys.stderr)

        # ---- music ------------------------------------------------------
        music = args.music or m.get("music")
        if music and apple:
            print("NOTE: apple-preview ignores the music bed on purpose "
                  "(App Preview should carry app audio or silence)",
                  file=sys.stderr)
            music = None
        if music and Path(music).exists():
            mix_music(silent, music, out, seed=args.seed)
        else:
            shutil.copy(silent, out)

        qa = run_video_qa(out)
        print(f"wrote {out}")
        print(f"  profile   {args.profile}")
        print(f"  duration  {probe_duration(out):.1f}s")
        print(f"  qa        {qa}")
        if apple:
            print("  overlays  NONE (no captions/cards/tap effect) — per App "
                  "Preview deliverable rules")
    finally:
        if args.keep_work:
            print(f"  work dir  {tmp}")
        else:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
