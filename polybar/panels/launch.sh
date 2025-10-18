#!/usr/bin/env bash

# Add this script to your wm startup file.

# Prefer panels dir but auto-detect available config locations
dir_candidates=(
  "$HOME/.config/polybar/panels"
  "$HOME/.config/polybar"
  "$HOME/.config/polybar/themes"
)

for d in "${dir_candidates[@]}"; do
  if [ -d "$d" ]; then
    DIR="$d"
    break
  fi
done
DIR="${DIR:-$HOME/.config/polybar/panels}" # fallback

# select configuration file
if [ -f "$DIR/config.ini" ]; then
  CONFIG="$DIR/config.ini"
elif [ -f "$DIR/panels/config.ini" ]; then
  CONFIG="$DIR/panels/config.ini"
else
  echo "Error: config.ini not found in $DIR or $DIR/panels" >&2
  exit 1
fi

# ensure polybar exists
if ! command -v polybar >/dev/null 2>&1; then
  echo "Error: polybar not found in PATH." >&2
  exit 1
fi

# Terminate already running bar instances
killall -q polybar || true

# Wait until the processes have been shut down
while pgrep -u "$UID" -x polybar >/dev/null; do sleep 1; done

# Launch the bar
polybar -q main -c "$CONFIG" &
