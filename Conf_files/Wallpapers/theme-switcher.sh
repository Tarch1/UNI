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
# Options: 0 = Auto heuristic | 2 = Best for flat illustrations | 11 = Balanced | 20 = Photographs
WALLUST_THRESHOLD=0

# Wallust palette for Night mode
# Options: "dark16" | "harddark16" | "softdark16"
WALLUST_DAY_PALETTE="softdark16"
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
if [[ -n "$CURRENT_WALL" && -f "$CURRENT_WALL" ]]; then
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

get_json_bool() {
	local key="$1" def="$2" val
	val=$(grep -o "\"$key\": *[a-z]*" "$QS_DIR/colors.json" 2>/dev/null | awk -F: '{gsub(/[[:space:]]/,"",$2); print $2}')
	[[ "$val" =~ ^(true|false)$ ]] && echo "$val" || echo "$def"
}

# Ensures background is never pitch-black (#000000) and color0 (card surface) is visibly elevated above background
ensure_surface_contrast() {
	[[ ! -f "$QS_DIR/colors.json" ]] && return 0
	awk '
	function hex2dec(h,  i, c, v) {
		v = 0; h = tolower(h)
		for (i = 1; i <= length(h); i++) {
			c = substr(h, i, 1)
			v = v * 16 + index("0123456789abcdef", c) - 1
		}
		return v
	}
	function lift_hex(hex, min_luma, add_rgb,  r, g, b, luma, d) {
		gsub(/[^0-9a-fA-F]/, "", hex)
		if (length(hex) != 6) return "#1e1e2e"
		r = hex2dec(substr(hex, 1, 2)) + add_rgb
		g = hex2dec(substr(hex, 3, 2)) + add_rgb
		b = hex2dec(substr(hex, 5, 2)) + add_rgb
		luma = int(0.299 * r + 0.587 * g + 0.114 * b)
		if (luma < min_luma) {
			d = min_luma - luma
			r += d; g += d; b += d
		}
		if (r > 255) r = 255; if (g > 255) g = 255; if (b > 255) b = 255
		return sprintf("#%02x%02x%02x", r, g, b)
	}
	{
		lines[NR] = $0
		if ($0 ~ /"background":/) {
			match($0, /#[0-9a-fA-F]{6}/)
			bg_hex = substr($0, RSTART + 1, 6)
		}
	}
	END {
		new_bg = lift_hex(bg_hex, 26, 0)
		new_c0 = lift_hex(new_bg, 42, 16)
		for (i = 1; i <= NR; i++) {
			if (lines[i] ~ /"background":/) sub(/#[0-9a-fA-F]{6}/, new_bg, lines[i])
			else if (lines[i] ~ /"color0":/) sub(/#[0-9a-fA-F]{6}/, new_c0, lines[i])
			print lines[i]
		}
	}' "$QS_DIR/colors.json" > "$QS_DIR/colors.json.tmp" && mv -f "$QS_DIR/colors.json.tmp" "$QS_DIR/colors.json"
}

update_qt6ct_colors() {
	mkdir -p "$QT6_DIR"
	[[ ! -f "$QS_DIR/colors.json" ]] && return 0
	awk -F'"' '
	BEGIN { bg="1e1e2e"; fg="cdd6f4"; c0="282a36"; c4="89b4fa"; c8="585b70" }
	/"background":/ { sub(/^#/,"",$4); bg=$4 }
	/"foreground":/ { sub(/^#/,"",$4); fg=$4 }
	/"color0":/     { sub(/^#/,"",$4); c0=$4 }
	/"color4":/     { sub(/^#/,"",$4); c4=$4 }
	/"color8":/     { sub(/^#/,"",$4); c8=$4 }
	END {
		printf "[ColorScheme]\n"
		printf "active_colors=#ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ffffffff, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #80%s\n", fg, c0, c8, c8, bg, c8, fg, fg, c0, bg, bg, c4, bg, c4, c4, c0, fg, bg, fg, fg
		printf "disabled_colors=#ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ffffffff, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #80%s\n", c8, c0, c8, c8, bg, c8, c8, c8, c0, bg, bg, c8, bg, c4, c4, c0, c8, bg, c8, c8
		printf "inactive_colors=#ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ffffffff, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #80%s\n", fg, c0, c8, c8, bg, c8, fg, fg, c0, bg, bg, c4, bg, c4, c4, c0, fg, bg, fg, fg
	}' "$QS_DIR/colors.json" > "$QT6_DIR/wallust.conf"
}

sync_quickshell_state() {
	local wall="$1" mode="$2" fx="$3" fr="$4"
	local tpl="$HOME/.config/wallust/templates/colors-quickshell.json"
	if [[ -f "$tpl" ]]; then
		sed -i -e "s|\"wallMode\": *\"[^\"]*\"|\"wallMode\": \"$mode\"|" \
			-e "s|\"uiEffects\": *[a-z]*|\"uiEffects\": $fx|" \
			-e "s|\"firstRunDone\": *[a-z]*|\"firstRunDone\": $fr|" "$tpl"
	fi
}

apply_theme() {
	local theme="$1"
	local static_dir="$2"
	local anim_dir="$3"
	local mode fx fr
	mode=$(get_wall_mode)
	fx=$(get_json_bool "uiEffects" "true")
	fr=$(get_json_bool "firstRunDone" "false")
	FORCED_MODE=""

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

	sync_quickshell_state "$wall" "$mode" "$fx" "$fr"
	local pal="$WALLUST_DAY_PALETTE"
	[[ "$theme" == "night" ]] && pal="$WALLUST_NIGHT_PALETTE"
	wallust run -s --backend "$WALLUST_BACKEND" -t "$WALLUST_THRESHOLD" "$wall_img" --palette "$pal" 2>/dev/null

	if [[ -f "$QS_DIR/colors.json" ]]; then
		sed -i -e "s|\"wallpaper\": *\"[^\"]*\"|\"wallpaper\": \"$wall\"|" \
			-e "s|\"wallMode\": *\"[^\"]*\"|\"wallMode\": \"$mode\"|" \
			-e "s|\"uiEffects\": *[a-z]*|\"uiEffects\": $fx|" \
			-e "s|\"firstRunDone\": *[a-z]*|\"firstRunDone\": $fr|" "$QS_DIR/colors.json"
		ensure_surface_contrast
	fi
	killall -SIGUSR1 kitty 2>/dev/null || true
	if command -v quickshell >/dev/null 2>&1; then
		update_qt6ct_colors
		quickshell ipc call theme reload >/dev/null 2>&1 || true
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
	if [[ -n "${WAYLAND_DISPLAY:-}" && ! -S "${XDG_RUNTIME_DIR:-/run/user/$UID}/$WAYLAND_DISPLAY" ]]; then exit 0 ; fi
	FORCE_ROTATE=0
	if (( ROTATE_INTERVAL > 0 && (SECONDS - LAST_ROTATE_TS) >= ROTATE_INTERVAL )); then
		FORCE_ROTATE=1
	fi
	printf -v HOUR '%(%k)T' -1
	if (( HOUR >= DAY_START_HOUR && HOUR < NIGHT_START_HOUR )); then
		if [[ "$CURRENT_THEME" != "day" || -n "$FORCED_MODE" || "$FORCE_ROTATE" -eq 1 ]]; then
			apply_theme "day" "$DAY_DIR" "$DAY_ANIM_DIR"
		fi
	else
		if [[ "$CURRENT_THEME" != "night" || -n "$FORCED_MODE" || "$FORCE_ROTATE" -eq 1 ]]; then
			apply_theme "night" "$NIGHT_DIR" "$NIGHT_ANIM_DIR"
		fi
	fi
	sleep "$CHECK_INTERVAL"
done
