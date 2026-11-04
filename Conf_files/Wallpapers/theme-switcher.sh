#!/bin/bash
PIDFILE="/tmp/theme-switcher-$UID.pid"
if [[ -f "$PIDFILE" ]]; then
	old_pid=$(<"$PIDFILE")
	[[ -n "$old_pid" && "$old_pid" != "$$" ]] && kill "$old_pid" 2>/dev/null || true
fi
echo "$$" > "$PIDFILE"

WALL_DIR="$HOME/.config/wallpapers"
DAY_DIR="$WALL_DIR/day"
NIGHT_DIR="$WALL_DIR/night"
DAY_ANIM_DIR="$WALL_DIR/day_animated"
NIGHT_ANIM_DIR="$WALL_DIR/night_animated"
QS_DIR="$HOME/.config/quickshell"
FORCED_MODE="${1:-}"
CURRENT_WALL=""
CURRENT_THEME=""
LAST_MODE=""

get_wall_mode() {
	if [[ "$FORCED_MODE" =~ ^(animated|static)$ ]]; then
		echo "$FORCED_MODE"
		return
	fi
	local m
	m=$(grep -o '"wallMode": *"[^"]*"' "$QS_DIR/colors.json" 2>/dev/null | cut -d'"' -f4)
	[[ "$m" == "animated" ]] && echo "animated" || echo "static"
}

update_quickshell_json() {
	local wall="$1"
	local mode
	mode=$(get_wall_mode)
	FORCED_MODE=""
	mkdir -p "$QS_DIR"
	if [[ -f "$QS_DIR/colors-wallust.json" ]] && grep -q '"color4": *"#' "$QS_DIR/colors-wallust.json" 2>/dev/null; then
		sed "s|{|{\n\t\"wallpaper\": \"$wall\",\n\t\"wallMode\": \"$mode\",|" "$QS_DIR/colors-wallust.json" > "$QS_DIR/colors.json"
	elif [[ -f "$HOME/.config/kitty/colors.conf" ]]; then
		awk -v w="$wall" -v m="$mode" '
		BEGIN {
			c["background"]="#1e1e2e"; c["foreground"]="#cdd6f4";
			c["color0"]="#1e1e2e"; c["color1"]="#f38ba8"; c["color2"]="#a6e3a1";
			c["color3"]="#f9e2af"; c["color4"]="#89b4fa"; c["color5"]="#cba6f7";
			c["color6"]="#94e2d5"; c["color7"]="#bac2de"; c["color8"]="#585b70";
		}
		/^(background|foreground|color[0-8])[[:space:]]+#/ { c[$1]=$2 }
		END {
			printf "{\n\t\"wallpaper\": \"%s\",\n\t\"wallMode\": \"%s\",\n\t\"background\": \"%s\",\n\t\"foreground\": \"%s\",\n\t\"color0\": \"%s\",\n\t\"color1\": \"%s\",\n\t\"color2\": \"%s\",\n\t\"color3\": \"%s\",\n\t\"color4\": \"%s\",\n\t\"color5\": \"%s\",\n\t\"color6\": \"%s\",\n\t\"color7\": \"%s\",\n\t\"color8\": \"%s\"\n}\n",
			w, m, c["background"], c["foreground"], c["color0"], c["color1"], c["color2"], c["color3"], c["color4"], c["color5"], c["color6"], c["color7"], c["color8"]
		}' "$HOME/.config/kitty/colors.conf" > "$QS_DIR/colors.json"
	fi
	quickshell ipc call theme reload >/dev/null 2>&1 || true
}

apply_theme() {
	local theme="$1"
	local static_dir="$2"
	local anim_dir="$3"
	local mode
	mode=$(get_wall_mode)
	local target_dir="$static_dir"
	if [[ "$mode" == "animated" && -d "$anim_dir" ]]; then
		if [[ -n $(find "$anim_dir" -type f \( -iname "*.gif" -o -iname "*.webp" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -print -quit 2>/dev/null) ]]; then
			target_dir="$anim_dir"
		fi
	fi
	[[ ! -d "$target_dir" ]] && return 1
	local wall
	wall=$(find "$target_dir" -type f \( -iname "*.gif" -o -iname "*.webp" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | shuf -n 1)
	[[ -z "$wall" ]] && return 1
	[[ "$CURRENT_WALL" == "$wall" && "$LAST_MODE" == "$mode" ]] && return 0
	if ! command -v quickshell >/dev/null 2>&1; then
		if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
			pgrep -u "$UID" -x hyprpaper >/dev/null || { hyprpaper & sleep 1; }
			hyprctl hyprpaper preload "$wall" >/dev/null 2>&1 || return 1
			hyprctl hyprpaper wallpaper ",$wall" >/dev/null 2>&1 || return 1
		else
			pgrep -u "$UID" -x awww-daemon >/dev/null || { awww-daemon & sleep 1; }
			awww img "$wall" --transition-type grow --transition-pos 0.5,0.5 >/dev/null 2>&1 || return 1
		fi
	fi
	if [[ "$theme" == "night" ]]; then
		wallust run -s --backend resized -t 2 "$wall" --palette dark16 2>/dev/null || wallust run -s -t 2 "$wall" --palette dark16
	else
		wallust run -s --backend resized -t 2 "$wall" 2>/dev/null || wallust run -s -t 2 "$wall"
	fi
	killall -SIGUSR1 kitty 2>/dev/null || true
	if command -v quickshell >/dev/null 2>&1; then
		update_quickshell_json "$wall"
	else
		if pgrep -u "$UID" -x waybar >/dev/null; then killall -SIGUSR2 waybar ; else waybar & fi
		swaync-client -rs >/dev/null 2>&1 || true
	fi
	CURRENT_WALL="$wall"
	CURRENT_THEME="$theme"
	LAST_MODE="$mode"
}

[[ -z "$FORCED_MODE" ]] && sleep 1
while true; do
	if ! pgrep -u "$UID" -x niri >/dev/null && ! pgrep -u "$UID" -x Hyprland >/dev/null; then exit 0 ; fi
	NOW_MODE=$(get_wall_mode)
	printf -v HOUR '%(%k)T' -1
	if (( HOUR >= 7 && HOUR < 19 )); then
		if [[ "$CURRENT_THEME" != "day" || "$LAST_MODE" != "$NOW_MODE" ]]; then
			apply_theme "day" "$DAY_DIR" "$DAY_ANIM_DIR"
		fi
	else
		if [[ "$CURRENT_THEME" != "night" || "$LAST_MODE" != "$NOW_MODE" ]]; then
			apply_theme "night" "$NIGHT_DIR" "$NIGHT_ANIM_DIR"
		fi
	fi
	if ! command -v quickshell >/dev/null 2>&1; then
		if ! pgrep -u "$UID" -x waybar >/dev/null; then waybar & fi
	fi
	if [[ -z "$CURRENT_THEME" ]]; then sleep 2 ; else sleep 5 ; fi
done
