#!/usr/bin/env python3
import argparse
import hashlib
import json
import math
import shutil
import struct
import subprocess
import tempfile
import wave
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[2]
PROTOCOL_DIR = REPO_ROOT / ".context/benchmarks/model-roi/task-parallelism"
ASSETS_DIR = PROTOCOL_DIR / "assets"
PRIMITIVES_PATH = ASSETS_DIR / "source/primitives.json"
FFMPEG_VERSION = "6.1.1-3ubuntu5"


def canonical_json(value: object) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode()


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run_ffmpeg(arguments: list[str]) -> None:
    completed = subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *arguments],
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode:
        raise RuntimeError(completed.stderr.strip() or "ffmpeg failed")


def verify_ffmpeg() -> None:
    first_line = subprocess.check_output(["ffmpeg", "-version"], text=True).splitlines()[0]
    if first_line.split()[2] != FFMPEG_VERSION:
        raise RuntimeError(f"ffmpeg {FFMPEG_VERSION} required, found {first_line}")


def write_wave(path: Path, frequency: float, duration_ms: int, volume: float) -> None:
    sample_rate = 44100
    frames = int(sample_rate * duration_ms / 1000)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(sample_rate)
        samples = bytearray()
        for index in range(frames):
            envelope = min(1.0, index / 220.0, (frames - index) / 440.0)
            value = int(32767 * volume * envelope * math.sin(2 * math.pi * frequency * index / sample_rate))
            samples.extend(struct.pack("<h", value))
        output.writeframes(bytes(samples))


def write_music(path: Path, frequency: float) -> None:
    with tempfile.TemporaryDirectory(prefix="vector-siege-audio-") as temp:
        source = Path(temp) / "source.wav"
        write_wave(source, frequency, 2000, 0.16)
        path.parent.mkdir(parents=True, exist_ok=True)
        run_ffmpeg([
            "-i", str(source), "-map_metadata", "-1", "-c:a", "libmp3lame",
            "-b:a", "96k", "-write_xing", "0", "-id3v2_version", "0", str(path),
        ])


def rgba(hex_color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    value = hex_color.lstrip("#")
    return tuple(int(value[index:index + 2], 16) for index in (0, 2, 4)) + (alpha,)


def write_pam(path: Path, width: int, height: int, background: tuple[int, int, int, int], accent: tuple[int, int, int, int]) -> None:
    pixels = bytearray(background * (width * height))
    center_x, center_y = width // 2, height // 2
    radius = max(4, min(width, height) // 3)
    for y in range(height):
        for x in range(width):
            diamond = abs(x - center_x) + abs(y - center_y) <= radius
            border = x < 4 or y < 4 or x >= width - 4 or y >= height - 4
            if diamond or border:
                offset = (y * width + x) * 4
                pixels[offset:offset + 4] = bytes(accent)
    header = f"P7\nWIDTH {width}\nHEIGHT {height}\nDEPTH 4\nMAXVAL 255\nTUPLTYPE RGB_ALPHA\nENDHDR\n".encode()
    path.write_bytes(header + pixels)


def write_webp(path: Path, width: int, height: int, background: tuple[int, int, int, int], accent: tuple[int, int, int, int]) -> None:
    with tempfile.TemporaryDirectory(prefix="vector-siege-visual-") as temp:
        source = Path(temp) / "source.pam"
        write_pam(source, width, height, background, accent)
        path.parent.mkdir(parents=True, exist_ok=True)
        run_ffmpeg([
            "-i", str(source), "-map_metadata", "-1", "-frames:v", "1",
            "-c:v", "libwebp", "-lossless", "1", "-compression_level", "6",
            "-preset", "drawing", str(path),
        ])


def media_type(path: Path) -> str:
    return {
        ".json": "application/json",
        ".mp3": "audio/mpeg",
        ".wav": "audio/wav",
        ".webp": "image/webp",
    }[path.suffix]


def generate(output_dir: Path) -> None:
    verify_ffmpeg()
    primitives = json.loads(PRIMITIVES_PATH.read_text(encoding="utf-8"))
    source_path = output_dir / "source/primitives.json"
    source_path.parent.mkdir(parents=True, exist_ok=True)
    source_path.write_bytes(canonical_json(primitives))

    for item in primitives["audio"]:
        target = output_dir / item["path"]
        if target.suffix == ".mp3":
            write_music(target, item["frequency_hz"])
        else:
            write_wave(target, item["frequency_hz"], item["duration_ms"], item["volume"])

    background = rgba(primitives["palette"]["background"])
    transparent = rgba("#000000", 0)
    for item in primitives["visuals"]:
        canvas = background if item["opaque"] else transparent
        write_webp(output_dir / item["path"], item["width"], item["height"], canvas, rgba(item["accent"]))

    palette_path = output_dir / "visuals/palette.json"
    palette_path.write_bytes(canonical_json(primitives["palette"]))
    for atlas in primitives["atlases"]:
        frames = {
            f"frame-{index}": {
                "frame": {"x": index * atlas["frame_width"], "y": 0, "w": atlas["frame_width"], "h": atlas["frame_height"]},
                "pivot": {"x": 0.5, "y": 0.5},
            }
            for index in range(atlas["frames"])
        }
        (output_dir / atlas["json_path"]).write_bytes(canonical_json({"frames": frames, "meta": {"image": Path(atlas["path"]).name, "scale": "1"}}))

    visual_files = sorted(path for path in (output_dir / "visuals").rglob("*") if path.is_file() and path.name != "manifest.json")
    visual_manifest = {
        "schema_version": "vector-siege-visual-manifest.v1",
        "provenance": "repository-owned programmatic placeholder shapes; no model or provider call",
        "assets": [
            {"path": str(path.relative_to(output_dir / "visuals")), "sha256": sha256(path), "bytes": path.stat().st_size}
            for path in visual_files
        ],
    }
    (output_dir / "visuals/manifest.json").write_bytes(canonical_json(visual_manifest))

    all_files = sorted(path for path in output_dir.rglob("*") if path.is_file() and path.name != "manifest.json")
    all_files.append(output_dir / "visuals/manifest.json")
    all_files.sort()
    manifest = {
        "schema_version": "task-parallelism-assets.v1",
        "generator": "generate-placeholder-assets.py",
        "ffmpeg_version": FFMPEG_VERSION,
        "provenance": "deterministic local placeholders from repository-owned primitives; no model, media provider, network, or Cloudflare operation",
        "assets": [
            {
                "path": str(path.relative_to(output_dir)),
                "media_type": media_type(path),
                "bytes": path.stat().st_size,
                "sha256": sha256(path),
            }
            for path in all_files
        ],
    }
    (output_dir / "manifest.json").write_bytes(canonical_json(manifest))


def compare_directories(expected: Path, actual: Path) -> None:
    expected_files = sorted(path.relative_to(expected) for path in expected.rglob("*") if path.is_file())
    actual_files = sorted(path.relative_to(actual) for path in actual.rglob("*") if path.is_file())
    if expected_files != actual_files:
        raise RuntimeError("asset bundle file list differs from regenerated output")
    mismatches = [str(path) for path in expected_files if (expected / path).read_bytes() != (actual / path).read_bytes()]
    if mismatches:
        raise RuntimeError(f"asset bundle differs: {', '.join(mismatches)}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.check:
        with tempfile.TemporaryDirectory(prefix="task-parallelism-assets-") as temp:
            regenerated = Path(temp) / "assets"
            generate(regenerated)
            compare_directories(ASSETS_DIR, regenerated)
        print("asset bundle is byte-stable")
        return 0

    preserved_source = PRIMITIVES_PATH.read_bytes()
    if ASSETS_DIR.exists():
        shutil.rmtree(ASSETS_DIR)
    PRIMITIVES_PATH.parent.mkdir(parents=True, exist_ok=True)
    PRIMITIVES_PATH.write_bytes(preserved_source)
    generate(ASSETS_DIR)
    print(f"generated deterministic assets under {ASSETS_DIR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
