#!/bin/bash

# Пути к конфигам
FOOT_CONF="$HOME/.config/foot/foot.ini"
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"
WAYBAR_STYLE="$HOME/.config/waybar/style.css"

# Определяем текущую тему по конфигу foot
CURRENT_THEME=$(grep "initial-color-theme=" "$FOOT_CONF" | cut -d'=' -f2)

if [ "$CURRENT_THEME" = "dark" ]; then
    # --- ПЕРЕКЛЮЧАЕМ НА СВЕТЛУЮ (LATTE) ---
    NEW_THEME="light"
    GTK_THEME="catppuccin-latte-lavender-standard+default"
    COLOR_SCHEME="prefer-light"
    SIGNAL="USR2"
    HYPR_THEME_FILE="latte.conf"
    WAYBAR_OLD="mocha.css"
    WAYBAR_NEW="latte.css"
else
    # --- ПЕРЕКЛЮЧАЕМ НА ТЁМНУЮ (MOCHA) ---
    NEW_THEME="dark"
    GTK_THEME="catppuccin-mocha-lavender-standard+default"
    COLOR_SCHEME="prefer-dark"
    SIGNAL="USR1"
    HYPR_THEME_FILE="mocha.conf"
    WAYBAR_OLD="latte.css"
    WAYBAR_NEW="mocha.css"
fi

# 1. Меняем GTK темы (GTK3, GTK4, libadwaita)
gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME"
gsettings set org.gnome.desktop.interface color-scheme "$COLOR_SCHEME"

# 2. Переключаем все открытые foot
pkill -$SIGNAL foot

# 3. Обновляем foot.ini (для новых окон)
sed -i "s/initial-color-theme=$CURRENT_THEME/initial-color-theme=$NEW_THEME/" "$FOOT_CONF"

# 4. Обновляем Hyprland (рамки и цвета)
sed -i "s/themes\/.*\.conf/themes\/$HYPR_THEME_FILE/" "$HYPR_CONF"

# 5. Обновляем Waybar
sed -i "s/$WAYBAR_OLD/$WAYBAR_NEW/" "$WAYBAR_STYLE"
pkill -USR2 waybar

# Опционально: уведомление
notify-send "Theme Switched" "Active theme: $NEW_THEME" -i accent
