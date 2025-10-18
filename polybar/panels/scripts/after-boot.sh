#!/usr/bin/env bash
set -euo pipefail

# locate repo root (common locations)
if [ -d "$HOME/projects/kali-punk" ]; then
    REPO="$HOME/projects/kali-punk"
elif [ -d "$HOME/kali-punk" ]; then
    REPO="$HOME/kali-punk"
else
    # fallback to script-relative lookup (two levels up)
    REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

# Play boot video (if wallset present)
if command -v wallset >/dev/null 2>&1; then
    [ -f "$REPO/boot/boot.mp4" ] && wallset --video "$REPO/boot/boot.mp4" || true
    sleep 7
    wallset --quit || true
fi

# set wallpaper if available
if [ -f "$REPO/walls/main-wall.png" ]; then
    feh --bg-fill "$REPO/walls/main-wall.png" || true
fi
