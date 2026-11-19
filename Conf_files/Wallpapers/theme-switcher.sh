#!/bin/bash
# ==============================================================================
# USER CONFIGURATION & TUNING VARIABLES (THEME SWITCHER)
# ==============================================================================
DAY_START_HOUR=7
NIGHT_START_HOUR=19
CHECK_INTERVAL=60
ROTATE_INTERVAL=0

# Wallust palettes written into ~/.config/wallust/wallust.toml on Day/Night switch
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
	local src_json="${RAW_QS_JSON:-/tmp/wallust_raw_${UID:-0}.json}"
	[[ ! -f "$src_json" ]] && src_json="$QS_DIR/colors.json"
	[[ ! -f "$src_json" ]] && return 0

	local probe_img="$wall" sil_file="/tmp/wall_sil_${UID:-0}.txt" u2_used=0
	: > "$sil_file"
	[[ "${wall,,}" =~ \.(webm|mp4)$ && -f "/tmp/wall_frame.jpg" ]] && probe_img="/tmp/wall_frame.jpg"

	local model_path="" py_bin="python3"
	for p in "/usr/share/quickshell/u2netp.onnx" "$HOME/.local/share/quickshell/u2netp.onnx"; do
		[[ -f "$p" ]] && { model_path="$p"; break; }
	done
	[[ -x "/opt/u2net-venv/bin/python" ]] && py_bin="/opt/u2net-venv/bin/python"

	if [[ -f "$probe_img" && -n "$model_path" ]] && "$py_bin" -c "import onnxruntime, numpy, PIL" 2>/dev/null; then
		if "$py_bin" - "$probe_img" "$model_path" "$sil_file" <<'PYEOF' 2>/dev/null; then
import sys
from collections import deque
import numpy as np
from PIL import Image, ImageFilter
import onnxruntime as ort

img_path, model_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
gw, gh = 360, 202

sess_opts = ort.SessionOptions()
sess_opts.intra_op_num_threads = 2
sess_opts.inter_op_num_threads = 1
sess = ort.InferenceSession(model_path, sess_options=sess_opts, providers=["CPUExecutionProvider"])
in_name = sess.get_inputs()[0].name

im = Image.open(img_path).convert("RGB")
im_net = im.resize((320, 320), Image.Resampling.BILINEAR)
arr = np.asarray(im_net, dtype=np.float32) / 255.0
mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
std = np.array([0.229, 0.224, 0.225], dtype=np.float32)
arr = ((arr - mean) / std).transpose(2, 0, 1)[None, ...]

pred = sess.run(None, {in_name: arr})[0][0, 0]
pred = np.clip(pred, 0.0, 1.0)
mask_im = Image.fromarray((pred * 255.0).astype(np.uint8), mode="L").resize((gw, gh), Image.Resampling.BILINEAR)
m = np.asarray(mask_im, dtype=np.float32) / 255.0

thr = float(np.percentile(m, 78))
thr = max(0.35, min(0.75, thr))
fg = m >= thr

# Fill enclosed interior holes via exterior BFS from border
h, w = fg.shape
ext = np.zeros((h, w), dtype=bool)
q = deque()
for x in range(w):
	if not fg[0, x]:
		ext[0, x] = True; q.append((0, x))
	if not fg[h - 1, x]:
		ext[h - 1, x] = True; q.append((h - 1, x))
for y in range(1, h - 1):
	if not fg[y, 0]:
		ext[y, 0] = True; q.append((y, 0))
	if not fg[y, w - 1]:
		ext[y, w - 1] = True; q.append((y, w - 1))

while q:
	cy, cx = q.popleft()
	if cx > 0 and not fg[cy, cx - 1] and not ext[cy, cx - 1]:
		ext[cy, cx - 1] = True; q.append((cy, cx - 1))
	if cx < w - 1 and not fg[cy, cx + 1] and not ext[cy, cx + 1]:
		ext[cy, cx + 1] = True; q.append((cy, cx + 1))
	if cy > 0 and not fg[cy - 1, cx] and not ext[cy - 1, cx]:
		ext[cy - 1, cx] = True; q.append((cy - 1, cx))
	if cy < h - 1 and not fg[cy + 1, cx] and not ext[cy + 1, cx]:
		ext[cy + 1, cx] = True; q.append((cy + 1, cx))

closed = (~ext).astype(np.float32) * 15.0
sm_im = Image.fromarray(closed.astype(np.uint8), mode="L").filter(ImageFilter.BoxBlur(1))
q_arr = np.clip(np.round(np.asarray(sm_im, dtype=np.float32)), 0, 15).astype(np.uint8)
hex_chars = "0123456789abcdef"
out_str = "".join(hex_chars[v] for v in q_arr.ravel())
with open(out_path, "w", encoding="ascii") as f:
	f.write(out_str)
PYEOF
			[[ $(wc -c < "$sil_file") -ge 72720 ]] && u2_used=1
		fi
	fi

	if [[ "$u2_used" -eq 0 && -f "$probe_img" ]] && command -v ffmpeg >/dev/null 2>&1; then
		ffmpeg -v quiet -i "$probe_img" -frames:v 1 -vf "scale=360:202:flags=area" -pix_fmt rgb24 -f rawvideo - 2>/dev/null | od -An -tu1 -v | LC_ALL=C awk '
		function abs(v) { return v < 0 ? -v : v }
		function clamp(v, lo, hi) { return v < lo ? lo : (v > hi ? hi : v) }
		{
			for (i = 1; i <= NF; i++) raw[n++] = $i
		}
		END {
			gw = 360; gh = 202; tot = gw * gh
			if (n < tot * 3) exit 0
			for (p = 0; p < tot; p++) {
				b = p * 3
				R[p] = raw[b]; G[p] = raw[b + 1]; B[p] = raw[b + 2]
			}

			for (y = 1; y < gh - 1; y++) {
				row = y * gw
				for (x = 1; x < gw - 1; x++) {
					i = row + x
					gx = abs(R[i + 1] - R[i - 1]) + abs(G[i + 1] - G[i - 1]) + abs(B[i + 1] - B[i - 1])
					gy = abs(R[i + gw] - R[i - gw]) + abs(G[i + gw] - G[i - gw]) + abs(B[i + gw] - B[i - gw])
					grad[i] = (gx + gy) * 0.5
				}
			}

			head = 0; tail = 0
			for (x = 0; x < gw; x++) {
				iT = x; iB = (gh - 1) * gw + x
				is_bg[iT] = 1; oR[iT] = R[iT]; oG[iT] = G[iT]; oB[iT] = B[iT]; q[tail++] = iT
				is_bg[iB] = 1; oR[iB] = R[iB]; oG[iB] = G[iB]; oB[iB] = B[iB]; q[tail++] = iB
			}
			for (y = 1; y < gh - 1; y++) {
				iL = y * gw; iR = y * gw + (gw - 1)
				is_bg[iL] = 1; oR[iL] = R[iL]; oG[iL] = G[iL]; oB[iL] = B[iL]; q[tail++] = iL
				is_bg[iR] = 1; oR[iR] = R[iR]; oG[iR] = G[iR]; oB[iR] = B[iR]; q[tail++] = iR
			}

			while (head < tail) {
				u = q[head++]
				ux = u % gw; uy = int(u / gw)
				nb[0] = (ux > 0) ? u - 1 : -1
				nb[1] = (ux < gw - 1) ? u + 1 : -1
				nb[2] = (uy > 0) ? u - gw : -1
				nb[3] = (uy < gh - 1) ? u + gw : -1
				for (k = 0; k < 4; k++) {
					v = nb[k]
					if (v < 0 || is_bg[v]) continue
					step_d = abs(R[v] - R[u]) + abs(G[v] - G[u]) + abs(B[v] - B[u])
					orig_d = abs(R[v] - oR[u]) + abs(G[v] - oG[u]) + abs(B[v] - oB[u])
					chr_d = abs((R[v] - G[v]) - (oR[u] - oG[u])) + abs((G[v] - B[v]) - (oG[u] - oB[u]))
					if (step_d <= 44 && grad[v] <= 52 && orig_d <= 105 && chr_d <= 75) {
						is_bg[v] = 1
						oR[v] = int(oR[u] * 0.96 + R[v] * 0.04)
						oG[v] = int(oG[u] * 0.96 + G[v] * 0.04)
						oB[v] = int(oB[u] * 0.96 + B[v] * 0.04)
						q[tail++] = v
					}
				}
			}

			best_cid = 0; best_score = -1; cid = 0
			for (y = 4; y < gh - 4; y++) {
				for (x = 4; x < gw - 4; x++) {
					start_i = y * gw + x
					if (is_bg[start_i] || comp[start_i]) continue
					cid++
					ch_head = 0; ch_tail = 0
					cq[ch_tail++] = start_i
					comp[start_i] = cid
					c_size = 0; sum_x = 0; sum_y = 0
					while (ch_head < ch_tail) {
						u = cq[ch_head++]
						ux = u % gw; uy = int(u / gw)
						c_size++; sum_x += ux; sum_y += uy
						if (ux > 2 && !is_bg[u - 1] && !comp[u - 1]) { comp[u - 1] = cid; cq[ch_tail++] = u - 1 }
						if (ux < gw - 3 && !is_bg[u + 1] && !comp[u + 1]) { comp[u + 1] = cid; cq[ch_tail++] = u + 1 }
						if (uy > 2 && !is_bg[u - gw] && !comp[u - gw]) { comp[u - gw] = cid; cq[ch_tail++] = u - gw }
						if (uy < gh - 3 && !is_bg[u + gw] && !comp[u + gw]) { comp[u + gw] = cid; cq[ch_tail++] = u + gw }
					}
					comp_sz[cid] = c_size
					if (c_size >= int(tot * 0.015)) {
						cx = (sum_x / c_size) / gw - 0.5
						cy = (sum_y / c_size) / gh - 0.5
						c_w = clamp(1.0 - (cx * cx * 2.2 + cy * cy * 2.2), 0.25, 1.0)
						sc = c_size * c_w
						if (sc > best_score) { best_score = sc; best_cid = cid }
					}
				}
			}

			best_sz = (best_cid > 0) ? comp_sz[best_cid] : 0
			if (best_cid > 0 && best_sz >= int(tot * 0.025) && best_sz <= int(tot * 0.28)) {
				for (i = 0; i < tot; i++) {
					if (comp[i] == best_cid) inSil[i] = 1
				}
			} else {
				seed = int(gh * 0.55) * gw + int(gw * 0.5)
				best_seed_sc = -1
				for (y = int(gh * 0.22); y <= int(gh * 0.82); y += 3) {
					row = y * gw
					for (x = int(gw * 0.18); x <= int(gw * 0.82); x += 3) {
						i = row + x
						if (is_bg[i]) continue
						dx = (x / gw) - 0.5; dy = (y / gh) - 0.55
						cw = clamp(1.0 - (dx * dx * 2.0 + dy * dy * 2.0), 0.3, 1.0)
						loc_g = grad[i] + grad[i - 2] + grad[i + 2] + grad[i - 2 * gw] + grad[i + 2 * gw]
						sc = loc_g * cw
						if (sc > best_seed_sc) { best_seed_sc = sc; seed = i }
					}
				}
				sR = R[seed]; sG = G[seed]; sB = B[seed]
				target = int(tot * 0.11)
				vis[seed] = 1; b_cnt[255] = 1; b_dat[255, 0] = seed
				cur_b = 255; picked = 0
				while (picked < target) {
					while (cur_b >= 20 && b_cnt[cur_b] <= 0) cur_b--
					if (cur_b < 20) break
					u = b_dat[cur_b, --b_cnt[cur_b]]
					inSil[u] = 1; picked++
					ux = u % gw; uy = int(u / gw)
					if (ux <= 4 || ux >= gw - 5 || uy <= 4 || uy >= gh - 5) continue
					nb[0] = u - 1; nb[1] = u + 1; nb[2] = u - gw; nb[3] = u + gw
					for (k = 0; k < 4; k++) {
						v = nb[k]
						if (!vis[v] && !is_bg[v]) {
							vis[v] = 1
							step_d = abs(R[v] - R[u]) + abs(G[v] - G[u]) + abs(B[v] - B[u])
							seed_d = abs(R[v] - sR) + abs(G[v] - sG) + abs(B[v] - sB)
							pr = clamp(int(240 - step_d * 1.4 - seed_d * 0.45 - grad[v] * 0.6), 1, 255)
							idx_b = b_cnt[pr] + 0
							b_dat[pr, idx_b] = v
							b_cnt[pr] = idx_b + 1
							if (pr > cur_b) cur_b = pr
						}
					}
				}
			}

			eq[0] = 0; ext[0] = 1; ehead = 0; etail = 1
			while (ehead < etail) {
				u = eq[ehead++]
				ux = u % gw; uy = int(u / gw)
				if (ux > 0 && !inSil[u - 1] && !ext[u - 1]) { ext[u - 1] = 1; eq[etail++] = u - 1 }
				if (ux < gw - 1 && !inSil[u + 1] && !ext[u + 1]) { ext[u + 1] = 1; eq[etail++] = u + 1 }
				if (uy > 0 && !inSil[u - gw] && !ext[u - gw]) { ext[u - gw] = 1; eq[etail++] = u - gw }
				if (uy < gh - 1 && !inSil[u + gw] && !ext[u + gw]) { ext[u + gw] = 1; eq[etail++] = u + gw }
			}

			for (y = 2; y < gh - 2; y++) {
				row = y * gw
				for (x = 2; x < gw - 2; x++) {
					i = row + x
					closed[i] = (!ext[i]) ? 15.0 : 0.0
				}
			}

			hex = "0123456789abcdef"
			out = ""
			for (y = 0; y < gh; y++) {
				row = y * gw
				for (x = 0; x < gw; x++) {
					i = row + x
					if (y <= 1 || y >= gh - 2 || x <= 1 || x >= gw - 2) {
						q_val = 0
					} else {
						sm = (closed[i] * 6.0 + (closed[i - 1] + closed[i + 1] + closed[i - gw] + closed[i + gw]) * 2.0 + closed[i - gw - 1] + closed[i - gw + 1] + closed[i + gw - 1] + closed[i + gw + 1]) / 18.0
						q_val = clamp(int(sm + 0.5), 0, 15)
					}
					out = out substr(hex, q_val + 1, 1)
				}
			}
			printf "%s", out
		}' > "$sil_file" 2>/dev/null || true
	fi

	LC_ALL=C awk -F'"' \
		-v theme="$theme" -v wall="$wall" -v mode="$mode" -v bl="$bl" -v an="$an" -v fr="$fr" -v sil_file="$sil_file" \
		-v qs_out="$QS_DIR/colors.json.tmp" \
		-v qt_out="$QT6_DIR/wallust.conf" \
		-v kitty_out="$KITTY_CONF" \
		-v hypr_out="$HYPR_CONF" '
	function abs(v) { return v < 0 ? -v : v }
	function clamp(v, lo, hi) { return v < lo ? lo : (v > hi ? hi : v) }
	function hex2dec(h, i, ch, v) {
		v = 0; h = tolower(h)
		for (i = 1; i <= length(h); i++) {
			ch = substr(h, i, 1)
			v = v * 16 + index("0123456789abcdef", ch) - 1
		}
		return v
	}
	function rgb2hsl(hex, r, g, b, mx, mn, d, h, s, l) {
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
	function hsl2hex(h, s, l, q, p, hk, r, g, b, ri, gi, bi) {
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
	function hdist(h1, h2, d) {
		d = abs(h1 - h2) % 360.0
		return d > 180.0 ? 360.0 - d : d
	}
	BEGIN {
		raw_bg = "1e1e2e"; raw_fg = "cdd6f4"; sil = ""
		if ((getline sil < sil_file) > 0) close(sil_file)
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

		b1 = 4; best_s1 = -1
		for (i = 0; i < 16; i++) {
			sc = cs[i] * (1.0 - 0.50 * abs(cl[i] - 0.52))
			if (cl[i] > 0.06 && cl[i] < 0.94 && sc > best_s1) { best_s1 = sc; b1 = i }
		}
		if (bg_s < 0.06 && cs[b1] > 0.08) { bg_h = ch[b1]; bg_s = clamp(cs[b1] * 0.6, 0.08, 0.22) }

		b2 = b1; best_s2 = -1
		for (i = 0; i < 16; i++) {
			if (i == b1 || cl[i] <= 0.06 || cl[i] >= 0.94) continue
			hd = (cs[i] >= 0.16) ? (hdist(ch[i], ch[b1]) / 180.0) : 0.0
			sc = cs[i] * (0.45 + 0.55 * hd)
			if (sc > best_s2) { best_s2 = sc; b2 = i }
		}
		if (cs[b2] < 0.10) b2 = b1

		b3 = b2; best_s3 = -1
		for (i = 0; i < 16; i++) {
			if (i == b1 || i == b2 || cl[i] <= 0.06 || cl[i] >= 0.94) continue
			hd = (cs[i] >= 0.16) ? ((hdist(ch[i], ch[b1]) + hdist(ch[i], ch[b2])) / 360.0) : 0.0
			sc = cs[i] * (0.45 + 0.55 * hd)
			if (sc > best_s3) { best_s3 = sc; b3 = i }
		}
		if (cs[b3] < 0.10) b3 = b1

		if (theme == "day") {
			surf_s = clamp(bg_s, 0.08, 0.26)
			bg_hex = hsl2hex(bg_h, surf_s, 0.85)
			c0_hex = hsl2hex(bg_h, surf_s, 0.78)
			fg_hex = hsl2hex(bg_h, clamp(bg_s, 0.06, 0.20), 0.12)
			c8_hex = hsl2hex(bg_h, clamp(bg_s, 0.06, 0.16), 0.36)
			c7_hex = hsl2hex(bg_h, clamp(bg_s, 0.06, 0.18), 0.24)
			c15_hex = hsl2hex(bg_h, clamp(bg_s, 0.05, 0.14), 0.10)
		} else {
			surf_s = clamp(bg_s, 0.08, 0.28)
			base_l = clamp(bg_l, 0.11, 0.16)
			bg_hex = hsl2hex(bg_h, surf_s, base_l)
			c0_hex = hsl2hex(bg_h, surf_s, base_l + 0.065)
			fg_hex = hsl2hex(bg_h, clamp(bg_s, 0.06, 0.18), 0.91)
			c8_hex = hsl2hex(bg_h, clamp(bg_s, 0.06, 0.16), 0.62)
			c7_hex = hsl2hex(bg_h, clamp(bg_s, 0.06, 0.16), 0.78)
			c15_hex = hsl2hex(bg_h, clamp(bg_s, 0.05, 0.14), 0.94)
		}

		ah[4] = ch[b1]; as[4] = cs[b1]; al[4] = cl[b1]
		ah[5] = ch[b2]; as[5] = cs[b2]; al[5] = cl[b2]
		ah[6] = ch[b3]; as[6] = cs[b3]; al[6] = cl[b3]
		for (k = 1; k <= 3; k++) {
			src = (cs[k] >= cs[k + 8]) ? k : (k + 8)
			if (cs[src] < 0.12) {
				pick = (k == 1) ? b2 : ((k == 2) ? b3 : b1)
				ah[k] = ch[pick]
				as[k] = cs[pick]
				al[k] = cl[src]
			} else {
				ah[k] = ch[src]; as[k] = cs[src]; al[k] = cl[src]
			}
		}

		out_c[0] = c0_hex; out_c[7] = c7_hex; out_c[8] = c8_hex; out_c[15] = c15_hex
		min_s = clamp(cs[b1], 0.14, 0.32)
		for (k = 1; k <= 6; k++) {
			sat = clamp(as[k] * 1.12, min_s, 0.78)
			if (theme == "day") {
				l_norm = clamp(al[k], 0.28, 0.40)
				l_bold = clamp(l_norm - 0.05, 0.22, 0.34)
			} else {
				l_norm = clamp(al[k], 0.62, 0.74)
				l_bold = clamp(l_norm + 0.06, 0.68, 0.82)
			}
			out_c[k] = hsl2hex(ah[k], sat, l_norm)
			out_c[k + 8] = hsl2hex(ah[k], sat, l_bold)
		}

		printf "{\n\t\"wallpaper\": \"%s\",\n\t\"silhouette\": \"%s\",\n\t\"wallMode\": \"%s\",\n\t\"uiBlur\": %s,\n\t\"uiAnimations\": %s,\n\t\"firstRunDone\": %s,\n", wall, sil, mode, bl, an, fr > qs_out
		printf "\t\"background\": \"#%s\",\n\t\"foreground\": \"#%s\",\n", bg_hex, fg_hex >> qs_out
		for (i = 0; i < 16; i++) {
			printf "\t\"color%d\": \"#%s\"%s\n", i, out_c[i], (i < 15 ? "," : "") >> qs_out
		}
		printf "}\n" >> qs_out
		close(qs_out)

		printf "[ColorScheme]\n" > qt_out
		printf "active_colors=#ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #80%s\n", fg_hex, c0_hex, c0_hex, c0_hex, bg_hex, c0_hex, fg_hex, fg_hex, fg_hex, bg_hex, c0_hex, bg_hex, out_c[4], bg_hex, out_c[4], out_c[5], c0_hex, fg_hex, c0_hex, fg_hex, fg_hex >> qt_out
		printf "disabled_colors=#ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #80%s\n", c8_hex, c0_hex, c0_hex, c0_hex, bg_hex, c0_hex, c8_hex, c8_hex, c8_hex, bg_hex, c0_hex, bg_hex, c8_hex, bg_hex, out_c[4], out_c[5], c0_hex, c8_hex, c0_hex, c8_hex, c8_hex >> qt_out
		printf "inactive_colors=#ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #80%s\n", fg_hex, c0_hex, c0_hex, c0_hex, bg_hex, c0_hex, fg_hex, fg_hex, fg_hex, bg_hex, c0_hex, bg_hex, out_c[4], bg_hex, out_c[4], out_c[5], c0_hex, fg_hex, c0_hex, fg_hex, fg_hex >> qt_out
		close(qt_out)

		printf "foreground #%s\nbackground #%s\ncursor #%s\nselection_foreground #%s\nselection_background #%s\n", fg_hex, bg_hex, out_c[4], bg_hex, out_c[4] > kitty_out
		for (i = 0; i < 16; i++) printf "color%d #%s\n", i, out_c[i] >> kitty_out
		close(kitty_out)

		printf "$background = rgb(%s)\n$foreground = rgb(%s)\n$color0 = rgb(%s)\n$color4 = rgb(%s)\n$color5 = rgb(%s)\n$color6 = rgb(%s)\n", bg_hex, fg_hex, c0_hex, out_c[4], out_c[5], out_c[6] > hypr_out
		close(hypr_out)
	}' "$src_json"

	rm -f "$sil_file" 2>/dev/null || true
	mv -f "$QS_DIR/colors.json.tmp" "$QS_DIR/colors.json"

	if [[ -f "$HOME/.config/niri/config.kdl" ]]; then
		local n_c4 n_c0
		n_c4=$(grep -o '"color4": *"[^"]*"' "$QS_DIR/colors.json" | cut -d'"' -f4)
		n_c0=$(grep -o '"color0": *"[^"]*"' "$QS_DIR/colors.json" | cut -d'"' -f4)
		[[ -n "$n_c4" ]] && sed -i "s|active-color \"#[0-9a-fA-F]*\"|active-color \"$n_c4\"|g" "$HOME/.config/niri/config.kdl"
		[[ -n "$n_c0" ]] && sed -i "s|inactive-color \"#[0-9a-fA-F]*\"|inactive-color \"$n_c0\"|g" "$HOME/.config/niri/config.kdl"
	fi

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
	wall=$(find "$target_dir" -type f \( -iname "*.webm" -o -iname "*.mp4" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) ! -wholename "$CURRENT_WALL" 2>/dev/null | shuf -n 1)
	[[ -z "$wall" ]] && wall=$(find "$target_dir" -type f \( -iname "*.webm" -o -iname "*.mp4" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) 2>/dev/null | shuf -n 1)
	[[ -z "$wall" ]] && return 1
	[[ "$CURRENT_WALL" == "$wall" && "$LAST_MODE" == "$mode" && "$CURRENT_THEME" == "$theme" ]] && return 0

	local wall_img="$wall"
	if [[ "${wall,,}" =~ \.(webm|mp4)$ ]]; then
		wall_img="$FRAME_CACHE"
		[[ -f "$FRAME_CACHE" ]] && cp -f "$FRAME_CACHE" "/tmp/wall_frame_prev.jpg" 2>/dev/null || true
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
