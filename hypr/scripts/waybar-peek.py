#!/usr/bin/env python3
"""Waybar auto-hide / peek-on-top-edge daemon for Hyprland.

Waybar has no built-in proximity-show. This daemon polls Hyprland for the
cursor position and toggles waybar visibility via SIGUSR1 (hide) /
SIGUSR2 (show). Hysteresis prevents flicker at the boundary.

Trigger zone:
  cursor_y <= SHOW_Y -> show waybar
  cursor_y >= HIDE_Y -> hide waybar
  in between: leave current state alone

Auto-hide is paused entirely while the cursor is over waybar so the user
can interact with modules without the bar collapsing under them.
"""

from __future__ import annotations

import json
import os
import signal
import socket
import subprocess
import sys
import time


SHOW_Y = 5             # px from top edge
HIDE_Y = 60            # below this, hide
POLL_INTERVAL = 0.1    # seconds (10 Hz)


def hyprland_socket_path() -> str:
    runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    his = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not his:
        sys.stderr.write("HYPRLAND_INSTANCE_SIGNATURE not set\n")
        sys.exit(1)
    return f"{runtime}/hypr/{his}/.socket.sock"


def ipc_request(sock_path: str, cmd: str) -> str:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(1.0)
    try:
        s.connect(sock_path)
        s.sendall(cmd.encode())
        chunks: list[bytes] = []
        while True:
            data = s.recv(4096)
            if not data:
                break
            chunks.append(data)
    finally:
        s.close()
    return b"".join(chunks).decode("utf-8", errors="replace")


def cursor_y(sock_path: str) -> int | None:
    """Cursor Y in monitor coordinates. None on failure."""
    try:
        # `cursorpos` returns "x, y\n"
        out = ipc_request(sock_path, "cursorpos")
        x_str, y_str = out.strip().split(",")
        return int(y_str.strip())
    except Exception:
        return None


def waybar_height(sock_path: str) -> int:
    """Best-effort: read waybar layer surface height."""
    try:
        out = ipc_request(sock_path, "j/layers")
        data = json.loads(out)
        for _mon, levels in data.items():
            for lvl in levels.get("levels", {}).values():
                for layer in lvl:
                    if layer.get("namespace") == "waybar":
                        return int(layer.get("h", 50))
    except Exception:
        pass
    return 50


def waybar_pids() -> list[int]:
    try:
        out = subprocess.check_output(["pidof", "waybar"], text=True)
        return [int(p) for p in out.split()]
    except subprocess.CalledProcessError:
        return []


def send_signal(sig: signal.Signals) -> None:
    for pid in waybar_pids():
        try:
            os.kill(pid, sig)
        except ProcessLookupError:
            pass


def show() -> None:
    send_signal(signal.SIGUSR2)


def hide() -> None:
    send_signal(signal.SIGUSR1)


def main() -> None:
    sock_path = hyprland_socket_path()

    # Wait for waybar to be up before issuing the first hide.
    for _ in range(40):
        if waybar_pids():
            break
        time.sleep(0.25)

    visible = True  # waybar starts visible unless config has start_hidden
    hide()
    visible = False
    hide_threshold = max(HIDE_Y, waybar_height(sock_path) + 5)

    paused = False

    def toggle_pause(_signum: int, _frame: object) -> None:
        nonlocal paused
        paused = not paused
        if paused:
            show()
        # When unpausing, the next poll cycle will set the right state.

    signal.signal(signal.SIGHUP, toggle_pause)

    while True:
        if paused:
            time.sleep(POLL_INTERVAL)
            continue

        y = cursor_y(sock_path)
        if y is None:
            time.sleep(POLL_INTERVAL)
            continue

        if y <= SHOW_Y and not visible:
            show()
            visible = True
        elif y >= hide_threshold and visible:
            hide()
            visible = False

        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    main()
