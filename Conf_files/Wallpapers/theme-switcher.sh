#!/bin/bash
# ==============================================================================
# USER CONFIGURATION & TUNING VARIABLES (THEME SWITCHER)
# ==============================================================================
DAY_START_HOUR=7
NIGHT_START_HOUR=19
CHECK_INTERVAL=60
ROTATE_INTERVAL=0

# Wallust palettes written into ~/.config/wallust/wallust.toml on Day/Night switch
# Options: "softdark16" "softdark" "dark16" "harddark16"
DAY_PALETTE="light16"
NIGHT_PALETTE="dark16"
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
KITTY_CONF="$HOME/.config/kitty/colors.conf"
HYPR_CONF="$HOME/.config/hypr/colors.conf"
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

sync_quickshell_state() {
	local mode="$1" bl="$2" an="$3" fr="$4"
	local tpl="$HOME/.config/wallust/templates/colors-quickshell.json"
	if [[ -f "$tpl" ]]; then
		sed -i -e "s|\"wallMode\": *\"[^\"]*\"|\"wallMode\": \"$mode\"|" \
			-e "s|\"uiBlur\": *[a-z]*|\"uiBlur\": $bl|" \
			-e "s|\"uiAnimations\": *[a-z]*|\"uiAnimations\": $an|" \
			-e "s|\"firstRunDone\": *[a-z]*|\"firstRunDone\": $fr|" "$tpl"
	fi
}

calibrate_and_apply_colors() {
	local theme="$1" wall="$2" mode="$3" bl="$4" an="$5" fr="$6"
	mkdir -p "$QT6_DIR" "$QS_DIR"
	[[ ! -f "$QS_DIR/colors.json" ]] && return 0

	LC_ALL=C awk -F'"' \
		-v theme="$theme" -v wall="$wall" -v mode="$mode" -v bl="$bl" -v an="$an" -v fr="$fr" \
		-v qs_out="$QS_DIR/colors.json.tmp" \
		-v qt_out="$QT6_DIR/wallust.conf" \
		-v kitty_out="$KITTY_CONF" \
		-v hypr_out="$HYPR_CONF" '
	function abs(v) { return v < 0 ? -v : v }
	function clamp(v, lo, hi) { return v < lo ? lo : (v > hi ? hi : v) }
	function hex2dec(h,  i, ch, v) {
		v = 0; h = tolower(h)
		for (i = 1; i <= length(h); i++) {
			ch = substr(h, i, 1)
			v = v * 16 + index("0123456789abcdef", ch) - 1
		}
		return v
	}
	function rgb2hsl(hex,  r, g, b, mx, mn, d, h, s, l) {
		gsub(/^#/, "", hex)
		r = hex2dec(substr(hex, 1, 2)) / 255.0
		g = hex2dec(substr(hex, 3, 2)) / 255.0
		b = hex2dec(substr(hex, 5, 2)) / 255.0
		mx = r; if (g > mx) mx = g; if (b > mx) mx = b
		mn = r; if (g < mn) mn = g; if (b < mn) mn = b
		l = (mx + mn) / 2.0
		d = mx - mn
		if (d < 0.0001) { h = 0; s = 0 }
		else {
			s = (l > 0.5) ? (d / (2.0 - mx - mn)) : (d / (mx + mn))
			if (mx == r) h = (g - b) / d + (g < b ? 6.0 : 0.0)
			else if (mx == g) h = (b - r) / d + 2.0
			else h = (r - g) / d + 4.0
			h *= 60.0
		}
		H = h; S = s; L = l
	}
	function hue2rgb(p, q, t) {
		if (t < 0.0) t += 1.0
		if (t > 1.0) t -= 1.0
		if (t < 1.0 / 6.0) return p + (q - p) * 6.0 * t
		if (t < 0.5) return q
		if (t < 2.0 / 3.0) return p + (q - p) * (2.0 / 3.0 - t) * 6.0
		return p
	}
	function hsl2hex(h, s, l,  q, p, hk, r, g, b, ri, gi, bi) {
		l = clamp(l, 0.0, 1.0); s = clamp(s, 0.0, 1.0)
		while (h < 0.0) h += 360.0
		while (h >= 360.0) h -= 360.0
		if (s < 0.0001) { r = l; g = l; b = l }
		else {
			q = (l < 0.5) ? (l * (1.0 + s)) : (l + s - l * s)
			p = 2.0 * l - q
			hk = h / 360.0
			r = hue2rgb(p, q, hk + 1.0 / 3.0)
			g = hue2rgb(p, q, hk)
			b = hue2rgb(p, q, hk - 1.0 / 3.0)
		}
		ri = int(r * 255.0 + 0.5); gi = int(g * 255.0 + 0.5); bi = int(b * 255.0 + 0.5)
		return sprintf("%02x%02x%02x", clamp(ri, 0, 255), clamp(gi, 0, 255), clamp(bi, 0, 255))
	}
	function hdist(h1, h2,  d) {
		d = abs(h1 - h2) % 360.0
		return d > 180.0 ? 360.0 - d : d
	}
	BEGIN {
		raw_bg = "1e1e2e"; raw_fg = "cdd6f4"
		for (i = 0; i < 16; i++) raw_c[i] = "89b4fa"
	}
	/"background":/ { gsub(/^#/, "", $4); raw_bg = $4 }
	/"foreground":/ { gsub(/^#/, "", $4); raw_fg = $4 }
	/"color[0-9]+":/ {
		k = $2; sub(/^color/, "", k); idx = int(k)
		if (idx >= 0 && idx <= 15) { gsub(/^#/, "", $4); raw_c[idx] = $4 }
	}
	END {
		rgb2hsl(raw_bg); bg_h = H; bg_s = S; bg_l = L
		for (i = 0; i < 16; i++) {
			rgb2hsl(raw_c[i])
			ch[i] = H; cs[i] = S; cl[i] = L
		}

		# 1. Pick Primary (most saturated/vibrant), Secondary (most contrasting hue) & Tertiary accents across all 16 slots
		b1 = 4; best_s1 = -1
		for (i = 0; i < 16; i++) {
			sc = cs[i] * (1.0 - 0.55 * abs(cl[i] - 0.52))
			if (cl[i] > 0.08 && cl[i] < 0.94 && sc > best_s1) { best_s1 = sc; b1 = i }
		}
		if (bg_s < 0.06 && cs[b1] > 0.10) { bg_h = ch[b1]; bg_s = 0.16 }

		b2 = 5; best_s2 = -1
		for (i = 0; i < 16; i++) {
			if (i == b1) continue
			sc = (cs[i] + 0.08) * (0.25 + 0.75 * (hdist(ch[i], ch[b1]) / 180.0))
			if (cl[i] > 0.08 && cl[i] < 0.94 && sc > best_s2) { best_s2 = sc; b2 = i }
		}

		b3 = 6; best_s3 = -1
		for (i = 0; i < 16; i++) {
			if (i == b1 || i == b2) continue
			sc = (cs[i] + 0.08) * (0.25 + 0.75 * ((hdist(ch[i], ch[b1]) + hdist(ch[i], ch[b2])) / 360.0))
			if (cl[i] > 0.08 && cl[i] < 0.94 && sc > best_s3) { best_s3 = sc; b3 = i }
		}

		# 2. Harmonious low-contrast Surfaces (bg & color0) + High-contrast Text (fg & color8)
		if (theme == "day") {
			surf_s = clamp(bg_s, 0.10, 0.28)
			bg_hex = hsl2hex(bg_h, surf_s, 0.85)
			c0_hex = hsl2hex(bg_h, surf_s, 0.78)
			fg_hex = hsl2hex(bg_h, clamp(bg_s, 0.08, 0.22), 0.12)
			c8_hex = hsl2hex(bg_h, clamp(bg_s, 0.08, 0.18), 0.36)
			c7_hex = hsl2hex(bg_h, clamp(bg_s, 0.08, 0.20), 0.24)
			c15_hex = hsl2hex(bg_h, clamp(bg_s, 0.06, 0.16), 0.10)
		} else {
			surf_s = clamp(bg_s, 0.10, 0.30)
			base_l = clamp(bg_l, 0.11, 0.16)
			bg_hex = hsl2hex(bg_h, surf_s, base_l)
			c0_hex = hsl2hex(bg_h, surf_s, base_l + 0.065)
			fg_hex = hsl2hex(bg_h, clamp(bg_s, 0.08, 0.20), 0.91)
			c8_hex = hsl2hex(bg_h, clamp(bg_s, 0.08, 0.18), 0.62)
			c7_hex = hsl2hex(bg_h, clamp(bg_s, 0.08, 0.18), 0.78)
			c15_hex = hsl2hex(bg_h, clamp(bg_s, 0.06, 0.16), 0.94)
		}

		# 3. Assign Accents (color4 = primary, color5 = secondary contrasting hue, color6 = tertiary)
		ah[4] = ch[b1]; as[4] = cs[b1]; al[4] = cl[b1]
		ah[5] = ch[b2]; as[5] = cs[b2]; al[5] = cl[b2]
		ah[6] = ch[b3]; as[6] = cs[b3]; al[6] = cl[b3]
		for (k = 1; k <= 3; k++) {
			src = (cs[k] >= cs[k + 8]) ? k : (k + 8)
			if (cs[src] < 0.15) {
				ah[k] = (ch[b1] + k * 55.0) % 360.0
				as[k] = clamp(cs[b1], 0.45, 0.75)
				al[k] = 0.55
			} else {
				ah[k] = ch[src]; as[k] = cs[src]; al[k] = cl[src]
			}
		}

		out_c[0] = c0_hex; out_c[7] = c7_hex; out_c[8] = c8_hex; out_c[15] = c15_hex
		for (k = 1; k <= 6; k++) {
			sat = clamp(as[k] < 0.42 ? as[k] + 0.22 : as[k], 0.45, 0.86)
			if (theme == "day") {
				l_norm = clamp(al[k], 0.28, 0.39)
				l_bold = clamp(l_norm - 0.05, 0.22, 0.34)
			} else {
				l_norm = clamp(al[k], 0.64, 0.75)
				l_bold = clamp(l_norm + 0.06, 0.70, 0.82)
			}
			out_c[k] = hsl2hex(ah[k], sat, l_norm)
			out_c[k + 8] = hsl2hex(ah[k], sat, l_bold)
		}

		# A. Write Quickshell colors.json
		printf "{\n\t\"wallpaper\": \"%s\",\n\t\"wallMode\": \"%s\",\n\t\"uiBlur\": %s,\n\t\"uiAnimations\": %s,\n\t\"firstRunDone\": %s,\n", wall, mode, bl, an, fr > qs_out
		printf "\t\"background\": \"#%s\",\n\t\"foreground\": \"#%s\",\n", bg_hex, fg_hex >> qs_out
		for (i = 0; i < 16; i++) {
			printf "\t\"color%d\": \"#%s\"%s\n", i, out_c[i], (i < 15 ? "," : "") >> qs_out
		}
		printf "}\n" >> qs_out
		close(qs_out)

		# B. Write Qt6ct wallust.conf (Cohesive Window=c0 / Base=bg / Button=c0 + High-contrast Text=fg)
		printf "[ColorScheme]\n" > qt_out
		printf "active_colors=#ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #80%s\n", fg_hex, c0_hex, c0_hex, c0_hex, bg_hex, c0_hex, fg_hex, fg_hex, fg_hex, bg_hex, c0_hex, bg_hex, out_c[4], bg_hex, out_c[4], out_c[5], c0_hex, fg_hex, c0_hex, fg_hex, fg_hex >> qt_out
		printf "disabled_colors=#ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #80%s\n", c8_hex, c0_hex, c0_hex, c0_hex, bg_hex, c0_hex, c8_hex, c8_hex, c8_hex, bg_hex, c0_hex, bg_hex, c8_hex, bg_hex, out_c[4], out_c[5], c0_hex, c8_hex, c0_hex, c8_hex, c8_hex >> qt_out
		printf "inactive_colors=#ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #80%s\n", fg_hex, c0_hex, c0_hex, c0_hex, bg_hex, c0_hex, fg_hex, fg_hex, fg_hex, bg_hex, c0_hex, bg_hex, out_c[4], bg_hex, out_c[4], out_c[5], c0_hex, fg_hex, c0_hex, fg_hex, fg_hex >> qt_out
		close(qt_out)

		# C. Write Kitty colors.conf
		printf "foreground #%s\nbackground #%s\ncursor #%s\nselection_foreground #%s\nselection_background #%s\n", fg_hex, bg_hex, out_c[4], bg_hex, out_c[4] > kitty_out
		for (i = 0; i < 16; i++) printf "color%d #%s\n", i, out_c[i] >> kitty_out
		close(kitty_out)

		# D. Write Hyprland colors.conf
		printf "$background = rgb(%s)\n$foreground = rgb(%s)\n$color0 = rgb(%s)\n$color4 = rgb(%s)\n$color5 = rgb(%s)\n$color6 = rgb(%s)\n", bg_hex, fg_hex, c0_hex, out_c[4], out_c[5], out_c[6] > hypr_out
		close(hypr_out)
	}' "$QS_DIR/colors.json"

	mv -f "$QS_DIR/colors.json.tmp" "$QS_DIR/colors.json"

	# Sync Niri active/inactive window border colors with calibrated color4 & color0
	if [[ -f "$HOME/.config/niri/config.kdl" ]]; then
		local n_c4 n_c0
		n_c4=$(grep -o '"color4": *"[^"]*"' "$QS_DIR/colors.json" | cut -d'"' -f4)
		n_c0=$(grep -o '"color0": *"[^"]*"' "$QS_DIR/colors.json" | cut -d'"' -f4)
		[[ -n "$n_c4" ]] && sed -i "s|active-color \"#[0-9a-fA-F]*\"|active-color \"$n_c4\"|g" "$HOME/.config/niri/config.kdl"
		[[ -n "$n_c0" ]] && sed -i "s|inactive-color \"#[0-9a-fA-F]*\"|inactive-color \"$n_c0\"|g" "$HOME/.config/niri/config.kdl"
	fi

	# Sync Icon Theme (Papirus-Light on Day, Papirus-Dark on Night) & FeatherPad sheet lightness
	local icon_thm="Papirus-Dark" dark_fp="true" fp_bg="30"
	if [[ "$theme" == "day" ]]; then
		icon_thm="Papirus-Light"; dark_fp="false"; fp_bg="222"
	fi
	[[ -f "$HOME/.config/qt6ct/qt6ct.conf" ]] && sed -i "s|^icon_theme=.*|icon_theme=$icon_thm|" "$HOME/.config/qt6ct/qt6ct.conf"
	[[ -f "$HOME/.config/pcmanfm-qt/default/settings.conf" ]] && sed -i "s|^IconThemeName=.*|IconThemeName=$icon_thm|" "$HOME/.config/pcmanfm-qt/default/settings.conf"
	if [[ -f "$HOME/.config/featherpad/fp.conf" ]]; then
		sed -i -e "s|^darkColScheme=.*|darkColScheme=$dark_fp|" -e "s|^bgColValue=.*|bgColValue=$fp_bg|" "$HOME/.config/featherpad/fp.conf"
	fi
}

apply_theme() {
	local theme="$1"
	local static_dir="$2"
	local anim_dir="$3"
	local mode bl an fr
	mode=$(get_wall_mode)
	bl=$(get_json_bool "uiBlur" "true")
	an=$(get_json_bool "uiAnimations" "true")
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

	local target_pal="$DAY_PALETTE"
	[[ "$theme" == "night" ]] && target_pal="$NIGHT_PALETTE"
	if [[ -f "$WALLUST_TOML" ]]; then
		sed -i "s|^[[:space:]]*palette *=.*|palette = \"$target_pal\"|" "$WALLUST_TOML"
	fi

	sync_quickshell_state "$mode" "$bl" "$an" "$fr"
	wallust run -s "$wall_img" 2>/dev/null
	calibrate_and_apply_colors "$theme" "$wall" "$mode" "$bl" "$an" "$fr"

	killall -SIGUSR1 kitty 2>/dev/null || true
	if command -v quickshell >/dev/null 2>&1; then
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
