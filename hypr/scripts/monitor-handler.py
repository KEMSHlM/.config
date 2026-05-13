#!/usr/bin/env python3
"""Hyprland monitor handler.

Policy:
  - DP-1 connected      -> use DP-1 only (disable HDMI-A-1)
  - DP-1 not connected  -> use HDMI-A-1 only

HDMI-A-1 is a JetKVM virtual display used for remote KVM video transport.
It should stay disabled whenever DP-1 is physically attached, and become
active automatically when the user falls back to remote operation.

Loop-safety:
  Issuing `hyprctl keyword monitor X, disable/enable` itself generates
  monitoradded/monitorremoved events on .socket2.sock. Without protection
  the handler reacts to its own output and, paired with JetKVM's DRM
  hotplug flapping, can spin a tight feedback loop that hangs the GPU.
  This implementation mitigates that with three guards:
    1. State idempotency: skip apply if the desired state matches the
       last applied state.
    2. Self-event suppression: ignore monitor events for SUPPRESS_AFTER_S
       seconds following a hyprctl keyword we issued.
    3. Coalescing: collapse bursts of events with DEBOUNCE_S so we apply
       at most once per debounce window.
"""

from __future__ import annotations

import json
import os
import select
import socket
import subprocess
import sys
import time


PRIMARY = "DP-1"
FALLBACK = "HDMI-A-1"

DEBOUNCE_S = 0.5            # coalesce event bursts
SUPPRESS_AFTER_S = 2.0      # ignore events for this long after our hyprctl
MIN_APPLY_INTERVAL_S = 1.0  # hard floor on apply frequency


def all_known_monitors() -> set[str]:
    """All monitors Hyprland knows about, including disabled ones."""
    out = subprocess.check_output(
        ["hyprctl", "monitors", "all", "-j"], text=True
    )
    return {m["name"] for m in json.loads(out)}


def desired_state() -> dict[str, str]:
    """Map monitor -> desired hyprctl keyword arg."""
    monitors = all_known_monitors()
    if PRIMARY in monitors:
        return {
            FALLBACK: f"{FALLBACK}, disable",
            PRIMARY: f"{PRIMARY}, preferred, auto, auto",
        }
    return {FALLBACK: f"{FALLBACK}, preferred, auto, auto"}


def hyprctl_keyword(arg: str) -> None:
    subprocess.run(["hyprctl", "keyword", "monitor", arg], check=False)


class Handler:
    def __init__(self) -> None:
        self.last_applied: dict[str, str] = {}
        self.last_apply_ts: float = 0.0
        self.suppress_until: float = 0.0

    def apply_if_changed(self) -> None:
        now = time.monotonic()
        if now - self.last_apply_ts < MIN_APPLY_INTERVAL_S:
            return
        try:
            target = desired_state()
        except Exception as exc:
            sys.stderr.write(f"desired_state failed: {exc}\n")
            return
        if target == self.last_applied:
            return
        changed = False
        for name, arg in target.items():
            if self.last_applied.get(name) == arg:
                continue
            hyprctl_keyword(arg)
            changed = True
        self.last_applied = target
        self.last_apply_ts = now
        if changed:
            self.suppress_until = now + SUPPRESS_AFTER_S


def event_socket_path() -> str:
    runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    his = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not his:
        sys.stderr.write("HYPRLAND_INSTANCE_SIGNATURE not set\n")
        sys.exit(1)
    return f"{runtime}/hypr/{his}/.socket2.sock"


def main() -> None:
    handler = Handler()
    handler.apply_if_changed()

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(event_socket_path())
    sock.setblocking(False)

    buf = b""
    pending = False
    pending_deadline = 0.0
    monitor_event_prefixes = (
        b"monitoradded>>",
        b"monitorremoved>>",
        b"monitoraddedv2>>",
        b"monitorremovedv2>>",
    )

    with sock:
        while True:
            timeout: float | None = None
            if pending:
                timeout = max(0.0, pending_deadline - time.monotonic())
            ready, _, _ = select.select([sock], [], [], timeout)
            now = time.monotonic()

            if ready:
                try:
                    chunk = sock.recv(4096)
                except BlockingIOError:
                    chunk = b""
                if not chunk and not ready:
                    continue
                if not chunk:
                    break
                buf += chunk
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    if not any(line.startswith(p) for p in monitor_event_prefixes):
                        continue
                    if now < handler.suppress_until:
                        continue
                    if not pending:
                        pending = True
                        pending_deadline = now + DEBOUNCE_S

            if pending and time.monotonic() >= pending_deadline:
                pending = False
                handler.apply_if_changed()


if __name__ == "__main__":
    main()
