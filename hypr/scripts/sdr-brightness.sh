#!/usr/bin/env bash
# Adjust DP-1 sdrbrightness: how aggressively SDR content is mapped into
# the HDR luminance range. 1.0 = native EDID-derived SDR floor (looks dim
# under HDR), 1.5-2.0 = typical "comfortable SDR" while keeping HDR signal
# range available for HDR media.
#
# Subcommands:
#   get       Print the current sdrbrightness (one decimal).
#   set N     Apply the given value (clamped to [0.5, 3.0]).
#   pick      Show a rofi menu of presets and apply the selection.
#   inc / dec Adjust by 0.1 (used by waybar scroll).
#   waybar    JSON output for waybar custom module.

set -u

MONITOR="${SDR_BRIGHTNESS_MONITOR:-DP-1}"
MIN=0.5
MAX=3.0
STEP=0.1
PRESETS=(1.0 1.2 1.4 1.6 1.8 2.0 2.5)

current() {
    hyprctl monitors -j 2>/dev/null \
        | python3 -c "
import json, sys
mons = json.load(sys.stdin)
for m in mons:
    if m['name'] == '$MONITOR':
        print(f\"{m.get('sdrBrightness', 1.0):.1f}\")
        break
"
}

apply() {
    local val="$1"
    # Clamp via python so we accept decimals safely.
    val=$(python3 -c "
v = max($MIN, min($MAX, float('$val')))
print(f'{v:.2f}')
")
    # Re-apply the full monitor spec so the rest of the HDR pipeline stays
    # consistent with the configured baseline.
    hyprctl keyword monitor \
        "$MONITOR, preferred, auto, auto, bitdepth, 10, cm, hdredid, sdrbrightness, $val, sdrsaturation, 1.0" \
        >/dev/null 2>&1
}

pick() {
    local choices
    choices=$(printf '%s\n' "${PRESETS[@]}")
    local choice
    choice=$(printf '%s' "$choices" | rofi -dmenu -p "SDR brightness" -i -no-custom -lines "${#PRESETS[@]}")
    [ -n "$choice" ] && apply "$choice"
}

cycle() {
    # Move to the next/previous preset, snapping to the closest preset
    # if the current value is between two (or outside the list).
    local dir="$1"  # +1 or -1
    local cur
    cur="$(current)"
    python3 - "$cur" "$dir" "${PRESETS[@]}" <<'PY' | xargs -I{} "$0" set {}
import sys
cur = float(sys.argv[1])
dir_ = int(sys.argv[2])
presets = [float(x) for x in sys.argv[3:]]
# Find the index of the closest preset to current.
i = min(range(len(presets)), key=lambda j: abs(presets[j] - cur))
# If current isn't exactly on a preset, snap toward the scroll direction.
if abs(presets[i] - cur) > 1e-6:
    if dir_ > 0 and presets[i] < cur:
        i += 1
    elif dir_ < 0 and presets[i] > cur:
        i -= 1
else:
    i += dir_
i = max(0, min(len(presets) - 1, i))
print(f"{presets[i]:.2f}")
PY
}

waybar() {
    local cur
    cur="$(current)"
    printf '{"text":"%s","tooltip":"SDR brightness (HDR scale): %s\\nscroll: cycle presets · click: menu","class":"sdr-brightness"}\n' \
        "$cur" "$cur"
}

case "${1:-get}" in
    get)    current ;;
    set)    apply "${2:?value required}" ;;
    pick)   pick ;;
    next)   cycle 1 ;;
    prev)   cycle -1 ;;
    waybar) waybar ;;
    *)      echo "usage: $0 {get|set <n>|pick|next|prev|waybar}" >&2; exit 2 ;;
esac
