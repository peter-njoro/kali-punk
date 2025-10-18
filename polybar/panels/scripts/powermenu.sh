#!/usr/bin/env bash
set -euo pipefail

# detect menu dir
dir_candidates=(
  "$HOME/.config/polybar/panels/menu"
  "$HOME/.config/polybar/menu"
  "$HOME/.config/polybar/panels"
  "$HOME/.config/polybar"
)
for d in "${dir_candidates[@]}"; do
  [ -d "$d" ] && DIR="$(dirname "$d")/menu" && break
done
DIR="${DIR:-$HOME/.config/polybar/panels/menu}"

uptime=$(uptime -p | sed -e 's/up //g')

theme=""
if  [[ "$1" = "--budgie" ]]; then theme="budgie"
elif  [[ "$1" = "--deepin" ]]; then theme="deepin"
elif  [[ "$1" = "--elight" ]]; then theme="elementary"
elif  [[ "$1" = "--edark" ]]; then theme="elementary_dark"
elif  [[ "$1" = "--gnome" ]]; then theme="gnome"
elif  [[ "$1" = "--klight" ]]; then theme="kde"
elif  [[ "$1" = "--kdark" ]]; then theme="kde_dark"
elif  [[ "$1" = "--liri" ]]; then theme="liri"
elif  [[ "$1" = "--mint" ]]; then theme="mint"
elif  [[ "$1" = "--ugnome" ]]; then theme="ubuntu_gnome"
elif  [[ "$1" = "--unity" ]]; then theme="ubuntu_unity"
elif  [[ "$1" = "--xubuntu" ]]; then theme="xubuntu"
elif  [[ "$1" = "--zorin" ]]; then theme="zorin"
else
    rofi -e "No theme specified."
    exit 1
fi

rofi_command="rofi -theme $DIR/$theme/powermenu.rasi"

# Options
shutdown=" Shutdown"
reboot=" Restart"
lock=" Lock"
suspend=" Sleep"
logout=" Logout"

confirm_exit() {
    rofi -dmenu -i -no-fixed-num-lines -p "Are You Sure? : " -theme "$DIR/$theme/confirm.rasi"
}

msg() {
    rofi -theme "$DIR/$theme/message.rasi" -e "Available Options  -  yes / y / no / n"
}

options="$lock\n$suspend\n$logout\n$reboot\n$shutdown"

chosen="$(echo -e "$options" | $rofi_command -p "Uptime: $uptime" -dmenu -selected-row 0)"
case $chosen in
    $shutdown)
        ans=$(confirm_exit)
        if [[ $ans =~ ^([yY][eE][sS]|[yY])$ ]]; then systemctl poweroff
        elif [[ $ans =~ ^([nN][oO]|[nN])$ ]]; then exit 0
        else msg; fi
        ;;
    $reboot)
        ans=$(confirm_exit)
        if [[ $ans =~ ^([yY][eE][sS]|[yY])$ ]]; then systemctl reboot
        elif [[ $ans =~ ^([nN][oO]|[nN])$ ]]; then exit 0
        else msg; fi
        ;;
    $lock)
        if command -v i3lock >/dev/null 2>&1; then i3lock
        elif command -v betterlockscreen >/dev/null 2>&1; then betterlockscreen -l
        else rofi -e "No lock utility found."; fi
        ;;
    $suspend)
        ans=$(confirm_exit)
        if [[ $ans =~ ^([yY][eE][sS]|[yY])$ ]]; then
            command -v mpc >/dev/null 2>&1 && mpc -q pause || true
            command -v amixer >/dev/null 2>&1 && amixer set Master mute || true
            systemctl suspend
        elif [[ $ans =~ ^([nN][oO]|[nN])$ ]]; then exit 0
        else msg; fi
        ;;
    $logout)
        ans=$(confirm_exit)
        if [[ $ans =~ ^([yY][eE][sS]|[yY])$ ]]; then
            if [[ "$DESKTOP_SESSION" == "Openbox" ]]; then openbox --exit
            elif [[ "$DESKTOP_SESSION" == "bspwm" ]]; then bspc quit
            elif [[ "$DESKTOP_SESSION" == "i3" ]]; then i3-msg exit
            else echo "Logout command not configured for session: $DESKTOP_SESSION" >&2; fi
        elif [[ $ans =~ ^([nN][oO]|[nN])$ ]]; then exit 0
        else msg; fi
        ;;
esac
