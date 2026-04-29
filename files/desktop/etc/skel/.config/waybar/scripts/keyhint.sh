#!/bin/sh
# "Change keyboard layout in" "~/.config/hypr/hyprland.conf" " " \

yad --width=530 --height=650 \
--center \
--fixed \
--title="Garuda Hyprland Keybindings" \
--no-buttons \
--list \
--column=Key: \
--column=Description: \
--column=Command: \
--timeout=60 \
--timeout-indicator=right \
"ESC" "close this app" "" "=" "modkey" "(set mod Mod4)" \
"+Shift+g" "G-hyprland" "implement G-Hyprland" \
"+enter/+t" "Terminal" "(foot)" \
"" "Application Menu" "(wofi)" \
"+Shift+d" "Full Launcher" "(nwggrid)" \
"+o" "" "Open Broswer" \
"+e" "💧" "Emoje selector" \
"+n" "" "Open Files" \
"+q" "close focused app" "(kill)" \
"+v" "clipboard manager" "(cliphist)" \
"+r" "Resize windows" "(resize)" \
"Print" "screenshot" "(grimblast)" \
"Shift+Print" "screenshot region" "(grimblast)" \
"+Print" "screenshot window" "(grimblast)" \
"+Shift+e" "power-menu" "(wofi)" \
"+Shift+c" "Change wallpaper" "(wpaperd)" \
"+f" "Fullscreen" "Toggles to full screen" \
"+Shift+f" "fullscreenstate" "Behave full screen without full screen" \
"+m" "maximize" "Hides all the windows other then focused window" \
"+Shift+Spacebar" "Float" "Toggle windows to float" \
"+p" "Dwindle effect" "pseudo" \
"+Shift+p" "Dwindle effect" "toggle split" \
"+i" "Calamares" "Install Garuda Hyprland" \
"" "" "     Window closed in 60 sec."\
