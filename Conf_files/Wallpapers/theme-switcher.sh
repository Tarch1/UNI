#!/bin/bash
# ==============================================================================
# USER CONFIGURATION & TUNING VARIABLES (THEME SWITCHER & WALLUST)
# ==============================================================================
# Day theme start hour (0-23, default: 7 -> 07:00 AM)
DAY_START_HOUR=7

# Night theme start hour (0-23, default: 19 -> 07:00 PM)
NIGHT_START_HOUR=19

# Time check interval in seconds (default: 5)
CHECK_INTERVAL=5

# Automatic wallpaper rotation interval within the same time period (in seconds)
# Options: 0 = Disabled (changes only at 07:00, 19:00, or manual toggle)
#          900 = Every 15 min | 1800 = Every 30 min | 3600 = Every hour
ROTATE_INTERVAL=0

# Wallust color extraction backend
# Options: "resized" (recommended, ~0.1s) | "kmeans" (slower) | "wal"
WALLUST_BACKEND="resized"

# Wallust color difference threshold (1-20)
# Options: 2 = Best for flat illustrations | 11 = Balanced | 20 = Photographs
WALLUST_THRESHOLD=2

# Wallust palette for Night mode
# Options: "dark16" | "harddark16" | "softdark16"
WALLUST_NIGHT_PALETTE="dark16"
# ==============================================================================

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
QT6_DIR="$HOME/.config/qt6ct/colors"
FRAME_CACHE="/tmp/wall_frame.jpg"
FORCED_MODE="${1:-}"
CURRENT_WALL=$(grep -o '"wallpaper": *"[^"]*"' "$QS_DIR/colors.json" 2>/dev/null | cut -d'"' -f4)
CURRENT_THEME=""
LAST_MODE=$(grep -o '"wallMode": *"[^"]*"' "$QS_DIR/colors.json" 2>/dev/null | cut -d'"' -f4)
[[ -z "$LAST_MODE" ]] && LAST_MODE="static"
if [[ -n "$CURRENT_WALL" && -f "$CURRENT_WALL" && -f "$QS_DIR/colors-wallust.json" ]]; then
	[[ "$CURRENT_WALL" == *"/day"* ]] && CURRENT_THEME="day"
	[[ "$CURRENT_WALL" == *"/night"* ]] && CURRENT_THEME="night"
else
	CURRENT_WALL=""
fi
LAST_ROTATE_TS=$SECONDS

get_wall_mode() {
	if [[ "$FORCED_MODE" =~ ^(animated|static)$ ]]; then
		echo "$FORCED_MODE"
		return
	fi
	local m
	m=$(grep -o '"wallMode": *"[^"]*"' "$QS_DIR/colors.json" 2>/dev/null | cut -d'"' -f4)
	[[ "$m" == "animated" ]] && echo "animated" || echo "static"
}

get_ui_effects() {
	local fx
	fx=$(grep -o '"uiEffects": *[a-z]*' "$QS_DIR/colors.json" 2>/dev/null | awk -F: '{gsub(/[[:space:]]/,"",$2); print $2}')
	[[ "$fx" == "false" ]] && echo "false" || echo "true"
}

update_qt6ct_colors() {
	mkdir -p "$QT6_DIR"
	[[ ! -f "$QS_DIR/colors.json" ]] && return 0
	awk -F'"' '
	BEGIN { bg="1e1e2e"; fg="cdd6f4"; c0="1e1e2e"; c4="89b4fa"; c8="585b70" }
	/"background":/ { sub(/^#/,"",$4); bg=$4 }
	/"foreground":/ { sub(/^#/,"",$4); fg=$4 }
	/"color0":/     { sub(/^#/,"",$4); c0=$4 }
	/"color4":/     { sub(/^#/,"",$4); c4=$4 }
	/"color8":/     { sub(/^#/,"",$4); c8=$4 }
	END {
		printf "[ColorScheme]\n"
		printf "active_colors=#ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ffffffff, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #80%s\n", fg, bg, c8, c8, c0, c8, fg, fg, c0, bg, c0, c4, bg, c4, c4, c0, fg, c0, fg, fg
		printf "disabled_colors=#ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ffffffff, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #80%s\n", c8, bg, c8, c8, c0, c8, c8, c8, c0, bg, c0, c8, bg, c4, c4, c0, c8, c0, c8, c8
		printf "inactive_colors=#ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ffffffff, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #80%s\n", fg, bg, c8, c8, c0, c8, fg, fg, c0, bg, c0, c4, bg, c4, c4, c0, fg, c0, fg, fg
	}' "$QS_DIR/colors.json" > "$QT6_DIR/wallust.conf"
}

update_quickshell_json() {
	local wall="$1"
	local mode fx
	mode=$(get_wall_mode)
	fx=$(get_ui_effects)
	FORCED_MODE=""
	mkdir -p "$QS_DIR"
	if [[ -f "$QS_DIR/colors-wallust.json" ]] && grep -q '"color4": *"#' "$QS_DIR/colors-wallust.json" 2>/dev/null; then
		sed "s|{|{\n\t\"wallpaper\": \"$wall\",\n\t\"wallMode\": \"$mode\",\n\t\"uiEffects\": $fx,|" "$QS_DIR/colors-wallust.json" > "$QS_DIR/colors.json"
	elif [[ -f "$HOME/.config/kitty/colors.conf" ]]; then
		awk -v w="$wall" -v m="$mode" -v fx="$fx" '
		BEGIN {
			c["background"]="#1e1e2e"; c["foreground"]="#cdd6f4";
			c["color0"]="#1e1e2e"; c["color1"]="#f38ba8"; c["color2"]="#a6e3a1";
			c["color3"]="#f9e2af"; c["color4"]="#89b4fa"; c["color5"]="#cba6f7";
			c["color6"]="#94e2d5"; c["color7"]="#bac2de"; c["color8"]="#585b70";
		}
		/^(background|foreground|color[0-8])[[:space:]]+#/ { c[$1]=$2 }
		END {
			printf "{\n\t\"wallpaper\": \"%s\",\n\t\"wallMode\": \"%s\",\n\t\"uiEffects\": %s,\n\t\"background\": \"%s\",\n\t\"foreground\": \"%s\",\n\t\"color0\": \"%s\",\n\t\"color1\": \"%s\",\n\t\"color2\": \"%s\",\n\t\"color3\": \"%s\",\n\t\"color4\": \"%s\",\n\t\"color5\": \"%s\",\n\t\"color6\": \"%s\",\n\t\"color7\": \"%s\",\n\t\"color8\": \"%s\"\n}\n",
			w, m, fx, c["background"], c["foreground"], c["color0"], c["color1"], c["color2"], c["color3"], c["color4"], c["color5"], c["color6"], c["color7"], c["color8"]
		}' "$HOME/.config/kitty/colors.conf" > "$QS_DIR/colors.json"
	fi
	update_qt6ct_colors
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
		if [[ -n $(find "$anim_dir" -type f \( -iname "*.webm" -o -iname "*.mp4" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -print -quit 2>/dev/null) ]]; then
			target_dir="$anim_dir"
		fi
	fi
	[[ ! -d "$target_dir" ]] && return 1
	local wall
	wall=$(find "$target_dir" -type f \( -iname "*.webm" -o -iname "*.mp4" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | shuf -n 1)
	[[ -z "$wall" ]] && return 1
	[[ "$CURRENT_WALL" == "$wall" && "$LAST_MODE" == "$mode" ]] && return 0

	local wall_img="$wall"
	if [[ "${wall,,}" =~ \.(webm|mp4)$ ]]; then
		wall_img="$FRAME_CACHE"
		ffmpeg -y -loglevel quiet -i "$wall" -frames:v 1 -vf "scale=320:-1" -q:v 4 "$wall_img" 2>/dev/null
	fi

	if ! command -v quickshell >/dev/null 2>&1; then
		if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
			pgrep -u "$UID" -x hyprpaper >/dev/null || { hyprpaper & sleep 1; }
			hyprctl hyprpaper preload "$wall_img" >/dev/null 2>&1 || return 1
			hyprctl hyprpaper wallpaper ",$wall_img" >/dev/null 2>&1 || return 1
		else
			pgrep -u "$UID" -x awww-daemon >/dev/null || { awww-daemon & sleep 1; }
			awww img "$wall_img" --transition-type grow --transition-pos 0.5,0.5 >/dev/null 2>&1 || return 1
		fi
	fi

	if [[ "$theme" == "night" ]]; then
		wallust run -s --backend "$WALLUST_BACKEND" -t "$WALLUST_THRESHOLD" "$wall_img" --palette "$WALLUST_NIGHT_PALETTE" 2>/dev/null
	else
		wallust run -s --backend "$WALLUST_BACKEND" -t "$WALLUST_THRESHOLD" "$wall_img" 2>/dev/null
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
	LAST_ROTATE_TS=$SECONDS
}

[[ -z "$FORCED_MODE" ]] && sleep 1
while true; do
	if ! pgrep -u "$UID" -x niri >/dev/null && ! pgrep -u "$UID" -x Hyprland >/dev/null; then exit 0 ; fi
	NOW_MODE=$(get_wall_mode)
	FORCE_ROTATE=0
	if (( ROTATE_INTERVAL > 0 && (SECONDS - LAST_ROTATE_TS) >= ROTATE_INTERVAL )); then
		FORCE_ROTATE=1
	fi
	printf -v HOUR '%(%k)T' -1
	if (( HOUR >= DAY_START_HOUR && HOUR < NIGHT_START_HOUR )); then
		if [[ "$CURRENT_THEME" != "day" || "$LAST_MODE" != "$NOW_MODE" || "$FORCE_ROTATE" -eq 1 ]]; then
			apply_theme "day" "$DAY_DIR" "$DAY_ANIM_DIR"
		fi
	else
		if [[ "$CURRENT_THEME" != "night" || "$LAST_MODE" != "$NOW_MODE" || "$FORCE_ROTATE" -eq 1 ]]; then
			apply_theme "night" "$NIGHT_DIR" "$NIGHT_ANIM_DIR"
		fi
	fi
	if ! command -v quickshell >/dev/null 2>&1; then
		if ! pgrep -u "$UID" -x waybar >/dev/null; then waybar & fi
	fi
	if [[ -z "$CURRENT_THEME" ]]; then sleep 2 ; else sleep "$CHECK_INTERVAL" ; fi
done
