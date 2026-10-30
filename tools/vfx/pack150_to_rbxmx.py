"""Turn effects harvested from +150VFX.rbxl (JSON from a Studio property walk, one file per effect in
work/h150/) into aura template candidates: assets/VFX-candidates/Pack150/P<id>_<name>.rbxmx.

Same shape as tools/vfx/extract_auras.py output, so RelicAura can attach them: a Model holding
invisible Parts (CFrames relative to the effect's pivot) with the emitters, beams and lights, plus
a RefHeight value. Emitters the pack fired from scripts (Enabled = false with a live Rate) get
EmitCount / EmitEvery values so RelicAura replays them as a loop.

Usage: python -I tools/vfx/pack150_to_rbxmx.py
"""

import json
import re
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "work" / "h150"
TARGET = ROOT / "assets" / "VFX-candidates" / "Pack150"

TOKEN_NAMES = {"EmissionDirection", "FlipbookLayout", "FlipbookMode", "Orientation", "Shape", "ShapeInOut",
               "ShapeStyle", "TextureMode", "FaceCamera"}


def num(x):
    return f"{x:.6g}"


def prop(name, value):
    kind, v = value
    if name == "Texture":
        return f'<Content name="Texture"><url>{escape(v)}</url></Content>' if v else ""
    if kind == "token":
        return f'<token name="{name}">{v}</token>'
    if kind == "boolean":
        return f'<bool name="{name}">{"true" if v else "false"}</bool>'
    if kind == "number":
        tag = "int" if name == "Segments" else "float"
        return f'<{tag} name="{name}">{num(v)}</{tag}>'
    if kind == "string":
        return f'<string name="{name}">{escape(v)}</string>'
    if kind == "Vector3":
        return f'<Vector3 name="{name}"><X>{num(v[0])}</X><Y>{num(v[1])}</Y><Z>{num(v[2])}</Z></Vector3>'
    if kind == "Vector2":
        return f'<Vector2 name="{name}"><X>{num(v[0])}</X><Y>{num(v[1])}</Y></Vector2>'
    if kind == "Color3":
        return f'<Color3 name="{name}"><R>{num(v[0])}</R><G>{num(v[1])}</G><B>{num(v[2])}</B></Color3>'
    if kind == "NumberRange":
        return f'<NumberRange name="{name}">{num(v[0])} {num(v[1])} </NumberRange>'
    if kind == "NumberSequence":
        return f'<NumberSequence name="{name}">' + " ".join(f"{num(a)} {num(b)} {num(c)}" for a, b, c in v) + " </NumberSequence>"
    if kind == "ColorSequence":
        return f'<ColorSequence name="{name}">' + " ".join(f"{num(t)} {num(r)} {num(g)} {num(b)} 0" for t, r, g, b in v) + " </ColorSequence>"
    if kind == "CFrame":
        keys = ["X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"]
        return f'<CoordinateFrame name="{name}">' + "".join(f"<{k}>{num(x)}</{k}>" for k, x in zip(keys, v)) + "</CoordinateFrame>"
    return ""


def value_item(cls, name, v):
    tag = "double" if cls == "NumberValue" else "string"
    return f'<Item class="{cls}"><Properties><string name="Name">{name}</string><{tag} name="Value">{v}</{tag}></Properties></Item>'


def node(n):
    p = n["props"]
    body = f'<string name="Name">{escape(n["name"])}</string>' + "".join(prop(k, v) for k, v in p.items())
    if n.get("a0"):
        body += f'<Ref name="Attachment0">{n["a0"]}</Ref>'
    if n.get("a1"):
        body += f'<Ref name="Attachment1">{n["a1"]}</Ref>'
    extra = ""
    if n["class"] == "ParticleEmitter":
        enabled = p.get("Enabled", ["boolean", True])[1]
        rate = p.get("Rate", ["number", 0])[1]
        if not enabled and rate > 0:
            life = p.get("Lifetime", ["NumberRange", [1, 1]])[1][1]
            extra += value_item("NumberValue", "EmitCount", max(1, min(40, round(rate * 0.1))))
            extra += value_item("NumberValue", "EmitEvery", round(max(life, 0.8) + 0.4, 2))
    kids = "".join(node(k) for k in n["kids"])
    return f'<Item class="{n["class"]}" referent="{n["ref"]}"><Properties>{body}</Properties>{extra}{kids}</Item>'


def convert(effect):
    parts = ""
    for i, part in enumerate(effect["parts"]):
        size = part["size"][1]
        parts += (
            f'<Item class="Part" referent="P{effect["id"]}_{i}"><Properties><string name="Name">{escape(part["name"])}</string>'
            f'<Vector3 name="size"><X>{num(size[0])}</X><Y>{num(size[1])}</Y><Z>{num(size[2])}</Z></Vector3>'
            + prop("CFrame", part["cframe"])
            + '<bool name="Anchored">false</bool><bool name="CanCollide">false</bool><bool name="CanQuery">false</bool>'
            '<bool name="CanTouch">false</bool><bool name="CastShadow">false</bool><bool name="Massless">true</bool>'
            '<float name="Transparency">1</float></Properties>'
            + "".join(node(k) for k in part["kids"])
            + "</Item>"
        )
    height = effect["height"] if 0.5 < effect["height"] < 40 else 5
    model = (
        f'<roblox version="4"><Item class="Model" referent="M{effect["id"]}"><Properties><string name="Name">P{effect["id"]}</string></Properties>'
        + value_item("NumberValue", "RefHeight", round(height, 3))
        + value_item("StringValue", "SourceName", escape(effect["path"]))
        + parts
        + "</Item></roblox>"
    )
    return model


def main():
    TARGET.mkdir(parents=True, exist_ok=True)
    count = 0
    for f in sorted(SOURCE.glob("*.json")):
        effect = json.loads(f.read_text(encoding="utf-8"))
        slug = re.sub(r"[^A-Za-z0-9]+", "", effect["name"])[:24] or "Unnamed"
        (TARGET / f"P{effect['id']}_{slug}.rbxmx").write_text(convert(effect), encoding="utf-8")
        count += 1
    print(f"wrote {count} candidates to {TARGET}")


if __name__ == "__main__":
    main()
