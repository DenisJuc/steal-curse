"""Upload a Tripo/Meshy .fbx/.glb as a Roblox Model with Open Cloud and save it as a relic .rbxm.

The API key is read from ROBLOX_API_KEY (process env, else the Windows user environment), never
from arguments, so it stays out of shell history and logs. The key needs Assets read/write.

Usage: python -I tools/models/upload_model.py <model.fbx|.glb> <RelicId> [--user 153530464]
Writes assets/RelicModels/<RelicId>.rbxmx: the downloaded Model asset plus a SurfaceAppearance
built from the export's PBR maps (Tripo puts them in <name>.fbm/*_basecolor|_normal|_metallic|
_roughness.*), each uploaded as a Decal. Open Cloud model uploads drop FBX textures, hence this.
"""

import argparse
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET
import gzip
import json
import os
import sys
import time
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
API = "https://apis.roblox.com"


def api_key():
    key = os.environ.get("ROBLOX_API_KEY")
    if not key and sys.platform == "win32":
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as env:
            key, _ = winreg.QueryValueEx(env, "ROBLOX_API_KEY")
    if not key:
        sys.exit("ROBLOX_API_KEY is not set")
    return key


def call(method, url, key, body=None, content_type=None):
    request = urllib.request.Request(url, data=body, method=method, headers={"x-api-key": key})
    if content_type:
        request.add_header("Content-Type", content_type)
    with urllib.request.urlopen(request) as response:
        return json.loads(response.read())


def upload(path: Path, name: str, user_id: str, key: str) -> str:
    content_type = {".fbx": "model/fbx", ".glb": "model/gltf-binary", ".gltf": "model/gltf+json"}[path.suffix.lower()]
    request = {
        "assetType": "Model",
        "displayName": name,
        "description": "Seal a Curse relic model",
        "creationContext": {"creator": {"userId": user_id}},
    }
    return upload_file(path, request, content_type, key)


def upload_file(path: Path, request: dict, content_type: str, key: str) -> str:
    boundary = uuid.uuid4().hex
    parts = [
        f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\n\r\n{json.dumps(request)}\r\n'.encode(),
        f'--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{path.name}"\r\n'
        f"Content-Type: {content_type}\r\n\r\n".encode(),
        path.read_bytes(),
        f"\r\n--{boundary}--\r\n".encode(),
    ]
    operation = call("POST", f"{API}/assets/v1/assets", key, b"".join(parts), f"multipart/form-data; boundary={boundary}")
    path_id = operation["path"]
    for _ in range(60):
        if operation.get("done"):
            break
        time.sleep(2)
        operation = call("GET", f"{API}/assets/v1/{path_id}", key)
    if not operation.get("done"):
        sys.exit(f"upload still processing: {path_id}")
    if "error" in operation:
        sys.exit(f"upload failed: {operation['error']}")
    return operation["response"]["assetId"]


def download(asset_id: str, key: str) -> bytes:
    location = call("GET", f"{API}/asset-delivery-api/v1/assetId/{asset_id}", key)["location"]
    with urllib.request.urlopen(location) as response:
        data = response.read()
    return gzip.decompress(data) if data[:2] == b"\x1f\x8b" else data


MAPS = {"ColorMapContent": "basecolor", "NormalMapContent": "normal",
        "MetalnessMapContent": "metallic", "RoughnessMapContent": "roughness",
        "EmissiveMaskContent": "emissive"}
# Glow for relics that ship an emissive mask (Blender-built ones).
EMISSIVE_STRENGTH = "3"


def upload_image(path: Path, user_id: str, key: str) -> str:
    """Uploads an image as a Decal and returns the underlying Image asset id."""
    content_type = "image/png" if path.suffix.lower() == ".png" else "image/jpeg"
    request = {"assetType": "Decal", "displayName": path.stem[:50], "description": "Seal a Curse texture",
               "creationContext": {"creator": {"userId": user_id}}}
    decal = upload_file(path, request, content_type, key)
    for _ in range(15):
        try:
            xml = download(decal, key).decode("utf-8", "ignore")
            match = re.search(r"id=(\d+)", xml) or re.search(r"rbxassetid://(\d+)", xml)
            if match:
                return match.group(1)
        except urllib.error.HTTPError:
            pass
        time.sleep(3)
    sys.exit(f"could not resolve image for decal {decal}")


def texture_maps(model: Path) -> dict:
    folder = model.with_suffix(".fbm")
    found = {}
    if folder.is_dir():
        for prop, suffix in MAPS.items():
            for file in folder.iterdir():
                if file.stem.lower().endswith("_" + suffix):
                    found[prop] = file
    return found


def to_rbxmx(rbxm: bytes, name: str) -> ET.ElementTree:
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / "m.rbxm"
        src.write_bytes(rbxm)
        (Path(tmp) / "m.project.json").write_text(json.dumps({"name": name, "tree": {"$path": "m.rbxm"}}))
        subprocess.run(["rojo", "build", str(Path(tmp) / "m.project.json"), "-o", str(Path(tmp) / "m.rbxmx")],
                       check=True, cwd=ROOT, capture_output=True)
        return ET.parse(Path(tmp) / "m.rbxmx")


def add_surface(tree: ET.ElementTree, image_ids: dict):
    for part in tree.getroot().iter("Item"):
        if part.get("class") != "MeshPart":
            continue
        surface = ET.SubElement(part, "Item", {"class": "SurfaceAppearance", "referent": uuid.uuid4().hex})
        props = ET.SubElement(surface, "Properties")
        ET.SubElement(props, "string", {"name": "Name"}).text = "SurfaceAppearance"
        for prop, image in image_ids.items():
            content = ET.SubElement(props, "Content", {"name": prop})
            ET.SubElement(content, "uri").text = f"rbxassetid://{image}"
        if "EmissiveMaskContent" in image_ids:
            ET.SubElement(props, "float", {"name": "EmissiveStrength"}).text = EMISSIVE_STRENGTH


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("model", type=Path)
    parser.add_argument("relic_id")
    parser.add_argument("--user", default="153530464")
    parser.add_argument("--out", type=Path, default=None)
    args = parser.parse_args()
    key = api_key()
    asset_id = upload(args.model, args.relic_id, args.user, key)
    print(f"uploaded {args.model.name} -> asset {asset_id}")
    data = None
    for _ in range(15):  # delivery can lag a few seconds behind the upload
        try:
            data = download(asset_id, key)
            break
        except urllib.error.HTTPError:
            time.sleep(3)
    if data is None:
        sys.exit(f"asset {asset_id} not downloadable yet; rerun later")
    tree = to_rbxmx(data, args.relic_id)
    maps = texture_maps(args.model)
    image_ids = {prop: upload_image(file, args.user, key) for prop, file in maps.items()}
    print(f"textures: {', '.join(f'{p}={i}' for p, i in image_ids.items()) or 'none found'}")
    add_surface(tree, image_ids)
    out = args.out or ROOT / "assets" / "RelicModels" / f"{args.relic_id}.rbxmx"
    tree.write(out, encoding="utf-8", xml_declaration=False)
    print(f"saved {out}")


if __name__ == "__main__":
    main()
