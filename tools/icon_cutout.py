"""Cuts icon art (an object on a plain, solid background of any color) out to a transparent 512 px
PNG for IconAssets.Color.

    python tools/icon_cutout.py <source image> <output png> [--outline]

Background = areas close to the border color that touch the border, plus enclosed pockets of that
color (e.g. inside a ring) too big to be a detail. --outline adds the thick navy outline of the
gvesster icon pack, for art drawn without one.
"""

import sys

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

SIZE = 512
# A pixel is background when every channel is within this of the border color.
TOLERANCE = 24
# Enclosed background-colored pockets bigger than this share of the image are background too.
POCKET_SHARE = 0.0012
MARGIN = 0.05
OUTLINE_COLOR = (4, 4, 53)
# Outline thickness as a share of the output size (the gvesster icons' outline).
OUTLINE_SHARE = 0.044


def background_mask(rgb: np.ndarray) -> np.ndarray:
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    color = np.median(border, axis=0)
    close = np.abs(rgb - color).max(axis=2) <= TOLERANCE

    labels, count = ndimage.label(close)
    edge = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]])))
    sizes = ndimage.sum(close, labels, range(1, count + 1))
    pocket = POCKET_SHARE * close.size
    ids = [i for i in range(1, count + 1) if i in edge or sizes[i - 1] >= pocket]
    # Grow by a pixel to eat the anti-aliased fringe blended with the background color.
    return ndimage.binary_dilation(np.isin(labels, ids), iterations=1)


def add_outline(icon: Image.Image) -> Image.Image:
    alpha = np.asarray(icon.split()[3]) > 127
    radius = max(1, round(icon.width * OUTLINE_SHARE))
    yy, xx = np.ogrid[-radius : radius + 1, -radius : radius + 1]
    grown = ndimage.binary_dilation(alpha, structure=xx * xx + yy * yy <= radius * radius)
    ring = Image.fromarray((grown * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))
    outlined = Image.new("RGBA", icon.size, OUTLINE_COLOR + (0,))
    outlined.putalpha(ring)
    outlined.alpha_composite(icon)
    return outlined


def cutout(source: str, target: str, outline: bool) -> None:
    image = Image.open(source).convert("RGB")
    background = background_mask(np.asarray(image).astype(np.int16))
    alpha = Image.fromarray(np.where(background, 0, 255).astype(np.uint8))
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.8))

    rgba = image.copy()
    rgba.putalpha(alpha)
    box = alpha.point(lambda v: 255 if v > 16 else 0).getbbox()
    if box:
        rgba = rgba.crop(box)
    side = max(rgba.size)
    # Room for the outline as well as the margin.
    pad = MARGIN * 2 + (OUTLINE_SHARE * 2.2 if outline else 0)
    canvas_side = int(side * (1 + pad))
    canvas = Image.new("RGBA", (canvas_side, canvas_side), (0, 0, 0, 0))
    canvas.paste(rgba, ((canvas_side - rgba.width) // 2, (canvas_side - rgba.height) // 2))
    icon = canvas.resize((SIZE, SIZE), Image.LANCZOS)
    if outline:
        icon = add_outline(icon)
    icon.save(target)


if __name__ == "__main__":
    args = [arg for arg in sys.argv[1:] if not arg.startswith("--")]
    cutout(args[0], args[1], "--outline" in sys.argv)
