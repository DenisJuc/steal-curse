"""Turn prop JSON (from tools/props/PropExport.server.luau, one file per model) into
assets/MapProps/<Name>.rbxmx for MapProps. Scripts never get here (the exporter skips them).

Usage: python -I tools/props/export_props.py <json dir> [Name=NewName ...]
"""

import json
import sys
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "assets" / "MapProps"

# Property names as rbxmx spells them where they differ from the Lua name.
XML_NAME = {"Size": "size", "Shape": "shape"}
# Content properties written in the current "...Content" form with a <uri> (as Studio saves them).
URI_NAME = {
    "MeshPart": {"MeshId": "MeshContent", "TextureID": "TextureContent"},
    "SurfaceAppearance": {
        "ColorMap": "ColorMapContent",
        "NormalMap": "NormalMapContent",
        "RoughnessMap": "RoughnessMapContent",
        "MetalnessMap": "MetalnessMapContent",
    },
}
PART_CLASSES = ("Part", "MeshPart")
counter = [0]


def num(x):
    return f"{x:.6g}"


def prop(cls, name, value):
    kind, v = value
    if kind == "content" and name in URI_NAME.get(cls, {}):
        tag = URI_NAME[cls][name]
        return f'<Content name="{tag}"><uri>{escape(v)}</uri></Content>' if v else ""
    if kind == "content":
        return f'<Content name="{name}"><url>{escape(v)}</url></Content>' if v else f'<Content name="{name}"><null></null></Content>'
    if cls in PART_CLASSES and name == "Color":
        r, g, b = (max(0, min(255, round(c * 255))) for c in v)
        return f'<Color3uint8 name="Color3uint8">{0xFF000000 | (r << 16) | (g << 8) | b}</Color3uint8>'
    name = XML_NAME.get(name, name) if cls in PART_CLASSES else name
    if kind == "token":
        return f'<token name="{name}">{v}</token>'
    if kind == "boolean":
        return f'<bool name="{name}">{"true" if v else "false"}</bool>'
    if kind == "number":
        return f'<float name="{name}">{num(v)}</float>'
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


def node(n, name=None):
    counter[0] += 1
    cls = n["class"]
    xml_cls = "Part" if cls in ("Part", "WedgePart", "CornerWedgePart", "TrussPart") else cls
    body = f'<string name="Name">{escape(name or n["name"])}</string>'
    body += "".join(prop(xml_cls, k, v) for k, v in (n["props"] or {}).items() if v)
    if xml_cls in PART_CLASSES:
        body += '<bool name="Anchored">true</bool><bool name="CanCollide">false</bool>'
    kids = "".join(node(k) for k in n["kids"])
    return f'<Item class="{cls}" referent="R{counter[0]}"><Properties>{body}</Properties>{kids}</Item>'


def main():
    source = Path(sys.argv[1])
    renames = dict(arg.split("=", 1) for arg in sys.argv[2:])
    TARGET.mkdir(parents=True, exist_ok=True)
    for f in sorted(source.glob("*.json")):
        data = json.loads(f.read_text(encoding="utf-8"))
        name = renames.get(f.stem, f.stem)
        out = TARGET / f"{name}.rbxmx"
        out.write_text(f'<roblox version="4">{node(data, name)}</roblox>', encoding="utf-8")
        print("wrote", out.relative_to(ROOT))


if __name__ == "__main__":
    main()
