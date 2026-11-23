#!/bin/bash
# ==============================================================================
# USER CONFIGURATION & TUNING VARIABLES (THEMING)
# Optional per-user overrides: ~/.config/wallpapers/theming.conf
# ==============================================================================
DAY_START_HOUR=7
NIGHT_START_HOUR=19
CHECK_INTERVAL=60
ROTATE_INTERVAL=0

# Wallust palettes written into ~/.config/wallust/wallust.toml on Day/Night switch
DAY_PALETTE="light16"
NIGHT_PALETTE="dark16"
# ==============================================================================

WALL_DIR="$HOME/.config/wallpapers"
[[ -f "$WALL_DIR/theming.conf" ]] && source "$WALL_DIR/theming.conf"

DAY_DIR="$WALL_DIR/day"
NIGHT_DIR="$WALL_DIR/night"
DAY_ANIM_DIR="$WALL_DIR/day_animated"
NIGHT_ANIM_DIR="$WALL_DIR/night_animated"
WALLUST_TOML="$HOME/.config/wallust/wallust.toml"
QS_DIR="$HOME/.config/quickshell"
QT6_DIR="$HOME/.config/qt6ct/colors"
KITTY_CONF="$HOME/.config/kitty/colors.conf"
HYPR_CONF="$HOME/.config/hypr/colors.conf"
RAW_QS_JSON="/tmp/wallust_raw_${UID:-0}.json"
PIDFILE="/tmp/theming-${UID:-0}.pid"
SIL_TMP="/tmp/theming_sil_${UID:-0}_$$.txt"

# === CACHE, HASHING & JSON HELPERS ===

init_cache_dirs() {
	local base="/var/cache/quickshell"
	if [[ -d "$base/frames" && -w "$base/frames" && -d "$base/silhouettes" && -w "$base/silhouettes" ]]; then
		FRAME_CACHE_DIR="$base/frames"
		SIL_CACHE_DIR="$base/silhouettes"
	else
		FRAME_CACHE_DIR="$HOME/.cache/quickshell/frames"
		SIL_CACHE_DIR="$HOME/.cache/quickshell/silhouettes"
		mkdir -p "$FRAME_CACHE_DIR" "$SIL_CACHE_DIR"
	fi
}

wall_hash() {
	local sz
	sz=$(stat -c '%s' "$1" 2>/dev/null || echo 0)
	{ printf '%s|' "$sz"; head -c 262144 "$1" 2>/dev/null; } | sha256sum | cut -c1-16
}

is_video_file() { [[ "${1,,}" =~ \.(webm|mp4)$ ]]; }

find_wallpapers() {
	local dir="$1" args=()
	[[ -d "$dir" ]] || return 0
	[[ -n "${2:-}" ]] && args=(! -wholename "$2")
	find "$dir" -type f \( -iname "*.webm" -o -iname "*.mp4" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) "${args[@]}" 2>/dev/null
}

get_json_str() {
	grep -o "\"$1\": *\"[^\"]*\"" "$QS_DIR/colors.json" 2>/dev/null | head -n1 | cut -d'"' -f4
}

get_json_bool() {
	local val
	val=$(grep -o "\"$1\": *[a-z]*" "$QS_DIR/colors.json" 2>/dev/null | head -n1 | awk -F: '{gsub(/[[:space:]]/,"",$2); print $2}')
	[[ "$val" =~ ^(true|false)$ ]] && echo "$val" || echo "$2"
}

get_wall_mode() {
	[[ "$FORCED_MODE" =~ ^(animated|static)$ ]] && { echo "$FORCED_MODE"; return; }
	[[ "$(get_json_str wallMode)" == "animated" ]] && echo "animated" || echo "static"
}

stop_previous_daemon() {
	if [[ -f "$PIDFILE" ]]; then
		local old_pid
		old_pid=$(<"$PIDFILE")
		if [[ -n "$old_pid" && "$old_pid" != "$$" ]]; then
			pkill -P "$old_pid" 2>/dev/null || true
			kill "$old_pid" 2>/dev/null || true
		fi
		rm -f "$PIDFILE" 2>/dev/null || true
	fi
}

# === VIDEO FRAME & SILHOUETTE CACHE ===

ensure_video_frame() {
	local src="$1" whash="$2" dst tmp
	is_video_file "$src" || { echo ""; return 0; }
	dst="$FRAME_CACHE_DIR/${whash}.jpg"
	[[ -s "$dst" ]] && { echo "$dst"; return 0; }
	command -v ffmpeg >/dev/null 2>&1 || { echo ""; return 1; }
	tmp="${dst}.${UID:-0}.$$.tmp.jpg"
	if ffmpeg -nostdin -y -loglevel quiet -i "$src" -frames:v 1 -vf "scale='min(1280,iw)':-1" -q:v 2 "$tmp" </dev/null >/dev/null 2>&1 && [[ -s "$tmp" ]]; then
		chmod 644 "$tmp" 2>/dev/null || true
		mv -f "$tmp" "$dst" 2>/dev/null || rm -f "$tmp" 2>/dev/null || true
		[[ -s "$dst" ]] && { echo "$dst"; return 0; }
	fi
	rm -f "$tmp" 2>/dev/null || true
	echo ""
	return 1
}

generate_silhouette() {
	local probe_img="$1" whash="$2"
	: > "$SIL_TMP"
	[[ -f "$probe_img" ]] || return 0

	local sam_enc="" sam_dec="" d sil_ready=0
	for d in "/usr/share/quickshell" "$HOME/.local/share/quickshell"; do
		if [[ -f "$d/mobile_sam_image_encoder.onnx" && -f "$d/sam_mask_decoder_multi.onnx" ]]; then
			sam_enc="$d/mobile_sam_image_encoder.onnx"
			sam_dec="$d/sam_mask_decoder_multi.onnx"
			break
		fi
	done

	local sam_cache="$SIL_CACHE_DIR/mobilesam_v1_${whash}.txt"
	local awk_cache="$SIL_CACHE_DIR/awk_v1_${whash}.txt"

	# 1. Fast path: MobileSAM shared cache hit (<5ms, 0% CPU)
	if [[ -n "$sam_enc" && -s "$sam_cache" ]]; then
		shuf -n 1 "$sam_cache" | tr -d '\r\n' > "$SIL_TMP"
		[[ $(wc -c < "$SIL_TMP") -ge 72720 ]] && sil_ready=1
	fi

	# 2. Primary engine: MobileSAM (2-stage BFS, nice -n 15, up to 5 clean objects)
	if [[ "$sil_ready" -eq 0 && -n "$sam_enc" ]] && python3 -c "import onnxruntime, numpy, PIL" </dev/null >/dev/null 2>&1; then
		local run_nice=()
		command -v nice >/dev/null 2>&1 && run_nice=(nice -n 15)
		if "${run_nice[@]}" python3 - "$probe_img" "$sam_enc" "$sam_dec" "$sam_cache" "$SIL_TMP" <<'PYEOF' >/dev/null 2>&1; then
import os, random, sys
from collections import deque
import numpy as np
from PIL import Image
import onnxruntime as ort

def bfs_largest(mask):
    h, w = mask.shape
    lbl = np.zeros((h, w), dtype=np.int32)
    sizes, cid = [0], 0
    for y in range(h):
        for x in range(w):
            if mask[y, x] and lbl[y, x] == 0:
                cid += 1
                cnt, q = 0, deque([(y, x)])
                lbl[y, x] = cid
                while q:
                    cy, cx = q.popleft()
                    cnt += 1
                    for ny, nx in ((cy, cx - 1), (cy, cx + 1), (cy - 1, cx), (cy + 1, cx)):
                        if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and lbl[ny, nx] == 0:
                            lbl[ny, nx] = cid
                            q.append((ny, nx))
                sizes.append(cnt)
    if cid == 0:
        return np.zeros((h, w), dtype=bool), 0
    best = int(np.argmax(sizes[1:])) + 1
    return (lbl == best), sizes[best]

def fill_holes(mask):
    h, w = mask.shape
    ext = np.zeros((h, w), dtype=bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if not mask[y, x] and not ext[y, x]:
                ext[y, x] = True; q.append((y, x))
    for y in range(1, h - 1):
        for x in (0, w - 1):
            if not mask[y, x] and not ext[y, x]:
                ext[y, x] = True; q.append((y, x))
    while q:
        cy, cx = q.popleft()
        for ny, nx in ((cy, cx - 1), (cy, cx + 1), (cy - 1, cx), (cy + 1, cx)):
            if 0 <= ny < h and 0 <= nx < w and not mask[ny, nx] and not ext[ny, nx]:
                ext[ny, nx] = True
                q.append((ny, nx))
    return ~ext

def dedup_pick(cands, limit=5):
    cands.sort(key=lambda x: x[0], reverse=True)
    picked = []
    for item in cands:
        ms = item[1]
        if any((np.logical_and(ms, p[1]).sum() / max(1, np.logical_or(ms, p[1]).sum())) > 0.45 for p in picked):
            continue
        picked.append(item)
        if len(picked) >= limit:
            break
    return picked

img_path, enc_path, dec_path, out_cache, out_single = sys.argv[1:6]
gw, gh = 360, 202

ncpu = os.cpu_count() or 2
opts = ort.SessionOptions()
opts.intra_op_num_threads = max(2, min(4, ncpu // 2 if ncpu >= 4 else ncpu))
opts.inter_op_num_threads = 1
enc = ort.InferenceSession(enc_path, opts, providers=["CPUExecutionProvider"])
dec = ort.InferenceSession(dec_path, opts, providers=["CPUExecutionProvider"])
ein = enc.get_inputs()[0]

im = Image.open(img_path).convert("RGB")
ow, oh = im.size
scale = 1024.0 / max(ow, oh)
nw, nh = int(round(ow * scale)), int(round(oh * scale))
im_r = im.resize((nw, nh), Image.Resampling.BILINEAR)

if len(ein.shape) == 3:
    enc_arr = np.asarray(im_r, dtype=np.float32)
else:
    arr = (np.asarray(im_r, dtype=np.float32) - np.array([123.675, 116.28, 103.53], np.float32)) / np.array([58.395, 57.12, 57.375], np.float32)
    pad = np.zeros((1024, 1024, 3), dtype=np.float32)
    pad[:nh, :nw, :] = arr
    enc_arr = pad.transpose(2, 0, 1)[None, ...]

emb = enc.run(None, {ein.name: enc_arr})[0]
orig_size = np.array([max(120, int(round(360 * oh / ow))), 360], dtype=np.float32)
mask_in = np.zeros((1, 1, 256, 256), dtype=np.float32)
has_mask = np.zeros((1,), dtype=np.float32)

strict_cands, relaxed_cands = [], []
for gy in (0.14, 0.33, 0.52, 0.71, 0.88):
    for gx in (0.09, 0.21, 0.33, 0.44, 0.56, 0.67, 0.79, 0.91):
        masks, ious, _ = dec.run(None, {
            "image_embeddings": emb,
            "point_coords": np.array([[[gx * nw, gy * nh], [0.0, 0.0]]], dtype=np.float32),
            "point_labels": np.array([[1.0, -1.0]], dtype=np.float32),
            "mask_input": mask_in,
            "has_mask_input": has_mask,
            "orig_im_size": orig_size,
        })
        for k in (range(1, masks.shape[1]) if masks.shape[1] >= 4 else range(masks.shape[1])):
            iou = float(ious[0, k])
            if iou < 0.82:
                continue
            logits = masks[0, k]
            m = logits > 0.0
            if not (0.0045 <= float(m.mean()) <= 0.28):
                continue
            m_lo, m_hi = logits > -1.0, logits > 1.0
            u_st = int(np.logical_or(m_lo, m_hi).sum())
            if u_st == 0:
                continue
            stab = float(np.logical_and(m_lo, m_hi).sum()) / u_st
            if stab < 0.84:
                continue
            btouch = (m[0, :].mean() + m[-1, :].mean() + m[:, 0].mean() + m[:, -1].mean()) / 4.0
            if btouch > 0.16:
                continue
            ms = m[::2, ::2]
            tot_s = int(ms.sum())
            if tot_s == 0:
                continue
            main_s, main_px = bfs_largest(ms)
            if (main_px / tot_s) < 0.86:
                continue
            clean_s = fill_holes(main_s)
            if ((int(clean_s.sum()) - main_px) / max(1, main_px)) > 0.30:
                continue
            score = iou * stab + (0.045 if btouch < 0.01 else 0.0)
            (strict_cands if (iou >= 0.88 and stab >= 0.90) else relaxed_cands).append((score, clean_s, m))

picked = dedup_pick(strict_cands, 5)
if len(picked) < 2 and relaxed_cands:
    picked = dedup_pick(strict_cands + relaxed_cands, 4)
if not picked:
    sys.exit(1)

lines = []
for _, _, raw_m in picked:
    cm = fill_holes(bfs_largest(raw_m)[0])
    if cm.shape != (gh, gw):
        cm = np.asarray(Image.fromarray(cm.astype(np.uint8) * 255).resize((gw, gh), Image.Resampling.NEAREST)) > 127
    lines.append("".join("f" if v else "0" for v in cm.ravel()))

with open(out_single, "w", encoding="ascii") as f:
    f.write(random.choice(lines))

tmp_cache = f"{out_cache}.{os.getuid()}.{os.getpid()}.tmp"
try:
    with open(tmp_cache, "w", encoding="ascii") as f:
        f.write("\n".join(lines) + "\n")
    os.chmod(tmp_cache, 0o644)
    os.replace(tmp_cache, out_cache)
except OSError:
    try:
        os.unlink(tmp_cache)
    except OSError:
        pass
PYEOF
			[[ $(wc -c < "$SIL_TMP") -ge 72720 ]] && sil_ready=1
		fi
	fi

	# 3. Fallback cache hit (Void / Artix without Arch repos / offline)
	if [[ "$sil_ready" -eq 0 && -s "$awk_cache" ]]; then
		tr -d '\r\n' < "$awk_cache" > "$SIL_TMP"
		[[ $(wc -c < "$SIL_TMP") -ge 72720 ]] && sil_ready=1
	fi

	# 4. Zero-dependency fallback engine: ffmpeg + single-stage awk
	if [[ "$sil_ready" -eq 0 ]] && command -v ffmpeg >/dev/null 2>&1; then
		ffmpeg -nostdin -v quiet -i "$probe_img" -frames:v 1 -vf "scale=360:202:flags=area" -pix_fmt rgb24 -f rawvideo - </dev/null 2>/dev/null | od -An -tu1 -v | LC_ALL=C awk '
		function abs(v) { return v < 0 ? -v : v }
		function clamp(v, lo, hi) { return v < lo ? lo : (v > hi ? hi : v) }
		{ for (i = 1; i <= NF; i++) raw[n++] = $i }
		END {
			gw = 360; gh = 202; tot = gw * gh
			if (n < tot * 3) exit 0
			for (p = 0; p < tot; p++) { b = p * 3; R[p] = raw[b]; G[p] = raw[b + 1]; B[p] = raw[b + 2] }
			for (y = 1; y < gh - 1; y++) {
				row = y * gw
				for (x = 1; x < gw - 1; x++) {
					i = row + x
					grad[i] = (abs(R[i + 1] - R[i - 1]) + abs(G[i + 1] - G[i - 1]) + abs(B[i + 1] - B[i - 1]) + abs(R[i + gw] - R[i - gw]) + abs(G[i + gw] - G[i - gw]) + abs(B[i + gw] - B[i - gw])) * 0.5
				}
			}
			head = 0; tail = 0
			for (x = 0; x < gw; x++) {
				for (k = 0; k < 2; k++) { i = (k ? (gh - 1) * gw : 0) + x; is_bg[i] = 1; oR[i] = R[i]; oG[i] = G[i]; oB[i] = B[i]; q[tail++] = i }
			}
			for (y = 1; y < gh - 1; y++) {
				for (k = 0; k < 2; k++) { i = y * gw + (k ? gw - 1 : 0); is_bg[i] = 1; oR[i] = R[i]; oG[i] = G[i]; oB[i] = B[i]; q[tail++] = i }
			}
			while (head < tail) {
				u = q[head++]; ux = u % gw; uy = int(u / gw)
				nb[0] = (ux > 0) ? u - 1 : -1; nb[1] = (ux < gw - 1) ? u + 1 : -1
				nb[2] = (uy > 0) ? u - gw : -1; nb[3] = (uy < gh - 1) ? u + gw : -1
				for (k = 0; k < 4; k++) {
					v = nb[k]
					if (v < 0 || is_bg[v]) continue
					step_d = abs(R[v] - R[u]) + abs(G[v] - G[u]) + abs(B[v] - B[u])
					orig_d = abs(R[v] - oR[u]) + abs(G[v] - oG[u]) + abs(B[v] - oB[u])
					chr_d = abs((R[v] - G[v]) - (oR[u] - oG[u])) + abs((G[v] - B[v]) - (oG[u] - oB[u]))
					if (step_d <= 44 && grad[v] <= 52 && orig_d <= 105 && chr_d <= 75) {
						is_bg[v] = 1
						oR[v] = int(oR[u] * 0.96 + R[v] * 0.04); oG[v] = int(oG[u] * 0.96 + G[v] * 0.04); oB[v] = int(oB[u] * 0.96 + B[v] * 0.04)
						q[tail++] = v
					}
				}
			}
			best_cid = 0; best_score = -1; cid = 0
			for (y = 4; y < gh - 4; y++) {
				for (x = 4; x < gw - 4; x++) {
					start_i = y * gw + x
					if (is_bg[start_i] || comp[start_i]) continue
					cid++; ch_head = 0; ch_tail = 0; cq[ch_tail++] = start_i; comp[start_i] = cid
					c_size = 0; sum_x = 0; sum_y = 0
					while (ch_head < ch_tail) {
						u = cq[ch_head++]; ux = u % gw; uy = int(u / gw)
						c_size++; sum_x += ux; sum_y += uy
						if (ux > 2 && !is_bg[u - 1] && !comp[u - 1]) { comp[u - 1] = cid; cq[ch_tail++] = u - 1 }
						if (ux < gw - 3 && !is_bg[u + 1] && !comp[u + 1]) { comp[u + 1] = cid; cq[ch_tail++] = u + 1 }
						if (uy > 2 && !is_bg[u - gw] && !comp[u - gw]) { comp[u - gw] = cid; cq[ch_tail++] = u - gw }
						if (uy < gh - 3 && !is_bg[u + gw] && !comp[u + gw]) { comp[u + gw] = cid; cq[ch_tail++] = u + gw }
					}
					comp_sz[cid] = c_size
					if (c_size >= int(tot * 0.025) && c_size <= int(tot * 0.30)) {
						cx = (sum_x / c_size) / gw - 0.5; cy = (sum_y / c_size) / gh - 0.5
						sc = c_size * clamp(1.0 - (cx * cx * 2.2 + cy * cy * 2.2), 0.25, 1.0)
						if (sc > best_score) { best_score = sc; best_cid = cid }
					}
				}
			}
			if (best_cid == 0) exit 0
			for (i = 0; i < tot; i++) if (comp[i] == best_cid) inSil[i] = 1
			eq[0] = 0; ext[0] = 1; ehead = 0; etail = 1
			while (ehead < etail) {
				u = eq[ehead++]; ux = u % gw; uy = int(u / gw)
				if (ux > 0 && !inSil[u - 1] && !ext[u - 1]) { ext[u - 1] = 1; eq[etail++] = u - 1 }
				if (ux < gw - 1 && !inSil[u + 1] && !ext[u + 1]) { ext[u + 1] = 1; eq[etail++] = u + 1 }
				if (uy > 0 && !inSil[u - gw] && !ext[u - gw]) { ext[u - gw] = 1; eq[etail++] = u - gw }
				if (uy < gh - 1 && !inSil[u + gw] && !ext[u + gw]) { ext[u + gw] = 1; eq[etail++] = u + gw }
			}
			out = ""
			for (i = 0; i < tot; i++) out = out (!ext[i] ? "f" : "0")
			printf "%s", out
		}' > "$SIL_TMP" 2>/dev/null || true
		if [[ $(wc -c < "$SIL_TMP") -ge 72720 ]]; then
			local tmp_awk="${awk_cache}.${UID:-0}.$$.tmp"
			if cp -f "$SIL_TMP" "$tmp_awk" 2>/dev/null; then
				chmod 644 "$tmp_awk" 2>/dev/null || true
				mv -f "$tmp_awk" "$awk_cache" 2>/dev/null || rm -f "$tmp_awk" 2>/dev/null || true
			fi
		fi
	fi
}

# === WALLUST CONFIG & COLOR CALIBRATION ===

sync_wallust_toml() {
	local target_pal="$1" need_toml=0
	[[ -f "$WALLUST_TOML" ]] || return 0
	grep -q "^[[:space:]]*palette *= *\"$target_pal\"" "$WALLUST_TOML" || need_toml=1
	if grep -q '^\[templates\.quickshell\]' "$WALLUST_TOML" && ! grep -q "target = \"$RAW_QS_JSON\"" "$WALLUST_TOML"; then
		need_toml=1
	fi
	if [[ "$need_toml" -eq 1 ]]; then
		sed -i -e "s|^[[:space:]]*palette *=.*|palette = \"$target_pal\"|" \
			-e "/^\[templates\.quickshell\]/,/^\[/{s|^[[:space:]]*target *=.*|target = \"$RAW_QS_JSON\"|}" "$WALLUST_TOML"
	fi
}

calibrate_and_apply_colors() {
	local theme="$1" wall="$2" mode="$3" bl="$4" an="$5" fr="$6" wframe="${7:-}" whash="${8:-}"
	mkdir -p "$QT6_DIR" "$QS_DIR"
	local src_json="$RAW_QS_JSON"
	[[ ! -f "$src_json" ]] && src_json="$QS_DIR/colors.json"
	[[ ! -f "$src_json" ]] && return 0

	init_cache_dirs
	[[ -z "$whash" && -f "$wall" ]] && whash=$(wall_hash "$wall")
	if [[ -z "$wframe" && -n "$whash" ]] && is_video_file "$wall"; then
		wframe=$(ensure_video_frame "$wall" "$whash")
	fi

	: > "$SIL_TMP"
	if [[ "$an" == "true" && -n "$whash" ]] && command -v quickshell >/dev/null 2>&1; then
		generate_silhouette "${wframe:-$wall}" "$whash"
	fi

	local qs_tmp="$QS_DIR/colors.json.tmp.$$" n_c4="" n_c0=""
	IFS=' ' read -r n_c4 n_c0 <<< "$(LC_ALL=C awk -F'"' \
		-v theme="$theme" -v wall="$wall" -v wframe="$wframe" -v mode="$mode" -v bl="$bl" -v an="$an" -v fr="$fr" -v sil_file="$SIL_TMP" \
		-v qs_out="$qs_tmp" -v qt_out="$QT6_DIR/wallust.conf" -v kitty_out="$KITTY_CONF" -v hypr_out="$HYPR_CONF" '
	function abs(v) { return v < 0 ? -v : v }
	function clamp(v, lo, hi) { return v < lo ? lo : (v > hi ? hi : v) }
	function hex2dec(h, i, v) {
		v = 0; h = tolower(h)
		for (i = 1; i <= length(h); i++) v = v * 16 + index("0123456789abcdef", substr(h, i, 1)) - 1
		return v
	}
	function rgb2hsl(hex, r, g, b, mx, mn, d, h, s, l) {
		gsub(/^#/, "", hex)
		r = hex2dec(substr(hex, 1, 2)) / 255.0; g = hex2dec(substr(hex, 3, 2)) / 255.0; b = hex2dec(substr(hex, 5, 2)) / 255.0
		mx = (r > g ? (r > b ? r : b) : (g > b ? g : b)); mn = (r < g ? (r < b ? r : b) : (g < b ? g : b))
		l = (mx + mn) / 2.0; d = mx - mn
		if (d < 0.0001) { h = 0; s = 0 }
		else {
			s = (l > 0.5) ? (d / (2.0 - mx - mn)) : (d / (mx + mn))
			h = (mx == r) ? ((g - b) / d + (g < b ? 6.0 : 0.0)) : ((mx == g) ? ((b - r) / d + 2.0) : ((r - g) / d + 4.0))
			h *= 60.0
		}
		H = h; S = s; L = l
	}
	function hue2rgb(p, q, t) {
		if (t < 0.0) t += 1.0; if (t > 1.0) t -= 1.0
		if (t < 1.0 / 6.0) return p + (q - p) * 6.0 * t
		if (t < 0.5) return q
		if (t < 2.0 / 3.0) return p + (q - p) * (2.0 / 3.0 - t) * 6.0
		return p
	}
	function hsl2hex(h, s, l, q, p, hk, r, g, b) {
		l = clamp(l, 0.0, 1.0); s = clamp(s, 0.0, 1.0)
		while (h < 0.0) h += 360.0; while (h >= 360.0) h -= 360.0
		if (s < 0.0001) { r = l; g = l; b = l }
		else {
			q = (l < 0.5) ? (l * (1.0 + s)) : (l + s - l * s); p = 2.0 * l - q; hk = h / 360.0
			r = hue2rgb(p, q, hk + 1.0 / 3.0); g = hue2rgb(p, q, hk); b = hue2rgb(p, q, hk - 1.0 / 3.0)
		}
		return sprintf("%02x%02x%02x", clamp(int(r * 255.0 + 0.5), 0, 255), clamp(int(g * 255.0 + 0.5), 0, 255), clamp(int(b * 255.0 + 0.5), 0, 255))
	}
	function hdist(h1, h2, d) { d = abs(h1 - h2) % 360.0; return d > 180.0 ? 360.0 - d : d }
	function qt_row(txt, hl) {
		return sprintf("#ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #ff%s, #80%s", txt, c0_hex, c0_hex, c0_hex, bg_hex, c0_hex, txt, txt, txt, bg_hex, c0_hex, bg_hex, hl, bg_hex, out_c[4], out_c[5], c0_hex, txt, c0_hex, txt, txt)
	}
	BEGIN {
		raw_bg = "1e1e2e"; raw_fg = "cdd6f4"; sil = ""
		if (sil_file != "") { getline sil < sil_file; close(sil_file) }
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
		for (i = 0; i < 16; i++) { rgb2hsl(raw_c[i]); ch[i] = H; cs[i] = S; cl[i] = L }

		b1 = 4; best_s1 = -1
		for (i = 0; i < 16; i++) {
			sc = cs[i] * (1.0 - 0.50 * abs(cl[i] - 0.52))
			if (cl[i] > 0.06 && cl[i] < 0.94 && sc > best_s1) { best_s1 = sc; b1 = i }
		}
		if (bg_s < 0.06 && cs[b1] > 0.08) { bg_h = ch[b1]; bg_s = clamp(cs[b1] * 0.6, 0.08, 0.22) }

		b2 = b1; best_s2 = -1
		for (i = 0; i < 16; i++) {
			if (i == b1 || cl[i] <= 0.06 || cl[i] >= 0.94) continue
			sc = cs[i] * (0.45 + 0.55 * (cs[i] >= 0.16 ? hdist(ch[i], ch[b1]) / 180.0 : 0.0))
			if (sc > best_s2) { best_s2 = sc; b2 = i }
		}
		if (cs[b2] < 0.10) b2 = b1

		b3 = b2; best_s3 = -1
		for (i = 0; i < 16; i++) {
			if (i == b1 || i == b2 || cl[i] <= 0.06 || cl[i] >= 0.94) continue
			sc = cs[i] * (0.45 + 0.55 * (cs[i] >= 0.16 ? (hdist(ch[i], ch[b1]) + hdist(ch[i], ch[b2])) / 360.0 : 0.0))
			if (sc > best_s3) { best_s3 = sc; b3 = i }
		}
		if (cs[b3] < 0.10) b3 = b1

		if (theme == "day") {
			surf_s = clamp(bg_s, 0.08, 0.26)
			bg_hex = hsl2hex(bg_h, surf_s, 0.85); c0_hex = hsl2hex(bg_h, surf_s, 0.78)
			fg_hex = hsl2hex(bg_h, clamp(bg_s, 0.06, 0.20), 0.12); c8_hex = hsl2hex(bg_h, clamp(bg_s, 0.06, 0.16), 0.36)
			c7_hex = hsl2hex(bg_h, clamp(bg_s, 0.06, 0.18), 0.24); c15_hex = hsl2hex(bg_h, clamp(bg_s, 0.05, 0.14), 0.10)
		} else {
			surf_s = clamp(bg_s, 0.08, 0.28); base_l = clamp(bg_l, 0.11, 0.16)
			bg_hex = hsl2hex(bg_h, surf_s, base_l); c0_hex = hsl2hex(bg_h, surf_s, base_l + 0.065)
			fg_hex = hsl2hex(bg_h, clamp(bg_s, 0.06, 0.18), 0.91); c8_hex = hsl2hex(bg_h, clamp(bg_s, 0.06, 0.16), 0.62)
			c7_hex = hsl2hex(bg_h, clamp(bg_s, 0.06, 0.16), 0.78); c15_hex = hsl2hex(bg_h, clamp(bg_s, 0.05, 0.14), 0.94)
		}

		ah[4] = ch[b1]; as[4] = cs[b1]; al[4] = cl[b1]
		ah[5] = ch[b2]; as[5] = cs[b2]; al[5] = cl[b2]
		ah[6] = ch[b3]; as[6] = cs[b3]; al[6] = cl[b3]
		for (k = 1; k <= 3; k++) {
			src = (cs[k] >= cs[k + 8]) ? k : (k + 8)
			pick = (cs[src] < 0.12) ? (k == 1 ? b2 : (k == 2 ? b3 : b1)) : src
			ah[k] = ch[pick]; as[k] = cs[pick]; al[k] = cl[src]
		}

		out_c[0] = c0_hex; out_c[7] = c7_hex; out_c[8] = c8_hex; out_c[15] = c15_hex
		min_s = clamp(cs[b1], 0.14, 0.32)
		for (k = 1; k <= 6; k++) {
			sat = clamp(as[k] * 1.12, min_s, 0.78)
			if (theme == "day") { l_norm = clamp(al[k], 0.28, 0.40); l_bold = clamp(l_norm - 0.05, 0.22, 0.34) }
			else { l_norm = clamp(al[k], 0.62, 0.74); l_bold = clamp(l_norm + 0.06, 0.68, 0.82) }
			out_c[k] = hsl2hex(ah[k], sat, l_norm); out_c[k + 8] = hsl2hex(ah[k], sat, l_bold)
		}

		printf "{\n\t\"wallpaper\": \"%s\",\n\t\"wallFrame\": \"%s\",\n\t\"silhouette\": \"%s\",\n\t\"wallMode\": \"%s\",\n\t\"uiBlur\": %s,\n\t\"uiAnimations\": %s,\n\t\"firstRunDone\": %s,\n\t\"background\": \"#%s\",\n\t\"foreground\": \"#%s\",\n", wall, wframe, sil, mode, bl, an, fr, bg_hex, fg_hex > qs_out
		for (i = 0; i < 16; i++) printf "\t\"color%d\": \"#%s\"%s\n", i, out_c[i], (i < 15 ? "," : "") >> qs_out
		printf "}\n" >> qs_out; close(qs_out)

		act = qt_row(fg_hex, out_c[4]); dis = qt_row(c8_hex, c8_hex)
		printf "[ColorScheme]\nactive_colors=%s\ndisabled_colors=%s\ninactive_colors=%s\n", act, dis, act > qt_out; close(qt_out)

		printf "foreground #%s\nbackground #%s\ncursor #%s\nselection_foreground #%s\nselection_background #%s\n", fg_hex, bg_hex, out_c[4], bg_hex, out_c[4] > kitty_out
		for (i = 0; i < 16; i++) printf "color%d #%s\n", i, out_c[i] >> kitty_out
		close(kitty_out)

		printf "$background = rgb(%s)\n$foreground = rgb(%s)\n$color0 = rgb(%s)\n$color4 = rgb(%s)\n$color5 = rgb(%s)\n$color6 = rgb(%s)\n", bg_hex, fg_hex, c0_hex, out_c[4], out_c[5], out_c[6] > hypr_out; close(hypr_out)
		printf "#%s #%s\n", out_c[4], out_c[0]
	}' "$src_json")"

	rm -f "$SIL_TMP" 2>/dev/null || true
	[[ -s "$qs_tmp" ]] && mv -f "$qs_tmp" "$QS_DIR/colors.json" || rm -f "$qs_tmp" 2>/dev/null || true

	if [[ -f "$HOME/.config/niri/config.kdl" && -n "$n_c4" && -n "$n_c0" ]]; then
		sed -i -e "s|active-color \"#[0-9a-fA-F]*\"|active-color \"$n_c4\"|g" \
			-e "s|inactive-color \"#[0-9a-fA-F]*\"|inactive-color \"$n_c0\"|g" "$HOME/.config/niri/config.kdl"
	fi

	local icon_thm="Papirus-Dark" dark_fp="true" fp_bg="30"
	[[ "$theme" == "day" ]] && { icon_thm="Papirus-Light"; dark_fp="false"; fp_bg="222"; }
	[[ -f "$HOME/.config/qt6ct/qt6ct.conf" ]] && sed -i "s|^icon_theme=.*|icon_theme=$icon_thm|" "$HOME/.config/qt6ct/qt6ct.conf"
	[[ -f "$HOME/.config/pcmanfm-qt/default/settings.conf" ]] && sed -i "s|^IconThemeName=.*|IconThemeName=$icon_thm|" "$HOME/.config/pcmanfm-qt/default/settings.conf"
	if [[ -f "$HOME/.config/featherpad/fp.conf" ]]; then
		sed -i -e "s|^darkColScheme=.*|darkColScheme=$dark_fp|" -e "s|^bgColValue=.*|bgColValue=$fp_bg|" "$HOME/.config/featherpad/fp.conf"
	fi
}

# === ENTRYPOINT: ONE-SHOT INIT OR AUTO-DETACH DAEMON ===

if [[ "${1:-}" == "--init-only" ]]; then
	shift
	trap 'rm -f "$SIL_TMP" 2>/dev/null || true' EXIT
	calibrate_and_apply_colors "${1:-night}" "${2:-}" "${3:-static}" "${4:-true}" "${5:-true}" "${6:-false}"
	exit $?
fi

if [[ "${1:-}" != "--daemon" ]]; then
	if command -v setsid >/dev/null 2>&1; then
		setsid -f "$0" --daemon "$@" </dev/null >/dev/null 2>&1
	else
		nohup "$0" --daemon "$@" </dev/null >/dev/null 2>&1 &
	fi
	exit 0
fi
shift

cleanup_daemon() {
	pkill -P $$ 2>/dev/null || true
	rm -f "$SIL_TMP" 2>/dev/null || true
	[[ -f "$PIDFILE" && "$(<"$PIDFILE")" == "$$" ]] && rm -f "$PIDFILE" 2>/dev/null || true
}
trap cleanup_daemon EXIT INT TERM

stop_previous_daemon
echo "$$" > "$PIDFILE"
init_cache_dirs

FORCED_MODE="${1:-}"
CURRENT_WALL=$(get_json_str wallpaper)
CURRENT_FRAME=$(get_json_str wallFrame)
CURRENT_THEME=""
LAST_MODE=$(get_json_str wallMode)
[[ -z "$LAST_MODE" ]] && LAST_MODE="static"
if [[ -n "$CURRENT_WALL" && -f "$CURRENT_WALL" ]]; then
	[[ "$CURRENT_WALL" == *"/day"* ]] && CURRENT_THEME="day"
	[[ "$CURRENT_WALL" == *"/night"* ]] && CURRENT_THEME="night"
else
	CURRENT_WALL=""
fi
LAST_ROTATE_TS=$SECONDS

# === THEME SWITCH LOOP ===

apply_theme() {
	local theme="$1" static_dir="$2" anim_dir="$3"
	local mode bl an fr
	mode=$(get_wall_mode)
	bl=$(get_json_bool uiBlur true)
	an=$(get_json_bool uiAnimations true)
	fr=$(get_json_bool firstRunDone false)
	FORCED_MODE=""

	local target_dir="$static_dir"
	[[ "$mode" == "animated" && -n "$(find_wallpapers "$anim_dir" | head -n1)" ]] && target_dir="$anim_dir"
	[[ -d "$target_dir" ]] || return 1

	local wall
	wall=$(find_wallpapers "$target_dir" "$CURRENT_WALL" | shuf -n 1)
	[[ -z "$wall" ]] && wall=$(find_wallpapers "$target_dir" | shuf -n 1)
	[[ -z "$wall" ]] && return 1

	local whash wframe=""
	whash=$(wall_hash "$wall")
	is_video_file "$wall" && wframe=$(ensure_video_frame "$wall" "$whash")

	if [[ "$CURRENT_WALL" == "$wall" && "$LAST_MODE" == "$mode" && "$CURRENT_THEME" == "$theme" ]]; then
		if ! is_video_file "$wall" || [[ -n "$wframe" && "$CURRENT_FRAME" == "$wframe" ]]; then
			return 0
		fi
	fi

	local wall_img="${wframe:-$wall}"
	if ! command -v quickshell >/dev/null 2>&1; then
		if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
			pgrep -u "$UID" -x hyprpaper >/dev/null || { hyprpaper </dev/null >/dev/null 2>&1 & sleep 1; }
			hyprctl hyprpaper preload "$wall_img" >/dev/null 2>&1 || return 1
			hyprctl hyprpaper wallpaper ",$wall_img" >/dev/null 2>&1 || return 1
		else
			pgrep -u "$UID" -x awww-daemon >/dev/null || { awww-daemon </dev/null >/dev/null 2>&1 & sleep 1; }
			awww img "$wall_img" --transition-type grow --transition-pos 0.5,0.5 >/dev/null 2>&1 || return 1
		fi
	fi

	local target_pal="$DAY_PALETTE"
	[[ "$theme" == "night" ]] && target_pal="$NIGHT_PALETTE"
	sync_wallust_toml "$target_pal"

	wallust run -s "$wall_img" </dev/null >/dev/null 2>&1
	calibrate_and_apply_colors "$theme" "$wall" "$mode" "$bl" "$an" "$fr" "$wframe" "$whash"

	pkill -u "$UID" -USR1 -x kitty 2>/dev/null || true
	if command -v quickshell >/dev/null 2>&1; then
		quickshell ipc call theme reload >/dev/null 2>&1 || true
	else
		if pgrep -u "$UID" -x waybar >/dev/null; then pkill -u "$UID" -USR2 -x waybar ; else waybar </dev/null >/dev/null 2>&1 & fi
		swaync-client -rs >/dev/null 2>&1 || true
	fi
	CURRENT_WALL="$wall"
	CURRENT_FRAME="$wframe"
	CURRENT_THEME="$theme"
	LAST_MODE="$mode"
	LAST_ROTATE_TS=$SECONDS
}

[[ -z "$FORCED_MODE" ]] && sleep 1
while true; do
	[[ -n "${WAYLAND_DISPLAY:-}" && ! -S "${XDG_RUNTIME_DIR:-/run/user/$UID}/$WAYLAND_DISPLAY" ]] && exit 0
	FORCE_ROTATE=0
	(( ROTATE_INTERVAL > 0 && (SECONDS - LAST_ROTATE_TS) >= ROTATE_INTERVAL )) && FORCE_ROTATE=1
	printf -v HOUR '%(%k)T' -1
	if (( HOUR >= DAY_START_HOUR && HOUR < NIGHT_START_HOUR )); then
		[[ "$CURRENT_THEME" != "day" || -n "$FORCED_MODE" || "$FORCE_ROTATE" -eq 1 ]] && apply_theme "day" "$DAY_DIR" "$DAY_ANIM_DIR"
	else
		[[ "$CURRENT_THEME" != "night" || -n "$FORCED_MODE" || "$FORCE_ROTATE" -eq 1 ]] && apply_theme "night" "$NIGHT_DIR" "$NIGHT_ANIM_DIR"
	fi
	sleep "$CHECK_INTERVAL"
done
