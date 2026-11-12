#!/bin/bash
# ==============================================================================
# USER CONFIGURATION & TUNING VARIABLES (THEME SWITCHER)
# ==============================================================================
# Day theme start hour (0-23, default: 7 -> 07:00 AM)
DAY_START_HOUR=7

# Night theme start hour (0-23, default: 19 -> 07:00 PM)
NIGHT_START_HOUR=19

# Time check interval in seconds (default: 60)
CHECK_INTERVAL=60

# Automatic wallpaper rotation interval within the same time period (in seconds)
# Options: 0 = Disabled | 900 = 15 min | 1800 = 30 min | 3600 = 1 hour
ROTATE_INTERVAL=0

# Wallust palettes written into ~/.config/wallust/wallust.toml on Day/Night switch
# Options: "light" / "softlight" (Day) | "dark" / "softdark" / "harddark" (Night)
DAY_PALETTE="light"
NIGHT_PALETTE="dark"
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
WALLUST_TOML="$HOME/.config/wallust/wallust.toml"
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

update_qt6ct_colors() {
	local theme="$1"
	mkdir -p "$QT6_DIR"
	[[ ! -f "$QS_DIR/colors.json" ]] && return 0
	awk -F'"' '
	function hex2dec(h,  i, c, v) {
		v = 0; h = tolower(h)
		for (i = 1; i <= length(h); i++) { c = substr(h, i, 1); v = v * 16 + index("0123456789abcdef", c) - 1 }
		return v
	}
	function shift_col(h, delta,  r, g, b) {
		r = hex2dec(substr(h, 1, 2)) + delta; if (r > 255) r = 255; if (r < 0) r = 0
		g = hex2dec(substr(h, 3, 2)) + delta; if (g > 255) g = 255; if (g < 0) g = 0
		b = hex2dec(substr(h, 5, 2)) + delta; if (b > 255) b = 255; if (b < 0) b = 0
		return sprintf("%02x%02x%02x", r, g, b)
	}
	BEGIN { bg="1e1e2e"; fg="cdd6f4"; c4="89b4fa"; c8="6c7086" }
	/"background":/ { sub(/^#/,"",$4); bg=$4 }
	/"foreground":/ { sub(/^#/,"",$4); fg=$4 }
	/"color4":/     { sub(/^#/,"",$4); c4=$4 }
	/"color8":/     { sub(/^#/,"",$4); c8=$4 }
	END {
		luma = 0.299 * hex2dec(substr(bg,1,2)) + 0.587 * hex2dec(substr(bg,3,2)) + 0.114 * hex2dec(substr(bg,5,2))
		c0 = (luma > 128) ? shift_col(bg, -16) : shift_col(bg, 18)
		printf "[ColorScheme]\n"
		printf "active_colors=#ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ffffffff, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #80%s\n", fg, c0, c8, c8, bg, c8, fg, fg, c0, bg, bg, c4, bg, c4, c4, c0, fg, bg, fg, fg
		printf "disabled_colors=#ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ffffffff, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #80%s\n", c8, c0, c8, c8, bg, c8, c8, c8, c0, bg, bg, c8, bg, c4, c4, c0, c8, bg, c8, c8
		printf "inactive_colors=#ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ffffffff, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #80%s\n", fg, c0, c8, c8, bg, c8, fg, fg, c0, bg, bg, c4, bg, c4, c4, c0, fg, bg, fg, fg
	}' "$QS_DIR/colors.json" > "$QT6_DIR/wallust.conf"

	local icon_thm="Papirus-Dark" dark_fp="true"
	if [[ "$theme" == "day" ]]; then icon_thm="Papirus-Light"; dark_fp="false"; fi
	[[ -f "$HOME/.config/qt6ct/qt6ct.conf" ]] && sed -i "s|^icon_theme=.*|icon_theme=$icon_thm|" "$HOME/.config/qt6ct/qt6ct.conf"
	[[ -f "$HOME/.config/pcmanfm-qt/default/settings.conf" ]] && sed -i "s|^IconThemeName=.*|IconThemeName=$icon_thm|" "$HOME/.config/pcmanfm-qt/default/settings.conf"
	[[ -f "$HOME/.config/featherpad/fp.conf" ]] && sed -i "s|^darkColScheme=.*|darkColScheme=$dark_fp|" "$HOME/.config/featherpad/fp.conf"
}

sync_quickshell_state() {
	local mode="$1" fx="$2" fr="$3"
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
	[[ "$CURRENT_WALL" == "$wall" && "$LAST_MODE" == "$mode" && "$CURRENT_THEME" == "$theme" ]] && return 0

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

	# Update palette directly inside wallust.toml (Day -> light, Night -> dark) and let Wallust read wallust.toml
	local target_pal="$DAY_PALETTE"
	[[ "$theme" == "night" ]] && target_pal="$NIGHT_PALETTE"
	if [[ -f "$WALLUST_TOML" ]]; then
		sed -i "s|^[[:space:]]*palette *=.*|palette = \"$target_pal\"|" "$WALLUST_TOML"
	fi

	sync_quickshell_state "$mode" "$fx" "$fr"
	wallust run -s "$wall_img" 2>/dev/null

	if [[ -f "$QS_DIR/colors.json" ]]; then
		sed -i -e "s|\"wallpaper\": *\"[^\"]*\"|\"wallpaper\": \"$wall\"|" \
			-e "s|\"wallMode\": *\"[^\"]*\"|\"wallMode\": \"$mode\"|" \
			-e "s|\"uiEffects\": *[a-z]*|\"uiEffects\": $fx|" \
			-e "s|\"firstRunDone\": *[a-z]*|\"firstRunDone\": $fr|" "$QS_DIR/colors.json"
	fi
	killall -SIGUSR1 kitty 2>/dev/null || true
	if command -v quickshell >/dev/null 2>&1; then
		update_qt6ct_colors "$theme"
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
