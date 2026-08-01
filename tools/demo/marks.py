#!/usr/bin/env python3
"""
marks.py -- turn a scenario's timing marks into cuts, screenshots, manifests.

The scenarios in integration_test/demo/ report a list of marks through the
Flutter driver. Each mark carries a scenario-relative timestamp, a label, and
optionally a caption. This script maps those onto the raw screen recording.

Three subcommands:

  cut       Trim the install/launch lead-in and EXCISE every blindfold span
            (frames where a mnemonic was on screen), producing a clip that is
            safe to publish.

  shots     Pull store screenshots at native device resolution, one per
            captioned mark. Frames are taken from the MIDDLE of each hold
            rather than at its leading edge, which makes alignment robust
            against the ~0.5s of encoder start-up jitter.

  manifest  Assemble the per-scenario clips into a reel.py manifest.

TIME BASE
    recstart              device-clock epoch (ms) read just before
                          `adb shell screenrecord` was launched
    started_at_epoch_ms   device-clock epoch (ms) at scenario start

    video_time(mark) = (started_at_epoch_ms - recstart)/1000 + mark.at
                       - LEAD_CORRECTION

    Both epochs come from the DEVICE clock, so host/guest skew cannot break
    alignment. LEAD_CORRECTION absorbs the small delay between launching
    screenrecord and the encoder producing its first frame.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

# Seconds between `screenrecord` being launched and it emitting frame 0.
# Measured empirically on the x86_64 emulator; override with --lead-correction.
LEAD_CORRECTION = 0.45

# Safety margin applied around every blindfold span. A span boundary lands on a
# mark, and the frames immediately either side can still show the tail of a
# seed screen (or its dismiss animation). Used by BOTH the cut and the
# screenshot paths -- they must agree, or a screenshot can land in a region the
# video cut treated as unsafe.
BLINDFOLD_PAD = 0.6


def run(cmd: list[str]) -> None:
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        sys.stderr.write(r.stderr[-3000:])
        raise SystemExit(f"command failed: {' '.join(str(c) for c in cmd[:8])} ...")


def probe_duration(path: Path) -> float:
    r = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nk=1:nw=1", str(path)],
        capture_output=True, text=True,
    )
    try:
        return float(r.stdout.strip())
    except ValueError:
        raise SystemExit(f"cannot probe {path}")


def load_demo(marks_path: Path | None) -> dict | None:
    """Read the `demo` block out of the driver's response JSON."""
    if not marks_path or not marks_path.exists():
        return None
    try:
        data = json.loads(marks_path.read_text())
    except json.JSONDecodeError:
        return None
    if not data:
        return None
    demo = data.get("demo")
    # integrationDriver nests per-test results; dig one level if needed.
    if demo is None:
        for v in data.values():
            if isinstance(v, dict) and "demo" in v:
                demo = v["demo"]
                break
            if isinstance(v, str):
                try:
                    inner = json.loads(v)
                    if isinstance(inner, dict) and "demo" in inner:
                        demo = inner["demo"]
                        break
                except json.JSONDecodeError:
                    continue
    return demo


def video_offset(demo: dict, recstart_path: Path | None, lead: float) -> float:
    if not recstart_path or not recstart_path.exists():
        return 0.0
    try:
        recstart = float(recstart_path.read_text().strip())
    except ValueError:
        return 0.0
    started = float(demo.get("started_at_epoch_ms") or 0)
    if not started:
        return 0.0
    return max((started - recstart) / 1000.0 - lead, 0.0)


# ---------------------------------------------------------------------------
# cut
# ---------------------------------------------------------------------------
def safe_spans(demo: dict, offset: float, duration: float) -> list[tuple[float, float]]:
    """Video-time spans that contain no mnemonic frames.

    Everything before the scenario actually starts is also dropped -- that is
    the install/launch lead-in, which is not part of the story.
    """
    blind = [
        (offset + float(s["start"]), offset + float(s["end"]))
        for s in (demo.get("blindfold_spans") or [])
    ]
    blind = [(max(a - BLINDFOLD_PAD, 0.0), min(b + BLINDFOLD_PAD, duration))
             for a, b in blind]
    blind.sort()

    spans: list[tuple[float, float]] = []
    cursor = offset
    for a, b in blind:
        if a > cursor:
            spans.append((cursor, min(a, duration)))
        cursor = max(cursor, b)
    if cursor < duration:
        spans.append((cursor, duration))
    # Drop slivers that are not worth a cut.
    return [(a, b) for a, b in spans if b - a > 0.8]


def cmd_cut(args: argparse.Namespace) -> None:
    raw = Path(args.raw)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    duration = probe_duration(raw)
    demo = load_demo(Path(args.marks) if args.marks else None)

    if demo is None:
        print("WARNING: no marks available; copying raw recording unchanged. "
              "This clip has NOT been checked for seed frames — do not publish "
              "it without watching it.", file=sys.stderr)
        run(["ffmpeg", "-y", "-v", "error", "-i", str(raw),
             "-c", "copy", "-movflags", "+faststart", str(out)])
        manifest = {"scenario": raw.stem, "verified_seed_free": False,
                    "captions": [], "duration": duration}
        Path(args.manifest).write_text(json.dumps(manifest, indent=2))
        return

    offset = video_offset(demo, Path(args.recstart) if args.recstart else None,
                          args.lead_correction)
    spans = safe_spans(demo, offset, duration)
    if not spans:
        raise SystemExit(
            f"every frame of {raw} falls inside a blindfold span — nothing "
            f"safe to publish. Check the scenario."
        )

    blind_count = len(demo.get("blindfold_spans") or [])
    tmp = out.parent / f".{out.stem}-parts"
    tmp.mkdir(exist_ok=True)
    parts = []
    for i, (a, b) in enumerate(spans):
        p = tmp / f"part{i:02d}.mp4"
        run(["ffmpeg", "-y", "-v", "error", "-ss", f"{a:.3f}", "-to", f"{b:.3f}",
             "-i", str(raw), "-an", "-c:v", "libx264", "-preset", "veryfast",
             "-crf", "18", "-pix_fmt", "yuv420p", str(p)])
        parts.append(p)

    if len(parts) == 1:
        run(["ffmpeg", "-y", "-v", "error", "-i", str(parts[0]),
             "-c", "copy", "-movflags", "+faststart", str(out)])
    else:
        listing = tmp / "concat.txt"
        listing.write_text("".join(f"file '{p.resolve()}'\n" for p in parts))
        run(["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0",
             "-i", str(listing), "-c", "copy", "-movflags", "+faststart",
             str(out)])
    for p in parts:
        p.unlink(missing_ok=True)
    (tmp / "concat.txt").unlink(missing_ok=True)
    tmp.rmdir()

    # Captions, rebased onto the CUT timeline.
    captions = []
    removed_before = 0.0
    span_idx = 0
    for m in demo.get("marks", []):
        if not m.get("caption"):
            continue
        vt = offset + float(m["at"])
        # find which safe span this mark falls in, and how much was removed
        acc = 0.0
        placed = None
        for a, b in spans:
            if a <= vt <= b:
                placed = acc + (vt - a)
                break
            acc += b - a
        if placed is not None:
            captions.append({"at": round(placed, 3), "text": m["caption"],
                             "label": m["label"]})

    manifest = {
        "scenario": demo.get("scenario", raw.stem),
        "verified_seed_free": True,
        "blindfold_spans_excised": blind_count,
        "duration": round(sum(b - a for a, b in spans), 3),
        "captions": captions,
    }
    Path(args.manifest).write_text(json.dumps(manifest, indent=2))
    print(f"cut {out.name}: {manifest['duration']:.1f}s, "
          f"{blind_count} blindfold span(s) excised, "
          f"{len(captions)} caption(s)")


# ---------------------------------------------------------------------------
# shots
# ---------------------------------------------------------------------------
def cmd_shots(args: argparse.Namespace) -> None:
    raw = Path(args.raw)
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    demo = load_demo(Path(args.marks) if args.marks else None)
    if demo is None:
        raise SystemExit(f"no marks for {raw}; cannot place screenshots")

    duration = probe_duration(raw)
    offset = video_offset(demo, Path(args.recstart) if args.recstart else None,
                          args.lead_correction)
    # Same padding the video cut uses -- otherwise a screenshot could be taken
    # from a region `cut` considered unsafe enough to excise.
    blind = [(offset + float(s["start"]) - BLINDFOLD_PAD,
              offset + float(s["end"]) + BLINDFOLD_PAD)
             for s in (demo.get("blindfold_spans") or [])]

    marks = demo.get("marks", [])
    scenario = demo.get("scenario", raw.stem)
    made = 0
    for i, m in enumerate(marks):
        if not m.get("caption"):
            continue
        start_vt = offset + float(m["at"])
        # Land in the middle of the hold, not on its edge: the next mark tells
        # us when this screen stops being on camera.
        next_vt = duration
        for later in marks[i + 1:]:
            nv = offset + float(later["at"])
            if nv > start_vt:
                next_vt = nv
                break
        at = start_vt + min((next_vt - start_vt) / 2.0, 2.5)
        at = min(at, duration - 0.2)

        if any(a <= at <= b for a, b in blind):
            print(f"  skip {m['label']}: inside a blindfold span", file=sys.stderr)
            continue

        name = f"{scenario}-{made + 1:02d}-{m['label']}.png"
        run(["ffmpeg", "-y", "-v", "error", "-ss", f"{at:.3f}", "-i", str(raw),
             "-frames:v", "1", str(outdir / name)])
        made += 1
        print(f"  {name}  @{at:.2f}s")

    print(f"{made} screenshot(s) -> {outdir}")
    if made:
        sample = next(outdir.glob(f"{scenario}-*.png"), None)
        if sample:
            dims = subprocess.run(
                ["ffprobe", "-v", "error", "-select_streams", "v:0",
                 "-show_entries", "stream=width,height", "-of", "csv=p=0:s=x",
                 str(sample)], capture_output=True, text=True).stdout.strip()
            print(f"dimensions: {dims}")
            w, h = (int(x) for x in dims.split("x"))
            if h / w > 2.0:
                print(f"WARNING: aspect {h/w:.2f}:1 exceeds Google Play's 2:1 "
                      f"maximum for phone screenshots.", file=sys.stderr)


# ---------------------------------------------------------------------------
# manifest
# ---------------------------------------------------------------------------
def cmd_manifest(args: argparse.Namespace) -> None:
    cutdir = Path(args.cutdir)
    scenarios = args.scenarios.split()
    clips = []
    unsafe = []
    for s in scenarios:
        clip = cutdir / f"{s}.mp4"
        meta = cutdir / f"{s}.manifest.json"
        if not clip.exists():
            continue
        info = json.loads(meta.read_text()) if meta.exists() else {}
        if not info.get("verified_seed_free", False):
            unsafe.append(s)
        dur = probe_duration(clip)
        caption = ""
        caps = info.get("captions") or []
        if caps:
            caption = caps[0]["text"]
        # Apple previews get no captions at all.
        if args.profile == "apple-preview":
            caption = ""
        clips.append({
            "src": str(clip),
            "caption": caption,
            "seconds": round(min(dur, args.max_clip), 2),
            "start": 0,
        })

    if not clips:
        raise SystemExit(f"no cut clips found in {cutdir}. Record something first.")

    if unsafe:
        raise SystemExit(
            "REFUSING to build a publishable master.\n"
            f"These clips were never verified seed-free: {', '.join(unsafe)}\n"
            "They were cut without driver marks, so blindfold spans could not "
            "be excised. Re-record them, or watch each one and cut by hand."
        )

    manifest = {"transition": "cross_dissolve", "clips": clips}
    if args.music:
        manifest["music"] = args.music
    Path(args.out).write_text(json.dumps(manifest, indent=2))
    total = sum(c["seconds"] for c in clips)
    print(f"manifest: {len(clips)} clip(s), ~{total:.0f}s -> {args.out}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    c = sub.add_parser("cut")
    c.add_argument("--raw", required=True)
    c.add_argument("--marks")
    c.add_argument("--recstart")
    c.add_argument("--out", required=True)
    c.add_argument("--manifest", required=True)
    c.add_argument("--lead-correction", type=float, default=LEAD_CORRECTION)
    c.set_defaults(func=cmd_cut)

    s = sub.add_parser("shots")
    s.add_argument("--raw", required=True)
    s.add_argument("--marks")
    s.add_argument("--recstart")
    s.add_argument("--outdir", required=True)
    s.add_argument("--lead-correction", type=float, default=LEAD_CORRECTION)
    s.set_defaults(func=cmd_shots)

    m = sub.add_parser("manifest")
    m.add_argument("--cutdir", required=True)
    m.add_argument("--profile", default="social")
    m.add_argument("--out", required=True)
    m.add_argument("--scenarios", required=True)
    m.add_argument("--music", default=None)
    m.add_argument("--max-clip", type=float, default=8.0)
    m.set_defaults(func=cmd_manifest)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
