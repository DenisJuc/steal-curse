"""Hand-drawn HUD icons in the gvesster pack style: flat cel fills + thick navy outline.
Drawn with Pillow (no AI). Output: 256 px transparent PNGs in assets/PackIcons.
"""

from __future__ import annotations

import math
import os
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

SIZE = 256
OUTLINE = (4, 4, 53, 255)
# Outline thickness matching gvesster (~4.4% of width ≈ 11 px per side → grow radius ~6)
OUTLINE_R = 7
OUT = Path(__file__).resolve().parents[1] / "assets" / "PackIcons"


def rgba(r: int, g: int, b: int, a: int = 255) -> tuple[int, int, int, int]:
	return (r, g, b, a)


def lighten(c: tuple[int, int, int], n: int) -> tuple[int, int, int, int]:
	return rgba(min(255, c[0] + n), min(255, c[1] + n), min(255, c[2] + n))


def darken(c: tuple[int, int, int], n: int) -> tuple[int, int, int, int]:
	return rgba(max(0, c[0] - n), max(0, c[1] - n), max(0, c[2] - n))


def new_layer() -> Image.Image:
	return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def add_outline(icon: Image.Image) -> Image.Image:
	"""Grow opaque pixels into the gvesster navy outline, then put the fill back on top."""
	alpha = np.asarray(icon.split()[3]) > 16
	yy, xx = np.ogrid[-OUTLINE_R : OUTLINE_R + 1, -OUTLINE_R : OUTLINE_R + 1]
	kernel = xx * xx + yy * yy <= OUTLINE_R * OUTLINE_R
	grown = ndimage.binary_dilation(alpha, structure=kernel)
	ring = Image.fromarray((grown * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))
	base = Image.new("RGBA", icon.size, OUTLINE[:3] + (0,))
	base.putalpha(ring)
	base.alpha_composite(icon)
	return base


def paste(dst: Image.Image, src: Image.Image):
	dst.alpha_composite(src)


def ellipse(d: ImageDraw.ImageDraw, box, fill):
	d.ellipse(box, fill=fill)


def poly(d: ImageDraw.ImageDraw, pts, fill):
	d.polygon(pts, fill=fill)


def round_rect(d: ImageDraw.ImageDraw, box, r, fill):
	d.rounded_rectangle(box, radius=r, fill=fill)


# ---------- Spirit Sight ----------
def draw_spirit_sight() -> Image.Image:
	layer = new_layer()
	d = ImageDraw.Draw(layer)
	# Almond eye
	lid = [
		(30, 128),
		(68, 82),
		(128, 64),
		(188, 82),
		(226, 128),
		(188, 174),
		(128, 192),
		(68, 174),
	]
	poly(d, lid, rgba(236, 246, 255))
	# Soft top shade
	poly(d, [(30, 128), (68, 82), (128, 64), (188, 82), (226, 128), (180, 120), (128, 108), (76, 120)], rgba(200, 220, 240))
	# Iris
	ellipse(d, (90, 90, 166, 166), rgba(70, 210, 120))
	ellipse(d, (100, 100, 156, 156), rgba(50, 180, 100))
	# Pupil + shine
	ellipse(d, (112, 112, 144, 144), rgba(22, 36, 48))
	ellipse(d, (120, 102, 134, 116), rgba(255, 255, 255, 230))
	# Spirit sparks (diamond-ish via rotated squares approximated as diamonds)
	for cx, cy, s in ((46, 68, 9), (214, 70, 8), (208, 188, 7), (52, 186, 7)):
		poly(d, [(cx, cy - s), (cx + s, cy), (cx, cy + s), (cx - s, cy)], rgba(170, 255, 95))
	return add_outline(layer)


# ---------- Pulse ----------
def draw_pulse() -> Image.Image:
	layer = new_layer()
	d = ImageDraw.Draw(layer)
	cx, cy = 128, 140
	# Dish body (tilted oval)
	ellipse(d, (40, 70, 216, 210), rgba(90, 175, 210))
	ellipse(d, (56, 86, 200, 194), rgba(60, 140, 180))
	# Inner rings
	for r in (58, 38, 20):
		box = (cx - r, cy - r - 8, cx + r, cy + r - 8)
		d.ellipse(box, outline=rgba(180, 240, 255), width=6)
	# Antenna mast
	round_rect(d, (118, 36, 138, 88), 6, rgba(220, 230, 240))
	ellipse(d, (108, 24, 148, 64), rgba(255, 90, 90))
	ellipse(d, (118, 34, 138, 54), rgba(255, 160, 140))
	# Sweep wedge on dish
	pts = [(cx, cy - 8)]
	for deg in range(-35, 40, 3):
		rad = math.radians(deg - 90)
		pts.append((cx + 70 * math.cos(rad), cy - 8 + 55 * math.sin(rad)))
	poly(d, pts, rgba(140, 255, 190, 200))
	# Blip
	ellipse(d, (150, 108, 168, 126), rgba(255, 220, 80))
	return add_outline(layer)


# ---------- Bind (ofuda + chain) ----------
def draw_bind() -> Image.Image:
	layer = new_layer()
	d = ImageDraw.Draw(layer)
	# Paper body (slight tilt via parallelogram)
	paper = [
		(78, 36),
		(178, 28),
		(186, 220),
		(70, 228),
	]
	poly(d, paper, rgba(245, 230, 195))
	poly(d, [(78, 36), (178, 28), (176, 90), (80, 98)], rgba(252, 242, 220))
	# Red seal
	ellipse(d, (96, 86, 168, 158), rgba(210, 40, 55))
	ellipse(d, (108, 98, 156, 146), rgba(235, 70, 80))
	# Seal knot
	d.line([(118, 108), (146, 136)], fill=rgba(255, 230, 230), width=10)
	d.line([(146, 108), (118, 136)], fill=rgba(255, 230, 230), width=10)
	# Ink bars
	for y, w in ((170, 70), (188, 58), (206, 64)):
		round_rect(d, (100, y, 100 + w, y + 12), 4, rgba(55, 35, 80))
	# Chain links hanging at top
	for x in (92, 148):
		ellipse(d, (x, 18, x + 28, 46), rgba(220, 190, 70))
		ellipse(d, (x + 6, 24, x + 22, 40), (0, 0, 0, 0))
		# hole: punch by drawing navy? skip — outline pass will treat hole oddly.
		# Use dark fill as "hole" instead of true hole
		ellipse(d, (x + 7, 25, x + 21, 39), rgba(40, 30, 60))
	return add_outline(layer)


# ---------- Wild (pine) ----------
def draw_wild() -> Image.Image:
	layer = new_layer()
	d = ImageDraw.Draw(layer)
	# Ground
	poly(d, [(28, 208), (50, 178), (128, 168), (206, 178), (228, 208), (228, 232), (28, 232)], rgba(90, 140, 60))
	poly(d, [(50, 178), (128, 168), (206, 178), (180, 188), (128, 182), (76, 188)], rgba(110, 165, 75))
	# Trunk
	round_rect(d, (112, 152, 144, 208), 8, rgba(130, 78, 44))
	round_rect(d, (116, 156, 128, 200), 4, rgba(155, 100, 60))
	# Tiers
	tiers = [
		([(128, 32), (58, 108), (198, 108)], (55, 175, 85), (90, 210, 120)),
		([(128, 68), (64, 142), (192, 142)], (40, 150, 70), (70, 185, 100)),
		([(128, 108), (72, 178), (184, 178)], (30, 125, 60), (55, 155, 85)),
	]
	for pts, body, hi in tiers:
		poly(d, pts, rgba(*body))
		# left highlight wedge
		mid = ((pts[0][0] + pts[1][0]) / 2, (pts[0][1] + pts[1][1]) / 2)
		poly(d, [pts[0], pts[1], mid], rgba(*hi, 180))
	return add_outline(layer)


# ---------- Pedestals (marble stand + floating spirit orb) ----------
def draw_pedestals() -> Image.Image:
	layer = new_layer()
	d = ImageDraw.Draw(layer)
	marble = (215, 210, 228)
	shade = (165, 158, 185)
	# Floating spirit orb
	ellipse(d, (96, 28, 160, 92), rgba(170, 120, 255))
	ellipse(d, (108, 40, 148, 80), rgba(210, 180, 255))
	ellipse(d, (118, 48, 134, 64), rgba(255, 255, 255, 220))
	# Small sparkles
	for cx, cy, s in ((78, 44, 6), (180, 50, 5), (88, 88, 4)):
		poly(d, [(cx, cy - s), (cx + s, cy), (cx, cy + s), (cx - s, cy)], rgba(170, 255, 95))
	# Top plinth
	poly(d, [(48, 118), (208, 118), (196, 148), (60, 148)], rgba(*marble))
	poly(d, [(48, 118), (208, 118), (198, 128), (58, 128)], lighten(marble, 25))
	# Column
	round_rect(d, (86, 148, 170, 200), 8, rgba(*shade))
	round_rect(d, (94, 152, 120, 196), 6, lighten(shade, 30))
	# Base
	poly(d, [(36, 200), (220, 200), (228, 230), (28, 230)], rgba(*marble))
	poly(d, [(36, 200), (220, 200), (214, 212), (42, 212)], lighten(marble, 20))
	return add_outline(layer)


# ---------- Shrine (torii) — kept as optional spare ----------
def draw_shrine() -> Image.Image:
	layer = new_layer()
	d = ImageDraw.Draw(layer)
	red = (215, 45, 60)
	poly(d, [(22, 58), (40, 38), (216, 38), (234, 58), (220, 72), (36, 72)], rgba(*red))
	poly(d, [(40, 38), (216, 38), (210, 48), (46, 48)], lighten(red, 35))
	round_rect(d, (48, 78, 208, 100), 6, rgba(*red))
	round_rect(d, (54, 80, 120, 92), 4, lighten(red, 25))
	for x0 in (60, 172):
		round_rect(d, (x0, 96, x0 + 28, 216), 6, darken(red, 40))
		round_rect(d, (x0 + 4, 100, x0 + 14, 210), 4, rgba(*red))
	round_rect(d, (72, 128, 184, 148), 5, darken(red, 25))
	for x0 in (48, 160):
		round_rect(d, (x0, 208, x0 + 52, 230), 5, rgba(190, 185, 200))
		round_rect(d, (x0 + 4, 210, x0 + 28, 220), 3, rgba(220, 215, 230))
	return add_outline(layer)


def save(name: str, im: Image.Image):
	OUT.mkdir(parents=True, exist_ok=True)
	path = OUT / f"{name}.png"
	im.save(path)
	print(f"wrote {path}")


def main():
	icons = {
		"SpiritSight": draw_spirit_sight(),
		"Pulse": draw_pulse(),
		"Bind": draw_bind(),
		"Wild": draw_wild(),
		"Pedestals": draw_pedestals(),
		"Shrine": draw_shrine(),
	}
	for name, im in icons.items():
		save(name, im)

	refs = ["Luck", "Settings", "Home", "Hub"]
	cells = list(icons.keys()) + refs
	C = 150
	sheet = Image.new("RGB", (C * len(cells), C + 44), (28, 24, 36))
	sd = ImageDraw.Draw(sheet)
	for i, name in enumerate(cells):
		p = OUT / f"{name}.png"
		if not p.exists():
			continue
		icon = Image.open(p).convert("RGBA").resize((C - 18, C - 18), Image.LANCZOS)
		sheet.paste(icon, (i * C + 9, 10), icon)
		small = Image.open(p).convert("RGBA").resize((40, 40), Image.LANCZOS)
		sheet.paste(small, (i * C + C // 2 - 20, C - 2), small)
		sd.text((i * C + 8, C + 24), name[:12], fill=(220, 220, 230))
	preview = Path(os.environ.get("TEMP", ".")) / "hud_handdrawn.png"
	sheet.save(preview)
	print(preview)


if __name__ == "__main__":
	main()
