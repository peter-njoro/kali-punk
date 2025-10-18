#!/usr/bin/env bash
set -euo pipefail

# Detect OS (kept for future use)
if [ -f /etc/os-release ]; then . /etc/os-release; OS_ID="${ID,,}"; OS_LIKE="${ID_LIKE,,}"; else OS_ID="unknown"; OS_LIKE=""; fi
case "$OS_ID" in
  arch|manjaro) PLATFORM="arch" ;;
  debian|ubuntu|linuxmint) PLATFORM="debian" ;;
  *) if echo "$OS_LIKE" | grep -q "arch"; then PLATFORM="arch"; elif echo "$OS_LIKE" | grep -q "debian"; then PLATFORM="debian"; else PLATFORM="unknown"; fi ;;
esac

# detect config dir (prefer panels)
dir_candidates=(
  "$HOME/.config/polybar/panels"
  "$HOME/.config/polybar"
  "$HOME/.config/polybar/themes"
)
for d in "${dir_candidates[@]}"; do
  [ -d "$d" ] && DIR="$d" && break
done
DIR="${DIR:-$HOME/.config/polybar/panels}"

change_panel() {
    # replace config with selected panel (supports either panel/ or panels/ subdir)
    if [ -f "$DIR/panel/${panel}.ini" ]; then
        cat "$DIR/panel/${panel}.ini" > "$DIR/config.ini"
    elif [ -f "$DIR/panels/${panel}.ini" ]; then
        cat "$DIR/panels/${panel}.ini" > "$DIR/config.ini"
    else
        echo "Panel config not found: ${panel}.ini in $DIR/panel or $DIR/panels" >&2
        return 1
    fi

    # Change wallpaper (support wallpaper dir in repo/config)
    if [ -f "$DIR/wallpapers/$bg" ]; then
        feh --bg-fill "$DIR/wallpapers/$bg"
    else
        echo "Wallpaper not found: $DIR/wallpapers/$bg" >&2
    fi

    # Restarting polybar (if running)
    if command -v polybar-msg >/dev/null 2>&1; then
        polybar-msg cmd restart || true
    else
        echo "polybar-msg not available, please restart polybar manually." >&2
    fi
}

# CLI handling (unchanged options)
if  [[ "$1" = "--budgie" ]]; then
    panel="budgie"; bg="budgie.jpg"; change_panel
elif  [[ "$1" = "--deepin" ]]; then
    panel="deepin"; bg="deepin.jpg"; change_panel
elif  [[ "$1" = "--elight" ]]; then
    panel="elementary"; bg="elementary.jpg"; change_panel
elif  [[ "$1" = "--edark" ]]; then
    panel="elementary_dark"; bg="elementary_2.jpg"; change_panel
elif  [[ "$1" = "--gnome" ]]; then
    panel="gnome"; bg="gnome.jpg"; change_panel
elif  [[ "$1" = "--klight" ]]; then
    panel="kde"; bg="kde.jpg"; change_panel
elif  [[ "$1" = "--kdark" ]]; then
    panel="kde_dark"; bg="kde_2.jpg"; change_panel
elif  [[ "$1" = "--liri" ]]; then
    panel="liri"; bg="liri.png"; change_panel
elif  [[ "$1" = "--mint" ]]; then
    panel="mint"; bg="mint.jpg"; change_panel
elif  [[ "$1" = "--ugnome" ]]; then
    panel="ubuntu_gnome"; bg="ubuntu.jpg"; change_panel
elif  [[ "$1" = "--unity" ]]; then
    panel="ubuntu_unity"; bg="ubuntu.jpg"; change_panel
elif  [[ "$1" = "--xubuntu" ]]; then
    panel="xubuntu"; bg="xubuntu.png"; change_panel
elif  [[ "$1" = "--zorin" ]]; then
    panel="zorin"; bg="zorin.png"; change_panel
else
    cat <<- _EOF_
    No option specified, Available options:
    --budgie   --deepin   --elight   --edark   --gnome   --klight
    --kdark   --liri   --mint   --ugnome   --unity   --xubuntu
    --zorin
    _EOF_
    exit 1
fi
