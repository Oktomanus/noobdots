#!/bin/bash

sed -i 's|mocha\.css|latte.css|;t;s|latte\.css|mocha.css|' \
"$HOME/.config/waybar/style.css"

sed -i 's|catppuccin-mocha\.ini|catppuccin-latte.ini|;t;s|catppuccin-latte\.ini|catppuccin-mocha.ini|' \
"$HOME/.config/foot/foot.ini"

pkill -USR2 waybar
