#!/bin/bash

if output=$(yad \
--width=390 --height=290 \
--center \
--fixed \
--separator="\\n" \
--title='Garuda Hyprland Installer' \
--button='Exit!application-exit:1' \
--button='Install!system-run:0' \
--text=" \\n   Install Garuda Hyprland"); then
sudo -E calamares
fi
