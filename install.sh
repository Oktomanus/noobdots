#!/bin/sh

# =============================================================================
#  Arch Linux Hyprland Installation Script
#  Auto-detects CPU architecture via CachyOS & asks for GPU drivers
# =============================================================================

set -e

# -----------------------------------------------------------------------------
#  Color & Formatting
# -----------------------------------------------------------------------------
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RED="\033[0;31m"
CYAN="\033[0;36m"
BOLD="\033[1m"
NC="\033[0m"

# -----------------------------------------------------------------------------
#  Configuration
# -----------------------------------------------------------------------------
PACMAN_CONF="/etc/pacman.conf"
NOOBDOTS_REPO="https://github.com/Oktomanus/noobdots"

# -----------------------------------------------------------------------------
#  Helper Functions
# -----------------------------------------------------------------------------

print_banner() {
  echo -e "${CYAN}"
  echo "=============================================="
  echo "   Arch Linux Hyprland Setup                  "
  echo "=============================================="
  echo -e "${NC}"
}

print_step() {
  echo -e "\n${BLUE}━━━▶${NC} ${BOLD}$1${NC}"
}

print_substep() {
  echo -e "  ${CYAN}▸${NC} $1"
}

print_success() {
  echo -e "  ${GREEN}✓${NC} $1"
}

print_error() {
  echo -e "  ${RED}✗${NC} ${RED}$1${NC}" >&2
}

print_warning() {
  echo -e "  ${YELLOW}!${NC} ${YELLOW}$1${NC}" >&2
}

run_cmd() {
  local description="$1"
  shift

  while true; do
    print_substep "$description"

    if eval "$@"; then
      print_success "$description"
      return 0
    fi

    print_error "Failed: $description"
    echo ""
    echo -e "  ${YELLOW}[r]${NC} Retry  ${YELLOW}[s]${NC} Skip  ${YELLOW}[a]${NC} Abort"
    read -p "  Choice: " choice

    case "$choice" in
      [Rr]) continue ;;
      [Ss]) print_warning "Skipped: $description"; return 0 ;;
      [Aa]) print_error "Aborted by user."; exit 1 ;;
      *)    print_warning "Invalid choice. Try again." ;;
    esac
  done
}

# -----------------------------------------------------------------------------
#  Pre-flight Questions
# -----------------------------------------------------------------------------

ask_questions() {
  echo -e "${YELLOW}This script will set up a Hyprland desktop on Arch Linux.${NC}"
  echo ""

  echo -e "${CYAN}GPU Drivers${NC}"
  read -p "Do you have an NVIDIA GPU? (If no, AMD drivers will be installed) [y/N]: " nvidia_choice
  case "$nvidia_choice" in
    [Yy]*) HAS_NVIDIA=true;  print_success "GPU: NVIDIA" ;;
    *)     HAS_NVIDIA=false; print_success "GPU: AMD" ;;
  esac
  echo ""

  echo -e "${CYAN}AUR Packages${NC}"
  read -p "Install extra AUR packages (themes, cursor, upscayl)? [Y/n]: " aur_choice
  case "$aur_choice" in
    [Nn]*) INSTALL_AUR=false; print_warning "AUR packages: skipped" ;;
    *)     INSTALL_AUR=true;  print_success "AUR packages: yes" ;;
  esac
  echo ""
}

# -----------------------------------------------------------------------------
#  Pacman Configuration
# -----------------------------------------------------------------------------

configure_pacman() {
  print_step "Configuring pacman"

  if ! grep -q "^ILoveCandy" "$PACMAN_CONF"; then
    sudo sed -i '/^\[options\]/a ILoveCandy' "$PACMAN_CONF"
    print_success "Enabled ILoveCandy"
  fi

  if grep -q "^#ParallelDownloads" "$PACMAN_CONF"; then
    sudo sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 10/' "$PACMAN_CONF"
    print_success "Enabled ParallelDownloads = 10"
  fi
}

# -----------------------------------------------------------------------------
#  CachyOS Repositories Setup
# -----------------------------------------------------------------------------

add_cachyos_repo() {
  print_step "Adding CachyOS Repositories"
  
  local tmp_dir
  tmp_dir="$(mktemp -d /tmp/cachyos-repo.XXXXXX)"

  run_cmd "Downloading and running CachyOS repo script (Auto-detects CPU arch)" \
    "cd '$tmp_dir' && curl -O https://mirror.cachyos.org/cachyos-repo.tar.xz && tar xvf cachyos-repo.tar.xz && cd cachyos-repo && sudo ./cachyos-repo.sh"

  rm -rf "$tmp_dir"
}

# -----------------------------------------------------------------------------
#  System Update
# -----------------------------------------------------------------------------

update_system() {
  print_step "Full system update"
  run_cmd "Syncing databases and upgrading packages" \
    "sudo pacman -Syu"
}

# -----------------------------------------------------------------------------
#  Package Installation
# -----------------------------------------------------------------------------

install_packages() {
  print_step "Installing core, apps, and CachyOS pre-compiled packages"

  if [ "$HAS_NVIDIA" = true ]; then
    DRIVERS="nvidia-dkms nvidia-utils egl-wayland"
  else
    DRIVERS="mesa vulkan-radeon libva-mesa-driver amd-ucode xf86-video-amdgpu"
  fi

  CORE="
    hyprland xdg-desktop-portal-hyprland hyprlock hypridle hyprpicker hyprshot
    waybar mako ly
    base-devel udisks2
  "

  TERMINAL="
    yazi foot fastfetch fish tmux btop bat ripgrep fd
    brightnessctl git openssh helix duf fzf eza zoxide
    calcurse 7zip libqalculate cava lolcat bluetui impala
    gping trippy s-tui speedtest-cli
  "

  FUN="
    cmatrix cowsay figlet toilet sl asciiquarium nyancat
  "

  MEDIA="
    imagemagick mpd mpc mpv easyeffects nwg-look wiremix rmpc
  "

  FONTS="
    ttf-jetbrains-mono-nerd ttf-firacode-nerd ttf-dejavu-nerd
  "

  APPS="
    firefox inkscape krita gimp gmic gimp-plugin-gmic
    imv audacity libreoffice obs-studio zed fragments kooha swappy
  "

  CACHY_REPO="
    paru joplin ayugram-desktop waypaper tty-clock
  "

  ALL_PACKAGES=$(echo $DRIVERS $CORE $TERMINAL $FUN $MEDIA $FONTS $APPS $CACHY_REPO)

  # Флаг --needed предотвращает скачивание уже установленных пакетов
  run_cmd "Installing all packages via pacman (Interactive mode)" \
    "sudo pacman -S --needed $ALL_PACKAGES"
}

# -----------------------------------------------------------------------------
#  AUR Packages (via paru)
# -----------------------------------------------------------------------------

install_aur_packages() {
  print_step "Installing remaining AUR packages via paru"

  AUR_PACKAGES="
    battop pipes.sh upscayl bibata-cursor-theme
    catppuccin-gtk-theme-mocha catppuccin-gtk-theme-latte
  "

  AUR_PACKAGES=$(echo $AUR_PACKAGES)

  run_cmd "Installing extra AUR packages" \
    "paru -S --needed $AUR_PACKAGES"
}

# -----------------------------------------------------------------------------
#  Yazi Plugins
# -----------------------------------------------------------------------------

install_yazi_plugins() {
  print_step "Installing Yazi plugins"

  run_cmd "Adding mount plugin" \
    "yes | ya pkg add yazi-rs/plugins:mount"

  run_cmd "Adding chmod plugin" \
    "yes | ya pkg add yazi-rs/plugins:chmod"
}

# -----------------------------------------------------------------------------
#  Login Manager (ly)
# -----------------------------------------------------------------------------

configure_login_manager() {
  print_step "Configuring ly login manager"

  for dm in gdm sddm lightdm lxdm; do
    if systemctl is-enabled "${dm}.service" >/dev/null 2>&1; then
      run_cmd "Disabling conflicting ${dm}.service" \
        "sudo systemctl disable '${dm}.service'"
    fi
  done

  if systemctl is-enabled getty@tty2.service >/dev/null 2>&1; then
    run_cmd "Disabling getty@tty2.service" \
      "sudo systemctl disable getty@tty2.service"
  fi

  run_cmd "Enabling ly.service" \
    "sudo systemctl enable ly@tty2.service"
}

# -----------------------------------------------------------------------------
#  Default Shell → fish
# -----------------------------------------------------------------------------

configure_shell() {
  print_step "Setting default shell to fish"

  current_shell="$(getent passwd "$USER" | cut -d: -f7)"
  if [ "$current_shell" = "/usr/bin/fish" ]; then
    print_success "fish is already the default shell"
  else
    run_cmd "Changing shell to fish" \
      "chsh -s /usr/bin/fish"
  fi
}

# -----------------------------------------------------------------------------
#  Noobdots Configuration
# -----------------------------------------------------------------------------

setup_noobdots() {
  print_step "Setting up noobdots dotfiles"

  if [ ! -d "$HOME/noobdots" ]; then
    run_cmd "Cloning noobdots repository" \
      "git clone '$NOOBDOTS_REPO' '$HOME/noobdots'"
  else
    print_success "noobdots already cloned"
  fi

  if [ -d "$HOME/noobdots/config" ]; then
    run_cmd "Copying config folder contents to ~/.config" \
      "mkdir -p \"\$HOME/.config\" && cp -a \"\$HOME/noobdots/config/.\" \"\$HOME/.config/\""
  else
    run_cmd "Copying root contents to ~/.config" \
      "mkdir -p \"\$HOME/.config\" && cp -a \"\$HOME/noobdots/\"* \"\$HOME/.config/\""
  fi
}

# -----------------------------------------------------------------------------
#  Reboot Prompt
# -----------------------------------------------------------------------------

prompt_reboot() {
  echo ""
  echo -e "${GREEN}=============================================="
  echo "   Installation complete!                      "
  echo -e "==============================================${NC}"
  echo ""
  echo -e "${YELLOW}A reboot is recommended to apply all changes.${NC}"
  echo ""
  read -p "Reboot now? [Y/n]: " answer
  case "$answer" in
    [Nn]*) echo "Reboot later with: ${BOLD}reboot${NC}" ;;
    *)     print_success "Rebooting..."; reboot ;;
  esac
}

# -----------------------------------------------------------------------------
#  Main
# -----------------------------------------------------------------------------

main() {
  print_banner
  ask_questions

  # 1. Pacman tuning
  configure_pacman

  # 2. Add CachyOS Repositories
  add_cachyos_repo

  # 3. System update
  update_system

  # 4. Official repo + CachyOS packages + Drivers
  install_packages

  # 5. Extra AUR packages (if requested)
  if [ "$INSTALL_AUR" = true ]; then
    install_aur_packages
  fi

  # 6. Yazi plugins
  install_yazi_plugins

  # 7. Login manager & shell
  configure_login_manager
  configure_shell

  # 8. Dotfiles
  setup_noobdots

  # Done
  prompt_reboot
}

main "$@"
