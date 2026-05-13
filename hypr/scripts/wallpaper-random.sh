#!/usr/bin/env bash
# Randomly rotate Hyprland wallpapers from a folder using awww (swww fork).
#
# Usage:
#   wallpaper-random.sh [interval_seconds] [wallpaper_dir]
# Defaults: 300s, ~/Pictures/wallpaper

set -u

INTERVAL="${1:-300}"
WALL_DIR="${2:-$HOME/Pictures/wallpaper}"

# Prefer awww (Arch's swww replacement); fall back to swww if present.
CLI="$(command -v swww || command -v awww || true)"
DAEMON="$(command -v swww-daemon || command -v awww-daemon || true)"

shopt -s nullglob nocaseglob

list_wallpapers() {
    local f
    for f in "$WALL_DIR"/*.{jpg,jpeg,png,webp}; do
        [ -f "$f" ] && printf '%s\n' "$f"
    done
}

pick_random() {
    local files=()
    mapfile -t files < <(list_wallpapers)
    local n=${#files[@]}
    [ "$n" -eq 0 ] && return 1
    printf '%s' "${files[RANDOM % n]}"
}

ensure_daemon() {
    [ -n "$DAEMON" ] || { echo "no swww/awww-daemon found" >&2; return 1; }
    if "$CLI" query >/dev/null 2>&1; then
        return 0
    fi
    setsid -f "$DAEMON" >/dev/null 2>&1 &
    disown 2>/dev/null || true
    # Wait for the daemon socket.
    for _ in $(seq 1 30); do
        "$CLI" query >/dev/null 2>&1 && return 0
        sleep 0.2
    done
    return 1
}

apply_wallpaper() {
    local path="$1"
    "$CLI" img \
        --transition-type fade \
        --transition-duration 1 \
        --resize crop \
        "$path" >/dev/null 2>&1
}

main() {
    [ -n "$CLI" ] || { echo "no swww/awww CLI found" >&2; exit 1; }
    # Wait until Hyprland is up.
    for _ in $(seq 1 60); do
        [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && break
        [ -d "$XDG_RUNTIME_DIR/hypr" ] && break
        sleep 1
    done
    ensure_daemon || { echo "swww/awww daemon failed to start" >&2; exit 1; }
    while :; do
        path="$(pick_random)" || {
            echo "no wallpapers found in $WALL_DIR" >&2
            sleep "$INTERVAL"
            continue
        }
        apply_wallpaper "$path"
        sleep "$INTERVAL"
    done
}

main
