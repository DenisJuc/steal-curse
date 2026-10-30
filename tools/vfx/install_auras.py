"""Copy the chosen aura candidates into assets/VFX/Auras under their game names, optionally
pulling every emitter / beam / light color toward a target color (the textures are white, so
the Color property carries the hue).

Usage: python -I tools/vfx/install_auras.py
"""

import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "VFX-candidates" / "Auras"
TARGET = ROOT / "assets" / "VFX" / "Auras"

# game name: (candidate number, tint hex or None, tint strength 0..1)
CHOICES = {
    "Aura_Rare": (6, None, 0),
    "Aura_Epic": (18, None, 0),
    "Aura_Legendary": (25, "#FFB12E", 0.7),
    "Aura_Mythic": (21, "#FF4F6D", 0.35),
    "Aura_Celestial": (27, None, 0),
    "Aura_Cosmic": (23, "#FF6BF1", 0.5),
    "Aura_TitanicExtra": (22, "#FFD46A", 0.6),
    # Untinted bases for per-relic recipes (src/shared/RelicVfx.luau tints them at runtime).
    "Aura_Sparkle": (6, None, 0),
    "Aura_Rise": (20, None, 0),
    "Aura_Wind": (31, None, 0),
    "Aura_Ground": (19, None, 0),
    "Aura_Rays": (15, None, 0),
}


def rgb(hexcode):
    h = hexcode.lstrip("#")
    return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]


def tint_sequence(text, color, k):
    v = [float(x) for x in text.split()]
    for i in range(0, len(v), 5):
        for j in range(3):
            v[i + 1 + j] = v[i + 1 + j] * (1 - k) + color[j] * k
    return " ".join(f"{x:.4g}" for x in v)


def install(name, number, tint, strength):
    source = next(SOURCE.glob(f"Aura{number:02d}_*.rbxmx"))
    tree = ET.parse(source)
    model = tree.getroot().find("Item")
    for node in model.find("Properties"):
        if node.get("name") == "Name":
            node.text = name
    if tint:
        color = rgb(tint)
        for item in model.iter("Item"):
            if item.get("class") not in ("ParticleEmitter", "Beam", "Trail", "PointLight", "SpotLight"):
                continue
            for node in item.find("Properties"):
                if node.get("name") == "Color" and node.tag == "ColorSequence":
                    node.text = tint_sequence(node.text, color, strength)
                elif node.get("name") == "Color" and node.tag == "Color3":
                    for c, axis in zip(color, ("R", "G", "B")):
                        el = node.find(axis)
                        el.text = f"{float(el.text) * (1 - strength) + c * strength:.4g}"
    TARGET.mkdir(parents=True, exist_ok=True)
    tree.write(TARGET / f"{name}.rbxmx", encoding="utf-8", xml_declaration=False)
    print(f"{name} <- {source.name}" + (f" tinted {tint} x{strength}" if tint else ""))


# Effects harvested from +150VFX.rbxl (tools/vfx/pack150_to_rbxmx.py), used as per-relic primaries
# by src/shared/RelicVfx.luau. Installed untinted as Aura_P<id>.
PACK150 = SOURCE.parent / "Pack150"
PACK150_IDS = ["012", "015", "016", "017", "018", "019", "020", "021", "022", "023", "027", "028", "029", "030", "032",
               "031", "037", "038", "052", "064", "066", "067", "070", "071", "072", "083", "085", "087", "088",
               "089", "091", "092", "093", "094", "098", "121", "141", "142"]


def install_pack150(number):
    source = next(PACK150.glob(f"P{number}_*.rbxmx"))
    text = source.read_text(encoding="utf-8").replace(f'<string name="Name">P{number}</string>', f'<string name="Name">Aura_P{number}</string>', 1)
    (TARGET / f"Aura_P{number}.rbxmx").write_text(text, encoding="utf-8")


if __name__ == "__main__":
    for game_name, (num, hexcode, k) in CHOICES.items():
        install(game_name, num, hexcode, k)
    for number in PACK150_IDS:
        install_pack150(number)
    print(f"installed {len(PACK150_IDS)} pack150 auras")
