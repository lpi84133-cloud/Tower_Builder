#!/usr/bin/env python3
"""Re-encode the delivered art and give it a light Tower Builder grade.

The raw drop is shared with other titles built from the same art pack, so every
shared sprite is re-encoded here at its own quality with a small grade on top,
which is enough to keep our copies byte-distinct from any other build.

The grade is deliberately gentle: the playfield has to keep the painted look the
art was drawn with (warm timber, hazard-yellow rigging), so nothing here rotates
hue or flips a sprite the player reads up close. Only the two background layers
are mirrored, where the change is invisible in motion.

Originals are copied to ``tool/_raw/`` once (never bundled) so the pass stays
reversible and can be re-run from clean sources.

Run: ``python tool/regrade_art.py``
"""

from __future__ import annotations

import os
import shutil

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir))
ASSETS = os.path.join(ROOT, "assets")
RAW = os.path.join(ROOT, "tool", "_raw")


def _stash(rel: str) -> str:
    """Copy the untouched source into tool/_raw once; return the working path."""
    src = os.path.join(ASSETS, rel)
    backup = os.path.join(RAW, rel.replace("\\", "/").replace("/", "__"))
    os.makedirs(RAW, exist_ok=True)
    if not os.path.exists(backup):
        shutil.copy2(src, backup)
    return backup


def tint(img: Image.Image, colour: tuple[int, int, int], amount: float) -> Image.Image:
    """Blend a flat colour over the sprite, keeping the original alpha."""
    rgba = img.convert("RGBA")
    alpha = rgba.getchannel("A")
    layer = Image.new("RGB", rgba.size, colour)
    blended = Image.blend(rgba.convert("RGB"), layer, amount).convert("RGBA")
    blended.putalpha(alpha)
    return blended


def grade(img: Image.Image, saturation=1.0, contrast=1.0, brightness=1.0) -> Image.Image:
    out = img.convert("RGBA")
    if saturation != 1.0:
        out = ImageEnhance.Color(out).enhance(saturation)
    if contrast != 1.0:
        out = ImageEnhance.Contrast(out).enhance(contrast)
    if brightness != 1.0:
        out = ImageEnhance.Brightness(out).enhance(brightness)
    return out


def mirror(img: Image.Image) -> Image.Image:
    return img.transpose(Image.FLIP_LEFT_RIGHT)


def dekey(img: Image.Image, thresh: int = 20, feather: float = 1.4) -> Image.Image:
    """Knock out the flat dark backdrop the logotype was delivered on.

    The fill is flooded inward from the four corners, so only background that
    actually touches an edge is removed: the dark plate *inside* the logo's stone
    frame is enclosed and stays put. The resulting edge is feathered by a pixel
    or so, otherwise the cut reads as jagged over the app's grid backdrop.

    The threshold has to stay well under the plate's own luminance (~32-45): the
    card is pure black, and anything looser walks through a seam in the stone
    frame and eats the plate behind the lettering.
    """
    rgb = img.convert("RGB")
    # Cap below 255 so the flood's own fill value is unambiguous afterwards.
    key = rgb.convert("L").point(lambda p: min(p, 254))
    for corner in ((0, 0), (key.width - 1, 0), (0, key.height - 1),
                   (key.width - 1, key.height - 1)):
        ImageDraw.floodfill(key, corner, 255, thresh=thresh)

    hole = key.point(lambda p: 0 if p == 255 else 255).filter(
        ImageFilter.GaussianBlur(feather))
    out = rgb.convert("RGBA")
    out.putalpha(hole)
    return out


def trim(img: Image.Image) -> Image.Image:
    """Crop fully transparent margins away.

    The renderer stretches each module across a fixed footprint, so any padding
    baked into the sprite shrinks the facade on screen and leaves the crane's
    slings ending in empty pixels beside it. Cropping to the painted content
    makes the drawn box and the facade the same thing.
    """
    rgba = img.convert("RGBA")
    solid = rgba.getchannel("A").point(lambda p: 255 if p > 8 else 0)
    box = solid.getbbox()
    return rgba if box is None else rgba.crop(box)


def frost(
    img: Image.Image,
    box: tuple[float, float, float, float],
    radius: int = 16,
    feather: int = 24,
) -> Image.Image:
    """Blur a fractional region of the sprite as if behind reflective glazing.

    ``box`` is (left, top, right, bottom) in 0..1 units. Used to turn detailed
    shop interiors into anonymous glass so the sprite reads as a bare shell.
    """
    rgba = img.convert("RGBA")
    w, h = rgba.size
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rectangle(
        (box[0] * w, box[1] * h, box[2] * w, box[3] * h), fill=255
    )
    mask = mask.filter(ImageFilter.GaussianBlur(feather))
    return Image.composite(rgba.filter(ImageFilter.GaussianBlur(radius)), rgba, mask)


def save(img: Image.Image, rel: str, quality: int = 92) -> None:
    path = os.path.join(ASSETS, rel)
    img.convert("RGBA").save(path, "WEBP", quality=quality, method=5)
    print(f"  regraded {rel}  ({os.path.getsize(path) // 1024} KiB)")


def process(rel: str, fn, quality: int = 92) -> None:
    backup = _stash(rel)
    save(fn(Image.open(backup).convert("RGBA")), rel, quality)


def main() -> None:
    print("re-encoding art with the Tower Builder grade")

    # Crane rigging: hazard-yellow stays hazard-yellow, it is the one sprite the
    # eye tracks every hoist. Re-encode with a touch more bite only.
    process("art/site/crane_hook.webp",
            lambda im: grade(im, saturation=1.04, contrast=1.05), quality=90)

    # Facade modules. These are what the player stares at all run, so the timber
    # and brick keep their painted colour; each file just gets its own small
    # grade and its own encode quality.
    process("art/site/module_01.webp",
            lambda im: grade(trim(im), saturation=1.03, contrast=1.04), quality=84)
    process("art/site/module_02.webp",
            lambda im: grade(trim(im), saturation=1.02, contrast=1.03, brightness=1.01),
            quality=86)
    process("art/site/module_03.webp",
            lambda im: grade(trim(im), saturation=1.04, brightness=1.02), quality=88)
    process("art/site/module_04.webp",
            lambda im: grade(trim(im), saturation=1.03, contrast=1.05), quality=90)

    # Foundation shell: the delivered sprite is a lit drinks shop. The glazing is
    # frosted just enough that no bottles can be made out — an alcohol flag on
    # top of an already 18+ rating is not worth it — while the green joinery and
    # the lamps stay exactly as painted, since this unit anchors the tower.
    process("art/site/foundation_pad.webp",
            lambda im: grade(frost(im, (0.13, 0.26, 0.87, 0.74), radius=13, feather=18),
                             saturation=1.02, contrast=1.03),
            quality=90)

    # Clouds: mirrored, which nothing reads as a change once they are drifting.
    process("art/site/cloud_a.webp",
            lambda im: grade(mirror(im), brightness=1.01), quality=88)
    process("art/site/cloud_b.webp",
            lambda im: grade(mirror(im), brightness=1.01), quality=90)

    # Ground skyline: mirrored street, same daylight grade as drawn.
    process("art/site/skyline_strip.webp",
            lambda im: grade(mirror(im), saturation=1.03, contrast=1.03),
            quality=90)

    # Logotype: delivered as a square on a solid black card, which shows up as a
    # black box over the app's backdrop. The card is keyed out and cropped away,
    # then the logo is cooled slightly and re-encoded to keep our copy distinct.
    process("art/shell/wordmark.webp",
            lambda im: grade(trim(dekey(im)), saturation=1.05, contrast=1.04),
            quality=88)

    # Warning-tape plate behind the main site action. The gold has to stay gold
    # for the button to read, so this is a re-encode with a touch more bite.
    process("art/shell/plate_blank.webp",
            lambda im: grade(im, saturation=1.06, contrast=1.05, brightness=0.98),
            quality=86)

    print("regrade complete")


if __name__ == "__main__":
    main()
