#!/usr/bin/env python3
"""Derive launcher-icon and splash artwork from the master brand mark.

Inputs (checked into ``tool/_raw/``):
  * ``brand_mark.png``  - 1:1 master icon, opaque navy blueprint background.
  * ``wordmark.webp``   - the game's logotype, on a solid black card.

Outputs (into ``tool/branding/``, i.e. build-time only - never bundled):
  * ``launcher.png``          - legacy square launcher icon.
  * ``launcher_fg.png``       - adaptive foreground: the mark inside a feathered
                                disc, inset into the safe zone.
  * ``splash.png``            - logotype for the native splash.
  * ``splash_android12.png``  - centred mark for the Android 12+ splash slot.

The master's own background is a radial navy gradient, so the adaptive layers are
built by discing out its centre and pairing it with a flat navy plate sampled from
the master's corner: the two navies meet, which hides the seam without needing a
hand-authored cut-out of the subject.

Run: ``python tool/gen_branding.py``
"""

from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageFilter

# Same keying pass the bundled logotype goes through, so the splash and the boot
# screen cannot drift apart.
from regrade_art import dekey, trim

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir))
RAW = os.path.join(ROOT, "tool", "_raw")
OUT = os.path.join(ROOT, "tool", "branding")

MASTER = os.path.join(RAW, "brand_mark.png")
WORDMARK = os.path.join(RAW, "wordmark.webp")


def _disc(img: Image.Image, feather: int = 10) -> Image.Image:
    """Mask ``img`` to a centred circle with a feathered edge."""
    w, h = img.size
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, w - 1, h - 1), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(feather))
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def _plate_colour(img: Image.Image) -> tuple[int, int, int]:
    """Average the master's corners — the flat navy the disc has to sit on."""
    w, h = img.size
    pad = max(2, w // 40)
    spots = [(pad, pad), (w - pad, pad), (pad, h - pad), (w - pad, h - pad)]
    px = img.convert("RGB").load()
    samples = [px[min(x, w - 1), min(y, h - 1)] for x, y in spots]
    return tuple(sum(c[i] for c in samples) // len(samples) for i in range(3))  # type: ignore[return-value]


def _fit(subject: Image.Image, canvas: int, coverage: float) -> Image.Image:
    """Centre ``subject`` on a transparent square, occupying ``coverage`` of it."""
    target = int(canvas * coverage)
    scaled = subject.copy()
    scaled.thumbnail((target, target), Image.LANCZOS)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    out.alpha_composite(scaled, ((canvas - scaled.width) // 2, (canvas - scaled.height) // 2))
    return out


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    master = Image.open(MASTER).convert("RGBA")
    side = min(master.size)
    master = master.crop((
        (master.width - side) // 2, (master.height - side) // 2,
        (master.width + side) // 2, (master.height + side) // 2,
    )).resize((1024, 1024), Image.LANCZOS)

    master.save(os.path.join(OUT, "launcher.png"))
    print("  launcher.png            1024x1024")

    plate = _plate_colour(master)
    Image.new("RGBA", (1024, 1024), plate + (255,)).save(
        os.path.join(OUT, "launcher_bg.png"))
    print(f"  launcher_bg.png         flat #{plate[0]:02X}{plate[1]:02X}{plate[2]:02X}")

    # Adaptive foregrounds get cropped to a circle by many launchers, so the mark
    # is discked and inset well inside the safe zone.
    badge = _disc(master.resize((880, 880), Image.LANCZOS))
    _fit(badge, 1024, 0.74).save(os.path.join(OUT, "launcher_fg.png"))
    print("  launcher_fg.png         1024x1024 (74% safe zone)")

    # The logotype ships on a solid black card; keyed out here for the same
    # reason as in the bundle, so the splash shows a logo and not a black box.
    wordmark = trim(dekey(Image.open(WORDMARK)))
    splash = Image.new("RGBA", (1152, 1152), (0, 0, 0, 0))
    scaled = wordmark.copy()
    scaled.thumbnail((1000, 1000), Image.LANCZOS)
    splash.alpha_composite(scaled, ((1152 - scaled.width) // 2, (1152 - scaled.height) // 2))
    splash.save(os.path.join(OUT, "splash.png"))
    print("  splash.png              1152x1152")

    _fit(_disc(master.resize((760, 760), Image.LANCZOS)), 960, 0.66).save(
        os.path.join(OUT, "splash_android12.png"))
    print("  splash_android12.png    960x960")


if __name__ == "__main__":
    main()
