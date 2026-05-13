#!/usr/bin/env bash
# Blank all displays with a brief input lockout.
#
# `misc:{mouse_move,key_press}_enables_dpms = true` makes the very key release
# of the Alt+M chord (or any forwarded lan-mouse motion from the Mac) wake the
# display the instant we dispatch dpms off. We toggle those settings off for
# LOCKOUT seconds, dispatch dpms off, then restore them so subsequent activity
# wakes the display normally.
#
# Usage: screen-off.sh [LOCKOUT_SECONDS]

set -u

LOCKOUT="${1:-3}"

hyprctl keyword misc:key_press_enables_dpms false   >/dev/null
hyprctl keyword misc:mouse_move_enables_dpms false  >/dev/null

# Let the keychord that triggered us flush before we blank.
sleep 0.4
hyprctl dispatch dpms off >/dev/null

(
    sleep "$LOCKOUT"
    hyprctl keyword misc:key_press_enables_dpms true   >/dev/null
    hyprctl keyword misc:mouse_move_enables_dpms true  >/dev/null
) >/dev/null 2>&1 &
disown 2>/dev/null || true
