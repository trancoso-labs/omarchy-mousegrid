#!/usr/bin/env python3
"""Install the Hyprland loader and click helper for mousegrid."""

from __future__ import annotations

import json
import os
import shutil
import socket
import stat
import subprocess
import sys
from pathlib import Path

PLUGIN = Path(__file__).resolve().parent.parent
HOME = Path(os.environ.get("HOME") or Path.home())
HYPR_LUA_SRC = PLUGIN / "hypr" / "mousegrid.lua"
CLICK_SRC = PLUGIN / "scripts" / "mousegrid-click"
HYPR_LUA_DST = HOME / ".config" / "hypr" / "mousegrid.lua"
CLICK_DST = HOME / ".local" / "bin" / "mousegrid-click"
BINDINGS = HOME / ".config" / "hypr" / "bindings.lua"
REQUIRE_LINE = 'require("hypr.mousegrid")'
REQUIRE_BLOCK = """
-- Mousegrid: keyboard pointer on the focused window.
require("hypr.mousegrid")
"""
UINPUT = Path("/dev/uinput")
SOCK = Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp") / "mousegrid-click.sock"


def writable(path: Path) -> bool:
    try:
        return os.access(path, os.W_OK)
    except OSError:
        return False


def daemon_ok() -> bool:
    if not SOCK.exists():
        return False
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
            sock.settimeout(0.2)
            sock.connect(str(SOCK))
            sock.sendall(b"ping\n")
            return sock.makefile().readline().strip() == "ok"
    except OSError:
        return False


def bindings_wired() -> bool:
    if not BINDINGS.is_file():
        return False
    return REQUIRE_LINE in BINDINGS.read_text(encoding="utf-8")


def status() -> dict:
    return {
        "ok": True,
        "hypr_lua": HYPR_LUA_DST.is_file(),
        "click_bin": CLICK_DST.is_file() and os.access(CLICK_DST, os.X_OK),
        "bindings": bindings_wired(),
        "uinput": writable(UINPUT),
        "daemon": daemon_ok(),
    }


def ready(info: dict) -> bool:
    return all(info[key] for key in ("hypr_lua", "click_bin", "bindings", "uinput"))


def install() -> dict:
    HYPR_LUA_DST.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(HYPR_LUA_SRC, HYPR_LUA_DST)
    CLICK_DST.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(CLICK_SRC, CLICK_DST)
    CLICK_DST.chmod(CLICK_DST.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

    if BINDINGS.is_file() and not bindings_wired():
        with BINDINGS.open("a", encoding="utf-8") as handle:
            handle.write(REQUIRE_BLOCK)

    subprocess.Popen(
        [str(CLICK_DST), "--daemon"],
        start_new_session=True,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    info = status()
    info["message"] = "wired" if ready(info) else "partial"
    return info


def main() -> int:
    args = sys.argv[1:]
    if args == ["status"]:
        info = status()
        info["ready"] = ready(info)
        print(json.dumps(info))
        return 0
    if args and args != ["install"]:
        print("usage: install.py [status]", file=sys.stderr)
        return 2
    info = install()
    print(json.dumps(info, indent=2))
    if not info.get("uinput"):
        print("warning: /dev/uinput is not writable in this session", file=sys.stderr)
    if BINDINGS.is_file() and not info.get("bindings"):
        print(f"add this to {BINDINGS}: {REQUIRE_LINE}", file=sys.stderr)
    print("run: hyprctl reload", file=sys.stderr)
    return 0 if ready(info) else 1


if __name__ == "__main__":
    raise SystemExit(main())
