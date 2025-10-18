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
  pkg_install i3 i3-gaps polybar mate-terminal compton feh imagemagick ffmpeg \
    neofetch w3m ranger rofi zsh git base-devel
else
  pkg_install i3 i3-gaps mate-terminal compton feh imagemagick ffmpeg \
    neofetch w3m ranger rofi zsh git build-essential cmake pkg-config
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

# Brave browser
echo -e "\nInstalling Brave browser..."
if [ "$PLATFORM" = "arch" ]; then
  pkg_install brave
else
  sudo apt install -y apt-transport-https curl
  sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
    https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" \
    | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
  pkg_update
  sudo apt install -y brave-browser
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
chmod +x setup.sh
echo "Launching polybar-themes setup (choose options interactively)..."
./setup.sh || true
cd "$SCRIPT_DIR"

# zsh + oh-my-zsh + plugins
echo -e "\nInstalling zsh and oh-my-zsh..."
pkg_install zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true
fi
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions || true
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting || true
chsh -s "$(which zsh)" || true

echo -e "\nInstall script finished. Review output for any errors and run any interactive installers that were invoked."
