#!/usr/bin/env python3
"""Per-workspace wallpaper rotator for Hyprland + awww (swww fork).

Assigns each numeric workspace a distinct wallpaper. The assignment is a
ring offset that rotates every ``interval`` seconds, so a given wallpaper
moves through workspaces 1 -> 2 -> 3 ... over time. The wallpaper for the
*currently focused* workspace is what awww renders; on every workspace
switch we apply the wallpaper for the new workspace immediately.

Usage:
    wallpaper-rotator.py [INTERVAL_SECONDS] [WALLPAPER_DIR]

Defaults: 300 s, ~/Pictures/wallpaper. Supported extensions: jpg, jpeg,
png, webp. Wallpapers are sorted by filename so the cycle order is
deterministic.
"""

from __future__ import annotations

import os
import select
import shutil
import socket
import subprocess
import sys
import time
from pathlib import Path


def hyprland_socket_path() -> str:
    runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    his = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not his:
        sys.stderr.write("HYPRLAND_INSTANCE_SIGNATURE not set\n")
        sys.exit(1)
    return f"{runtime}/hypr/{his}/.socket2.sock"


SUPPORTED_EXT = {".jpg", ".jpeg", ".png", ".webp"}
DEFAULT_INTERVAL = 300
DEFAULT_DIR = Path.home() / "Pictures" / "wallpaper"


def list_wallpapers(directory: Path) -> list[Path]:
    return sorted(
        p for p in directory.iterdir()
        if p.is_file() and p.suffix.lower() in SUPPORTED_EXT
    )


def resolve_cli() -> str:
    for name in ("swww", "awww"):
        path = shutil.which(name)
        if path:
            return path
    sys.stderr.write("neither swww nor awww found in PATH\n")
    sys.exit(1)


def resolve_daemon() -> str:
    for name in ("swww-daemon", "awww-daemon"):
        path = shutil.which(name)
        if path:
            return path
    sys.stderr.write("neither swww-daemon nor awww-daemon found in PATH\n")
    sys.exit(1)


def ensure_daemon(cli: str, daemon: str) -> None:
    if subprocess.run([cli, "query"], capture_output=True).returncode == 0:
        return
    subprocess.Popen(
        [daemon],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    for _ in range(30):
        if subprocess.run([cli, "query"], capture_output=True).returncode == 0:
            return
        time.sleep(0.2)
    sys.stderr.write("swww/awww daemon failed to start\n")
    sys.exit(1)


def current_workspace_id() -> int | None:
    """Active workspace ID, or None if it can't be parsed (e.g. named)."""
    try:
        out = subprocess.check_output(
            ["hyprctl", "activeworkspace", "-j"], text=True
        )
    except subprocess.CalledProcessError:
        return None
    import json
    try:
        return int(json.loads(out)["id"])
    except (KeyError, ValueError, json.JSONDecodeError):
        return None


def wait_for_hyprland(socket_path: str, timeout: float = 30.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if os.path.exists(socket_path):
            return
        time.sleep(0.5)
    sys.stderr.write(f"Hyprland socket {socket_path} did not appear\n")
    sys.exit(1)


class Rotator:
    def __init__(self, cli: str, wallpapers: list[Path], interval: float):
        self.cli = cli
        self.wallpapers = wallpapers
        self.interval = interval
        self.offset = 0
        self.current_ws: int | None = None
        self.last_applied: Path | None = None

    def pick(self, ws_id: int) -> Path:
        n = len(self.wallpapers)
        # Workspaces are 1-indexed; map to 0-indexed slot.
        idx = (ws_id - 1 + self.offset) % n
        return self.wallpapers[idx]

    def apply(self, ws_id: int) -> None:
        path = self.pick(ws_id)
        if path == self.last_applied:
            return
        subprocess.run(
            [
                self.cli, "img",
                "--transition-type", "fade",
                "--transition-duration", "1",
                "--resize", "crop",
                str(path),
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        self.last_applied = path

    def tick_offset(self) -> None:
        self.offset = (self.offset + 1) % len(self.wallpapers)


def parse_workspace_event(line: bytes) -> int | None:
    """Extract workspace ID from a `workspace>>` or `workspacev2>>` event."""
    if line.startswith(b"workspacev2>>"):
        # Format: workspacev2>>ID,NAME
        payload = line[len(b"workspacev2>>"):].split(b",", 1)[0]
    elif line.startswith(b"workspace>>"):
        payload = line[len(b"workspace>>"):]
    else:
        return None
    try:
        return int(payload)
    except ValueError:
        return None


def main() -> None:
    interval = float(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_INTERVAL
    directory = Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_DIR

    wallpapers = list_wallpapers(directory)
    if not wallpapers:
        sys.stderr.write(f"no wallpapers in {directory}\n")
        sys.exit(1)

    socket_path = hyprland_socket_path()
    wait_for_hyprland(socket_path)

    cli = resolve_cli()
    daemon = resolve_daemon()
    ensure_daemon(cli, daemon)

    rotator = Rotator(cli, wallpapers, interval)
    ws = current_workspace_id()
    if ws is not None:
        rotator.current_ws = ws
        rotator.apply(ws)

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(socket_path)
    sock.setblocking(False)

    buf = b""
    deadline = time.monotonic() + interval

    with sock:
        while True:
            timeout = max(0.0, deadline - time.monotonic())
            ready, _, _ = select.select([sock], [], [], timeout)

            if ready:
                try:
                    chunk = sock.recv(4096)
                except BlockingIOError:
                    chunk = b""
                if not chunk:
                    sys.stderr.write("Hyprland socket closed\n")
                    return
                buf += chunk
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    ws = parse_workspace_event(line)
                    if ws is None:
                        continue
                    rotator.current_ws = ws
                    rotator.apply(ws)

            if time.monotonic() >= deadline:
                rotator.tick_offset()
                if rotator.current_ws is not None:
                    rotator.apply(rotator.current_ws)
                deadline = time.monotonic() + interval


if __name__ == "__main__":
    main()
