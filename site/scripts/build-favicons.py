#!/usr/bin/env python3
"""Build opaque favicon PNG/ICO/SVG assets from favicon-mark.svg."""

from __future__ import annotations

import struct
import subprocess
import sys
from pathlib import Path

from PIL import Image

BRAND = "#05083D"
BRAND_LIGHT = "#f4f1ea"
TEXT = "#16140f"
WHITE = "#FFFFFF"
CANVAS = 512
MARK_INSET = 72


def render_mark(site_dir: Path, foreground: str, width: int) -> Image.Image:
    script = site_dir / "scripts" / "render-mark.mjs"
    mark = site_dir / "favicon-mark.svg"
    result = subprocess.run(
        ["node", str(script), str(mark), str(width), foreground],
        check=True,
        capture_output=True,
    )
    from io import BytesIO

    return Image.open(BytesIO(result.stdout)).convert("RGBA")


def composite(background: str, mark: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", (CANVAS, CANVAS), background)
    mark_size = CANVAS - MARK_INSET * 2
    mark = mark.resize((mark_size, mark_size), Image.Resampling.LANCZOS)
    canvas.paste(mark, (MARK_INSET, MARK_INSET), mark)
    return canvas


def write_svg(path: Path, background: str, foreground: str, mark_svg: str) -> None:
    import re

    viewbox = re.search(r'viewBox="([^"]+)"', mark_svg)
    if not viewbox:
        raise ValueError("favicon-mark.svg is missing a viewBox")
    vb = viewbox.group(1)
    vb_parts = [float(v) for v in vb.split()]
    mark_width = vb_parts[2]

    inner = mark_svg.split("<svg", 1)[1]
    inner = inner.split(">", 1)[1]
    inner = inner.rsplit("</svg>", 1)[0].strip()

    path.write_text(
        f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {CANVAS} {CANVAS}">
  <rect width="{CANVAS}" height="{CANVAS}" fill="{background}"/>
  <g transform="translate({MARK_INSET} {MARK_INSET}) scale({(CANVAS - MARK_INSET * 2) / mark_width})">
    <svg viewBox="{vb}">
      {inner.replace('fill="currentColor"', f'fill="{foreground}"')}
    </svg>
  </g>
</svg>
''',
        encoding="utf-8",
    )


def encode_ico(png_path: Path, ico_path: Path) -> None:
    png_buffer = png_path.read_bytes()
    header = struct.pack("<HHH", 0, 1, 1)
    entry = struct.pack("<BBBBHHII", 16, 16, 0, 0, 1, 32, len(png_buffer), 6 + 16)
    ico_path.write_bytes(header + entry + png_buffer)


def count_foreground_pixels(image: Image.Image) -> int:
    return sum(1 for r, g, b, a in image.getdata() if a > 128 and (r > 180 or g > 180))


def main() -> int:
    site_dir = Path(sys.argv[1])
    mark_svg = (site_dir / "favicon-mark.svg").read_text(encoding="utf-8")

    dark_canvas = composite(BRAND, render_mark(site_dir, WHITE, 368))
    light_canvas = composite(BRAND_LIGHT, render_mark(site_dir, TEXT, 368))

    write_svg(site_dir / "favicon.svg", BRAND, WHITE, mark_svg)
    write_svg(site_dir / "favicon-light.svg", BRAND_LIGHT, TEXT, mark_svg)

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
        dark_canvas.resize((size, size), Image.Resampling.LANCZOS).save(site_dir / name)

    light_canvas.resize((32, 32), Image.Resampling.LANCZOS).save(site_dir / "favicon-light-32x32.png")
    encode_ico(site_dir / "favicon-16x16.png", site_dir / "favicon.ico")

    sample = dark_canvas.resize((32, 32), Image.Resampling.LANCZOS)
    foreground = count_foreground_pixels(sample)
    if foreground < 20:
        raise SystemExit(f"generated favicon mark is too small ({foreground} px)")
    print(f"built favicons with logo o mark (32px has {foreground} foreground pixels)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
