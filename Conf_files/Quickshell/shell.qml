import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray
import Quickshell.Services.Pam

ShellRoot {
	id: root

	property string homeDir: Quickshell.env("HOME")
	property bool isVM: Quickshell.env("QSG_RENDER_LOOP") === "basic"
	property bool isHyprland: Quickshell.env("XDG_CURRENT_DESKTOP") === "Hyprland"

	// Palette dinamica Wallust (~/.config/quickshell/colors.json)
	property string wallpaperPath: ""
	property color bg: "#1e1e2e"
	property color fg: "#cdd6f4"
	property color color0: "#1e1e2e"
	property color color1: "#f38ba8"
	property color color2: "#a6e3a1"
	property color color3: "#f9e2af"
	property color color4: "#89b4fa"
	property color color5: "#cba6f7"
	property color color6: "#94e2d5"
	property color color8: "#585b70"

	// Stato Globale UI: "none" | "calendar" | "system" | "launcher"
	property bool barVisible: true
	property string centerMode: "none"
	// Sottomenu: "" | "net" | "bt" | "tray" | "battery" | "rec" | "display" | "sound" | "mic" | "cpu" | "power"
	property string sysSubmenu: ""
	property bool screenLocked: false
	property bool wsExpanded: false
	property int lastActiveWs: 1

	// App Launcher integrato nella pillola
	property string searchQuery: ""
	property int selectedAppIndex: 0
	property var filteredApps: {
		let all = DesktopEntries.applications.values, q = searchQuery.toLowerCase().trim(), res = []
		for (let i = 0; i < all.length; i++) {
			let a = all[i]
			if (q === "" || (a.name && a.name.toLowerCase().includes(q)) || (a.genericName && a.genericName.toLowerCase().includes(q))) res.push(a)
		}
		return res
	}

	// Orologio, Calendario e Meteo
	property string timeStr: ""
	property string dateStr: ""
	property string fullDateStr: ""
	property string weatherShort: "󰖕 --°C"
	property string weatherDetail: "Fetching weather..."
	property int calMonth: (new Date()).getMonth()
	property int calYear: (new Date()).getFullYear()
	property var calendarDays: []

	// Stato Audio/Luminosità reattivo e OSD Destro
	property string osdMode: "volume"
	property int brightnessPct: 100
	property int lastBrightnessPct: -1
	property int outVolPct: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) ? Math.round(Pipewire.defaultAudioSink.audio.volume * 100) : 0
	property bool outMuted: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) ? Pipewire.defaultAudioSink.audio.muted : false
	property int micVolPct: (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) ? Math.round(Pipewire.defaultAudioSource.audio.volume * 100) : 0
	property bool micMuted: (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) ? Pipewire.defaultAudioSource.audio.muted : false
	property int lastMicVol: -1
	property bool lastMicMuted: false
	property bool isHeadphones: false
	property bool isHeadsetMic: false

	// Stato Rete (Ethernet + Wi-Fi) e Bluetooth
	property string ethIface: ""
	property bool ethConnected: false
	property string ethIp: "Disconnected"
	property bool hasWifiHw: false
	property bool wifiEnabled: true
	property string netName: "Offline"
	property var netList: []
	property var savedWifiList: []
	property string wifiPromptSsid: ""
	property bool hasBtAdapter: false
	property bool btEnabled: false
	property string btName: "No Adapter"
	property var btList: []

	// Dispositivi Audio, Monitor/Display e Night Light (wlsunset)
	property var audioSinks: []
	property var audioSources: []
	property var monitorsList: []
	property string expandedResMon: ""
	property bool nightLightOn: false
	property int nightLightTemp: 4000

	// Batteria, Registrazione Schermo e System Info
	property int batPct: (UPower.displayDevice && UPower.displayDevice.isLaptopBattery) ? Math.round(UPower.displayDevice.percentage * 100) : 100
	property bool batCharging: UPower.displayDevice && UPower.displayDevice.state === UPowerDeviceState.Charging
	property string batHealth: "100%"
	property string batPowerDraw: "0.0 W"
	property string batCycles: "0"
	property string batTech: "Li-ion"
	property bool isRecording: false
	property int recSeconds: 0
	property bool recSysAudio: true
	property bool recMicAudio: false
	property bool recAreaSelect: false
	property string cpuModel: "Processor"
	property int cpuUsage: 0
	property int cpuTemp: 40
	property string ramInfo: "0 / 0 GiB (0%)"
	property int ramPct: 0
	property string diskRootInfo: "0 / 0 GiB (0%)"
	property int diskRootPct: 0
	property string diskSecInfo: "Not mounted"
	property string kernelVer: "Linux"
	property string uptimeStr: "0m"
	property var workspacesList: [{ "idx": 1, "active": true, "occupied": true }]
	property var popupNotifications: []

	property var activePlayer: {
		let list = Mpris.players.values
		if (!list || list.length === 0) return null
		for (let i = 0; i < list.length; i++) if (list[i].playbackState === MprisPlaybackState.Playing) return list[i]
		return list[0]
	}

	function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
	function runCmd(cmd) { Quickshell.execDetached(["bash", "-c", cmd]) }
	function formatSec(s) {
		let sec = Math.max(0, Math.floor(s || 0)), m = Math.floor(sec / 60), r = sec % 60
		return m + ":" + (r < 10 ? "0" + r : r)
	}
	function closeCenterPill() {
		root.centerMode = "none"
		root.sysSubmenu = ""
		root.wifiPromptSsid = ""
		root.expandedResMon = ""
	}
	function openLauncher() {
		if (root.centerMode === "launcher") root.closeCenterPill()
		else {
			root.searchQuery = ""
			root.selectedAppIndex = 0
			root.sysSubmenu = ""
			root.wifiPromptSsid = ""
			root.centerMode = "launcher"
			focusTimer.restart()
		}
	}
	function openCalendar() {
		root.calMonth = (new Date()).getMonth()
		root.calYear = (new Date()).getFullYear()
		root.updateCalendar()
		root.sysSubmenu = ""
		root.wifiPromptSsid = ""
		root.centerMode = "calendar"
	}
	function openSystemPanel() {
		root.sysSubmenu = ""
		root.wifiPromptSsid = ""
		root.centerMode = "system"
		sysPoll.running = true
		subPoll.running = true
	}
	function triggerOsd(mode) { root.osdMode = mode; osdTimer.restart() }
	function triggerLock() { root.closeCenterPill(); root.screenLocked = true }

	function togglePrimaryNetwork() {
		if (root.ethIface !== "" && (!root.hasWifiHw || root.ethConnected)) {
			runCmd("nmcli dev " + (root.ethConnected ? "disconnect " : "connect ") + root.ethIface)
		} else if (root.hasWifiHw) {
			runCmd("nmcli radio wifi " + (root.wifiEnabled ? "off" : "on"))
		}
		sysPoll.running = true
	}

	function applyNightLight() {
		if (root.nightLightOn) {
			runCmd("pkill -x wlsunset 2>/dev/null; wlsunset -t " + root.nightLightTemp + " -T " + (root.nightLightTemp + 1) + " &")
		} else {
			runCmd("pkill -x wlsunset 2>/dev/null")
		}
	}

	function toggleRecording() {
		if (root.isRecording) {
			runCmd("pkill -INT -x wf-recorder; notify-send 'Screen Recorder' 'Saved in ~/Videos/Recordings'")
			root.isRecording = false; root.recSeconds = 0
		} else {
			let f = root.homeDir + "/Videos/Recordings/rec-" + Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss") + ".mp4"
			let sinkName = (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.name) ? (Pipewire.defaultAudioSink.name + ".monitor") : ""
			let aFlag = root.recMicAudio ? "-a" : ((root.recSysAudio && sinkName !== "") ? ("-a=\"" + sinkName + "\"") : "")
			if (root.recAreaSelect) { root.closeCenterPill(); runCmd("g=$(slurp) || exit 0; wf-recorder -g \"$g\" " + aFlag + " -f \"" + f + "\"") }
			else runCmd("wf-recorder " + aFlag + " -f \"" + f + "\"")
			root.isRecording = true; root.recSeconds = 0
		}
	}

	function updateCalendar() {
		let startDow = (new Date(root.calYear, root.calMonth, 1).getDay() + 6) % 7
		let daysInMonth = new Date(root.calYear, root.calMonth + 1, 0).getDate()
		let now = new Date(), arr = []
		for (let i = 0; i < startDow; i++) arr.push({ "day": "", "today": false })
		for (let d = 1; d <= daysInMonth; d++)
			arr.push({ "day": d.toString(), "today": (d === now.getDate() && root.calMonth === now.getMonth() && root.calYear === now.getFullYear()) })
		root.calendarDays = arr
	}

	Component.onCompleted: updateCalendar()

	FileView {
		id: colorFile
		path: root.homeDir + "/.config/quickshell/colors.json"
		blockLoading: true; watchChanges: true
		onFileChanged: reload()
		onLoaded: {
			try {
				let d = JSON.parse(text())
				if (d.wallpaper) root.wallpaperPath = d.wallpaper
				if (d.background) root.bg = d.background
				if (d.foreground) root.fg = d.foreground
				if (d.color0) root.color0 = d.color0
				if (d.color1) root.color1 = d.color1
				if (d.color2) root.color2 = d.color2
				if (d.color3) root.color3 = d.color3
				if (d.color4) root.color4 = d.color4
				if (d.color5) root.color5 = d.color5
				if (d.color6) root.color6 = d.color6
				if (d.color8) root.color8 = d.color8
			} catch (e) {}
		}
	}

	PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

	Connections {
		target: (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) ? Pipewire.defaultAudioSource.audio : null
		function onVolumeChanged() {
			if (root.lastMicVol !== -1 && root.micVolPct !== root.lastMicVol) root.triggerOsd("mic")
			root.lastMicVol = root.micVolPct
		}
		function onMutedChanged() {
			if (root.micMuted !== root.lastMicMuted) root.triggerOsd("mic")
			root.lastMicMuted = root.micMuted
		}
	}

	Timer { id: osdTimer; interval: 2000; onTriggered: root.osdMode = "volume" }
	Timer { id: wsCollapseTimer; interval: 1000; onTriggered: root.wsExpanded = false }
	Timer { id: autoCloseTimer; interval: 4500; onTriggered: { if (root.centerMode !== "none" && root.wifiPromptSsid === "") root.closeCenterPill() } }
	Timer { id: popupTimer; interval: 5000; onTriggered: root.popupNotifications = [] }
	Timer {
		id: focusTimer
		interval: 40
		repeat: false
		onTriggered: {
			if (root.centerMode === "launcher") {
				launcherSearchInput.text = ""
				launcherSearchInput.forceActiveFocus()
			} else if (root.wifiPromptSsid !== "") {
				wifiPwField.forceActiveFocus()
			}
		}
	}

	NotificationServer {
		id: notifServer
		onNotification: function(n) {
			n.tracked = true
			let arr = root.popupNotifications.slice()
			arr.unshift(n); if (arr.length > 4) arr.pop()
			root.popupNotifications = arr; popupTimer.restart()
		}
	}

	IpcHandler { target: "launcher"; function toggle(): void { root.openLauncher() } }
	IpcHandler { target: "controlcenter"; function toggle(): void { if (root.centerMode === "system") root.closeCenterPill(); else root.openSystemPanel() } }
	IpcHandler { target: "lock"; function lock(): void { root.triggerLock() } }
	IpcHandler { target: "theme"; function reload(): void { colorFile.reload() } }
	IpcHandler { target: "bar"; function toggle(): void { root.barVisible = !root.barVisible } }

	Process {
		id: fastPoll
		command: ["bash", "-c", "
			b=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%' || echo 100)
			if [[ -n \"$NIRI_SOCKET\" ]]; then
				ws=$(niri msg -j workspaces 2>/dev/null | awk 'BEGIN{RS=\"}\";ORS=\"\"}/\"idx\":/{match($0,/\"idx\":[0-9]+/);idx=substr($0,RSTART+6,RLENGTH-6);act=($0~/\"is_active\":true/)?\"1\":\"0\";occ=($0~/\"active_window_id\":null/)?\"0\":\"1\";print idx\":\"act\":\"occ\" \"}')
			elif [[ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ]]; then
				act=$(hyprctl activeworkspace -j 2>/dev/null | awk -F': ' '/\"id\":/{gsub(/,/,\"\",$2);print $2;exit}')
				occ_l=$(hyprctl workspaces -j 2>/dev/null | awk 'BEGIN{RS=\"}\"}/\"windows\": *[1-9]/{match($0,/\"id\": *[0-9]+/);print substr($0,RSTART+5,RLENGTH-5)}')
				ws=\"\"; for i in 1 2 3 4 5; do a=0; [[ \"$i\" == \"$act\" ]] && a=1; o=0; echo \"$occ_l\" | grep -qx \"$i\" && o=1; ws+=\"$i:$a:$o \"; done
			fi
			printf '%s|%s\n' \"${b:-100}\" \"$ws\"
		"]
		stdout: SplitParser {
			onRead: data => {
				let p = data.trim().split("|")
				if (p.length < 2) return
				let b = parseInt(p[0]) || 100
				if (root.lastBrightnessPct !== -1 && b !== root.lastBrightnessPct) root.triggerOsd("brightness")
				root.brightnessPct = b; root.lastBrightnessPct = b
				let items = p[1].trim().split(/\s+/), list = [], cur = root.lastActiveWs
				for (let i = 0; i < items.length; i++) {
					let kv = items[i].split(":")
					if (kv.length === 3) {
						let idx = parseInt(kv[0]), act = kv[1] === "1", occ = kv[2] === "1" || act
						if (act) cur = idx
						list.push({ "idx": idx, "active": act, "occupied": occ })
					}
				}
				if (list.length > 0) {
					list.sort((a, b) => a.idx - b.idx); root.workspacesList = list
					if (cur !== root.lastActiveWs) { root.lastActiveWs = cur; root.wsExpanded = true; wsCollapseTimer.restart() }
				}
			}
		}
	}

	Process {
		id: sysPoll
		command: ["bash", "-c", "
			t=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 40000)
			eth_line=$(nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev 2>/dev/null | awk -F: '$2==\"ethernet\"{print $0; exit}')
			IFS=':' read -r e_dev _ e_st e_con <<< \"$eth_line\"
			e_on=0; e_ip=\"Disconnected\"
			if [[ \"$e_st\" == \"connected\" ]]; then
				e_on=1
				e_ip=$(ip -4 -o addr show dev \"$e_dev\" 2>/dev/null | awk '{print $4}' | head -n1)
				[[ -z \"$e_ip\" ]] && e_ip=\"Connected\"
			fi
			w_hw=0; nmcli -t -f TYPE dev 2>/dev/null | grep -qx 'wifi' && w_hw=1
			w_rad=$(nmcli radio wifi 2>/dev/null)
			w_con=$(nmcli -t -f TYPE,STATE,CONNECTION dev 2>/dev/null | awk -F: '$1==\"wifi\" && $2==\"connected\"{print $3; exit}')
			if [[ -n \"$w_con\" ]]; then net=\"$w_con\"
			elif [[ \"$e_on\" -eq 1 ]]; then net=\"Ethernet\"
			else net=\"Offline\"; fi
			bt_line=$(bluetoothctl list 2>/dev/null | grep '^Controller' | head -n1)
			if [[ -z \"$bt_line\" ]]; then
				bt_hw=0; bt_en=0; bt_name=\"No Adapter\"
			else
				bt_hw=1
				if rfkill list bluetooth 2>/dev/null | grep -q 'Soft blocked: yes' || ! bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then
					bt_en=0; bt_name=\"Off\"
				else
					bt_en=1
					bt_c=$(bluetoothctl info 2>/dev/null | awk -F': ' '/Name:/{print $2; exit}')
					bt_name=\"${bt_c:-On}\"
				fi
			fi
			hp=0; hmic=0
			[[ \"$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | tr '[:upper:]' '[:lower:]')\" =~ (headphone|headset|bluez|earphone|buds) ]] && hp=1
			[[ \"$(wpctl inspect @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | tr '[:upper:]' '[:lower:]')\" =~ (headset|bluez|buds|headphone) ]] && hmic=1
			cpu_m=$(awk -F': ' '/model name/{print $2; exit}' /proc/cpuinfo)
			cpu_u=$(awk '/^cpu /{u=$2+$4; t=$2+$4+$5; if(t>0) printf \"%d\", (u*100)/t; else print 0}' /proc/stat)
			ram_s=$(free -m | awk '/^Mem:/{printf \"%.1f / %.1f GiB|%d\", $3/1024, $2/1024, ($3*100)/$2}')
			d_root=$(df -h / | awk 'NR==2{gsub(/%/,\"\",$5); printf \"%s / %s (%s%%)|%d\", $3, $2, $5, $5}')
			d_sec=$(df -h | awk '$6 ~ /^\\/media\\//{printf \"%s: %s / %s (%s)\", $6, $3, $2, $5; exit}')
			bat_d=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1)
			if [[ -n \"$bat_d\" ]]; then
				ef=$(cat \"$bat_d/energy_full\" 2>/dev/null || cat \"$bat_d/charge_full\" 2>/dev/null || echo 100)
				efd=$(cat \"$bat_d/energy_full_design\" 2>/dev/null || cat \"$bat_d/charge_full_design\" 2>/dev/null || echo 100)
				b_h=\"$(( ef * 100 / (efd > 0 ? efd : 100) ))%\"
				b_p=$(awk -v p=\"$(cat \"$bat_d/power_now\" 2>/dev/null || echo 0)\" 'BEGIN{printf \"%.1f W\", p/1000000}')
				b_c=$(cat \"$bat_d/cycle_count\" 2>/dev/null || echo 0); b_t=$(cat \"$bat_d/technology\" 2>/dev/null || echo \"Li-ion\")
			else b_h=\"AC Power\"; b_p=\"0.0 W\"; b_c=\"N/A\"; b_t=\"Virtual / AC\"; fi
			printf '%d|%s|%d|%s|%d|%s|%s|%d|%d|%s|%d|%d|%s|%d|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \"$((t/1000))\" \"${e_dev:-}\" \"$e_on\" \"$e_ip\" \"$w_hw\" \"${w_rad:-disabled}\" \"$net\" \"$bt_hw\" \"$bt_en\" \"$bt_name\" \"$hp\" \"$hmic\" \"${cpu_m:-CPU}\" \"${cpu_u:-10}\" \"$ram_s\" \"$d_root\" \"${d_sec:-No secondary drive}\" \"$(uname -r)\" \"$(uptime -p 2>/dev/null | sed 's/^up //')\" \"$b_h\" \"$b_p\" \"$b_c\" \"$b_t\"
		"]
		stdout: SplitParser {
			onRead: data => {
				let p = data.trim().split("|")
				if (p.length >= 25) {
					root.cpuTemp = parseInt(p[0]) || 40
					root.ethIface = p[1]
					root.ethConnected = (p[2] === "1")
					root.ethIp = p[3]
					root.hasWifiHw = (p[4] === "1")
					root.wifiEnabled = (p[5] === "enabled") && root.hasWifiHw
					root.netName = p[6]
					root.hasBtAdapter = (p[7] === "1")
					root.btEnabled = (p[8] === "1")
					root.btName = p[9]
					root.isHeadphones = (p[10] === "1")
					root.isHeadsetMic = (p[11] === "1")
					root.cpuModel = p[12]
					root.cpuUsage = parseInt(p[13]) || 0
					root.ramInfo = p[14] + " (" + p[15] + "%)"
					root.ramPct = parseInt(p[15]) || 0
					root.diskRootInfo = p[16]
					root.diskRootPct = parseInt(p[17]) || 0
					root.diskSecInfo = p[18]
					root.kernelVer = p[19]
					root.uptimeStr = p[20]
					root.batHealth = p[21]
					root.batPowerDraw = p[22]
					root.batCycles = p[23]
					root.batTech = p[24]
				}
			}
		}
	}

	Process {
		id: subPoll
		command: ["bash", "-c", "
			nets=$(nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID dev wifi list --rescan no 2>/dev/null | head -n 12 | awk -F: 'length($4)>0 {printf \"%s^%s^%s^%s;\", ($1==\"*\"?\"1\":\"0\"), $2, $3, $4}')
			saved=$(nmcli -t -f NAME,TYPE connection show 2>/dev/null | awk -F: '$2==\"802-11-wireless\"{printf \"%s;\", $1}')
			bts=\"\"
			if bluetoothctl list 2>/dev/null | grep -q '^Controller'; then
				bts=$(bluetoothctl devices 2>/dev/null | grep -E '^Device ([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | head -n 12 | while read -r _ mac name; do
					con=0; bluetoothctl info \"$mac\" 2>/dev/null | grep -q 'Connected: yes' && con=1
					printf '%s^%s^%d;' \"$mac\" \"$name\" \"$con\"
				done)
			fi
			sinks=$(wpctl status 2>/dev/null | awk '/Sinks:/,/Sources:/' | grep -E '[0-9]+\\.' | sed 's/│//g; s/^[[:space:]]*//' | while read -r l; do act=0; [[ \"$l\" == \\** ]] && act=1; c=$(echo \"$l\" | sed 's/^\\*[[:space:]]*//'); id=${c%%.*}; r=${c#*. }; printf '%s^%s^%d;' \"$id\" \"${r%% \\[vol*}\" \"$act\"; done)
			srcs=$(wpctl status 2>/dev/null | awk '/Sources:/,/Filters:|Streams:/' | grep -E '[0-9]+\\.' | sed 's/│//g; s/^[[:space:]]*//' | while read -r l; do act=0; [[ \"$l\" == \\** ]] && act=1; c=$(echo \"$l\" | sed 's/^\\*[[:space:]]*//'); id=${c%%.*}; r=${c#*. }; printf '%s^%s^%d;' \"$id\" \"${r%% \\[vol*}\" \"$act\"; done)
			if [[ -n \"$NIRI_SOCKET\" ]]; then
				disp=$(niri msg outputs 2>/dev/null | awk '
				/^Output / {
					if (name != \"\") printf \"%s^%s^%s^%s;\", name, cur, scale, modes
					match($0, /\\([^)]+\\)/)
					name = substr($0, RSTART+1, RLENGTH-2)
					cur = \"1920x1080@60\"; scale = \"1.0\"; modes = \"\"; mcount = 0
				}
				/\\(current\\)/ {
					m = $1; sub(/\\..*@/, \"@\", m)
					cur = m
					if (mcount < 8) { modes = modes (modes==\"\"?\"\":\",\") m; mcount++ }
				}
				/^[[:space:]]+[0-9]+x[0-9]+@/ && !/\\(current\\)/ {
					if (mcount < 8) {
						m = $1; sub(/\\..*@/, \"@\", m)
						if (index(modes, m) == 0) { modes = modes (modes==\"\"?\"\":\",\") m; mcount++ }
					}
				}
				/Scale:/ { scale = $2 }
				END { if (name != \"\") printf \"%s^%s^%s^%s;\", name, cur, scale, modes }')
			elif [[ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ]]; then
				disp=$(hyprctl monitors 2>/dev/null | awk '
				/^Monitor / {
					if (name != \"\") printf \"%s^%s^%s^%s;\", name, cur, scale, modes
					name = $2; cur = \"1920x1080@60\"; scale = \"1.0\"; modes = \"\"
				}
				/^[[:space:]]+[0-9]+x[0-9]+@/ {
					m = $1; sub(/\\..*$/, \"\", m); cur = m
				}
				/^[[:space:]]+scale:/ { scale = $2 }
				/availableModes:/ {
					for (i=2; i<=NF && i<=9; i++) {
						m = $i; sub(/\\..*Hz/, \"\", m); sub(/Hz/, \"\", m)
						modes = modes (modes==\"\"?\"\":\",\") m
					}
				}
				END { if (name != \"\") printf \"%s^%s^%s^%s;\", name, cur, scale, modes }')
			fi
			printf 'NET:%s\nSAVED:%s\nBT:%s\nSINK:%s\nSRC:%s\nDISP:%s\n' \"$nets\" \"$saved\" \"$bts\" \"$sinks\" \"$srcs\" \"$disp\"
		"]
		stdout: SplitParser {
			onRead: data => {
				let l = data.trim()
				if (l.startsWith("NET:")) {
					let r = l.substring(4).split(";"), a = []
					for (let i = 0; i < r.length; i++) { let f = r[i].split("^"); if (f.length >= 4) a.push({ "connected": f[0] === "1", "signal": f[1], "sec": f[2], "ssid": f[3] }) }
					root.netList = a
				} else if (l.startsWith("SAVED:")) {
					root.savedWifiList = l.substring(6).split(";").filter(x => x.trim() !== "")
				} else if (l.startsWith("BT:")) {
					let r = l.substring(3).split(";"), a = []
					for (let i = 0; i < r.length; i++) { let f = r[i].split("^"); if (f.length >= 3) a.push({ "mac": f[0], "name": f[1], "connected": f[2] === "1" }) }
					root.btList = a
				} else if (l.startsWith("SINK:") || l.startsWith("SRC:")) {
					let isSink = l.startsWith("SINK:"), r = l.substring(isSink ? 5 : 4).split(";"), a = []
					for (let i = 0; i < r.length; i++) { let f = r[i].split("^"); if (f.length >= 3) a.push({ "id": f[0], "name": f[1], "active": f[2] === "1" }) }
					if (isSink) root.audioSinks = a; else root.audioSources = a
				} else if (l.startsWith("DISP:")) {
					let r = l.substring(5).split(";"), a = []
					for (let i = 0; i < r.length; i++) {
						let f = r[i].split("^")
						if (f.length >= 4 && f[0] !== "") {
							let mArr = f[3].split(",").filter(x => x !== "")
							if (mArr.length === 0) mArr = [f[1]]
							a.push({ "name": f[0], "curMode": f[1], "scale": f[2], "modes": mArr })
						}
					}
					root.monitorsList = a
				}
			}
		}
	}

	Process {
		id: weatherProc
		command: ["bash", "-c", "
			raw=$(curl -s --max-time 5 'wttr.in/?format=%C~%t~%f~%w~%h' || true)
			IFS='~' read -r cond temp feels wind hum <<< \"$raw\"
			[[ -z \"$temp\" || \"$raw\" == *Unknown* ]] && exit 0
			lc=\"${cond,,}\"; icon=\"󰖕\"
			if [[ \"$lc\" =~ (sun|clear) ]]; then icon=\"󰖙\"
			elif [[ \"$lc\" =~ (partly) ]]; then icon=\"󰖕\"
			elif [[ \"$lc\" =~ (cloud|overcast) ]]; then icon=\"󰖐\"
			elif [[ \"$lc\" =~ (rain|drizzle|shower) ]]; then icon=\"󰖗\"
			elif [[ \"$lc\" =~ (thunder|storm) ]]; then icon=\"󰖓\"
			elif [[ \"$lc\" =~ (snow|sleet|ice|blizzard) ]]; then icon=\"󰖘\"
			elif [[ \"$lc\" =~ (fog|mist|haze) ]]; then icon=\"󰖑\"; fi
			printf '%s %s|%s • Temp: %s (Feels %s) • Wind: %s • Hum: %s\n' \"$icon\" \"$temp\" \"$cond\" \"$temp\" \"$feels\" \"$wind\" \"$hum\"
		"]
		stdout: SplitParser {
			onRead: data => {
				let p = data.trim().split("|")
				if (p.length >= 2 && p[0] !== "") { root.weatherShort = p[0]; root.weatherDetail = p[1] }
			}
		}
	}

	Timer { interval: 300; running: true; repeat: true; onTriggered: fastPoll.running = true }
	Timer { interval: 1800000; running: true; repeat: true; triggeredOnStart: true; onTriggered: weatherProc.running = true }
	Timer {
		interval: 1000; running: true; repeat: true; triggeredOnStart: true
		property int tick: 0
		onTriggered: {
			let now = new Date()
			root.timeStr = Qt.formatDateTime(now, "HH:mm")
			root.dateStr = Qt.formatDateTime(now, "dd MMM")
			root.fullDateStr = Qt.formatDateTime(now, "ddd, MMM dd")
			if (root.isRecording) root.recSeconds++
			if (tick % 3 === 0) sysPoll.running = true
			if (tick % 10 === 0 && root.weatherShort.includes("--")) weatherProc.running = true
			if (tick % 4 === 0 && root.centerMode === "system" && root.sysSubmenu !== "") subPoll.running = true
			tick = (tick + 1) % 3600
		}
	}

	// 1. SFONDO DESKTOP NATIVO
	Variants {
		model: Quickshell.screens
		PanelWindow {
			required property var modelData
			screen: modelData
			WlrLayershell.layer: WlrLayer.Background
			WlrLayershell.namespace: "wallpaper"
			WlrLayershell.exclusionMode: ExclusionMode.Ignore
			anchors { top: true; bottom: true; left: true; right: true }
			color: root.bg
			Image { anchors.fill: parent; source: root.wallpaperPath !== "" ? "file://" + root.wallpaperPath : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true }
		}
	}

	// 2. FERMO FISSO INVISIBILE DA 46px (Impedisce alle finestre di salire sotto i pallini o muoversi in hover)
	Variants {
		model: Quickshell.screens
		PanelWindow {
			required property var modelData
			screen: modelData
			visible: root.barVisible
			WlrLayershell.layer: WlrLayer.Top
			WlrLayershell.namespace: "waybar-spacer"
			WlrLayershell.exclusionMode: ExclusionMode.Normal
			exclusiveZone: 46
			anchors { top: true; left: true; right: true }
			implicitHeight: 46
			color: "transparent"
		}
	}

	// 3. STRATO CLICK-OUTSIDE (Sotto all'isola quando aperta)
	Variants {
		model: Quickshell.screens
		PanelWindow {
			required property var modelData
			screen: modelData
			visible: root.centerMode !== "none"
			WlrLayershell.layer: WlrLayer.Top
			WlrLayershell.namespace: "qs-backdrop"
			WlrLayershell.exclusionMode: ExclusionMode.Ignore
			anchors { top: true; bottom: true; left: true; right: true }
			color: "transparent"
			MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton; onClicked: root.closeCenterPill() }
		}
	}

	// 4. DYNAMIC ISLAND TOP BAR
	Variants {
		model: Quickshell.screens
		PanelWindow {
			required property var modelData
			screen: modelData
			visible: root.barVisible
			WlrLayershell.layer: (root.centerMode === "none" && !centerPill.isHoverPreview && !mediaPill.expanded) ? WlrLayer.Top : WlrLayer.Overlay
			WlrLayershell.namespace: "waybar"
			WlrLayershell.exclusionMode: ExclusionMode.Ignore
			WlrLayershell.keyboardFocus: (root.centerMode === "launcher" || root.wifiPromptSsid !== "") ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
			anchors { top: true }
			margins.top: 8
			implicitWidth: islandRow.implicitWidth + 16
			implicitHeight: islandRow.implicitHeight + 8
			color: "transparent"

			RowLayout {
				id: islandRow
				anchors.top: parent.top
				anchors.horizontalCenter: parent.horizontalCenter
				spacing: 10

				// A. PALLINO / CARD MEDIA (Estrema Sinistra)
				Rectangle {
					id: mediaPill
					visible: root.activePlayer !== null
					Layout.alignment: Qt.AlignTop
					property bool expanded: mediaHover.hovered
					implicitWidth: expanded ? 330 : 38
					implicitHeight: expanded ? 150 : 38
					radius: expanded ? 22 : 19
					color: root.withAlpha(root.bg, root.isVM ? 0.96 : 0.85)
					border.width: expanded ? 2 : 1
					border.color: expanded ? root.color4 : root.withAlpha(root.color4, 0.6)
					clip: true
					Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
					Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
					HoverHandler { id: mediaHover }

					Rectangle {
						anchors.centerIn: parent; visible: !mediaPill.expanded; width: 26; height: 26; radius: 8; color: root.color0; clip: true
						Image { anchors.fill: parent; source: (root.activePlayer && root.activePlayer.trackArtUrl) ? root.activePlayer.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; visible: source != "" }
						Text { anchors.centerIn: parent; visible: !root.activePlayer || !root.activePlayer.trackArtUrl; text: "󰝚"; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
					}

					ColumnLayout {
						anchors.fill: parent; anchors.margins: 14; visible: mediaPill.expanded; spacing: 8
						RowLayout {
							Layout.fillWidth: true; spacing: 12
							Rectangle {
								implicitWidth: 64; implicitHeight: 64; radius: 12; color: root.color0; clip: true
								Image { anchors.fill: parent; source: (root.activePlayer && root.activePlayer.trackArtUrl) ? root.activePlayer.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop }
								Text { anchors.centerIn: parent; visible: !root.activePlayer || !root.activePlayer.trackArtUrl; text: "󰝚"; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 26 }
							}
							ColumnLayout {
								Layout.fillWidth: true; spacing: 2
								Text { text: (root.activePlayer && root.activePlayer.trackTitle) ? root.activePlayer.trackTitle : "Media Playing"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
								Text { text: (root.activePlayer && root.activePlayer.trackArtist) ? root.activePlayer.trackArtist : "Unknown Artist"; color: root.withAlpha(root.fg, 0.8); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
								Text { text: (root.activePlayer && root.activePlayer.identity) ? root.activePlayer.identity : "Player"; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
							}
						}
						ColumnLayout {
							Layout.fillWidth: true; spacing: 3
							Rectangle {
								Layout.fillWidth: true; implicitHeight: 5; radius: 3; color: Qt.rgba(1, 1, 1, 0.15)
								property real prog: (root.activePlayer && root.activePlayer.length > 0) ? Math.min(1, root.activePlayer.position / root.activePlayer.length) : 0.25
								Rectangle { width: parent.width * parent.prog; height: parent.height; radius: 3; color: root.color6 }
							}
							RowLayout {
								Layout.fillWidth: true
								Text { text: root.activePlayer ? root.formatSec(root.activePlayer.position) : "0:00"; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 }
								Item { Layout.fillWidth: true }
								Text { text: (root.activePlayer && root.activePlayer.length > 0) ? root.formatSec(root.activePlayer.length) : ""; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 }
							}
						}
						RowLayout {
							Layout.alignment: Qt.AlignHCenter; spacing: 22
							Text { text: "󰒮"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18; MouseArea { anchors.fill: parent; onClicked: { if (root.activePlayer) root.activePlayer.previous() } } }
							Rectangle {
								implicitWidth: 32; implicitHeight: 32; radius: 16; color: Qt.rgba(1, 1, 1, 0.15)
								Text { anchors.centerIn: parent; text: (root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing) ? "󰏤" : "󰐊"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16 }
								MouseArea { anchors.fill: parent; onClicked: { if (root.activePlayer) root.activePlayer.togglePlaying() } }
							}
							Text { text: "󰒭"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18; MouseArea { anchors.fill: parent; onClicked: { if (root.activePlayer) root.activePlayer.next() } } }
						}
					}
				}

				// B. PALLINO / PILLOLA WORKSPACES
				Rectangle {
					id: wsPill
					Layout.alignment: Qt.AlignTop
					property bool showAll: root.wsExpanded || wsHover.hovered
					implicitWidth: showAll ? (wsRow.implicitWidth + 16) : 38
					implicitHeight: 38; radius: 19
					color: root.withAlpha(root.bg, root.isVM ? 0.96 : 0.85)
					border.width: 1; border.color: root.withAlpha(root.color4, 0.6); clip: true
					Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
					HoverHandler { id: wsHover }

					Text { anchors.centerIn: parent; visible: !wsPill.showAll; text: root.lastActiveWs.toString(); color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.bold: true }
					RowLayout {
						id: wsRow; anchors.centerIn: parent; visible: wsPill.showAll; spacing: 6
						Repeater {
							model: root.workspacesList
							Rectangle {
								required property var modelData
								implicitWidth: 26; implicitHeight: 26; radius: 13
								color: modelData.active ? root.color4 : (modelData.occupied ? root.withAlpha(root.color2, 0.25) : Qt.rgba(1, 1, 1, 0.06))
								border.width: modelData.occupied && !modelData.active ? 1 : 0; border.color: root.color2
								Text { anchors.centerIn: parent; text: modelData.idx.toString(); color: modelData.active ? root.bg : (modelData.occupied ? root.color2 : root.color8); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true }
								MouseArea { anchors.fill: parent; onClicked: root.runCmd((root.isHyprland ? "hyprctl dispatch workspace " : "niri msg action focus-workspace ") + modelData.idx) }
							}
						}
					}
				}

				// C. PILLOLA CENTRALE (Larghezza Unificata 390px per Anteprima, Calendario, Sistema e Launcher)
				Rectangle {
					id: centerPill
					Layout.alignment: Qt.AlignTop

					property bool isHoverPreview: centerHover.hovered && root.centerMode === "none"
					property bool isCalOpen: root.centerMode === "calendar"
					property bool isSysOpen: root.centerMode === "system"
					property bool isLauncherOpen: root.centerMode === "launcher"

					implicitWidth: (isHoverPreview || isCalOpen || isSysOpen || isLauncherOpen) ? 390 : (compactClockRow.implicitWidth + 28)
					implicitHeight: isLauncherOpen ? 410 : (isSysOpen ? (sysContainer.implicitHeight + 28) : (isCalOpen ? Math.max(410, calCardCol.implicitHeight + 52) : (isHoverPreview ? (calPreviewBox.implicitHeight + 56) : 38)))
					radius: (isHoverPreview || isCalOpen || isSysOpen || isLauncherOpen) ? 22 : 19
					color: root.withAlpha(root.bg, root.isVM ? 0.96 : 0.88)
					border.width: (isCalOpen || isSysOpen || isLauncherOpen) ? 2 : (isHoverPreview ? 0 : 1)
					border.color: (isCalOpen || isSysOpen || isLauncherOpen) ? root.color4 : root.withAlpha(root.color4, 0.6)
					clip: true
					Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
					Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

					HoverHandler {
						id: centerHover
						onHoveredChanged: {
							if (hovered) autoCloseTimer.stop()
							else if (root.centerMode === "calendar" || root.centerMode === "system") autoCloseTimer.restart()
						}
					}

					// Click Destro ovunque nel Calendario (anche aperto) -> Pannello di Controllo
					MouseArea {
						anchors.fill: parent
						visible: centerPill.isCalOpen || centerPill.isHoverPreview
						acceptedButtons: Qt.RightButton
						onClicked: root.openSystemPanel()
					}

					// Header Pillola Chiusa / Calendario
					Item {
						id: topPillBar
						visible: !centerPill.isSysOpen && !centerPill.isLauncherOpen
						anchors { top: parent.top; left: parent.left; right: parent.right }
						height: 38
						RowLayout {
							id: compactClockRow; anchors.centerIn: parent; spacing: 8
							Rectangle { visible: notifServer.trackedNotifications.values.length > 0; implicitWidth: 7; implicitHeight: 7; radius: 4; color: root.color2 }
							Text { text: root.timeStr; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true }
							Text { text: "•"; color: root.color8; font.pixelSize: 12 }
							Text { text: root.dateStr; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true }
							Text { text: root.weatherShort; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true }
						}
						MouseArea {
							anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
							onClicked: mouse => {
								if (mouse.button === Qt.LeftButton) { if (root.centerMode === "calendar") root.closeCenterPill(); else root.openCalendar() }
								else if (mouse.button === Qt.RightButton) root.openSystemPanel()
								else if (mouse.button === Qt.MiddleButton) root.openLauncher()
							}
						}
					}

					// CONTENUTO 1: HOVER PREVIEW & CALENDARIO + METEO + NOTIFICHE
					ColumnLayout {
						id: calCardCol
						visible: centerPill.isHoverPreview || centerPill.isCalOpen
						anchors { top: topPillBar.bottom; left: parent.left; right: parent.right; margins: 14 }
						spacing: 10

						Item {
							id: calPreviewBox; Layout.fillWidth: true; implicitHeight: calInnerCol.implicitHeight
							ColumnLayout {
								id: calInnerCol
								anchors { left: parent.left; right: parent.right }
								spacing: 6
								RowLayout {
									Layout.fillWidth: true
									Rectangle {
										visible: centerPill.isCalOpen; implicitWidth: 26; implicitHeight: 26; radius: 8; color: Qt.rgba(1, 1, 1, 0.08)
										Text { anchors.centerIn: parent; text: "‹"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; font.bold: true }
										MouseArea {
											anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
											onClicked: mouse => {
												if (mouse.button === Qt.RightButton) root.openSystemPanel()
												else { if (root.calMonth === 0) { root.calMonth = 11; root.calYear-- } else root.calMonth--; root.updateCalendar() }
											}
										}
									}
									Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: Qt.formatDate(new Date(root.calYear, root.calMonth, 1), "MMMM yyyy"); color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.bold: true }
									Rectangle {
										visible: centerPill.isCalOpen; implicitWidth: 26; implicitHeight: 26; radius: 8; color: Qt.rgba(1, 1, 1, 0.08)
										Text { anchors.centerIn: parent; text: "›"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; font.bold: true }
										MouseArea {
											anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
											onClicked: mouse => {
												if (mouse.button === Qt.RightButton) root.openSystemPanel()
												else { if (root.calMonth === 11) { root.calMonth = 0; root.calYear++ } else root.calMonth++; root.updateCalendar() }
											}
										}
									}
								}
								GridLayout {
									Layout.fillWidth: true; columns: 7; rowSpacing: 4; columnSpacing: 4
									Repeater {
										model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
										Text { required property string modelData; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: modelData; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true }
									}
									Repeater {
										model: root.calendarDays
										Rectangle {
											required property var modelData
											Layout.fillWidth: true; implicitHeight: 26; radius: 8; color: modelData.today ? root.color4 : "transparent"
											Text { anchors.centerIn: parent; text: modelData.day; color: modelData.today ? root.bg : root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: modelData.today }
										}
									}
								}
							}
							MouseArea {
								anchors.fill: parent; visible: centerPill.isHoverPreview; acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
								onClicked: mouse => {
									if (mouse.button === Qt.LeftButton) root.openCalendar()
									else if (mouse.button === Qt.RightButton) root.openSystemPanel()
									else if (mouse.button === Qt.MiddleButton) root.openLauncher()
								}
							}
						}

						Rectangle {
							visible: centerPill.isCalOpen; Layout.fillWidth: true; implicitHeight: 54; radius: 14; color: root.color0
							ColumnLayout {
								anchors.fill: parent; anchors.margins: 10; spacing: 2
								Text { text: "Today's Weather   " + root.weatherShort; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true }
								Text { text: root.weatherDetail; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
							}
						}

						ColumnLayout {
							visible: centerPill.isCalOpen; Layout.fillWidth: true; spacing: 6
							RowLayout {
								Layout.fillWidth: true
								Text { text: "Notifications (" + notifServer.trackedNotifications.values.length + ")"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true }
								Rectangle {
									implicitWidth: 74; implicitHeight: 24; radius: 8; color: Qt.rgba(1, 1, 1, 0.08)
									Text { anchors.centerIn: parent; text: "Clear all"; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true }
									MouseArea {
										anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
										onClicked: mouse => {
											if (mouse.button === Qt.RightButton) root.openSystemPanel()
											else { let l = notifServer.trackedNotifications.values; for (let i = l.length - 1; i >= 0; i--) l[i].dismiss(); root.popupNotifications = [] }
										}
									}
								}
							}
							ListView {
								Layout.fillWidth: true; implicitHeight: Math.min(180, Math.max(60, contentHeight)); clip: true; spacing: 6
								model: notifServer.trackedNotifications
								Text { anchors.centerIn: parent; visible: notifServer.trackedNotifications.values.length === 0; text: "No active notifications"; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
								delegate: Rectangle {
									required property var modelData
									width: ListView.view.width; height: 56; radius: 12; color: root.color0
									RowLayout {
										anchors.fill: parent; anchors.margins: 10
										ColumnLayout {
											Layout.fillWidth: true; spacing: 2
											Text { text: modelData.summary || "Notification"; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
											Text { text: modelData.body || ""; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
										}
										Rectangle { implicitWidth: 22; implicitHeight: 22; radius: 11; color: Qt.rgba(1, 1, 1, 0.1); Text { anchors.centerIn: parent; text: "✕"; color: root.fg; font.pixelSize: 11 } MouseArea { anchors.fill: parent; onClicked: modelData.dismiss() } }
									}
								}
							}
						}
					}

					// CONTENUTO 2: APP LAUNCHER INTEGRATO NELLA PILLOLA
					ColumnLayout {
						visible: centerPill.isLauncherOpen; anchors.fill: parent; anchors.margins: 16; spacing: 10
						Rectangle {
							Layout.fillWidth: true; implicitHeight: 40; radius: 12; color: root.color0; border.width: 1; border.color: root.color4
							RowLayout {
								anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 6
								Text { text: "󰍉 "; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
								TextInput {
									id: launcherSearchInput; Layout.fillWidth: true; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.bold: true; clip: true
									onTextChanged: { root.searchQuery = text; root.selectedAppIndex = 0 }
									Keys.onDownPressed: { if (root.selectedAppIndex < root.filteredApps.length - 1) root.selectedAppIndex++ }
									Keys.onUpPressed: { if (root.selectedAppIndex > 0) root.selectedAppIndex-- }
									Keys.onEscapePressed: root.closeCenterPill()
									Keys.onReturnPressed: { if (root.filteredApps.length > 0) { let a = root.filteredApps[root.selectedAppIndex]; root.closeCenterPill(); a.execute() } }
								}
							}
						}
						ListView {
							Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 4; model: root.filteredApps; currentIndex: root.selectedAppIndex
							delegate: Rectangle {
								required property var modelData; required property int index
								width: ListView.view.width; height: 38; radius: 10
								property bool isSel: index === root.selectedAppIndex
								color: isSel ? root.withAlpha(root.color4, 0.25) : (appMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
								border.width: isSel ? 1 : 0; border.color: root.color4
								RowLayout {
									anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
									IconImage { implicitSize: 22; source: Quickshell.iconPath(modelData.icon, true) }
									Text { text: modelData.name; color: parent.parent.isSel ? root.color4 : root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
								}
								MouseArea { id: appMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { root.closeCenterPill(); modelData.execute() } }
							}
						}
					}

					// CONTENUTO 3: PANNELLO DI GESTIONE SISTEMA + SOTTOMENU A TUTTA CARD
					Item {
						id: sysContainer
						visible: centerPill.isSysOpen
						anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
						implicitHeight: root.sysSubmenu === "" ? sysMainCol.implicitHeight : sysSubCol.implicitHeight

						// VISTA PRINCIPALE PANNELLO DI SISTEMA
						ColumnLayout {
							id: sysMainCol
							visible: root.sysSubmenu === ""
							anchors { left: parent.left; right: parent.right }
							spacing: 10

							// 1. RIGA IN CIMA: Sinistra Ora/Data/Meteo (UNICO punto che riporta al Calendario) | Destra CPU + Power
							RowLayout {
								Layout.fillWidth: true; spacing: 8
								Item {
									implicitWidth: topSysClockRow.implicitWidth; implicitHeight: 32
									RowLayout {
										id: topSysClockRow; anchors.verticalCenter: parent.verticalCenter; spacing: 8
										Text { text: root.timeStr; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; font.bold: true }
										Text { text: root.fullDateStr; color: root.withAlpha(root.fg, 0.8); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
										Rectangle {
											implicitHeight: 24; implicitWidth: wTopTxt.implicitWidth + 14; radius: 12; color: root.color0
											Text { id: wTopTxt; anchors.centerIn: parent; text: root.weatherShort; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true }
										}
									}
									MouseArea { anchors.fill: parent; onClicked: root.openCalendar() }
								}
								Item { Layout.fillWidth: true }
								Rectangle {
									implicitWidth: 34; implicitHeight: 34; radius: 17; color: cpuBtnMouse.containsMouse ? root.color4 : root.color0
									Text { anchors.centerIn: parent; text: "󰻠"; color: cpuBtnMouse.containsMouse ? root.bg : root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 17 }
									MouseArea { id: cpuBtnMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { sysPoll.running = true; root.sysSubmenu = "cpu" } }
								}
								Rectangle {
									implicitWidth: 34; implicitHeight: 34; radius: 17; color: pwrBtnMouse.containsMouse ? root.color1 : root.color0
									Text { anchors.centerIn: parent; text: "󰐥"; color: pwrBtnMouse.containsMouse ? root.bg : root.color1; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16 }
									MouseArea { id: pwrBtnMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.sysSubmenu = "power" }
								}
							}

							// 2. GRIGLIA 2x2 PERFETTAMENTE ALLINEATA AL 50% (Network, Bluetooth, App Tray, Battery)
							GridLayout {
								Layout.fillWidth: true
								columns: 2
								rowSpacing: 10
								columnSpacing: 10

								// Tile 1: Network
								Rectangle {
									Layout.fillWidth: true; Layout.preferredWidth: 1; implicitHeight: 58; radius: 16; color: root.color0
									property bool netActive: root.ethConnected || (root.wifiEnabled && root.netName !== "Offline")
									RowLayout {
										anchors.fill: parent; anchors.margins: 10; spacing: 8
										Rectangle {
											implicitWidth: 36; implicitHeight: 36; radius: 18; color: parent.parent.netActive ? root.color4 : Qt.rgba(1, 1, 1, 0.08)
											Text { anchors.centerIn: parent; text: root.ethConnected ? "󰈀" : (root.wifiEnabled ? "󰤨" : "󰤭"); color: parent.parent.parent.netActive ? root.bg : root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 17 }
											MouseArea { anchors.fill: parent; onClicked: root.togglePrimaryNetwork() }
										}
										ColumnLayout {
											Layout.fillWidth: true; spacing: 1
											Text { text: "Network"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true }
											Text { text: root.netName; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
										}
										Rectangle {
											implicitWidth: 26; implicitHeight: 36; radius: 8; color: Qt.rgba(1, 1, 1, 0.05)
											Text { anchors.centerIn: parent; text: "󰅀"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
											MouseArea { anchors.fill: parent; onClicked: { root.runCmd("nmcli dev wifi rescan 2>/dev/null || true"); subPoll.running = true; root.sysSubmenu = "net" } }
										}
									}
								}

								// Tile 2: Bluetooth
								Rectangle {
									Layout.fillWidth: true; Layout.preferredWidth: 1; implicitHeight: 58; radius: 16; color: root.color0
									RowLayout {
										anchors.fill: parent; anchors.margins: 10; spacing: 8
										Rectangle {
											implicitWidth: 36; implicitHeight: 36; radius: 18; color: root.btEnabled ? root.color4 : Qt.rgba(1, 1, 1, 0.08)
											Text { anchors.centerIn: parent; text: ""; color: root.btEnabled ? root.bg : root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 17 }
											MouseArea {
												anchors.fill: parent
												onClicked: {
													if (root.hasBtAdapter) {
														root.runCmd(root.btEnabled ? "bluetoothctl power off; rfkill block bluetooth" : "rfkill unblock bluetooth; bluetoothctl power on")
														sysPoll.running = true
													}
												}
											}
										}
										ColumnLayout {
											Layout.fillWidth: true; spacing: 1
											Text { text: "Bluetooth"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true }
											Text { text: root.btName; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
										}
										Rectangle {
											implicitWidth: 26; implicitHeight: 36; radius: 8; color: Qt.rgba(1, 1, 1, 0.05)
											Text { anchors.centerIn: parent; text: "󰅀"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
											MouseArea { anchors.fill: parent; onClicked: { subPoll.running = true; root.sysSubmenu = "bt" } }
										}
									}
								}

								// Tile 3: App Tray (Allineata a Network)
								Rectangle {
									Layout.fillWidth: true; Layout.preferredWidth: 1; implicitHeight: 58; radius: 16; color: root.color0
									RowLayout {
										anchors.fill: parent; anchors.margins: 10; spacing: 8
										ColumnLayout {
											Layout.fillWidth: true; spacing: 4
											Text { text: "App Tray (" + SystemTray.items.values.length + ")"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true }
											RowLayout {
												spacing: 5
												Repeater {
													model: SystemTray.items.values.slice(0, 4)
													Rectangle {
														required property var modelData
														implicitWidth: 20; implicitHeight: 20; radius: 5; color: Qt.rgba(1, 1, 1, 0.08)
														IconImage { anchors.centerIn: parent; implicitSize: 14; source: modelData.icon }
														MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: mouse => { if (mouse.button === Qt.RightButton) modelData.secondaryActivate(); else modelData.activate() } }
													}
												}
												Text { visible: SystemTray.items.values.length === 0; text: "Empty"; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11 }
											}
										}
										Rectangle {
											implicitWidth: 26; implicitHeight: 36; radius: 8; color: Qt.rgba(1, 1, 1, 0.05)
											Text { anchors.centerIn: parent; text: "󰅀"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
											MouseArea { anchors.fill: parent; onClicked: root.sysSubmenu = "tray" }
										}
									}
								}

								// Tile 4: Battery (Allineata a Bluetooth)
								Rectangle {
									Layout.fillWidth: true; Layout.preferredWidth: 1; implicitHeight: 58; radius: 16; color: root.color0
									RowLayout {
										anchors.fill: parent; anchors.margins: 10; spacing: 8
										Rectangle {
											implicitWidth: 36; implicitHeight: 36; radius: 18; color: root.withAlpha(root.color2, 0.2)
											Text { anchors.centerIn: parent; text: root.batCharging ? "󰂄" : "󰁹"; color: root.color2; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 17 }
										}
										ColumnLayout {
											Layout.fillWidth: true; spacing: 1
											Text { text: "Battery"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true }
											Text { text: root.batPct + "% • " + (root.batCharging ? "Charging" : "Ready"); color: root.color2; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
										}
										Rectangle {
											implicitWidth: 26; implicitHeight: 36; radius: 8; color: Qt.rgba(1, 1, 1, 0.05)
											Text { anchors.centerIn: parent; text: "󰅀"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
											MouseArea { anchors.fill: parent; onClicked: { sysPoll.running = true; root.sysSubmenu = "battery" } }
										}
									}
								}
							}

							// 3. SEZIONE REGISTRAZIONE SCHERMO (3 Pulsanti)
							Rectangle {
								Layout.fillWidth: true; implicitHeight: 54; radius: 16; color: root.color0
								RowLayout {
									anchors.fill: parent; anchors.margins: 9; spacing: 10
									Rectangle {
										Layout.fillWidth: true; implicitHeight: 36; radius: 12; color: root.isRecording ? root.color1 : Qt.rgba(1, 1, 1, 0.08)
										RowLayout {
											anchors.centerIn: parent; spacing: 8
											Text { text: root.isRecording ? "󰓛" : "󰻂"; color: root.isRecording ? root.bg : root.color1; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16 }
											Text { text: root.isRecording ? ("Stop • " + root.formatSec(root.recSeconds)) : "Record Screen"; color: root.isRecording ? root.bg : root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true }
										}
										MouseArea { anchors.fill: parent; onClicked: root.toggleRecording() }
									}
									Rectangle {
										implicitWidth: 42; implicitHeight: 36; radius: 12; color: Qt.rgba(1, 1, 1, 0.08)
										Text { anchors.centerIn: parent; text: "󰄄"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16 }
										MouseArea { anchors.fill: parent; onClicked: { root.closeCenterPill(); root.runCmd("sleep 0.2; grim -g \"$(slurp)\" - | swappy -f -") } }
									}
									Rectangle {
										implicitWidth: 28; implicitHeight: 36; radius: 10; color: Qt.rgba(1, 1, 1, 0.05)
										Text { anchors.centerIn: parent; text: "󰅀"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
										MouseArea { anchors.fill: parent; onClicked: root.sysSubmenu = "rec" }
									}
								}
							}

							// 4. SLIDERS SU SINGOLA RIGA CON TRASCINAMENTO FLUIDO (Display, Sound, Microphone)
							Repeater {
								model: ["display", "sound", "mic"]
								Rectangle {
									required property string modelData
									Layout.fillWidth: true; implicitHeight: 46; radius: 14; color: root.color0
									property int valPct: modelData === "display" ? root.brightnessPct : (modelData === "sound" ? root.outVolPct : root.micVolPct)
									property bool isMuted: modelData === "sound" ? root.outMuted : (modelData === "mic" ? root.micMuted : false)
									property string iconTxt: modelData === "display" ? "󰃠" : (modelData === "sound" ? (isMuted ? "󰖁" : (root.isHeadphones ? "󰋋" : "󰕾")) : (isMuted ? "󰍭" : (root.isHeadsetMic ? "󰋎" : "󰍬")))

									function setLevelFromRatio(r) {
										let cl = Math.max(0, Math.min(1, r))
										if (modelData === "display") {
											let p = Math.max(5, Math.round(cl * 100))
											root.brightnessPct = p
											root.runCmd("brightnessctl s " + p + "%")
										} else if (modelData === "sound" && Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
											Pipewire.defaultAudioSink.audio.volume = cl
										} else if (modelData === "mic" && Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) {
											Pipewire.defaultAudioSource.audio.volume = cl
										}
									}

									RowLayout {
										anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 8

										// Nome + Percentuale allineati a larghezza fissa
										RowLayout {
											Layout.preferredWidth: 124
											Layout.fillWidth: false
											spacing: 4
											Text {
												text: modelData === "display" ? "Display" : (modelData === "sound" ? "Sound" : "Mic")
												color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true
											}
											Item { Layout.fillWidth: true }
											Text {
												text: parent.parent.parent.isMuted ? "Mute" : (parent.parent.parent.valPct + "%")
												color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
											}
										}

										// Icona cliccabile per Mute/Unmute
										Text {
											text: parent.parent.iconTxt
											color: parent.parent.isMuted ? root.color1 : root.color4
											font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
											MouseArea {
												anchors.fill: parent
												onClicked: {
													if (modelData === "sound") root.runCmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
													else if (modelData === "mic") root.runCmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
												}
											}
										}

										// Barra di regolazione trascinabile in tempo reale
										Rectangle {
											Layout.fillWidth: true; implicitHeight: 14; radius: 7; color: Qt.rgba(1, 1, 1, 0.1)
											Rectangle {
												width: parent.width * Math.min(1, parent.parent.parent.valPct / 100.0)
												height: parent.height; radius: 7
												color: parent.parent.parent.isMuted ? root.color8 : root.color4
											}
											MouseArea {
												anchors.fill: parent
												onPressed: mouse => parent.parent.parent.setLevelFromRatio(mouse.x / width)
												onPositionChanged: mouse => { if (pressed) parent.parent.parent.setLevelFromRatio(mouse.x / width) }
											}
										}

										// Freccia Sottomenu rivolta in giù
										Rectangle {
											implicitWidth: 26; implicitHeight: 28; radius: 8; color: Qt.rgba(1, 1, 1, 0.05)
											Text { anchors.centerIn: parent; text: "󰅀"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14 }
											MouseArea { anchors.fill: parent; onClicked: { subPoll.running = true; root.sysSubmenu = modelData } }
										}
									}
								}
							}
						}

						// =====================================================
						// VISTA SOTTOMENU A TUTTA CARD
						// =====================================================
						ColumnLayout {
							id: sysSubCol
							visible: root.sysSubmenu !== ""
							anchors { left: parent.left; right: parent.right }
							spacing: 12

							// HEADER UNIVERSALE SOTTOMENU
							RowLayout {
								Layout.fillWidth: true; implicitHeight: 34; spacing: 10
								Rectangle {
									implicitWidth: 32; implicitHeight: 32; radius: 16; color: Qt.rgba(1, 1, 1, 0.08)
									Text { anchors.centerIn: parent; text: "‹"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18; font.bold: true }
									MouseArea { anchors.fill: parent; onClicked: { root.wifiPromptSsid = ""; root.expandedResMon = ""; root.sysSubmenu = "" } }
								}
								Text {
									Layout.fillWidth: true
									text: ({ "net": "Network", "bt": "Bluetooth", "tray": "System Tray Apps", "battery": "Battery Details", "sound": "Audio Output", "mic": "Audio Input", "display": "Display", "rec": "Screen Recorder", "cpu": "System Info", "power": "Power Menu" })[root.sysSubmenu] || ""
									color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; font.bold: true
								}

								// Switch On/Off Header: per Network controlla Ethernet, per BT/Sound/Mic controlla il relativo stato
								Rectangle {
									visible: (root.sysSubmenu === "net" && root.ethIface !== "") || root.sysSubmenu === "bt" || root.sysSubmenu === "sound" || root.sysSubmenu === "mic"
									implicitWidth: 46; implicitHeight: 24; radius: 12
									property bool isOn: root.sysSubmenu === "net" ? root.ethConnected : (root.sysSubmenu === "bt" ? root.btEnabled : (root.sysSubmenu === "sound" ? !root.outMuted : !root.micMuted))
									color: isOn ? root.color4 : Qt.rgba(1, 1, 1, 0.15)
									Rectangle { width: 18; height: 18; radius: 9; anchors.verticalCenter: parent.verticalCenter; x: parent.isOn ? 24 : 4; color: parent.isOn ? root.bg : root.fg; Behavior on x { NumberAnimation { duration: 120 } } }
									MouseArea {
										anchors.fill: parent
										onClicked: {
											if (root.sysSubmenu === "net" && root.ethIface !== "") {
												root.runCmd("nmcli dev " + (root.ethConnected ? "disconnect " : "connect ") + root.ethIface)
											} else if (root.sysSubmenu === "bt" && root.hasBtAdapter) {
												root.runCmd(root.btEnabled ? "bluetoothctl power off; rfkill block bluetooth" : "rfkill unblock bluetooth; bluetoothctl power on")
											} else if (root.sysSubmenu === "sound") {
												root.runCmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
											} else if (root.sysSubmenu === "mic") {
												root.runCmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
											}
											sysPoll.running = true
										}
									}
								}
								Rectangle {
									visible: root.sysSubmenu === "rec"; implicitWidth: 88; implicitHeight: 28; radius: 10; color: root.isRecording ? root.color1 : root.color4
									Text { anchors.centerIn: parent; text: root.isRecording ? "󰓛 Stop" : "󰻂 Start"; color: root.bg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true }
									MouseArea { anchors.fill: parent; onClicked: root.toggleRecording() }
								}
								Rectangle {
									visible: root.sysSubmenu === "power"; implicitWidth: 110; implicitHeight: 30; radius: 10; color: root.color1
									Text { anchors.centerIn: parent; text: "󰐥 Poweroff"; color: root.bg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true }
									MouseArea { anchors.fill: parent; onClicked: root.runCmd("loginctl poweroff || poweroff") }
								}
							}

							// SOTTOMENU SOUND / MIC (Slider Trascinabile + Lista Dispositivi)
							ColumnLayout {
								visible: root.sysSubmenu === "sound" || root.sysSubmenu === "mic"
								Layout.fillWidth: true; spacing: 8

								Rectangle {
									Layout.fillWidth: true; implicitHeight: 54; radius: 14; color: root.color0
									property int subPct: root.sysSubmenu === "sound" ? root.outVolPct : root.micVolPct
									function updateAudioRatio(r) {
										let cl = Math.max(0, Math.min(1, r))
										if (root.sysSubmenu === "sound" && Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) Pipewire.defaultAudioSink.audio.volume = cl
										else if (root.sysSubmenu === "mic" && Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) Pipewire.defaultAudioSource.audio.volume = cl
									}
									ColumnLayout {
										anchors.fill: parent; anchors.margins: 10; spacing: 6
										RowLayout {
											Layout.fillWidth: true
											Text { text: root.sysSubmenu === "sound" ? "Output Volume" : "Input Volume"; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; Layout.fillWidth: true }
											Text { text: parent.parent.subPct + "%"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true }
										}
										Rectangle {
											Layout.fillWidth: true; implicitHeight: 12; radius: 6; color: Qt.rgba(1, 1, 1, 0.1)
											Rectangle { width: parent.width * Math.min(1, parent.parent.subPct / 100.0); height: parent.height; radius: 6; color: root.color4 }
											MouseArea {
												anchors.fill: parent
												onPressed: mouse => parent.parent.parent.updateAudioRatio(mouse.x / width)
												onPositionChanged: mouse => { if (pressed) parent.parent.parent.updateAudioRatio(mouse.x / width) }
											}
										}
									}
								}

								Text { text: "Available Devices"; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true }
								Repeater {
									model: root.sysSubmenu === "sound" ? root.audioSinks : (root.sysSubmenu === "mic" ? root.audioSources : [])
									Rectangle {
										required property var modelData
										Layout.fillWidth: true; implicitHeight: 42; radius: 12
										color: modelData.active ? root.withAlpha(root.color4, 0.2) : root.color0
										border.width: modelData.active ? 1 : 0; border.color: root.color4
										RowLayout {
											anchors.fill: parent; anchors.margins: 10; spacing: 8
											Text { text: root.sysSubmenu === "sound" ? "󰕾" : "󰍬"; color: modelData.active ? root.color4 : root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
											Text { text: modelData.name; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: modelData.active; elide: Text.ElideRight; Layout.fillWidth: true }
										}
										MouseArea { anchors.fill: parent; onClicked: { root.runCmd("wpctl set-default " + modelData.id); subPoll.running = true } }
									}
								}
							}

							// SOTTOMENU DISPLAY (Monitor, Luminosità, Scala, Risoluzione@Hz e Night Light)
							ColumnLayout {
								visible: root.sysSubmenu === "display"
								Layout.fillWidth: true; spacing: 10

								Repeater {
									model: root.sysSubmenu === "display" ? root.monitorsList : []
									Rectangle {
										required property var modelData
										Layout.fillWidth: true
										implicitHeight: monCardCol.implicitHeight + 24
										radius: 14; color: root.color0

										ColumnLayout {
											id: monCardCol
											anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
											spacing: 10

											// Intestazione Monitor
											RowLayout {
												Layout.fillWidth: true; spacing: 10
												Rectangle {
													implicitWidth: 34; implicitHeight: 34; radius: 17; color: root.withAlpha(root.color4, 0.2)
													Text { anchors.centerIn: parent; text: "󰍹"; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16 }
												}
												ColumnLayout {
													Layout.fillWidth: true; spacing: 1
													Text { text: modelData.name; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.bold: true }
													Text { text: modelData.curMode.replace("@", " · ") + " Hz · " + modelData.scale + "x"; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11 }
												}
												Text { text: "focused"; color: root.color2; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true }
											}

											// Barra Luminosità Trascinabile
											RowLayout {
												Layout.fillWidth: true; spacing: 10
												Rectangle {
													Layout.fillWidth: true; implicitHeight: 20; radius: 10; color: Qt.rgba(1, 1, 1, 0.08)
													Rectangle { width: parent.width * (root.brightnessPct / 100.0); height: parent.height; radius: 10; color: root.color2 }
													Text { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: "󰃠"; color: root.bg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
													MouseArea {
														anchors.fill: parent
														function setBri(xPos) {
															let p = Math.max(5, Math.min(100, Math.round((xPos / width) * 100)))
															root.brightnessPct = p
															root.runCmd("brightnessctl s " + p + "%")
														}
														onPressed: mouse => setBri(mouse.x)
														onPositionChanged: mouse => { if (pressed) setBri(mouse.x) }
													}
												}
												Text { text: root.brightnessPct + "%"; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true }
											}

											// Pulsanti Scala (1.0x, 1.25x, 1.5x, 1.75x, 2.0x)
											RowLayout {
												Layout.fillWidth: true; spacing: 6
												Repeater {
													model: ["1.0", "1.25", "1.5", "1.75", "2.0"]
													Rectangle {
														required property string modelData
														property string monName: monCardCol.parent.modelData.name
														property string curScale: monCardCol.parent.modelData.scale
														property string curMode: monCardCol.parent.modelData.curMode
														property bool activeScale: parseFloat(curScale) === parseFloat(modelData)
														Layout.fillWidth: true; implicitHeight: 28; radius: 14
														color: activeScale ? root.color2 : Qt.rgba(1, 1, 1, 0.08)
														Text { anchors.centerIn: parent; text: modelData + "x"; color: parent.activeScale ? root.bg : root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true }
														MouseArea {
															anchors.fill: parent
															onClicked: {
																if (root.isHyprland) root.runCmd("hyprctl keyword monitor " + parent.monName + "," + parent.curMode + ",auto," + modelData)
																else root.runCmd("niri msg output \"" + parent.monName + "\" scale " + modelData)
																subPoll.running = true
															}
														}
													}
												}
											}

											// Riga Selettore Risoluzione @ Refresh Rate (Hz)
											RowLayout {
												Layout.fillWidth: true
												Text { text: "Resolution"; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; Layout.fillWidth: true }
												RowLayout {
													spacing: 6
													Text { text: modelData.curMode.replace("@", " @ ") + " Hz"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true }
													Text { text: "󰅀"; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14 }
												}
												MouseArea {
													anchors.fill: parent
													onClicked: root.expandedResMon = (root.expandedResMon === modelData.name ? "" : modelData.name)
												}
											}

											// Menu a tendina Risoluzioni/Refresh Rate disponibili
											ColumnLayout {
												visible: root.expandedResMon === modelData.name
												Layout.fillWidth: true; spacing: 4
												Repeater {
													model: (root.expandedResMon === modelData.name) ? modelData.modes : []
													Rectangle {
														required property string modelData
														property string monName: monCardCol.parent.modelData.name
														property string curScale: monCardCol.parent.modelData.scale
														property bool isCurrent: modelData === monCardCol.parent.modelData.curMode
														Layout.fillWidth: true; implicitHeight: 32; radius: 8
														color: isCurrent ? root.withAlpha(root.color4, 0.25) : Qt.rgba(1, 1, 1, 0.05)
														RowLayout {
															anchors.fill: parent; anchors.margins: 8
															Text { text: modelData.replace("@", " @ ") + " Hz"; color: parent.parent.isCurrent ? root.color4 : root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: parent.parent.isCurrent; Layout.fillWidth: true }
															Text { visible: parent.parent.isCurrent; text: "Active"; color: root.color2; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 }
														}
														MouseArea {
															anchors.fill: parent
															onClicked: {
																if (root.isHyprland) root.runCmd("hyprctl keyword monitor " + parent.monName + "," + modelData + ",auto," + parent.curScale)
																else root.runCmd("niri msg output \"" + parent.monName + "\" mode " + modelData)
																root.expandedResMon = ""
																subPoll.running = true
															}
														}
													}
												}
											}
										}
									}
								}

								// Card Night Light (Filtro Luce Blu via wlsunset)
								Rectangle {
									Layout.fillWidth: true; implicitHeight: 88; radius: 14; color: root.color0
									ColumnLayout {
										anchors.fill: parent; anchors.margins: 12; spacing: 8
										RowLayout {
											Layout.fillWidth: true; spacing: 10
											Rectangle {
												implicitWidth: 32; implicitHeight: 32; radius: 16; color: root.nightLightOn ? root.color2 : Qt.rgba(1, 1, 1, 0.08)
												Text { anchors.centerIn: parent; text: "󰖔"; color: root.nightLightOn ? root.bg : root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
											}
											ColumnLayout {
												Layout.fillWidth: true; spacing: 1
												Text { text: "Night Light"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true }
												Text { text: root.nightLightTemp + " K"; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11 }
											}
											Rectangle {
												implicitWidth: 44; implicitHeight: 22; radius: 11; color: root.nightLightOn ? root.color2 : Qt.rgba(1, 1, 1, 0.15)
												Rectangle { width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter; x: root.nightLightOn ? 24 : 4; color: root.nightLightOn ? root.bg : root.fg; Behavior on x { NumberAnimation { duration: 120 } } }
												MouseArea { anchors.fill: parent; onClicked: { root.nightLightOn = !root.nightLightOn; root.applyNightLight() } }
											}
										}
										Rectangle {
											Layout.fillWidth: true; implicitHeight: 18; radius: 9; color: Qt.rgba(1, 1, 1, 0.08)
											Rectangle { width: parent.width * ((root.nightLightTemp - 2500) / 3500.0); height: parent.height; radius: 9; color: root.color2 }
											MouseArea {
												anchors.fill: parent
												function setKelvin(xPos) {
													let r = Math.max(0, Math.min(1, xPos / width))
													root.nightLightTemp = Math.round((2500 + r * 3500) / 100) * 100
													if (root.nightLightOn) root.applyNightLight()
												}
												onPressed: mouse => setKelvin(mouse.x)
												onPositionChanged: mouse => { if (pressed) setKelvin(mouse.x) }
											}
										}
									}
								}
							}

							// SOTTOMENU SYSTEM TRAY
							ColumnLayout {
								visible: root.sysSubmenu === "tray"; Layout.fillWidth: true; spacing: 6
								Rectangle {
									visible: SystemTray.items.values.length === 0; Layout.fillWidth: true; implicitHeight: 44; radius: 12; color: root.color0
									Text { anchors.centerIn: parent; text: "No applications in System Tray"; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
								}
								Repeater {
									model: root.sysSubmenu === "tray" ? SystemTray.items.values : []
									Rectangle {
										required property var modelData
										Layout.fillWidth: true; implicitHeight: 44; radius: 12; color: root.color0
										RowLayout {
											anchors.fill: parent; anchors.margins: 10; spacing: 10
											IconImage { implicitSize: 22; source: modelData.icon }
											Text { text: modelData.title || modelData.tooltipTitle || modelData.id || "Tray App"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
											Text { text: "Open"; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11 }
										}
										MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: mouse => { if (mouse.button === Qt.RightButton) modelData.secondaryActivate(); else modelData.activate() } }
									}
								}
							}

							// SOTTOMENU BATTERY DETAILS
							ColumnLayout {
								visible: root.sysSubmenu === "battery"; Layout.fillWidth: true; spacing: 8
								Rectangle {
									Layout.fillWidth: true; implicitHeight: 62; radius: 12; color: root.color0
									ColumnLayout {
										anchors.fill: parent; anchors.margins: 10; spacing: 6
										RowLayout {
											Layout.fillWidth: true
											Text { text: root.batCharging ? "󰂄  Charging" : "󰁹  Charge Level"; color: root.color2; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true }
											Text { text: root.batPct + "%"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true }
										}
										Rectangle { Layout.fillWidth: true; implicitHeight: 10; radius: 5; color: Qt.rgba(1, 1, 1, 0.1); Rectangle { width: parent.width * (root.batPct / 100.0); height: parent.height; radius: 5; color: root.color2 } }
									}
								}
								GridLayout {
									Layout.fillWidth: true; columns: 2; rowSpacing: 8; columnSpacing: 8
									Repeater {
										model: [ { "l": "Battery Health", "v": root.batHealth }, { "l": "Power Draw", "v": root.batPowerDraw }, { "l": "Cycle Count", "v": root.batCycles }, { "l": "Technology", "v": root.batTech } ]
										Rectangle {
											required property var modelData
											Layout.fillWidth: true; Layout.preferredWidth: 1; implicitHeight: 52; radius: 12; color: root.color0
											ColumnLayout {
												anchors.fill: parent; anchors.margins: 10; spacing: 2
												Text { text: modelData.l; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11 }
												Text { text: modelData.v; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true }
											}
										}
									}
								}
							}

							// SOTTOMENU NETWORK (Sezione Ethernet + Sezione Wi-Fi con Switch, Disponibili e Salvate)
							ColumnLayout {
								visible: root.sysSubmenu === "net"; Layout.fillWidth: true; spacing: 8

								// Card Stato Porta Ethernet
								Rectangle {
									Layout.fillWidth: true; implicitHeight: 50; radius: 12; color: root.color0
									RowLayout {
										anchors.fill: parent; anchors.margins: 10; spacing: 10
										Text { text: "󰈀"; color: root.ethConnected ? root.color4 : root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18 }
										ColumnLayout {
											Layout.fillWidth: true; spacing: 1
											Text { text: "Ethernet (" + (root.ethIface !== "" ? root.ethIface : "No port") + ")"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true }
											Text { text: root.ethIp; color: root.ethConnected ? root.color2 : root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11 }
										}
										Text { text: root.ethConnected ? "Connected" : "Offline"; color: root.ethConnected ? root.color4 : root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true }
									}
								}

								// Barra Switch Dedicato Wi-Fi + Statistiche
								Rectangle {
									Layout.fillWidth: true; implicitHeight: 50; radius: 12; color: root.color0
									RowLayout {
										anchors.fill: parent; anchors.margins: 10; spacing: 10
										Text { text: root.wifiEnabled ? "󰤨" : "󰤭"; color: root.wifiEnabled ? root.color4 : root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18 }
										ColumnLayout {
											Layout.fillWidth: true; spacing: 1
											Text { text: "Wi-Fi"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true }
											Text {
												text: !root.hasWifiHw ? "No Wi-Fi Adapter" : ("Available: " + root.netList.length + " • Saved: " + root.savedWifiList.length)
												color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10
											}
										}
										Rectangle {
											visible: root.hasWifiHw && root.wifiEnabled
											implicitWidth: 56; implicitHeight: 22; radius: 6; color: Qt.rgba(1, 1, 1, 0.08)
											Text { anchors.centerIn: parent; text: "Rescan"; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.bold: true }
											MouseArea { anchors.fill: parent; onClicked: { root.runCmd("nmcli dev wifi rescan 2>/dev/null || true"); subPoll.running = true } }
										}
										Rectangle {
											visible: root.hasWifiHw
											implicitWidth: 42; implicitHeight: 22; radius: 11; color: root.wifiEnabled ? root.color4 : Qt.rgba(1, 1, 1, 0.15)
											Rectangle { width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter; x: root.wifiEnabled ? 22 : 4; color: root.wifiEnabled ? root.bg : root.fg; Behavior on x { NumberAnimation { duration: 120 } } }
											MouseArea { anchors.fill: parent; onClicked: { root.runCmd("nmcli radio wifi " + (root.wifiEnabled ? "off" : "on")); sysPoll.running = true; subPoll.running = true } }
										}
									}
								}

								// Prompt Password Wi-Fi
								Rectangle {
									visible: root.wifiPromptSsid !== ""; Layout.fillWidth: true; implicitHeight: 74; radius: 12; color: root.color0; border.width: 1; border.color: root.color4
									ColumnLayout {
										anchors.fill: parent; anchors.margins: 8; spacing: 4
										Text { text: "Password for " + root.wifiPromptSsid; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true }
										RowLayout {
											Layout.fillWidth: true
											TextInput {
												id: wifiPwField; Layout.fillWidth: true; color: root.fg; echoMode: TextInput.Password; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
												Keys.onEscapePressed: { text = ""; root.wifiPromptSsid = "" }
												onAccepted: { root.runCmd("nmcli dev wifi connect \"" + root.wifiPromptSsid + "\" password \"" + text + "\""); text = ""; root.wifiPromptSsid = "" }
											}
											Rectangle {
												implicitWidth: 64; implicitHeight: 24; radius: 6; color: root.color4
												Text { anchors.centerIn: parent; text: "Join"; color: root.bg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true }
												MouseArea { anchors.fill: parent; onClicked: { root.runCmd("nmcli dev wifi connect \"" + root.wifiPromptSsid + "\" password \"" + wifiPwField.text + "\""); wifiPwField.text = ""; root.wifiPromptSsid = "" } }
											}
										}
									}
								}

								// Lista Reti Connesse e Collegabili
								Repeater {
									model: (root.sysSubmenu === "net" && root.wifiEnabled) ? root.netList : []
									Rectangle {
										required property var modelData
										Layout.fillWidth: true; implicitHeight: 40; radius: 12; color: modelData.connected ? root.withAlpha(root.color4, 0.2) : root.color0
										RowLayout {
											anchors.fill: parent; anchors.margins: 10; spacing: 8
											Text { text: "󰤨"; color: modelData.connected ? root.color4 : root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
											Text { text: modelData.ssid; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: modelData.connected; elide: Text.ElideRight; Layout.fillWidth: true }
											Text { text: modelData.connected ? "Disconnect" : (modelData.signal + "%"); color: modelData.connected ? root.color1 : root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11 }
										}
										MouseArea {
											anchors.fill: parent
											onClicked: {
												if (modelData.connected) root.runCmd("nmcli con down id \"" + modelData.ssid + "\"")
												else if (root.savedWifiList.includes(modelData.ssid) || modelData.sec === "" || modelData.sec === "--") root.runCmd("nmcli dev wifi connect \"" + modelData.ssid + "\"")
												else { root.wifiPromptSsid = modelData.ssid; focusTimer.restart() }
											}
										}
									}
								}

								// Lista Profili Wi-Fi Salvati
								Text { visible: root.savedWifiList.length > 0; text: "Saved Wi-Fi Profiles"; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true }
								Repeater {
									model: root.sysSubmenu === "net" ? root.savedWifiList : []
									Rectangle {
										required property string modelData
										Layout.fillWidth: true; implicitHeight: 38; radius: 10; color: root.color0
										RowLayout {
											anchors.fill: parent; anchors.margins: 10; spacing: 8
											Text { text: "󰆼"; color: root.color6; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14 }
											Text { text: modelData; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
											Rectangle {
												implicitWidth: 52; implicitHeight: 22; radius: 6; color: Qt.rgba(1, 1, 1, 0.08)
												Text { anchors.centerIn: parent; text: "Forget"; color: root.color1; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 }
												MouseArea { anchors.fill: parent; onClicked: { root.runCmd("nmcli connection delete id \"" + modelData + "\""); subPoll.running = true } }
											}
										}
									}
								}
							}

							// SOTTOMENU BLUETOOTH
							ColumnLayout {
								visible: root.sysSubmenu === "bt"; Layout.fillWidth: true; spacing: 6
								RowLayout {
									Layout.fillWidth: true
									Text { text: root.hasBtAdapter ? "Bluetooth Devices" : "No Bluetooth Controller Found"; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
									Rectangle {
										visible: root.hasBtAdapter && root.btEnabled
										implicitWidth: 64; implicitHeight: 22; radius: 6; color: Qt.rgba(1, 1, 1, 0.08)
										Text { anchors.centerIn: parent; text: "Scan"; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true }
										MouseArea { anchors.fill: parent; onClicked: { root.runCmd("bluetoothctl --timeout 5 scan on"); subPoll.running = true } }
									}
								}
								Rectangle {
									visible: !root.hasBtAdapter || root.btList.length === 0
									Layout.fillWidth: true; implicitHeight: 42; radius: 12; color: root.color0
									Text { anchors.centerIn: parent; text: !root.hasBtAdapter ? "Hardware adapter not present" : "No paired or discovered devices"; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
								}
								Repeater {
									model: root.sysSubmenu === "bt" ? root.btList : []
									Rectangle {
										required property var modelData
										Layout.fillWidth: true; implicitHeight: 42; radius: 12; color: modelData.connected ? root.withAlpha(root.color4, 0.2) : root.color0
										RowLayout {
											anchors.fill: parent; anchors.margins: 10; spacing: 8
											Text { text: ""; color: modelData.connected ? root.color4 : root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
											Text { text: modelData.name; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: modelData.connected; elide: Text.ElideRight; Layout.fillWidth: true }
											Text { text: modelData.connected ? "Disconnect" : "Connect"; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11 }
										}
										MouseArea { anchors.fill: parent; onClicked: { root.runCmd("bluetoothctl " + (modelData.connected ? "disconnect " : "connect ") + modelData.mac); subPoll.running = true } }
									}
								}
							}

							// SOTTOMENU SCREEN RECORDER
							ColumnLayout {
								visible: root.sysSubmenu === "rec"; Layout.fillWidth: true; spacing: 8
								Repeater {
									model: [ { "title": "Record System Audio", "key": "sys" }, { "title": "Record Microphone", "key": "mic" }, { "title": "Select Screen Region (slurp)", "key": "area" } ]
									Rectangle {
										required property var modelData
										Layout.fillWidth: true; implicitHeight: 44; radius: 12; color: root.color0
										property bool activeOpt: modelData.key === "sys" ? root.recSysAudio : (modelData.key === "mic" ? root.recMicAudio : root.recAreaSelect)
										RowLayout {
											anchors.fill: parent; anchors.margins: 10
											Text { text: modelData.title; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true }
											Rectangle {
												implicitWidth: 40; implicitHeight: 22; radius: 11; color: parent.parent.activeOpt ? root.color4 : Qt.rgba(1, 1, 1, 0.15)
												Rectangle { width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter; x: parent.parent.parent.activeOpt ? 20 : 4; color: parent.parent.parent.activeOpt ? root.bg : root.fg }
											}
										}
										MouseArea { anchors.fill: parent; onClicked: { if (modelData.key === "sys") root.recSysAudio = !root.recSysAudio; else if (modelData.key === "mic") root.recMicAudio = !root.recMicAudio; else root.recAreaSelect = !root.recAreaSelect } }
									}
								}
							}

							// SOTTOMENU SYSTEM INFO (CPU, RAM, Storage, Kernel)
							ColumnLayout {
								visible: root.sysSubmenu === "cpu"; Layout.fillWidth: true; spacing: 8
								Repeater {
									model: [
										{ "title": "󰻠  " + root.cpuModel, "right": root.cpuUsage + "% • " + root.cpuTemp + "°C", "pct": root.cpuUsage, "col": root.color4, "sub": "" },
										{ "title": "󰍛  Memory (RAM)", "right": root.ramInfo, "pct": root.ramPct, "col": root.color2, "sub": "" },
										{ "title": "󰋊  Storage (/)", "right": root.diskRootInfo, "pct": root.diskRootPct, "col": root.color6, "sub": "Secondary: " + root.diskSecInfo }
									]
									Rectangle {
										required property var modelData
										Layout.fillWidth: true; implicitHeight: modelData.sub !== "" ? 72 : 58; radius: 12; color: root.color0
										ColumnLayout {
											anchors.fill: parent; anchors.margins: 10; spacing: 4
											RowLayout {
												Layout.fillWidth: true
												Text { text: modelData.title; color: modelData.col; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
												Text { text: modelData.right; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11 }
											}
											Rectangle { Layout.fillWidth: true; implicitHeight: 8; radius: 4; color: Qt.rgba(1, 1, 1, 0.1); Rectangle { width: parent.width * (modelData.pct / 100.0); height: parent.height; radius: 4; color: modelData.col } }
											Text { visible: modelData.sub !== ""; text: modelData.sub; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
										}
									}
								}
								Rectangle {
									Layout.fillWidth: true; implicitHeight: 44; radius: 12; color: root.color0
									RowLayout {
										anchors.fill: parent; anchors.margins: 10
										Text { text: "󰌽  Kernel: " + root.kernelVer; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; Layout.fillWidth: true }
										Text { text: "  Up: " + root.uptimeStr; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11 }
									}
								}
							}

							// SOTTOMENU POWER (Reboot, Suspend, Hibernate, Lock Screen, Log Out)
							ColumnLayout {
								visible: root.sysSubmenu === "power"; Layout.fillWidth: true; spacing: 8
								Repeater {
									model: [
										{ "icon": "󰑐", "label": "Reboot System", "cmd": "loginctl reboot || reboot" },
										{ "icon": "󰤄", "label": "Suspend", "cmd": "loginctl suspend || zzz" },
										{ "icon": "󰒲", "label": "Hibernate", "cmd": "loginctl hibernate || ZZZ" },
										{ "icon": "󰌾", "label": "Lock Screen", "cmd": "LOCK" },
										{ "icon": "󰍃", "label": "Log Out", "cmd": "niri msg action quit -s 2>/dev/null || hyprctl dispatch exit 2>/dev/null || loginctl terminate-session \"$XDG_SESSION_ID\" 2>/dev/null || pkill -u \"$UID\" -x 'niri|Hyprland'" }
									]
									Rectangle {
										required property var modelData
										Layout.fillWidth: true; implicitHeight: 44; radius: 12; color: pwrItemMouse.containsMouse ? root.withAlpha(root.color4, 0.25) : root.color0
										RowLayout {
											anchors.fill: parent; anchors.margins: 12; spacing: 12
											Text { text: modelData.icon; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16 }
											Text { text: modelData.label; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true }
										}
										MouseArea { id: pwrItemMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { if (modelData.cmd === "LOCK") root.triggerLock(); else root.runCmd(modelData.cmd) } }
									}
								}
							}
						}
					}
				}

				// D. PALLINO DI DESTRA: VOLUME PERMANENTE + OSD 2s (Mic / Luminosità)
				Rectangle {
					id: rightOsdPill
					Layout.alignment: Qt.AlignTop
					implicitWidth: 38; implicitHeight: 38; radius: 19
					color: root.withAlpha(root.bg, root.isVM ? 0.96 : 0.85)
					property real arcPct: root.osdMode === "brightness" ? (root.brightnessPct / 100.0) : (root.osdMode === "mic" ? (root.micMuted ? 0 : root.micVolPct / 100.0) : (root.outMuted ? 0 : root.outVolPct / 100.0))
					property string centerIcon: root.osdMode === "brightness" ? "󰃠" : (root.osdMode === "mic" ? (root.micMuted ? (root.isHeadsetMic ? "󰋐" : "󰍭") : (root.isHeadsetMic ? "󰋎" : "󰍬")) : (root.outMuted ? (root.isHeadphones ? "󰟎" : "󰖁") : (root.isHeadphones ? "󰋋" : "󰕾")))
					onArcPctChanged: osdCanvas.requestPaint()
					onCenterIconChanged: osdCanvas.requestPaint()

					Canvas {
						id: osdCanvas; anchors.fill: parent
						onPaint: {
							var ctx = getContext("2d"); ctx.reset()
							var cx = width / 2, cy = height / 2, r = (width / 2) - 3
							ctx.lineWidth = 2.6; ctx.lineCap = "round"
							ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2, false); ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.14); ctx.stroke()
							if (rightOsdPill.arcPct > 0.005) {
								var s = -Math.PI / 2, e = s + (Math.PI * 2 * Math.min(1, rightOsdPill.arcPct))
								ctx.beginPath(); ctx.arc(cx, cy, r, s, e, false)
								ctx.strokeStyle = root.osdMode === "mic" ? root.color2.toString() : (root.osdMode === "brightness" ? root.color3.toString() : root.color4.toString())
								ctx.stroke()
							}
						}
					}
					Text { anchors.centerIn: parent; text: rightOsdPill.centerIcon; color: ((root.osdMode === "volume" && root.outMuted) || (root.osdMode === "mic" && root.micMuted)) ? root.color1 : root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15; font.bold: true }
					MouseArea {
						anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
						onClicked: mouse => {
							if (mouse.button === Qt.RightButton) root.runCmd("pavucontrol")
							else if (root.osdMode === "mic") root.runCmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
							else root.runCmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
						}
						onWheel: wheel => {
							let up = wheel.angleDelta.y > 0
							if (root.osdMode === "brightness") root.runCmd("brightnessctl s 5%" + (up ? "+" : "-"))
							else if (root.osdMode === "mic") root.runCmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SOURCE@ 5%" + (up ? "+" : "-"))
							else root.runCmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%" + (up ? "+" : "-"))
						}
					}
				}
			}
		}
	}

	// 5. POPUP NOTIFICHE
	PanelWindow {
		visible: root.popupNotifications.length > 0 && root.centerMode === "none"
		WlrLayershell.layer: WlrLayer.Overlay
		WlrLayershell.namespace: "swaync-notification-window"
		WlrLayershell.exclusionMode: ExclusionMode.Ignore
		anchors { top: true }
		margins.top: 56
		implicitWidth: 360; implicitHeight: notifPopupCol.implicitHeight + 16; color: "transparent"
		ColumnLayout {
			id: notifPopupCol; anchors.fill: parent; anchors.margins: 8; spacing: 8
			Repeater {
				model: root.popupNotifications
				Rectangle {
					required property var modelData
					Layout.fillWidth: true; implicitHeight: 68; radius: 16; color: root.withAlpha(root.color0, root.isVM ? 0.96 : 0.88); border.width: 2; border.color: root.color4
					ColumnLayout {
						anchors.fill: parent; anchors.margins: 12; spacing: 3
						Text { text: modelData.summary || "Notification"; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
						Text { text: modelData.body || ""; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
					}
				}
			}
		}
	}

	// 6. LOCKSCREEN INTEGRATO
	property bool authError: false
	property bool authBusy: false
	property string pendingPassword: ""

	PamContext {
		id: pamLock; config: "quickshell"
		onResponseRequiredChanged: { if (responseRequired && root.authBusy) respond(root.pendingPassword) }
		onCompleted: result => {
			root.authBusy = false
			if (result === PamResult.Success) { root.screenLocked = false; root.authError = false } else root.authError = true
		}
	}

	Variants {
		model: Quickshell.screens
		PanelWindow {
			required property var modelData
			screen: modelData; visible: root.screenLocked
			WlrLayershell.layer: WlrLayer.Overlay; WlrLayershell.namespace: "lockscreen"
			WlrLayershell.exclusionMode: ExclusionMode.Ignore
			WlrLayershell.keyboardFocus: root.screenLocked ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
			anchors { top: true; bottom: true; left: true; right: true }
			color: root.bg
			onVisibleChanged: { if (visible) { pwLockInput.text = ""; pwLockInput.forceActiveFocus() } }
			Image { id: lockWall; anchors.fill: parent; source: root.wallpaperPath !== "" ? "file://" + root.wallpaperPath : ""; fillMode: Image.PreserveAspectCrop; visible: root.isVM }
			MultiEffect { anchors.fill: parent; source: lockWall; visible: !root.isVM && root.wallpaperPath !== ""; blurEnabled: !root.isVM; blurMax: 48; blur: 1.0 }
			Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.35) }
			Text { anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -80; text: root.timeStr; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 64; font.bold: true }
			Rectangle {
				width: 260; height: 50; radius: 25; anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 20
				color: root.bg; border.width: 3; border.color: root.authError ? root.color1 : root.color4
				TextInput {
					id: pwLockInput; anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 20; verticalAlignment: TextInput.AlignVCenter; horizontalAlignment: TextInput.AlignHCenter
					echoMode: TextInput.Password; passwordCharacter: "●"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18; focus: true
					onTextChanged: root.authError = false
					Keys.onReturnPressed: { if (root.authBusy || text === "") return; root.authError = false; root.authBusy = true; root.pendingPassword = text; text = ""; pamLock.start() }
				}
				Text { anchors.centerIn: parent; visible: pwLockInput.text.length === 0; text: root.authError ? "Wrong password..." : "Password..."; color: root.authError ? root.color1 : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.5); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15; font.italic: true }
			}
		}
	}
}
