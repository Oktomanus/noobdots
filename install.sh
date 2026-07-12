#!/bin/bash
set -e

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"

PACMAN_CONF="/etc/pacman.conf"
NOOBDOTS_REPO="https://github.com/Oktomanus/noobdots"

log() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}==>${NC} $1"; }
error() { echo -e "${RED}ERROR:${NC} $1" >&2; }

run_cmd() {
  local desc="$1"
  shift
  while true; do
    log "$desc"
    if eval "$@"; then return 0; fi
    error "Failed: $desc"
    echo -e "${YELLOW}[r]${NC} Retry  ${YELLOW}[s]${NC} Skip  ${YELLOW}[a]${NC} Abort"
    read -p "Choice: " choice
    case "$choice" in
      [Rr]) continue ;;
      [Ss]) warn "Skipped: $desc"; return 0 ;;
      [Aa]) error "Aborted."; exit 1 ;;
      *) warn "Invalid choice." ;;
    esac
  done
}

ask_questions() {
  read -p "Install NVIDIA drivers? (If no, AMD will be installed) [y/N]: " nvidia_choice
  case "$nvidia_choice" in
    [Yy]*) HAS_NVIDIA=true ;;
    *) HAS_NVIDIA=false ;;
  esac

  read -p "Install extra AUR packages? [Y/n]: " aur_choice
  case "$aur_choice" in
    [Nn]*) INSTALL_AUR=false ;;
    *) INSTALL_AUR=true ;;
  esac
}

configure_pacman() {
  if ! grep -q "^ILoveCandy" "$PACMAN_CONF"; then
    sudo sed -i '/^\[options\]/a ILoveCandy' "$PACMAN_CONF"
  fi
  if grep -q "^#ParallelDownloads" "$PACMAN_CONF"; then
    sudo sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 10/' "$PACMAN_CONF"
  fi
}

add_cachyos_repo() {
  local tmp_dir
  tmp_dir="$(mktemp -d /tmp/cachyos-repo.XXXXXX)"
  run_cmd "Adding CachyOS repositories" \
    "( cd \"$tmp_dir\" && curl -L https://mirror.cachyos.org/cachyos-repo.tar.xz -o cachyos-repo.tar.xz && tar xvf cachyos-repo.tar.xz && cd cachyos-repo && sudo ./cachyos-repo.sh )"
  rm -rf "$tmp_dir"
}

update_system() {
  run_cmd "Updating system databases" "sudo pacman -Syu"
}

install_packages() {
  if [ "$HAS_NVIDIA" = true ]; then
    DRIVERS="nvidia-dkms nvidia-utils egl-wayland"
  else
    DRIVERS="mesa vulkan-radeon libva-mesa-driver amd-ucode xf86-video-amdgpu"
  fi

  CORE="hyprland xdg-desktop-portal-hyprland hyprlock hypridle hyprpicker hyprshot waybar mako ly base-devel udisks2"
  TERMINAL="yazi foot fastfetch fish tmux btop bat ripgrep fd brightnessctl git openssh helix duf fzf eza zoxide calcurse 7zip libqalculate cava lolcat bluetui impala gping rustnet trippy s-tui speedtest-cli"
  FUN="cmatrix cowsay figlet toilet sl asciiquarium nyancat"
  MEDIA="imagemagick awww mpd mpc mpv easyeffects nwg-look wiremix rmpc"
  FONTS="ttf-jetbrains-mono-nerd ttf-firacode-nerd ttf-dejavu-nerd"
  APPS="librewolf inkscape krita gimp gmic gimp-plugin-gmic imv audacity libreoffice obs-studio zed fragments kooha swappy"
  CACHY_REPO="paru joplin telegram-desktop waypaper tty-clock"

  ALL_PACKAGES=$(echo $DRIVERS $CORE $TERMINAL $FUN $MEDIA $FONTS $APPS $CACHY_REPO)
  run_cmd "Installing official and CachyOS packages" "sudo pacman -S --needed $ALL_PACKAGES"
}

install_aur_packages() {
  AUR_PACKAGES="battop pipes.sh upscayl bibata-cursor-theme catppuccin-gtk-theme-mocha catppuccin-gtk-theme-latte"
  run_cmd "Installing AUR packages via paru" "paru -S --needed $AUR_PACKAGES"
}

install_yazi_plugins() {
  run_cmd "Installing Yazi plugins" "ya pkg add yazi-rs/plugins:mount yazi-rs/plugins:chmod"
}

configure_login_manager() {
  for dm in gdm sddm lightdm lxdm; do
    if systemctl is-enabled "${dm}.service" >/dev/null 2>&1; then
      sudo systemctl disable "${dm}.service"
    fi
  done
  if systemctl is-enabled getty@tty2.service >/dev/null 2>&1; then
    sudo systemctl disable getty@tty2.service
  fi
  sudo systemctl enable ly@tty2.service
}

configure_shell() {
  current_shell="$(getent passwd "$USER" | cut -d: -f7)"
  if [ "$current_shell" != "/usr/bin/fish" ]; then
    chsh -s /usr/bin/fish
  fi
}

setup_noobdots() {
  if [ ! -d "$HOME/noobdots" ]; then
    run_cmd "Cloning noobdots repository" "git clone --depth 1 --single-branch '$NOOBDOTS_REPO' '$HOME/noobdots'"
  fi

  if [ -d "$HOME/noobdots/config" ]; then
    mkdir -p "$HOME/.config" && cp -a "$HOME/noobdots/config/." "$HOME/.config/"
  else
    mkdir -p "$HOME/.config" && cp -a "$HOME/noobdots/." "$HOME/.config/"
  fi
}

main() {
  ask_questions
  configure_pacman
  add_cachyos_repo
  update_system
  install_packages
  [ "$INSTALL_AUR" = true ] && install_aur_packages
  install_yazi_plugins
  configure_login_manager
  configure_shell
  setup_noobdots
  
  read -p "Reboot now? [Y/n]: " answer
  case "$answer" in
    [Nn]*) log "Done. Reboot manually when ready." ;;
    *) reboot ;;
  esac
}

main "$@"
