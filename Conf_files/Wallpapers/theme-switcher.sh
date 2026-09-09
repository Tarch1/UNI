#!/bin/bash
# ~/.config/wallpapers/theme-switcher.sh

WALL_DIR="$HOME/.config/wallpapers"
DAY_DIR="$WALL_DIR/day"
NIGHT_DIR="$WALL_DIR/night"
CURRENT_WALL=""
CURRENT_THEME=""

apply_theme() {
    local theme="$1"
    local target_dir="$2"
    [[ ! -d "$target_dir" ]] && return 1
    local wall
    wall=$(find "$target_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | shuf -n 1)
    [[ -z "$wall" ]] && return 1
    if [[ "$CURRENT_WALL" == "$wall" ]]; then
        return 0
    fi
    CURRENT_WALL="$wall"
    if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
        hyprctl hyprpaper preload "$wall"
        hyprctl hyprpaper wallpaper ",$wall"
    else
        # Per Niri e gli altri usiamo swww
        awww img "$wall" --transition-type grow --transition-pos 0.5,0.5
    fi
    if [[ "$theme" == "night" ]]; then
        wallust run "$wall" --palette dark16
    else
        wallust run "$wall"
    fi
    killall -SIGUSR2 waybar
    swaync-client -rs
    CURRENT_THEME="$theme"
}
sleep 3
while true; do
    HOUR=$(date +%H)
    if (( HOUR >= 7 && HOUR < 19 )); then
        if [[ "$CURRENT_THEME" != "day" ]]; then
            apply_theme "day" "$DAY_DIR"
        fi
    else
        if [[ "$CURRENT_THEME" != "night" ]]; then
            apply_theme "night" "$NIGHT_DIR"
        fi
    fi
    sleep 300
done
