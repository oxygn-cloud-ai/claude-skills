#!/usr/bin/env python3
"""Generate a subtle background image with the session name as a watermark."""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

WIDTH, HEIGHT = 1920, 1080
BG_COLOR = (255, 255, 255)  # white
TEXT_OPACITY = 40  # 0-255, subtle watermark

# Muted accent colors per-session (used for a thin stripe or tint)
ACCENTS = [
    (100, 40, 40),   # deep red
    (40, 90, 110),   # teal
    (90, 55, 110),   # purple
    (40, 90, 55),    # forest green
    (110, 85, 30),   # amber
    (55, 55, 110),   # navy
    (100, 45, 75),   # mauve
    (40, 100, 100),  # cyan
    (90, 75, 40),    # olive
    (75, 40, 90),    # violet
    (45, 85, 45),    # green
    (100, 55, 40),   # rust
]

FONT_CANDIDATES = [
    "/System/Library/Fonts/Menlo.ttc",
    "/System/Library/Fonts/Monaco.ttf",
]


def get_font(size):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    return ImageFont.load_default()


def generate(label, output_path, index=0):
    img = Image.new("RGB", (WIDTH, HEIGHT), BG_COLOR)
    draw = ImageDraw.Draw(img, "RGBA")

    # Large centered watermark text
    font_size = 160
    font = get_font(font_size)
    bbox = draw.textbbox((0, 0), label, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]

    # Scale down if text is wider than image
    while tw > WIDTH - 100 and font_size > 40:
        font_size -= 10
        font = get_font(font_size)
        bbox = draw.textbbox((0, 0), label, font=font)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]

    x = (WIDTH - tw) // 2
    y = (HEIGHT - th) // 2

    accent = ACCENTS[index % len(ACCENTS)]
    text_color = (max(accent[0] - 20, 0), max(accent[1] - 20, 0), max(accent[2] - 20, 0), TEXT_OPACITY)
    draw.text((x, y), label, fill=text_color, font=font)

    # Thin accent stripe at top (3px)
    stripe_color = (*accent, 120)
    draw.rectangle([(0, 0), (WIDTH, 3)], fill=stripe_color)

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    img.save(output_path, "PNG")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <label> <output_path> [index]", file=sys.stderr)
        sys.exit(1)
    label = sys.argv[1]
    output_path = sys.argv[2]
    index = int(sys.argv[3]) if len(sys.argv) > 3 else 0
    generate(label, output_path, index)
