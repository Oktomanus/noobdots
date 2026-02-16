#!/bin/sh

set -e  # Stop the script on error

# Color variables
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RED="\033[0;31m"
NC="\033[0m" # No color

print_step() {
  echo -e "${BLUE}==> $1${NC}"
}

print_error() {
  echo -e "${RED}Error: $1${NC}" >&2
}

run_cmd() {
  description="$1"
  shift
  print_step "$description"
  if ! "$@"; then
    print_error "Failed to execute: $description"
    exit 1
  fi
}

# --- 1. Chaotic-AUR and pacman setup ---

run_cmd "Importing GPG key" sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com

run_cmd "Trusting the key" sudo pacman-key --lsign-key 3056513887B78AEB

run_cmd "Installing chaotic-keyring and chaotic-mirrorlist" sudo pacman -U --needed --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

CONF_FILE="/etc/pacman.conf"

print_step "Adding chaotic-aur repository to pacman.conf"
if ! grep -q "^\[chaotic-aur\]" "$CONF_FILE"; then
  {
    echo ""
    echo "[chaotic-aur]"
    echo "Include = /etc/pacman.d/chaotic-mirrorlist"
  } | sudo tee -a "$CONF_FILE" > /dev/null
fi

print_step "Adding ILoveCandy to pacman.conf"
if ! grep -q "^ILoveCandy" "$CONF_FILE"; then
  sudo sed -i '/^#Color/i ILoveCandy' "$CONF_FILE"
fi

print_step "Setting ParallelDownloads"
if grep -q "^#ParallelDownloads" "$CONF_FILE"; then
  sudo sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 10/' "$CONF_FILE"
elif grep -q "^ParallelDownloads" "$CONF_FILE"; then
  sudo sed -i 's/^ParallelDownloads.*/ParallelDownloads = 10/' "$CONF_FILE"
else
  sudo sed -i '/^#Color/a ParallelDownloads = 10' "$CONF_FILE"
fi

print_step "Enabling pacman color output"
if grep -q "^#Color" "$CONF_FILE"; then
  sudo sed -i 's/^#Color/Color/' "$CONF_FILE"
fi

# --- 2. Adding line to /etc/fstab ---
#FSTAB_LINE="UUID=23df1d4f-af77-41ce-bac6-0dc5e604511a         /mnt/storage       ext4     defaults 0 2"
#if ! grep -qF "$FSTAB_LINE" /etc/fstab; then
 # print_step "Adding entry to /etc/fstab"
 # echo "$FSTAB_LINE #storage" | sudo tee -a /etc/fstab > /dev/null
#else
#  print_step "Entry for /mnt/storage already exists in /etc/fstab"
#fi

# --- 3. Installing reflector and updating mirrors ---
run_cmd "Installing reflector if not installed" sudo pacman -Sy --noconfirm --needed reflector

run_cmd "Updating mirrorlist using reflector" sudo reflector --country Ukraine,Poland,Germany --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# --- 4. System update ---
run_cmd "Updating the system" sudo pacman -Syu --noconfirm

# --- 5. Installing applications ---
run_cmd "Installing main application list" sudo pacman -S --needed --noconfirm \
  hyprland xdg-desktop-portal-hyprland hyprlock hypridle hyprpicker wl-clipboard\
  waybar mako swww grim slurp swappy grimblast kooha ly\
  yazi foot fastfetch fish rust btop battop brightnessctl power-profiles-daemon git openssh helix paru duf fzf eza zoxide calcurse impala p7zip ntfs-3g qalculate-gtk cava lolcat \
  cmatrix asciiquarium cowsay figlet toilet nyancat sl speedtest-cli tty-clock \
   imagemagick bluetui mpd mpc rmpc \
   mpv wiremix easyeffects waypaper nwg-look \
  bibata-cursor-theme ttf-ms-fonts ttf-jetbrains-mono-nerd ttf-firacode-nerd ttf-dejavu-nerd noto-fonts noto-fonts-emoji \
  firefox telegram-desktop fragments zed shotcut inkscape krita gimp gmic gimp-plugin-gmic upscayl imv audacity libreoffice obs-studio
#   nvidia nvidia-settings libva-nvidia-driver cuda\
# --- 5.1 Installing AUR packages using paru. Pluguins ---

# run_cmd "Installing anytype and pipes.sh via paru" paru -S --needed anytype pipes.sh catppuccin-gtk-theme-mocha catppuccin-gtk-theme-latte

run_cmd "Installing Yazi mount plugin" sh -c "yes | ya pkg add yazi-rs/plugins:mount"
run_cmd "Installing Yazi Chmod plugin" sh -c "yes | ya pkg add yazi-rs/plugins:chmod"

# --- 6. Shell change, sddm and theme install ---
run_cmd "Changing shell to fish" chsh -s /usr/bin/fish

run_cmd "Enabling Login Manager" sudo systemctl enable ly@tty2.service
run_cmd "Enabling Login Manager" sudo systemctl disable getty@tty2.service
# --- 7. Cloning noobdots and copying configs ---
print_step "Cloning noobdots repository into home directory"
if [ ! -d "$HOME/noobdots" ]; then
  if ! git clone https://github.com/Oktomanus/noobdots "$HOME/noobdots"; then
    print_error "Failed to clone noobdots repository"
    exit 1
  fi
else
  print_step "noobdots repository already exists"
fi

print_step "Copying contents of ~/noobdots/config to ~/.config"
mkdir -p "$HOME/.config"
cp -r "$HOME/noobdots/config/"* "$HOME/.config/"

print_step "Making scripts executable"
chmod +x "$HOME/.config/waybar/cpuinfo" "$HOME/.config/waybar/wttrbar"

print_step "Copying wallpapers folder from ~/noobdots to ~/.config"
cp -r "$HOME/noobdots/wallpapers" "$HOME/.config/"

# --- 8. Adding paths to zoxide ---
print_step "Adding paths to zoxide"
zoxide add "$HOME/.config"

print_step "${GREEN}✅ All tasks completed. A reboot is recommended.${NC}"

read -p "Reboot now? [Y/n]: " answer
case "$answer" in
  [Yy]* ) reboot;;
  * ) echo "You can reboot later using the 'reboot' command.";;
esac
