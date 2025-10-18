#!/usr/bin/env bash
set -e

# repo/script dirs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HOME"

# Detect OS
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS_ID="${ID,,}"
  OS_LIKE="${ID_LIKE,,}"
else
  echo "Unable to detect OS (/etc/os-release missing)."
  exit 1
fi

case "$OS_ID" in
  arch|manjaro) PLATFORM="arch" ;;
  debian|ubuntu|linuxmint) PLATFORM="debian" ;;
  *)
    if echo "$OS_LIKE" | grep -q "arch"; then PLATFORM="arch"
    elif echo "$OS_LIKE" | grep -q "debian"; then PLATFORM="debian"
    else
      echo "Unsupported or unrecognized distro: $OS_ID (ID_LIKE=$OS_LIKE)"
      exit 1
    fi
    ;;
esac

echo "Detected platform: $PLATFORM"

pkg_update() {
  if [ "$PLATFORM" = "arch" ]; then
    sudo pacman -Syu --noconfirm
  else
    sudo apt update
  fi
}

pkg_install() {
  if [ "$PLATFORM" = "arch" ]; then
    sudo pacman -S --noconfirm --needed "$@"
  else
    sudo apt install -y "$@"
  fi
}

# Make all shipped scripts executable
echo "Making repository .sh files executable..."
find "$SCRIPT_DIR" -type f -name "*.sh" -exec chmod +x {} \;

# Update package DB
pkg_update

# Install common packages (map names where necessary)
echo -e "\nInstalling window manager and utilities..."
if [ "$PLATFORM" = "arch" ]; then
  # Candidates to install (will be split into repo vs AUR)
  ARCH_CANDIDATES=(
    i3-wm i3status i3lock i3blocks i3-gaps polybar mate-terminal
    picom feh imagemagick ffmpeg fastfetch w3m ranger rofi zsh git base-devel
    mpc mpd alsa-utils    # audio control and music client
    betterlockscreen      # often AUR (optional)
  )

  repo_pkgs=()
  aur_pkgs=()

  # classify packages as repo vs AUR
  for pkg in "${ARCH_CANDIDATES[@]}"; do
    if pacman -Si "$pkg" >/dev/null 2>&1; then
      repo_pkgs+=("$pkg")
    else
      aur_pkgs+=("$pkg")
    fi
  done

  # install repo packages
  if [ "${#repo_pkgs[@]}" -gt 0 ]; then
    sudo pacman -S --noconfirm --needed "${repo_pkgs[@]}" || {
      echo "Warning: pacman failed to install one or more repo packages: ${repo_pkgs[*]}"
      echo " - Check that the 'community' repo is enabled and run: sudo pacman -S --needed ${repo_pkgs[*]}"
    }
  fi

  ensure_yay() {
    if command -v yay >/dev/null 2>&1; then
      return 0
    fi
    echo "yay not found — attempting to build yay (requires base-devel & git)..."
    sudo pacman -S --noconfirm --needed base-devel git || true
    tmpd="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay.git "$tmpd/yay" >/dev/null 2>&1 || {
      echo "Failed to clone yay AUR repo."
      rm -rf "$tmpd"
      return 1
    }
    cd "$tmpd/yay" || return 1
    makepkg -si --noconfirm || {
      echo "Failed to build/install yay."
      cd - >/dev/null 2>&1 || true
      rm -rf "$tmpd"
      return 1
    }
    cd - >/dev/null 2>&1 || true
    rm -rf "$tmpd"
    command -v yay >/dev/null 2>&1 || {
      echo "yay installation failed or not in PATH."
      return 1
    }
    return 0
  }

  # install AUR packages via yay if any
  if [ "${#aur_pkgs[@]}" -gt 0 ]; then
    if ensure_yay; then
      yay -S --noconfirm --needed "${aur_pkgs[@]}" || {
        echo "Warning: yay failed to install one or more AUR packages: ${aur_pkgs[*]}"
        echo " - You may need to install these manually or enable the correct repos."
      }
    else
      echo "Skipping AUR packages (yay not available): ${aur_pkgs[*]}"
      echo " - Install an AUR helper (yay/paru) or install these manually."
    fi
  fi

else
  DEB_PKGS=(
    i3 i3-gaps mate-terminal picom feh imagemagick ffmpeg
    fastfetch w3m ranger rofi zsh git build-essential cmake pkg-config
    mpc mpd alsa-utils
  )
  pkg_install "${DEB_PKGS[@]}"
fi

# Polybar on Debian: build deps + build; on Arch use pacman package
if [ "$PLATFORM" = "debian" ]; then
  echo -e "\nInstalling polybar build dependencies and building polybar..."
  sudo apt install -y cmake cmake-data libcairo2-dev libxcb1-dev libxcb-ewmh-dev \
    libxcb-icccm4-dev libxcb-image0-dev libxcb-randr0-dev libxcb-util0-dev \
    libxcb-xkb-dev pkg-config python3-xcbgen xcb-proto libxcb-xrm-dev libasound2-dev \
    libmpdclient-dev libiw-dev libcurl4-openssl-dev libpulse-dev libxcb-composite0-dev
  if [ ! -d "$HOME/polybar" ]; then
    git clone https://github.com/jaagr/polybar.git "$HOME/polybar"
  fi
  cd "$HOME/polybar"
  ./build.sh
  sudo apt install -y polybar || true
  # try to install example config
  if [ -f /usr/share/doc/polybar/config ]; then
    install -Dm644 /usr/share/doc/polybar/config "$HOME/.config/polybar/config"
  fi
  cd "$SCRIPT_DIR"
else
  echo -e "\nPolybar installed from pacman (if available)."
  # pacman already installed polybar above; if not, user can build from AUR
fi


# wallset (install from upstream)
echo -e "\nInstalling wallset..."
if [ ! -d "$HOME/wallset" ]; then
  git clone https://github.com/terroo/wallset "$HOME/wallset"
fi
cd "$HOME/wallset"
sudo bash install.sh || true
sudo ./install.sh --force || true
cd "$SCRIPT_DIR"

# polybar-themes (user interactive)
echo -e "\nInstalling polybar-themes (interactive)..."
if [ ! -d "$HOME/polybar-themes" ]; then
  git clone --depth=1 https://github.com/adi1090x/polybar-themes.git "$HOME/polybar-themes"
fi
cd "$HOME/polybar-themes"
chmod +x setup.sh || true
echo "Launching polybar-themes setup (choose options interactively)..."
./setup.sh || true
cd "$SCRIPT_DIR"


# link repo polybar panels into user config (safe, non-destructive)
mkdir -p "$HOME/.config/polybar"
if [ -d "$SCRIPT_DIR/polybar/panels" ] && [ ! -e "$HOME/.config/polybar/panels" ]; then
    ln -s "$SCRIPT_DIR/polybar/panels" "$HOME/.config/polybar/panels"
    echo "Linked $SCRIPT_DIR/polybar/panels -> $HOME/.config/polybar/panels"
else
    echo "Skipping panels link (target exists or source missing)"
fi

# make panel scripts executable (ensure any nested scripts run)
if [ -d "$SCRIPT_DIR/polybar/panels/scripts" ]; then
  find "$SCRIPT_DIR/polybar/panels/scripts" -type f -name "*.sh" -exec chmod +x {} \; || true
fi
# also ensure top-level launchers are executable
[ -f "$SCRIPT_DIR/polybar/launch.sh" ] && chmod +x "$SCRIPT_DIR/polybar/launch.sh" || true
[ -f "$SCRIPT_DIR/polybar/panels/launch.sh" ] && chmod +x "$SCRIPT_DIR/polybar/panels/launch.sh" || true

# --- Wire up i3 and run repo scripts to complete i3/polybar setup ---

# 1) link i3 config from repo if present
I3_SRC_CANDIDATES=(
  "$SCRIPT_DIR/i3"
  "$SCRIPT_DIR/.config/i3"
  "$SCRIPT_DIR/configs/i3"
  "$SCRIPT_DIR/xdg_config/i3"
)
for s in "${I3_SRC_CANDIDATES[@]}"; do
  if [ -d "$s" ]; then
    mkdir -p "$HOME/.config"
    if [ ! -e "$HOME/.config/i3" ]; then
      ln -s "$s" "$HOME/.config/i3"
      echo "Linked i3 config: $s -> $HOME/.config/i3"
    else
      echo "i3 config already exists at ~/.config/i3, skipping link"
    fi
    break
  fi
done

# 2) ensure i3 will start the panels on session start (append if missing)
I3_CONFIG="$HOME/.config/i3/config"
LAUNCH_CANDIDATES=(
  "$HOME/.config/polybar/panels/launch.sh"
  "$HOME/.config/polybar/launch.sh"
  "$SCRIPT_DIR/polybar/panels/launch.sh"
  "$SCRIPT_DIR/polybar/launch.sh"
)
for p in "${LAUNCH_CANDIDATES[@]}"; do
  if [ -f "$p" ]; then
    PANEL_LAUNCH="$p"
    break
  fi
done

if [ -n "${PANEL_LAUNCH-}" ]; then
  chmod +x "$PANEL_LAUNCH" || true
  if [ -f "$I3_CONFIG" ]; then
    if ! grep -Fq "kali-punk: launch polybar panels" "$I3_CONFIG"; then
cat >> "$I3_CONFIG" <<EOF

# kali-punk: launch polybar panels
exec --no-startup-id "$PANEL_LAUNCH"
EOF
      echo "Appended panels launch to $I3_CONFIG"
    else
      echo "Panels launch already present in $I3_CONFIG"
    fi
  else
    echo "No i3 config at $I3_CONFIG to modify (skipping adding panels exec)"
  fi
else
  echo "No panel launch script found (skipping i3 exec addition)"
fi

# 3) run after-boot script (sets wallpaper / plays boot video) if present
AFTER_BOOT="$SCRIPT_DIR/polybar/panels/scripts/after-boot.sh"
if [ -f "$AFTER_BOOT" ]; then
  chmod +x "$AFTER_BOOT" || true
  echo "Running after-boot script (detached)..."
  # detach so any video player / GUI tools can't terminate the installer
  nohup setsid bash "$AFTER_BOOT" >> "$HOME/.kali-punk-after-boot.log" 2>&1 </dev/null &
else
  echo "after-boot.sh not found at $AFTER_BOOT"
fi

# 4) Start panel launcher now if possible (prefer the panels/launch.sh which launches immediately)
PREFERRED_LAUNCHERS=(
  "$HOME/.config/polybar/panels/launch.sh"
  "$HOME/.config/polybar/launch.sh"
  "$SCRIPT_DIR/polybar/panels/launch.sh"
  "$SCRIPT_DIR/polybar/launch.sh"
)
for l in "${PREFERRED_LAUNCHERS[@]}"; do
  if [ -x "$l" ]; then
    RUNTIME_PANEL_LAUNCH="$l"
    break
  fi
done

if [ -n "${DISPLAY-}" ] && command -v polybar >/dev/null 2>&1 && [ -n "${RUNTIME_PANEL_LAUNCH-}" ]; then
  echo "Attempting to launch polybar panels now using: $RUNTIME_PANEL_LAUNCH"
  # run in background so installer can finish; preserve logs to file for debugging
  nohup bash "$RUNTIME_PANEL_LAUNCH" >> "$HOME/.kali-punk-install.log" 2>&1 &
else
  echo "Skipping immediate polybar launch (no DISPLAY, no polybar, or no launcher found)."
fi

# 5) ensure helper scripts referenced by panels are present/executable in user config
USER_SCRIPTS_DIR="$HOME/.config/polybar/panels/scripts"
if [ -d "$USER_SCRIPTS_DIR" ]; then
  find "$USER_SCRIPTS_DIR" -type f -name "*.sh" -exec chmod +x {} \; || true
  echo "Ensured panel helper scripts are executable in $USER_SCRIPTS_DIR"
fi

# Ensure panel scripts are executable (already present earlier)
if [ -d "$SCRIPT_DIR/polybar/panels/scripts" ]; then
  find "$SCRIPT_DIR/polybar/panels/scripts" -type f -name "*.sh" -exec chmod +x {} \; || true
fi

# Apply a default panel style (runs styles.sh to install config & wallpaper)
# Choose a theme that exists in your panels (e.g. "--gnome" or "--budgie" or "--mint")
DEFAULT_STYLE="--gnome"
STYLES_SH_CANDIDATES=(
  "$HOME/.config/polybar/panels/scripts/styles.sh"
  "$SCRIPT_DIR/polybar/panels/scripts/styles.sh"
)
for s in "${STYLES_SH_CANDIDATES[@]}"; do
  if [ -x "$s" ]; then
    echo "Applying default polybar style: $DEFAULT_STYLE via $s"
    # run in foreground so any config changes take effect immediately
    bash "$s" "$DEFAULT_STYLE" || true
    break
  fi
done

# Note: style-switch.sh and powermenu.sh are interactive helpers (rofi menus).
# They are not suitable for automatic execution during install. They are left
# available under ~/.config/polybar/panels/scripts for runtime use.

echo -e "\nInstall script finished. Review $HOME/.kali-punk-install.log and the output for any errors and complete any interactive steps."
