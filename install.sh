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
    "sudo pacman -
