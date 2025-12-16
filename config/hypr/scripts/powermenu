#!/bin/bash

# ANSI color
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

# Menu
CHOICE=$(printf "%b\n" \
    "${RED}  Poweroff${RESET}" \
    "${YELLOW}  Reboot${RESET}" \
    "${GREEN}  Suspend${RESET}" \
    "󰗽  Logout" \
| fzf \
    --no-input \
    --ansi \
    --reverse \
    --prompt=" " \
    --height=100% \
    --border=none \
    --margin=1 \
    --pointer="➤" \
    --marker="✓" \
    --info=hidden)

# Commands
case "$CHOICE" in
    *Poweroff*) systemctl poweroff ;;
    *Reboot*) systemctl reboot ;;
    *Suspend*) systemctl suspend ;;
    *Logout*) hyprctl dispatch exit ;;
    *) exit 0 ;;
esac
