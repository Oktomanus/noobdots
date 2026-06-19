#!/bin/sh

# =============================================================================
#  Arch Linux Hyprland Installation Script
#  Automated setup for a complete Hyprland desktop environment
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
PARU_REPO="https://aur.archlinux.org/paru.git"

# -----------------------------------------------------------------------------
#  Helper Functions
# -----------------------------------------------------------------------------

print_banner() {
  echo -e "${CYAN}"
  echo "=============================================="
  echo "   Arch Linux Hyprland Installation Script    "
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

# Robust command runner with retry/skip/abort on failure
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

# Check if a command exists
has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# -----------------------------------------------------------------------------
#  Pre-flight Questions
# -----------------------------------------------------------------------------

ask_questions() {
  echo -e "${YELLOW}This script will set up a Hyprland desktop on Arch Linux.${NC}"
  echo -e "${YELLOW}On failure, you can retry, skip, or abort each step.${NC}"
  echo ""

  echo -e "${CYAN}NVIDIA Drivers${NC}"
  read -p "Install NVIDIA GPU drivers? [y/N]: " nvidia_choice
  case "$nvidia_choice" in
    [Yy]*) INSTALL_NVIDIA=true;  print_success "NVIDIA drivers: yes" ;;
    *)     INSTALL_NVIDIA=false; print_warning "NVIDIA drivers: no"  ;;
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
  else
    print_success "ILoveCandy already set"
  fi

  if grep -q "^#ParallelDownloads" "$PACMAN_CONF"; then
    sudo sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 10/' "$PACMAN_CONF"
    print_success "Enabled ParallelDownloads = 10"
  elif grep -q "^ParallelDownloads" "$PACMAN_CONF"; then
    sudo sed -i 's/^ParallelDownloads.*/ParallelDownloads = 10/' "$PACMAN_CONF"
    print_success "ParallelDownloads already configured"
  fi
}

# -----------------------------------------------------------------------------
#  System Update
# -----------------------------------------------------------------------------

update_system() {
  print_step "Full system update"
  run_cmd "Syncing databases and upgrading packages" \
    "sudo pacman -Syu --noconfirm"
}

# -----------------------------------------------------------------------------
#  NVIDIA Drivers
# -----------------------------------------------------------------------------

install_nvidia() {
  print_step "Installing NVIDIA drivers"
  run_cmd "Installing nvidia-open, nvidia-settings, libva-nvidia-driver, cuda" \
    "sudo pacman -S --needed --noconfirm nvidia-open nvidia-settings libva-nvidia-driver cuda"
}

# -----------------------------------------------------------------------------
#  Package Installation (official repos)
# -----------------------------------------------------------------------------

install_packages() {
  print_step "Installing packages from official repositories"

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

  # Убираем переносы строк с помощью echo
  ALL_PACKAGES=$(echo $CORE $TERMINAL $FUN $MEDIA $FONTS $APPS)

  run_cmd "Installing all official packages" \
    "sudo pacman -S --needed --noconfirm $ALL_PACKAGES"
}

# -----------------------------------------------------------------------------
#  Build & Install paru from source
# -----------------------------------------------------------------------------

install_paru() {
  print_step "Installing paru (AUR helper)"

  if has_cmd paru; then
    print_success "paru is already installed"
    return 0
  fi

  local build_dir
  build_dir="$(mktemp -d /tmp/paru-build.XXXXXX)"

  run_cmd "Cloning paru from AUR" \
    "git clone '$PARU_REPO' '$build_dir/paru'"

  run_cmd "Building and installing paru" \
    "cd '$build_dir/paru' && makepkg -si --noconfirm --needed"

  # Cleanup build artifacts
  rm -rf "$build_dir"
  print_success "Cleaned up paru build directory"
}

# -----------------------------------------------------------------------------
#  AUR Packages (via paru)
# -----------------------------------------------------------------------------

install_aur_packages() {
  print_step "Installing AUR packages via paru"

  AUR_PACKAGES="
    battop tty-clock pipes.sh waypaper joplin-desktop
    upscayl bibata-cursor-theme ayugram-desktop
    catppuccin-gtk-theme-mocha catppuccin-gtk-theme-latte
  "

  # Убираем переносы строк с помощью echo
  AUR_PACKAGES=$(echo $AUR_PACKAGES)

  run_cmd "Installing AUR packages" \
    "paru -S --needed --noconfirm $AUR_PACKAGES"
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

  # Disable any existing display managers that might conflict
  for dm in gdm sddm lightdm lxdm; do
    if systemctl is-enabled "${dm}.service" >/dev/null 2>&1; then
      run_cmd "Disabling conflicting ${dm}.service" \
        "sudo systemctl disable '${dm}.service'"
    fi
  done

  # Disable getty on tty2 (ly will use it by default)
  if systemctl is-enabled getty@tty2.service >/dev/null 2>&1; then
    run_cmd "Disabling getty@tty2.service (ly takes over)" \
      "sudo systemctl disable getty@tty2.service"
  fi

  run_cmd "Enabling ly.service" \
    "sudo systemctl enable ly@tty2.service"

  print_success "ly login manager configured"
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

  run_cmd "Copying config files to ~/.config" \
    "mkdir -p '$HOME/.config' && cp -r '$HOME/noobdots/config/'* '$HOME/.config/'"
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

  # 1. Pacman tuning & system update
  configure_pacman
  update_system

  # 2. NVIDIA (if requested)
  if [ "$INSTALL_NVIDIA" = true ]; then
    install_nvidia
  fi

  # 3. Official repo packages
  install_packages

  # 4. Build paru, then AUR packages
  install_paru
  install_aur_packages

  # 5. Yazi plugins
  install_yazi_plugins

  # 6. Login manager & shell
  configure_login_manager
  configure_shell

  # 7. Dotfiles
  setup_noobdots

  # Done
  prompt_reboot
}

main "$@"
