"""Approximate still renders of aura .rbxmx files, for choosing effects without opening Studio.

Each emitter is simulated as a steady-state snapshot: particles at random ages along their
lifetime, spawned in the emitter part's volume, moved by Speed/Acceleration inside the spread
cone, sized/colored/faded by their sequences and drawn with the real texture (Roblox thumbnail),
additively for LightEmission. Beams are drawn as tinted strips between their attachments.
Front orthographic view at relic scale. It is a guide to color, density and silhouette, not a
substitute for seeing motion in Studio.

Usage: python -I tools/vfx/preview_auras.py <aura dir> <texture dir> <out dir> [relic studs]
Textures: <texture dir>/<assetId>.png (thumbnails.roblox.com, 420x420).
"""

import math
import random
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

PX = 640
FOV_STUDS = 9.0  # view width in studs at relic scale
REF_HEIGHT = 5.0
MAX_PARTICLES = 80
NORMALS = {0: (1, 0, 0), 1: (0, 1, 0), 2: (0, 0, 1), 3: (-1, 0, 0), 4: (0, -1, 0), 5: (0, 0, -1)}
GRID = {1: 2, 2: 4, 3: 8}


def props(item):
    return {c.get("name"): c for c in item.find("Properties")}


def num(p, key, default=0.0):
    node = p.get(key)
    return float(node.text) if node is not None and node.text else default


def seq(p, key, default):
    node = p.get(key)
    if node is None or not node.text:
        return default
    return [float(x) for x in node.text.split()]


def sample_number(values, t):
    pts = [(values[i], values[i + 1]) for i in range(0, len(values), 3)]
    for (t0, v0), (t1, v1) in zip(pts, pts[1:]):
        if t <= t1:
            k = 0 if t1 == t0 else (t - t0) / (t1 - t0)
            return v0 + (v1 - v0) * k
    return pts[-1][1]


def sample_color(values, t):
    pts = [(values[i], values[i + 1:i + 4]) for i in range(0, len(values), 5)]
    for (t0, c0), (t1, c1) in zip(pts, pts[1:]):
        if t <= t1:
            k = 0 if t1 == t0 else (t - t0) / (t1 - t0)
            return [a + (b - a) * k for a, b in zip(c0, c1)]
    return pts[-1][1]


def vec(p, key):
    node = p.get(key)
    if node is None:
        return np.zeros(3)
    v = {c.tag: float(c.text) for c in node}
    return np.array([v.get("X", 0), v.get("Y", 0), v.get("Z", 0)])


def cframe(p):
    v = {c.tag: float(c.text) for c in p["CFrame"]}
    pos = np.array([v["X"], v["Y"], v["Z"]])
    rot = np.array([[v[f"R{i}{j}"] for j in range(3)] for i in range(3)])
    return pos, rot


def texture_id(p):
    node = p.get("TextureContent")
    if node is not None:
        uri = node.find("uri")
        if uri is not None and uri.text:
            return uri.text.split("//")[-1].split("=")[-1]
    node = p.get("Texture")
    if node is not None:
        url = node.find("url")
        text = url.text if url is not None else node.text
        if text:
            return text.split("//")[-1].split("=")[-1]
    return None


class Textures:
    def __init__(self, folder):
        self.folder, self.cache = Path(folder), {}

    def get(self, asset, layout):
        key = (asset, layout)
        if key not in self.cache:
            path = self.folder / f"{asset}.png" if asset else None
            if path and path.exists():
                im = Image.open(path).convert("RGBA")
                if not Image.open(path).mode.endswith("A") and "A" not in Image.open(path).mode:
                    # no alpha: luminance is the mask (Roblox shows black as black; additive hides it)
                    gray = im.convert("L")
                    im.putalpha(gray)
                n = GRID.get(layout)
                if n:
                    w = im.width // n
                    im = im.crop((0, 0, w, w))
            else:
                im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
                ImageDraw.Draw(im).ellipse((8, 8, 56, 56), fill=(255, 255, 255, 200))
            self.cache[key] = np.asarray(im.resize((96, 96)), dtype=np.float32) / 255.0
        return self.cache[key]


def composite(canvas, sprite_rgba, cx, cy, size_px, color, alpha, emission, angle):
    size_px = int(max(2, min(size_px, PX * 1.5)))
    img = Image.fromarray((sprite_rgba * 255).astype(np.uint8)).resize((size_px, size_px))
    if angle:
        img = img.rotate(angle)
    s = np.asarray(img, dtype=np.float32) / 255.0
    x0, y0 = int(cx - size_px / 2), int(cy - size_px / 2)
    x1, y1 = x0 + size_px, y0 + size_px
    cx0, cy0, cx1, cy1 = max(x0, 0), max(y0, 0), min(x1, PX), min(y1, PX)
    if cx0 >= cx1 or cy0 >= cy1:
        return
    s = s[cy0 - y0:cy1 - y0, cx0 - x0:cx1 - x0]
    rgb = s[..., :3] * np.array(color, dtype=np.float32)
    a = (s[..., 3:4] * alpha)
    region = canvas[cy0:cy1, cx0:cx1]
    blended = region * (1 - a) + rgb * a
    added = region + rgb * a
    region[:] = np.clip(blended * (1 - emission) + added * emission, 0, 1)


def to_px(point, scale):
    ppu = PX / FOV_STUDS
    return PX / 2 + point[0] * scale * ppu, PX * 0.62 - point[1] * scale * ppu


def render(path, textures, relic_studs):
    tree = ET.parse(path).getroot()
    model = tree.find("Item")
    scale = relic_studs / REF_HEIGHT
    canvas = np.zeros((PX, PX, 3), dtype=np.float32)
    canvas[:] = (0.06, 0.06, 0.08)
    ppu = PX / FOV_STUDS
    # the relic: grey rounded block centered at the origin
    relic = Image.new("RGBA", (PX, PX), (0, 0, 0, 0))
    r = relic_studs * ppu / 2
    cx, cy = to_px((0, 0, 0), 1)
    ImageDraw.Draw(relic).rounded_rectangle((cx - r * 0.6, cy - r, cx + r * 0.6, cy + r), radius=12, fill=(120, 115, 130, 255))
    rr = np.asarray(relic, dtype=np.float32) / 255
    canvas[:] = canvas * (1 - rr[..., 3:4]) + rr[..., :3] * rr[..., 3:4]

    rng = random.Random(7)
    attach_world = {}
    stats = {"emitters": 0, "particles_per_s": 0.0, "beams": 0, "lights": 0}
    for part in model.findall("Item"):
        if part.get("class") != "Part":
            continue
        pp = props(part)
        ppos, prot = cframe(pp)
        psize = vec(pp, "size")
        for item in part.iter("Item"):
            cls = item.get("class")
            p = props(item)
            if cls == "Attachment":
                apos = vec(p, "Position") if "Position" in p else np.zeros(3)
                if "CFrame" in p:
                    apos = cframe(p)[0]
                attach_world[item.get("referent")] = ppos + prot @ apos
            elif cls in ("PointLight", "SpotLight", "SurfaceLight"):
                stats["lights"] += 1
        for item in part.iter("Item"):
            if item.get("class") != "ParticleEmitter":
                continue
            p = props(item)
            if p.get("Enabled") is not None and p["Enabled"].text == "false" and item.find("Item") is None:
                continue
            stats["emitters"] += 1
            emit_count = None
            for v in item.findall("Item"):
                if props(v)["Name"].text == "EmitCount":
                    emit_count = float(props(v)["Value"].text)
            rate = num(p, "Rate")
            life = seq(p, "Lifetime", [1, 1])
            lmin, lmax = life[0], life[1] if len(life) > 1 else life[0]
            lavg = max((lmin + lmax) / 2, 0.05)
            count = emit_count if emit_count is not None else rate * lavg
            stats["particles_per_s"] += emit_count if emit_count is not None else min(rate, 1e4)
            count = int(min(count, MAX_PARTICLES))
            spd = seq(p, "Speed", [0, 0])
            accel = vec(p, "Acceleration")
            spread = vec(p, "SpreadAngle") if "SpreadAngle" in p else np.zeros(3)
            spread_x = math.radians(p["SpreadAngle"].find("X").text and float(p["SpreadAngle"].find("X").text)) if "SpreadAngle" in p else 0
            spread_y = math.radians(float(p["SpreadAngle"].find("Y").text)) if "SpreadAngle" in p else 0
            normal = np.array(NORMALS.get(int(num(p, "EmissionDirection", 1)), (0, 1, 0)), dtype=float)
            size_seq = seq(p, "Size", [0, 1, 0, 1, 1, 0])
            trans_seq = seq(p, "Transparency", [0, 0, 0, 1, 0, 0])
            color_seq = seq(p, "Color", [0, 1, 1, 1, 0, 1, 1, 1, 1, 0])
            emission = min(max(num(p, "LightEmission"), 0), 1)
            tex = textures.get(texture_id(p), int(num(p, "FlipbookLayout")))
            # emitter host: an attachment emits from a point, a part from its volume
            parent_att = None
            for att in part.iter("Item"):
                if att.get("class") == "Attachment" and item in list(att.findall("Item")):
                    parent_att = att
            for _ in range(count):
                age = rng.random()
                lifetime = rng.uniform(lmin, lmax)
                t = age * lifetime
                if parent_att is not None:
                    origin = attach_world.get(parent_att.get("referent"), ppos)
                else:
                    local = (np.array([rng.random(), rng.random(), rng.random()]) - 0.5) * psize
                    origin = ppos + prot @ local
                ax, ay = rng.uniform(-spread_x, spread_x), rng.uniform(-spread_y, spread_y)
                d = prot @ normal
                d = d + np.array([math.sin(ax), 0, math.sin(ay)]) * (1 if abs(d[1]) > 0.5 else 0) \
                    + np.array([0, math.sin(ax), 0]) * (0 if abs(d[1]) > 0.5 else 1)
                d /= (np.linalg.norm(d) or 1)
                speed = rng.uniform(spd[0], spd[-1] if len(spd) > 1 else spd[0])
                pos = origin + d * speed * t + 0.5 * accel * t * t
                size = sample_number(size_seq, age)
                trans = sample_number(trans_seq, age)
                color = sample_color(color_seq, age)
                x, y = to_px(pos, scale)
                composite(canvas, tex, x, y, size * scale * ppu, color, max(0, 1 - trans) * 0.9,
                          emission, rng.uniform(0, 360))
        for item in part.iter("Item"):
            if item.get("class") != "Beam":
                continue
            stats["beams"] += 1
            p = props(item)
            a0 = p.get("Attachment0").text if p.get("Attachment0") is not None else None
            a1 = p.get("Attachment1").text if p.get("Attachment1") is not None else None
            if a0 not in attach_world or a1 not in attach_world:
                continue
            w = (num(p, "Width0", 1) + num(p, "Width1", 1)) / 2
            color = sample_color(seq(p, "Color", [0, 1, 1, 1, 0, 1, 1, 1, 1, 0]), 0.5)
            alpha = max(0, 1 - sample_number(seq(p, "Transparency", [0, 0, 0, 1, 0, 0]), 0.5)) * 0.6
            layer = Image.new("RGBA", (PX, PX), (0, 0, 0, 0))
            x0, y0 = to_px(attach_world[a0], scale)
            x1, y1 = to_px(attach_world[a1], scale)
            ImageDraw.Draw(layer).line((x0, y0, x1, y1), fill=tuple(int(c * 255) for c in color) + (int(alpha * 255),),
                                       width=max(1, int(w * scale * ppu)))
            l = np.asarray(layer, dtype=np.float32) / 255
            canvas[:] = np.clip(canvas + l[..., :3] * l[..., 3:4], 0, 1)
    return Image.fromarray((canvas * 255).astype(np.uint8)), stats


def main():
    aura_dir, tex_dir, out_dir = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
    relic = float(sys.argv[4]) if len(sys.argv) > 4 else 3.0
    out_dir.mkdir(parents=True, exist_ok=True)
    textures = Textures(tex_dir)
    tiles = []
    for path in sorted(aura_dir.glob("*.rbxmx")):
        image, stats = render(path, textures, relic)
        label = path.stem
        ImageDraw.Draw(image).text((10, 10), label, fill=(255, 255, 255))
        ImageDraw.Draw(image).text((10, 26), f"{stats['emitters']} emitters, ~{int(stats['particles_per_s'])} particles/s, "
                                   f"{stats['beams']} beams, {stats['lights']} lights", fill=(200, 200, 200))
        image.save(out_dir / f"{label}.png")
        tiles.append(image.resize((320, 320)))
        print(label, stats)
    cols = 4
    for sheet in range(0, len(tiles), 8):
        group = tiles[sheet:sheet + 8]
        rows = math.ceil(len(group) / cols)
        board = Image.new("RGB", (cols * 320, rows * 320))
        for i, tile in enumerate(group):
            board.paste(tile, ((i % cols) * 320, (i // cols) * 320))
        board.save(out_dir / f"sheet_{sheet // 8 + 1}.png")


if __name__ == "__main__":
    main()
