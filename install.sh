#!/bin/sh

# =============================================================================
#  Arch Linux Hyprland Installation Script
#  Automated setup for a complete Hyprland desktop environment
# =============================================================================

# -----------------------------------------------------------------------------
#  Color Variables
# -----------------------------------------------------------------------------
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RED="\033[0;31m"
CYAN="\033[0;36m"
BOLD="\033[1m"
NC="\033[0m"  # No Color

# -----------------------------------------------------------------------------
#  Configuration
# -----------------------------------------------------------------------------
CHAOTIC_KEY="3056513887B78AEB"
CHAOTIC_KEYRING_URL="https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst"
CHAOTIC_MIRRORLIST_URL="https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst"
PACMAN_CONF="/etc/pacman.conf"
NOOBDOTS_REPO="https://github.com/Oktomanus/noobdots"
REFLECTOR_COUNTRIES="Ukraine,Poland,Germany"

# -----------------------------------------------------------------------------
#  Ask Questions at Script Start
# -----------------------------------------------------------------------------

echo -e "${CYAN}"
echo "=============================================="
echo "   Arch Linux Hyprland Installation Script    "
echo "=============================================="
echo -e "${NC}"

echo -e "${YELLOW}This script will configure your Arch Linux system with Hyprland.${NC}"
echo -e "${YELLOW}If any command fails, you can retry, skip, or abort.${NC}"
echo ""

# Ask about NVIDIA drivers
echo -e "${CYAN}NVIDIA Drivers${NC}"
read -p "Do you have an NVIDIA GPU and want to install drivers? [y/N]: " nvidia_choice

case "$nvidia_choice" in
  [Yy]*)
    INSTALL_NVIDIA=true
    echo -e "${GREEN}NVIDIA drivers will be installed.${NC}"
    ;;
  *)
    INSTALL_NVIDIA=false
    echo -e "${YELLOW}NVIDIA drivers will be skipped.${NC}"
    ;;
esac

echo ""

# Ask about wallpapers
echo -e "${CYAN}Wallpapers Setup${NC}"
echo "The noobdots repository includes a wallpapers folder."
read -p "Download and install wallpapers? [Y/n]: " wallpapers_choice

case "$wallpapers_choice" in
  [Nn]*)
    INSTALL_WALLPAPERS=false
    echo -e "${YELLOW}Wallpapers will be skipped.${NC}"
    ;;
  *)
    INSTALL_WALLPAPERS=true
    echo -e "${GREEN}Wallpapers will be installed.${NC}"
    ;;
esac

echo ""
echo -e "${CYAN}=== Starting Installation ===${NC}"
echo ""

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
  echo -e "\n${BLUE}==>${NC} ${BOLD}$1${NC}"
}

print_success() {
  echo -e "${GREEN}✓${NC} $1"
}

print_error() {
  echo -e "${RED}✗${NC} ${RED}Error: $1${NC}" >&2
}

print_warning() {
  echo -e "${YELLOW}!${NC} ${YELLOW}Warning: $1${NC}" >&2
}

# -----------------------------------------------------------------------------
#  Error Handling with Retry Logic
# -----------------------------------------------------------------------------

handle_command_failure() {
  local description="$1"
  shift

  while true; do
    print_step "$description"

    if "$@"; then
      print_success "$description completed successfully"
      return 0
    fi

    print_error "Command failed: $description"
    echo ""
    echo -e "${YELLOW}What would you like to do?${NC}"
    echo "  [${BOLD}r${NC}] Retry the command"
    echo "  [${BOLD}s${NC}] Skip and continue"
    echo "  [${BOLD}a${NC}] Abort the entire script"
    echo ""

    read -p "Choose an option (r/s/a): " choice

    case "$choice" in
      [Rr])
        continue
        ;;
      [Ss])
        print_warning "Skipping: $description"
        return 0
        ;;
      [Aa])
        print_error "Script aborted by user"
        exit 1
        ;;
      *)
        print_warning "Invalid option. Please choose r, s, or a."
        ;;
    esac
  done
}

run_cmd() {
  local description="$1"
  shift
  handle_command_failure "$description" "$@"
}

# -----------------------------------------------------------------------------
#  Chaotic-AUR Repository Setup
# -----------------------------------------------------------------------------

setup_chaotic_aur() {
  print_step "Setting up Chaotic-AUR repository"
  echo "-------------------------------------------"

  run_cmd "Importing Chaotic-AUR GPG key" \
    sudo pacman-key --recv-key "$CHAOTIC_KEY" --keyserver keyserver.ubuntu.com

  run_cmd "Trusting the Chaotic-AUR key" \
    sudo pacman-key --lsign-key "$CHAOTIC_KEY"

  run_cmd "Installing chaotic-keyring and chaotic-mirrorlist" \
    sudo pacman -U --needed --noconfirm "$CHAOTIC_KEYRING_URL" "$CHAOTIC_MIRRORLIST_URL"

  print_step "Configuring $PACMAN_CONF"

  if ! grep -q "^\[chaotic-aur\]" "$PACMAN_CONF"; then
    {
      echo ""
      echo "[chaotic-aur]"
      echo "Include = /etc/pacman.d/chaotic-mirrorlist"
    } | sudo tee -a "$PACMAN_CONF" > /dev/null
    print_success "Added [chaotic-aur] repository"
  else
    print_success "[chaotic-aur] repository already configured"
  fi

  if ! grep -q "^ILoveCandy" "$PACMAN_CONF"; then
    sudo sed -i '/^#Color/i ILoveCandy' "$PACMAN_CONF"
    print_success "Enabled ILoveCandy"
  fi

  if grep -q "^#ParallelDownloads" "$PACMAN_CONF"; then
    sudo sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 10/' "$PACMAN_CONF"
    print_success "Enabled ParallelDownloads = 10"
  elif grep -q "^ParallelDownloads" "$PACMAN_CONF"; then
    sudo sed -i 's/^ParallelDownloads.*/ParallelDownloads = 10/' "$PACMAN_CONF"
  fi

  if grep -q "^#Color" "$PACMAN_CONF"; then
    sudo sed -i 's/^#Color/Color/' "$PACMAN_CONF"
    print_success "Enabled color output"
  fi
}

# -----------------------------------------------------------------------------
#  Mirrorlist Update with Reflector
# -----------------------------------------------------------------------------

update_mirrorlist() {
  print_step "Updating pacman mirrorlist with Reflector"
  echo "-------------------------------------------"

  run_cmd "Installing reflector" \
    sudo pacman -Sy --noconfirm --needed reflector

  run_cmd "Fetching optimal mirrors for $REFLECTOR_COUNTRIES" \
    sudo reflector --country "$REFLECTOR_COUNTRIES" --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
}

# -----------------------------------------------------------------------------
#  System Update
# -----------------------------------------------------------------------------

update_system() {
  print_step "Performing full system update"
  echo "-------------------------------------------"

  # Убран --noconfirm, чтобы вы видели, что обновляется
  run_cmd "Updating all packages" \
    sudo pacman -Syu
}

# -----------------------------------------------------------------------------
#  Package Installation (Оптимизировано в одну транзакцию)
# -----------------------------------------------------------------------------

install_packages() {
  print_step "Installing packages"
  echo "-------------------------------------------"

  CORE_PACKAGES="hyprland xdg-desktop-portal-hyprland hyprlock hypridle hyprpicker wl-clipboard waybar mako swww swappy grimblast kooha sddm base-devel udisks2"
  TERMINAL_PACKAGES="yazi foot fastfetch fish rust btop bat battop brightnessctl git openssh helix paru duf fzf eza zoxide calcurse impala p7zip ntfs-3g qalculate-gtk cava lolcat"
  FUN_PACKAGES="cmatrix asciiquarium cowsay figlet toilet nyancat sl speedtest-cli tty-clock"
  MEDIA_PACKAGES="imagemagick bluetui mpd mpc rmpc mpv wiremix easyeffects waypaper nwg-look"
  FONTS_PACKAGES="bibata-cursor-theme ttf-ms-fonts ttf-jetbrains-mono-nerd ttf-firacode-nerd ttf-dejavu-nerd noto-fonts noto-fonts-emoji"
  APPS_PACKAGES="firefox joplin ayugram-desktop fragments zed shotcut inkscape krita gimp gmic gimp-plugin-gmic upscayl imv audacity libreoffice obs-studio"
  
  # Объединяем все пакеты для быстрой установки в одну команду. Убран --noconfirm
  ALL_PACKAGES="$CORE_PACKAGES $TERMINAL_PACKAGES $FUN_PACKAGES $MEDIA_PACKAGES $FONTS_PACKAGES $APPS_PACKAGES"

  run_cmd "Installing all official repository packages" \
    sudo pacman -S --needed $ALL_PACKAGES

  AUR_PACKAGES="anytype pipes.sh catppuccin-gtk-theme-mocha catppuccin-gtk-theme-latte"

  # Убран --noconfirm для AUR пакетов
  run_cmd "Installing AUR packages via paru" \
    paru -S --needed $AUR_PACKAGES

  run_cmd "Installing Yazi mount plugin" \
    sh -c "yes | ya pkg add yazi-rs/plugins:mount"

  run_cmd "Installing Yazi chmod plugin" \
    sh -c "yes | ya pkg add yazi-rs/plugins:chmod"
}

# -----------------------------------------------------------------------------
#  Shell and Display Manager Configuration
# -----------------------------------------------------------------------------

configure_shell_and_dm() {
  print_step "Configuring shell and display manager"
  echo "-------------------------------------------"

  run_cmd "Changing default shell to fish" \
    chsh -s /usr/bin/fish

  # Исправлена критическая ошибка: было .service, стало sddm.service
  run_cmd "Enabling sddm display manager" \
    sudo systemctl enable sddm.service
}

# -----------------------------------------------------------------------------
#  Noobdots Configuration Setup
# -----------------------------------------------------------------------------

setup_noobdots() {
  print_step "Setting up noobdots configuration"
  echo "-------------------------------------------"

  if [ ! -d "$HOME/noobdots" ]; then
    run_cmd "Cloning noobdots repository" \
      git clone "$NOOBDOTS_REPO" "$HOME/noobdots"
  else
    print_success "noobdots repository already exists"
  fi

  print_step "Copying configuration files"
  mkdir -p "$HOME/.config"
  cp -r "$HOME/noobdots/config/"* "$HOME/.config/"
  print_success "Configuration files copied to ~/.config"
}

# -----------------------------------------------------------------------------
#  Wallpapers Setup
# -----------------------------------------------------------------------------

setup_wallpapers() {
  print_step "Setting up wallpapers"
  echo "-------------------------------------------"

  if [ -d "$HOME/noobdots/wallpapers" ]; then
    cp -r "$HOME/noobdots/wallpapers" "$HOME/.config/"
    print_success "Wallpapers copied to ~/.config/wallpapers"
  else
    print_warning "Wallpapers folder not found in noobdots repository"
  fi
}

# -----------------------------------------------------------------------------
#  NVIDIA Driver Installation
# -----------------------------------------------------------------------------

install_nvidia_drivers() {
  print_step "Installing NVIDIA drivers"
  echo "-------------------------------------------"

  NVIDIA_PACKAGES="nvidia-open nvidia-settings libva-nvidia-driver cuda"

  # Убран --noconfirm
  run_cmd "Installing NVIDIA drivers" \
    sudo pacman -S --needed $NVIDIA_PACKAGES

  print_success "NVIDIA drivers installed"
}

# -----------------------------------------------------------------------------
#  Reboot Prompt
# -----------------------------------------------------------------------------

prompt_reboot() {
  echo ""
  echo -e "${GREEN}=============================================="
  echo "   All tasks completed successfully!${NC}"
  echo -e "${GREEN}==============================================${NC}"
  echo ""
  echo -e "${YELLOW}A reboot is recommended to apply all changes.${NC}"
  echo ""

  read -p "Reboot now? [Y/n]: " answer

  case "$answer" in
    [Yy]*)
      print_success "Rebooting system..."
      reboot
      ;;
    *)
      echo "You can reboot later using the 'reboot' command."
      ;;
  esac
}

# -----------------------------------------------------------------------------
#  Main Execution
# -----------------------------------------------------------------------------

main() {
  print_banner

  setup_chaotic_aur
  update_mirrorlist
  update_system

  if [ "$INSTALL_NVIDIA" = true ]; then
    install_nvidia_drivers
  fi

  install_packages
  configure_shell_and_dm
  setup_noobdots

  if [ "$INSTALL_WALLPAPERS" = true ]; then
    setup_wallpapers
  else
    print_step "Wallpapers"
    print_warning "Skipping wallpapers installation (user choice)"
  fi

  prompt_reboot
}

# Run main function
main "$@"
