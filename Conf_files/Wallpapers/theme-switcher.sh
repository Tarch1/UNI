#!/bin/bash
WALL_DIR="$HOME/.config/wallpapers"
DAY_DIR="$WALL_DIR/day"
NIGHT_DIR="$WALL_DIR/night"
CURRENT_WALL=""
CURRENT_THEME=""

for pid in $(pgrep -u "$USER" -f "theme-switcher.sh"); do [[ "$pid" != "$$" && "$pid" != "$PPID" ]] && kill "$pid" 2>/dev/null; done

apply_theme() {
	local theme="$1" ; local target_dir="$2"
	[[ ! -d "$target_dir" ]] && return 1
	local wall ; wall=$(find "$target_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | shuf -n 1)
	[[ -z "$wall" ]] && return 1
	[[ "$CURRENT_WALL" == "$wall" ]] && return 0
	CURRENT_WALL="$wall"
	if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
		hyprctl hyprpaper preload "$wall"
		hyprctl hyprpaper wallpaper ",$wall"
	else
		awww img "$wall" --transition-type grow --transition-pos 0.5,0.5
	fi
	if [[ "$theme" == "night" ]]; then wallust run "$wall" --palette dark16 ; else wallust run "$wall" ; fi
	if pgrep -x waybar > /dev/null; then killall -SIGUSR2 waybar ; else waybar & fi
	killall -SIGUSR1 kitty 2>/dev/null || true
	swaync-client -rs
	CURRENT_THEME="$theme"
}

sleep 3
while true; do
	HOUR=$(date +%-H)
	if (( HOUR >= 7 && HOUR < 19 )); then
		[[ "$CURRENT_THEME" != "day" ]] && apply_theme "day" "$DAY_DIR"
	else
		[[ "$CURRENT_THEME" != "night" ]] && apply_theme "night" "$NIGHT_DIR"
	fi
	if ! pgrep -x waybar > /dev/null; then waybar & fi
	sleep 10
done
