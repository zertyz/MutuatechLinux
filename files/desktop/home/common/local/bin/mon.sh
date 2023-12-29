#!/bin/bash 

hyprctl monitors > /tmp/monitor

var=$(sed -n '1{p;q}' /tmp/monitor | awk '{ print $2 }')

var1=$(sed -n '2{p;q}' /tmp/monitor | awk '{ print $1 }')

var2=$(sed -n '2{p;q}' /tmp/monitor | awk '{ print $3 }')

var3=$(sed -n '10{p;q}' /tmp/monitor | awk '{ print $2 }')

var4="$var, $var1, $var2, $var3"

var5=${var1%%x*}

sed -i "/monitor=/c\monitor= $var4" .config/hypr/hyprland.conf

sed -i "/\"width\":/c\    \"width\":$var5," .config/waybar/config

sed -i "s/USER/$USER/" .config/waybar/style.css
