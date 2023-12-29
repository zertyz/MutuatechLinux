#!/bin/bash
# .local/bin/garuda-locale.sh

localectl > /tmp/garuda-locale.txt

cat /tmp/garuda-locale.txt | grep Keymap > /tmp/keymap.txt

locale=$(cat /tmp/keymap.txt | awk '{ print $3 }')

sed -i "/kb_layout =/c\kb_layout = $locale" .config/hypr/hyprland.conf
