#!/usr/bin/env python3
"""Generate a 1024x1024 BayWave AppIcon PNG matching the in-app LogoMark:
amber ground, navy serif 'B', small accent dot at top-right.
"""

import os
import pathlib
from PIL import Image, ImageDraw, ImageFont

SIZE = 1024
AMBER = (0xE8, 0xA3, 0x3D)
NAVY = (0x05, 0x0B, 0x17)

OUT = pathlib.Path(__file__).resolve().parent.parent / "BayWave" / "BayWave" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"


def find_serif_font(size: int) -> ImageFont.FreeTypeFont:
    candidates = [
        "/System/Library/Fonts/NewYork.ttf",
        "/System/Library/Fonts/Supplemental/Georgia Bold.ttf",
        "/System/Library/Fonts/Supplemental/Georgia.ttf",
        "/Library/Fonts/Georgia.ttf",
        "/System/Library/Fonts/Times.ttc",
    ]
    for p in candidates:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                continue
    return ImageFont.load_default()


def main() -> None:
    img = Image.new("RGBA", (SIZE, SIZE), NAVY + (255,))
    draw = ImageDraw.Draw(img)

    # Filled amber rounded square fills the whole icon (iOS rounds the corners at render time).
    draw.rectangle([0, 0, SIZE, SIZE], fill=AMBER)

    # Big "B" in serif, navy, centered.
    font = find_serif_font(int(SIZE * 0.7))
    text = "B"
    # Measure with textbbox for accurate centering.
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (SIZE - tw) // 2 - bbox[0]
    y = (SIZE - th) // 2 - bbox[1] - int(SIZE * 0.02)  # nudge up a touch
    draw.text((x, y), text, fill=NAVY, font=font)

    # Accent dot: small navy disc near top-right with an amber core.
    dot_cx, dot_cy = int(SIZE * 0.82), int(SIZE * 0.18)
    outer_r = int(SIZE * 0.065)
    inner_r = int(SIZE * 0.028)
    draw.ellipse(
        [dot_cx - outer_r, dot_cy - outer_r, dot_cx + outer_r, dot_cy + outer_r],
        fill=NAVY,
    )
    draw.ellipse(
        [dot_cx - inner_r, dot_cy - inner_r, dot_cx + inner_r, dot_cy + inner_r],
        fill=AMBER,
    )

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, format="PNG")
    print(f"wrote {OUT} ({SIZE}×{SIZE})")


if __name__ == "__main__":
    main()
