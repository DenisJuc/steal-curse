#!/usr/bin/env python3
"""Localhost receiver for Studio playtest analytics exports.

Run before Stop & Export:
  python tools/playtest_export_server.py

Studio posts JSON to http://127.0.0.1:19283/export
Writes PLAYTEST_SESSION.json, PLAYTEST_SUMMARY.md, PLAYTEST_PURCHASES.csv
into docs/playtest/<SessionId>/ (and copies latest into docs/playtest/).
"""

from __future__ import annotations

import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

HOST = "127.0.0.1"
PORT = 19283
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "playtest"
FILES = ("PLAYTEST_SESSION.json", "PLAYTEST_SUMMARY.md", "PLAYTEST_PURCHASES.csv")


def write_files(session_id: str, files: dict[str, str]) -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    bag = OUT / session_id
    bag.mkdir(parents=True, exist_ok=True)
    for name in FILES:
        body = files.get(name)
        if body is None:
            continue
        (bag / name).write_text(body, encoding="utf-8")
        (OUT / name).write_text(body, encoding="utf-8")
    meta = {
        "SessionId": session_id,
        "Files": [n for n in FILES if n in files],
        "Dir": str(bag),
    }
    (bag / "_meta.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    return bag


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        sys.stdout.write("[playtest_export] " + (fmt % args) + "\n")
        sys.stdout.flush()

    def do_GET(self) -> None:
        if self.path in ("/", "/health"):
            body = b'{"ok":true,"service":"playtest_export","port":19283}\n'
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_error(404)

    def do_POST(self) -> None:
        if self.path.rstrip("/") != "/export":
            self.send_error(404)
            return
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length)
        try:
            payload = json.loads(raw.decode("utf-8"))
        except Exception as exc:  # noqa: BLE001
            self.send_error(400, f"invalid json: {exc}")
            return
        session_id = str(payload.get("SessionId") or "unknown")
        files = payload.get("Files") or {}
        if not isinstance(files, dict):
            self.send_error(400, "Files must be an object")
            return
        bag = write_files(session_id, {str(k): str(v) for k, v in files.items()})
        reply = json.dumps({"ok": True, "dir": str(bag), "sessionId": session_id}).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(reply)))
        self.end_headers()
        self.wfile.write(reply)
        print(f"[playtest_export] Wrote {session_id} → {bag}")
        for name in FILES:
            if name in files:
                print(f"  - {OUT / name}")


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    server = HTTPServer((HOST, PORT), Handler)
    print(f"[playtest_export] Listening on http://{HOST}:{PORT}/export")
    print(f"[playtest_export] Output directory: {OUT}")
    print("[playtest_export] Leave this running, then Stop & Export in Studio.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[playtest_export] Stopped.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
