#!/usr/bin/env python3
"""Hyprland monitor handler.

Policy:
  - DP-1 connected      -> use DP-1 only (disable HDMI-A-1)
  - DP-1 not connected  -> use HDMI-A-1 only

HDMI-A-1 is a JetKVM remote-viewer output that should stay off whenever
the physical display (DP-1) is attached, and become active automatically
when the user falls back to remote operation.
"""

from __future__ import annotations

import json
import os
import socket
import subprocess
import sys


PRIMARY = "DP-1"
FALLBACK = "HDMI-A-1"


def connected_monitors() -> set[str]:
    out = subprocess.check_output(["hyprctl", "monitors", "-j"], text=True)
    return {m["name"] for m in json.loads(out)}


def hyprctl_keyword(arg: str) -> None:
    subprocess.run(["hyprctl", "keyword", "monitor", arg], check=False)


def apply_state() -> None:
    monitors = connected_monitors()
    if PRIMARY in monitors:
        hyprctl_keyword(f"{FALLBACK}, disable")
        hyprctl_keyword(f"{PRIMARY}, preferred, auto, auto")
    else:
        hyprctl_keyword(f"{FALLBACK}, preferred, auto, auto")


def event_socket_path() -> str:
    runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    his = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not his:
        sys.stderr.write("HYPRLAND_INSTANCE_SIGNATURE not set\n")
        sys.exit(1)
    return f"{runtime}/hypr/{his}/.socket2.sock"


def main() -> None:
    apply_state()

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(event_socket_path())

    buf = b""
    monitor_event_prefixes = (
        b"monitoradded>>",
        b"monitorremoved>>",
        b"monitoraddedv2>>",
        b"monitorremovedv2>>",
    )
    with sock:
        while True:
            chunk = sock.recv(4096)
            if not chunk:
                break
            buf += chunk
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                if any(line.startswith(p) for p in monitor_event_prefixes):
                    apply_state()


if __name__ == "__main__":
    main()
