#!/usr/bin/env python3
"""Build opaque favicon PNG/ICO/SVG assets."""

from __future__ import annotations

import struct
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

BRAND = "#05083D"
BRAND_LIGHT = "#f4f1ea"
TEXT = "#16140f"
WHITE = "#FFFFFF"
CANVAS = 512

FONT_CANDIDATES = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf",
]


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in FONT_CANDIDATES:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def render_favicon(size: int, background: str, foreground: str) -> Image.Image:
    image = Image.new("RGBA", (size, size), background)
    draw = ImageDraw.Draw(image)
    font = load_font(max(8, int(size * 0.78)))
    text = "C"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    x = (size - text_width) / 2 - bbox[0]
    y = (size - text_height) / 2 - bbox[1] - size * 0.04
    draw.text((x, y), text, fill=foreground, font=font)
    return image


def write_svg(path: Path, background: str, foreground: str) -> None:
    path.write_text(
        f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {CANVAS} {CANVAS}">
  <rect width="{CANVAS}" height="{CANVAS}" fill="{background}"/>
  <text
    x="256"
    y="340"
    text-anchor="middle"
    font-family="system-ui, -apple-system, BlinkMacSystemFont, sans-serif"
    font-size="348"
    font-weight="700"
    fill="{foreground}">C</text>
</svg>
''',
        encoding="utf-8",
    )


def encode_ico(png_path: Path, ico_path: Path) -> None:
    png_buffer = png_path.read_bytes()
    header = struct.pack("<HHH", 0, 1, 1)
    entry = struct.pack("<BBBBHHII", 16, 16, 0, 0, 1, 32, len(png_buffer), 6 + 16)
    ico_path.write_bytes(header + entry + png_buffer)


def main() -> int:
    site_dir = Path(sys.argv[1])

    write_svg(site_dir / "favicon.svg", BRAND, WHITE)
    write_svg(site_dir / "favicon-light.svg", BRAND_LIGHT, TEXT)

    png_targets = {
        "favicon-16x16.png": 16,
        "favicon-32x32.png": 32,
        "favicon-48x48.png": 48,
        "favicon-64x64.png": 64,
        "favicon-128x128.png": 128,
        "favicon-180x180.png": 180,
        "favicon-192x192.png": 192,
        "favicon-256x256.png": 256,
        "favicon-512x512.png": 512,
        "apple-touch-icon.png": 180,
        "android-chrome-192x192.png": 192,
        "android-chrome-512x512.png": 512,
    }

    for name, size in png_targets.items():
        render_favicon(size, BRAND, WHITE).save(site_dir / name)

    render_favicon(32, BRAND_LIGHT, TEXT).save(site_dir / "favicon-light-32x32.png")
    encode_ico(site_dir / "favicon-16x16.png", site_dir / "favicon.ico")

    sample = render_favicon(32, BRAND, WHITE)
    white = sum(1 for px in sample.getdata() if px[0] > 200)
    if white < 20:
        raise SystemExit("generated favicon mark is too small")
    print(f"built favicons (32px mark has {white} foreground pixels)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
