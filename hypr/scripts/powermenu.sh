#!/usr/bin/env bash
# Rofi power menu, adapted for Hyprland from EndeavourOS i3 powermenu
# (endeavouros-team/endeavouros-i3wm-setup, classic commit 44d2c25).
#
# Original lays out 7 entries; powermenu.rasi was sized accordingly
# (lines=7, window-width=120, location=east). Keep the entry count and
# Nerd Font glyph prefixes intact so the rasi layout still fits.

set -u

THEME="$HOME/.config/rofi/powermenu.rasi"

declare -A actions=(
    ["  Shutdown"]="systemctl poweroff"
    ["  Reboot"]="systemctl reboot"
    ["  Suspend"]="systemctl suspend"
    ["  Hibernate"]="systemctl hibernate"
    ["  Lock"]="loginctl lock-session"
    ["  Logout"]="hyprctl dispatch exit"
    ["  Cancel"]=":"
)

# Preserve display order rather than the alphabetical sort the upstream
# script uses (which scatters Cancel between Hibernate and Lock).
ordered=(
    "  Shutdown"
    "  Reboot"
    "  Suspend"
    "  Hibernate"
    "  Lock"
    "  Logout"
    "  Cancel"
)

choice=$(printf '%s\n' "${ordered[@]}" \
    | rofi -dmenu -i -p "" -lines "${#ordered[@]}" -no-custom \
           -theme "$THEME") || exit 0

[ -z "$choice" ] && exit 0

cmd="${actions[$choice]:-}"
[ -z "$cmd" ] && exit 0

eval "$cmd"
