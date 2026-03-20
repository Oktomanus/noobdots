#!/bin/bash

# Colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

# Menu
CHOICE=$(printf "%b\n" \
    "${GREEN}󰾅  Balanced${RESET}" \
    "${YELLOW}󰾆  Power Save${RESET}" \
    "${RED}󰓅  Performance${RESET}" \
| fzf \
    --no-input \
    --ansi \
    --reverse \
    --prompt=" " \
    --height=100% \
    --border=none \
    --margin=1 \
    --pointer="➤" \
    --marker="✓" \
    --info=hidden)

# Apply power profile
set_profile() {
    local profile="$1"
    powerprofilesctl set "$profile"

    notify-send -u low "⚡ Power Profile" "Current profile: <b>$profile</b>"
}

case "$CHOICE" in
    *Balanced*)
        set_profile balanced

        # brightness 80%
        brightnessctl set 80% >/dev/null
        notify-send -u low "💡 Brightness" "Brightness set to 80%"
        ;;

    *Power\ Save*)
        set_profile power-saver

        # dim brightness
        brightnessctl set 30% >/dev/null
        notify-send -u low "💡 Brightness" "Brightness reduced to 30% (power saving)"
        ;;

    *Performance*)
        set_profile performance

        # full brightness
        brightnessctl set 100% >/dev/null
        notify-send -u low "💡 Brightness" "Brightness set to 100%"
        ;;

    *)
        exit 0 ;;
esac
