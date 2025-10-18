#!/usr/bin/env bash

dir_candidates=(
  "$HOME/.config/polybar"
  "$HOME/.config/polybar/panels"
  "$HOME/.config/polybar/themes"
)

# pick first existing candidate (fallback to first)
for d in "${dir_candidates[@]}"; do
  if [ -d "$d" ]; then
    dir="$d"
    break
  fi
done
dir="${dir:-$HOME/.config/polybar}" # default if none exist

# list themes (ignore files)
mapfile -t themes < <(for e in "$dir"/*; do [ -d "$e" ] && basename "$e"; done 2>/dev/null)

launch_bar() {
    # Terminate already running bar instances
    killall -q polybar

    # Wait until the processes have been shut down
    while pgrep -u "$UID" -x polybar >/dev/null; do sleep 1; done

    # choose config path based on style
    if [[ "$style" == "panels" ]]; then
        config="$dir/config.ini"
    elif [[ -f "$dir/$style/config.ini" ]]; then
        config="$dir/$style/config.ini"
    elif [[ -f "$dir/config.ini" ]]; then
        config="$dir/config.ini"
    else
        echo "Error: config not found for style '$style' in '$dir'." >&2
        exit 1
    fi

    # Launch the bar
    if [[ "$style" == "hack" || "$style" == "cuts" ]]; then
        polybar -q top -c "$config" &
        polybar -q bottom -c "$config" &
    elif [[ "$style" == "pwidgets" ]]; then
        # pwidgets has its own launcher (ensure path exists)
        if [[ -x "$dir/pwidgets/launch.sh" ]]; then
            bash "$dir"/pwidgets/launch.sh --main
        else
            echo "pwidgets launcher not found or not executable: $dir/pwidgets/launch.sh" >&2
            exit 1
        fi
    else
        polybar -q main -c "$config" &
    fi
}

if [[ "$1" == "--material" ]]; then
    style="material"
    launch_bar

elif [[ "$1" == "--shades" ]]; then
    style="shades"
    launch_bar

elif [[ "$1" == "--hack" ]]; then
    style="hack"
    launch_bar

elif [[ "$1" == "--docky" ]]; then
    style="docky"
    launch_bar

elif [[ "$1" == "--cuts" ]]; then
    style="cuts"
    launch_bar

elif [[ "$1" == "--shapes" ]]; then
    style="shapes"
    launch_bar

elif [[ "$1" == "--grayblocks" ]]; then
    style="grayblocks"
    launch_bar

elif [[ "$1" == "--blocks" ]]; then
    style="blocks"
    launch_bar

elif [[ "$1" == "--colorblocks" ]]; then
    style="colorblocks"
    launch_bar

elif [[ "$1" == "--forest" ]]; then
    style="forest"
    launch_bar

elif [[ "$1" == "--pwidgets" ]]; then
    style="pwidgets"
    launch_bar

elif [[ "$1" == "--panels" ]]; then
    style="panels"
    launch_bar

else
    cat <<- EOF
    Usage : launch.sh --theme
        
    Available Themes :
    --blocks    --colorblocks    --cuts      --docky
    --forest    --grayblocks     --hack      --material
    --panels    --pwidgets       --shades    --shapes
    EOF
fi
