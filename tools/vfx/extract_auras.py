"""Pull each aura out of a body-rigged aura pack and save it as a relic-ready .rbxmx.

Aura packs ship their effects parented to R6/R15 dummy limbs. For every top-level model in the
pack this keeps only the limbs that carry effects (as invisible, massless, non-colliding parts
with CFrames relative to the dummy's root), drops humanoids, meshes, clothing, animations and
scripts, and turns the packs' "while true do emitter:Emit(n) wait(t) end" loops into
EmitCount / EmitEvery NumberValues that RelicAura.luau replays on the client.

Input must be XML: convert the binary pack first with Rojo, e.g. a project
{"name":"pack","tree":{"$path":"Aura 1.rbxm"}} built with `rojo build -o pack.rbxmx`.

Usage: python -I tools/vfx/extract_auras.py <pack.rbxmx> <out dir>
"""

import copy
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

EFFECTS = {"ParticleEmitter", "Beam", "Trail", "PointLight", "SpotLight", "SurfaceLight"}
KEEP = EFFECTS | {"Attachment"}
PARTS = {"Part", "MeshPart", "UnionOperation"}
ROOT_NAMES = ("HumanoidRootPart", "Torso", "UpperTorso")
# The dummies the packs use are about 5 studs tall; RelicAura scales from this.
REF_HEIGHT = 5.0
EMIT_LOOP = re.compile(r":Emit\((\d+)\).*?wait\(([\d.]+)\)", re.S)


def props(item):
    return item.find("Properties")


def prop(item, name):
    for child in props(item):
        if child.get("name") == name:
            return child
    return None


def name_of(item):
    node = prop(item, "Name")
    return (node.text or "") if node is not None else ""


def read_cframe(node):
    v = {c.tag: float(c.text) for c in node}
    pos = (v["X"], v["Y"], v["Z"])
    rot = [[v["R00"], v["R01"], v["R02"]], [v["R10"], v["R11"], v["R12"]], [v["R20"], v["R21"], v["R22"]]]
    return pos, rot


def relative(root, part):
    # root^-1 * part, with orthonormal rotations
    (rp, rr), (pp, pr) = root, part
    rt = [[rr[j][i] for j in range(3)] for i in range(3)]
    d = [pp[i] - rp[i] for i in range(3)]
    pos = [sum(rt[i][k] * d[k] for k in range(3)) for i in range(3)]
    rot = [[sum(rt[i][k] * pr[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    return pos, rot


def write_cframe(node, cf):
    pos, rot = cf
    values = {"X": pos[0], "Y": pos[1], "Z": pos[2]}
    for i in range(3):
        for j in range(3):
            values[f"R{i}{j}"] = rot[i][j]
    for c in node:
        c.text = f"{values[c.tag]:.6g}"


def value_item(cls, name, tag, text):
    item = ET.Element("Item", {"class": cls})
    p = ET.SubElement(item, "Properties")
    ET.SubElement(p, "string", {"name": "Name"}).text = name
    ET.SubElement(p, tag, {"name": "Value"}).text = text
    return item


def has_effect(item):
    return any(d.get("class") in EFFECTS for d in item.iter("Item"))


def effect_children(item):
    """KEEP-class children, looking through Folder/Model wrappers (but not into other parts)."""
    for child in item.findall("Item"):
        cls = child.get("class")
        if cls in KEEP:
            yield child
        elif cls in ("Folder", "Model", "Configuration"):
            yield from effect_children(child)


def filtered(item):
    """Copy of an effect/attachment item keeping only effect descendants; scripts become values."""
    out = ET.Element("Item", dict(item.attrib))
    out.append(copy.deepcopy(props(item)))
    for child in item.findall("Item"):
        cls = child.get("class")
        if cls in KEEP:
            out.append(filtered(child))
        elif cls in ("Script", "LocalScript") and item.get("class") == "ParticleEmitter":
            source = prop(child, "Source")
            match = EMIT_LOOP.search(source.text or "") if source is not None else None
            if match:
                out.append(value_item("IntValue", "EmitCount", "int64", match.group(1)))
                out.append(value_item("NumberValue", "EmitEvery", "double", match.group(2)))
    return out


def all_parts(model):
    return [i for i in model.iter("Item") if i.get("class") in PARTS]


def find_root(model):
    parts = all_parts(model)
    for wanted in ROOT_NAMES:
        for p in parts:
            if name_of(p) == wanted:
                return p
    return parts[0] if parts else None


def set_bool(item, name, value):
    node = prop(item, name)
    if node is not None:
        node.text = "true" if value else "false"


def convert_part(part, root_cf, counter):
    """An invisible Part with the source part's size and relative CFrame plus its effects."""
    out = ET.Element("Item", {"class": "Part", "referent": f"AURA{counter}"})
    p = ET.SubElement(out, "Properties")
    ET.SubElement(p, "string", {"name": "Name"}).text = name_of(part) or "Part"
    size = copy.deepcopy(prop(part, "size") if prop(part, "size") is not None else prop(part, "InitialSize"))
    if size is None:
        size = ET.fromstring('<Vector3 name="size"><X>1</X><Y>1</Y><Z>1</Z></Vector3>')
    size.set("name", "size")
    p.append(size)
    cf = copy.deepcopy(prop(part, "CFrame"))
    write_cframe(cf, relative(root_cf, read_cframe(cf)))
    p.append(cf)
    for flag, value in (("Anchored", False), ("CanCollide", False), ("CanQuery", False), ("CanTouch", False),
                        ("CastShadow", False), ("Massless", True), ("Locked", True)):
        ET.SubElement(p, "bool", {"name": flag}).text = "true" if value else "false"
    ET.SubElement(p, "float", {"name": "Transparency"}).text = "1"
    for child in effect_children(part):
        out.append(filtered(child))
    return out


def referenced(model):
    refs = set()
    for item in model.iter("Item"):
        if item.get("class") in ("Beam", "Trail"):
            for node in props(item):
                if node.tag == "Ref" and node.text and node.text != "null":
                    refs.add(node.text)
    return refs


def extract(model, index, shared):
    root = find_root(model)
    if root is None:
        return None
    root_cf = read_cframe(prop(root, "CFrame"))
    refs = referenced(model)
    out = ET.Element("Item", {"class": "Model", "referent": f"AURAMODEL{index}"})
    p = ET.SubElement(out, "Properties")
    label = re.sub(r"[^A-Za-z0-9]+", "", name_of(model)) or "Unnamed"
    ET.SubElement(p, "string", {"name": "Name"}).text = f"Aura{index:02d}_{label}"
    out.append(value_item("NumberValue", "RefHeight", "double", str(REF_HEIGHT)))
    out.append(value_item("StringValue", "SourceName", "string", name_of(model)))
    kept = 0
    for n, part in enumerate(all_parts(model)):
        carries_ref = any(d.get("referent") in refs for d in part.iter("Item"))
        if has_effect(part) or carries_ref:
            out.append(convert_part(part, root_cf, f"{index}_{n}"))
            kept += 1
    if kept == 0:
        return None
    doc = ET.Element("roblox", {"version": "4"})
    doc.append(out)
    if shared is not None:
        doc.append(copy.deepcopy(shared))
    return f"Aura{index:02d}_{label}", doc


def main():
    source, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)
    tree = ET.parse(source).getroot()
    shared = tree.find("SharedStrings")
    pack = tree.find("Item")
    for index, model in enumerate(pack.findall("Item")):
        if model.get("class") != "Model":
            continue
        result = extract(model, index, shared)
        if result is None:
            print(f"skip {index:02d} {name_of(model)!r}: no effects")
            continue
        name, doc = result
        ET.ElementTree(doc).write(out_dir / f"{name}.rbxmx", encoding="utf-8", xml_declaration=False)
        emitters = sum(1 for i in doc.iter("Item") if i.get("class") == "ParticleEmitter")
        print(f"wrote {name}.rbxmx ({emitters} emitters)")


if __name__ == "__main__":
    main()
