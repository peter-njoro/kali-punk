#!/usr/bin/env bash
set -euo pipefail

# kali-punk uninstaller
# Removes files and attempts to uninstall packages installed by install.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HOME"

DRY_RUN=0
ASSUME_YES=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=1; shift ;;
    -y|--yes) ASSUME_YES=1; shift ;;
    -h|--help)
      cat <<EOF
Usage: $(basename "$0") [OPTIONS]
Options:
  -n, --dry-run   Show what would be removed, do not perform any destructive actions
  -y, --yes       Run non-interactively and proceed without confirmation
  -h, --help      Show this help
EOF
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Detect OS
if [ -f /etc/os-release ]; then
  . /etc/os-release
  # use safe defaults in case fields are missing
  OS_ID="${ID:-unknown}"
  OS_ID="${OS_ID,,}"
  OS_LIKE="${ID_LIKE:-}"
  OS_LIKE="${OS_LIKE,,}"
else
  echo "Unable to detect OS (/etc/os-release missing)." >&2
  exit 1
fi

case "$OS_ID" in
  arch|manjaro) PLATFORM="arch" ;;
  debian|ubuntu|linuxmint) PLATFORM="debian" ;;
  *)
    if echo "$OS_LIKE" | grep -q "arch"; then PLATFORM="arch"
    elif echo "$OS_LIKE" | grep -q "debian"; then PLATFORM="debian"
    else
      echo "Unsupported or unrecognized distro: $OS_ID (ID_LIKE=$OS_LIKE)" >&2
      exit 1
    fi
    ;;
esac

echo "Detected platform: $PLATFORM"

# Package candidates copied from install.sh (only these will be targeted)
ARCH_CANDIDATES=(
  i3-wm i3status i3lock i3blocks i3-gaps polybar mate-terminal
  picom feh imagemagick ffmpeg fastfetch w3m ranger rofi zsh git base-devel
  mpc mpd alsa-utils betterlockscreen
)

DEB_PKGS=(
  i3 i3-gaps mate-terminal picom feh imagemagick ffmpeg
  fastfetch w3m ranger rofi zsh git build-essential cmake pkg-config
  mpc mpd alsa-utils
)

to_remove_pkgs=()
aur_pkgs=()

if [ "$PLATFORM" = "arch" ]; then
  # split arch candidates into repo vs AUR (if pacman knows about them)
  repo_pkgs=()
  aur_pkgs=()
  for pkg in "${ARCH_CANDIDATES[@]}"; do
    if pacman -Si "$pkg" >/dev/null 2>&1; then
      repo_pkgs+=("$pkg")
    else
      aur_pkgs+=("$pkg")
    fi
  done
  # determine which of the repo packages are actually installed
  for pkg in "${repo_pkgs[@]}"; do
    if pacman -Qq "$pkg" >/dev/null 2>&1; then
      to_remove_pkgs+=("$pkg")
    fi
  done
  # check AUR packages installed via pacman/qeury (they present in pacman -Q)
  for pkg in "${aur_pkgs[@]}"; do
    if pacman -Qq "$pkg" >/dev/null 2>&1; then
      to_remove_pkgs+=("$pkg")
    fi
  done
elif [ "$PLATFORM" = "debian" ]; then
  for pkg in "${DEB_PKGS[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1 || apt list --installed 2>/dev/null | grep -Fq "${pkg}/"; then
      to_remove_pkgs+=("$pkg")
    fi
  done
fi

# Files and directories the installer created or linked
LINKS_AND_DIRS=(
  "$HOME/.config/polybar/panels"
  "$HOME/.config/polybar/launch.sh"
  "$HOME/.config/polybar/config"
  "$HOME/.config/polybar"
  "$HOME/.config/i3"
  "$HOME/polybar"
  "$HOME/wallset"
  "$HOME/polybar-themes"
  "$HOME/.kali-punk-install.log"
  "$HOME/.kali-punk-after-boot.log"
)

# i3 config modifications to undo
I3_CONFIG="$HOME/.config/i3/config"

echo "The uninstaller will perform the following actions:" 

if [ ${#to_remove_pkgs[@]} -gt 0 ]; then
  echo "\nPackages that will be removed (${#to_remove_pkgs[@]}):"
  for p in "${to_remove_pkgs[@]}"; do echo "  - $p"; done
else
  echo "\nNo target packages detected as installed (nothing to uninstall)."
fi

echo "\nFiles/directories/symlinks that will be removed (if present):"
for f in "${LINKS_AND_DIRS[@]}"; do echo "  - $f"; done

echo "\ni3 config changes: will attempt to remove the kali-punk panels exec block from: $I3_CONFIG"

if [ $DRY_RUN -eq 1 ]; then
  echo "\nDRY RUN: no destructive actions will be taken. Exiting."; exit 0
fi

if [ $ASSUME_YES -ne 1 ]; then
  read -r -p $'Type "yes" to proceed with the uninstallation: ' CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted by user."; exit 1
  fi
fi

echo "Starting uninstallation..."

# stop any running polybar and related processes
echo "Stopping polybar (if running) and related processes..."
pkill -f polybar || true

# remove files/dirs/symlinks (only existing ones)
for f in "${LINKS_AND_DIRS[@]}"; do
  if [ -e "$f" ] || [ -L "$f" ]; then
    echo "Removing: $f"
    rm -rf "$f" || echo "Failed to remove $f";
  fi
done

# restore i3 config: remove the appended block added by installer
if [ -f "$I3_CONFIG" ]; then
  if grep -Fq "kali-punk: launch polybar panels" "$I3_CONFIG"; then
    echo "Removing kali-punk panel launch block from $I3_CONFIG"
    # remove the comment line and the following exec line (and the preceding blank line that installer added)
    # delete the comment line and the next 2 lines (blank + exec)
    sed -i.bak '/# kali-punk: launch polybar panels/,+2d' "$I3_CONFIG" || true
    echo "Backup of original config saved as $I3_CONFIG.bak"
  else
    echo "No kali-punk panel launch block found in $I3_CONFIG"
  fi
else
  echo "$I3_CONFIG does not exist, skipping i3 config modifications"
fi

# attempt package removals
if [ ${#to_remove_pkgs[@]} -gt 0 ]; then
  echo "Removing packages..."
  if [ "$PLATFORM" = "arch" ]; then
    # Use pacman to remove installed packages
    sudo pacman -Rns --noconfirm "${to_remove_pkgs[@]}" || {
      echo "pacman remove failed for some packages: ${to_remove_pkgs[*]}"
      echo "You may need to remove some packages manually."
    }
    # For AUR packages that pacman didn't handle (if any remain), try yay
    if command -v yay >/dev/null 2>&1; then
      # check which AUR packages are still installed
      remaining=()
      for pkg in "${ARCH_CANDIDATES[@]}"; do
        if pacman -Qq "$pkg" >/dev/null 2>&1; then
          remaining+=("$pkg")
        fi
      done
      if [ ${#remaining[@]} -gt 0 ]; then
        echo "Attempting to remove remaining AUR packages via yay: ${remaining[*]}"
        yay -Rns --noconfirm "${remaining[@]}" || echo "yay failed to remove some AUR packages"
      fi
    else
      echo "No AUR helper (yay) found — if AUR packages were installed they must be removed manually: ${aur_pkgs[*]}"
    fi
  else
    # Debian/Ubuntu
    sudo apt remove -y --purge "${to_remove_pkgs[@]}" || echo "apt remove failed for some packages"
    sudo apt autoremove -y || true
  fi
else
  echo "No packages detected for removal."
fi

echo "Uninstaller finished. Review messages above for any manual steps or failures."

exit 0
