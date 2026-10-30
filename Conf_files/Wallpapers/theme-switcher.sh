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
CURRENT_WALL=""
CURRENT_THEME=""

apply_theme() {
	local theme="$1" ; local target_dir="$2"
	[[ ! -d "$target_dir" ]] && return 1
	local wall ; wall=$(find "$target_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | shuf -n 1)
	[[ -z "$wall" ]] && return 1
	[[ "$CURRENT_WALL" == "$wall" ]] && return 0
	if command -v quickshell >/dev/null 2>&1; then
		if ! pgrep -u "$UID" -x quickshell >/dev/null; then env QSG_RHI_BACKEND=opengl quickshell & sleep 1 ; fi
	else
		if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
			pgrep -u "$UID" -x hyprpaper >/dev/null || { hyprpaper & sleep 1; }
			hyprctl hyprpaper preload "$wall" >/dev/null 2>&1 || return 1
			hyprctl hyprpaper wallpaper ",$wall" >/dev/null 2>&1 || return 1
		else
			pgrep -u "$UID" -x awww-daemon >/dev/null || { awww-daemon & sleep 1; }
			awww img "$wall" --transition-type grow --transition-pos 0.5,0.5 >/dev/null 2>&1 || return 1
		fi
	fi
	if [[ "$theme" == "night" ]]; then wallust run -s "$wall" --palette dark16 ; else wallust run -s "$wall" ; fi
	killall -SIGUSR1 kitty 2>/dev/null || true
	if ! command -v quickshell >/dev/null 2>&1; then
		if pgrep -u "$UID" -x waybar >/dev/null; then killall -SIGUSR2 waybar ; else waybar & fi
		swaync-client -rs >/dev/null 2>&1 || true
	fi
	CURRENT_WALL="$wall"
	CURRENT_THEME="$theme"
}

sleep 2
while true; do
	pgrep -u "$UID" -x "niri|Hyprland" >/dev/null || exit 0
	printf -v HOUR '%(%k)T' -1
	if (( HOUR >= 7 && HOUR < 19 )); then
		[[ "$CURRENT_THEME" != "day" ]] && apply_theme "day" "$DAY_DIR"
	else
		[[ "$CURRENT_THEME" != "night" ]] && apply_theme "night" "$NIGHT_DIR"
	fi
	if command -v quickshell >/dev/null 2>&1; then
		if ! pgrep -u "$UID" -x quickshell >/dev/null; then env QSG_RHI_BACKEND=opengl quickshell & fi
	else
		if ! pgrep -u "$UID" -x waybar >/dev/null; then waybar & fi
	fi
	if [[ -z "$CURRENT_THEME" ]]; then sleep 2 ; else sleep 10 ; fi
done
