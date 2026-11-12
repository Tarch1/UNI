import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtMultimedia
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

	// =========================================================================
	// USER CONFIGURATION & TUNING VARIABLES (EFFECTS, ANIMATIONS, BLUR & PAUSE)
	// =========================================================================
	property bool cfgEnableEffects: !isVM
	property int cfgIslandAnimMs: 180
	property int cfgIslandEasing: Easing.OutCubic
	property string cfgSubmenuAnimStyle: "slide"
	property int cfgSubmenuAnimMs: 160
	property int cfgSubmenuSlidePx: 18
	property string cfgWallpaperTransition: "crossfade"
	property int cfgWallpaperTransitionMs: 420
	property real cfgGlassOpacity: 0.76
	property real cfgSolidOpacity: 0.96
	property bool cfgLockKeepAnimated: true
	property int cfgLockBlurMax: 48
	property bool cfgPauseOnFullscreen: true
	property bool cfgPauseOnScreenOff: true
	// =========================================================================

	property string homeDir: Quickshell.env("HOME")
	property bool isVM: Quickshell.env("QSG_RENDER_LOOP") === "basic"
	property bool isHyprland: Quickshell.env("XDG_CURRENT_DESKTOP") === "Hyprland"
	property bool isGreeterMode: Quickshell.env("QS_GREETER") === "1"
	property bool isInitialLogin: Quickshell.env("QS_START_LOCKED") === "1" || isGreeterMode

	property bool fxActive: cfgEnableEffects && !isVM
	property int animMs: fxActive ? cfgIslandAnimMs : 0
	property real panelAlpha: fxActive ? cfgGlassOpacity : cfgSolidOpacity

	property string wallpaperPath: ""
	property bool animWallpapers: false
	property bool firstRunDone: false
	property bool isVideoFile: wallpaperPath.toLowerCase().endsWith(".webm") || wallpaperPath.toLowerCase().endsWith(".mp4")
	property bool isAnimatedGif: !isVideoFile && (wallpaperPath.toLowerCase().endsWith(".gif") || (animWallpapers && wallpaperPath.toLowerCase().endsWith(".webp")))
	property bool hasActiveFullWindow: false
	property bool isMonitorDpmsOff: false
	property bool shouldPlayAnimation: {
		if (!animWallpapers || (!isVideoFile && !isAnimatedGif)) return false
		if (cfgPauseOnScreenOff && isMonitorDpmsOff) return false
		if (screenLocked) return cfgLockKeepAnimated
		if (cfgPauseOnFullscreen && hasActiveFullWindow) return false
		return true
	}
	property string wallpaperLabel: {
		if (wallpaperPath === "") return "None"
		let p = wallpaperPath.split("/")
		return p.length >= 2 ? (p[p.length - 2] + " / " + p[p.length - 1]) : wallpaperPath
	}

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

	property bool barVisible: true
	property string centerMode: "none"
	property string sysSubmenu: ""
	property string calSubmenu: ""
	property bool screenLocked: isInitialLogin
	property bool wsExpanded: false
	property int lastActiveWs: 1
	property string lastWsSignature: ""
	property real mediaProg: 0.0
	property var overviewWindows: []

	property string searchQuery: ""
	property int selectedAppIndex: 0
	property var filteredApps: {
		let all = DesktopEntries.applications.values, q = searchQuery.toLowerCase().trim(), res = []
		for (let i = 0; i < all.length; i++) {
			let a = all[i]
			if (q === "" || (a.name && a.name.toLowerCase().includes(q)) || (a.genericName && a.genericName.toLowerCase().includes(q)) || (a.comment && a.comment.toLowerCase().includes(q))) res.push(a)
		}
		return res
	}

	property string timeStr: ""
	property string dateStr: ""
	property string weatherShort: "󰖕 --°C"
	property string weatherDetail: "Fetching weather..."
	property string weatherLoc: "Local Weather"
	property string weatherWind: "-- km/h"
	property string weatherHum: "--%"
	property string weatherPrecip: "0.0 mm • UV 0"
	property string weatherPress: "1013 hPa"
	property var weatherForecast: []
	property int calMonth: (new Date()).getMonth()
	property int calYear: (new Date()).getFullYear()
	property var calendarDays: []

	property string osdMode: "volume"
	property int brightnessPct: 100
	property int lastBrightnessPct: -1
	property var sinkAudio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
	property var sourceAudio: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null
	property int outVolPct: sinkAudio ? Math.round(sinkAudio.volume * 100) : 45
	property bool outMuted: sinkAudio ? sinkAudio.muted : false
	property int micVolPct: sourceAudio ? Math.round(sourceAudio.volume * 100) : 100
	property bool micMuted: sourceAudio ? sourceAudio.muted : false
	property bool isHeadphones: false
	property bool isHeadsetMic: false

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
	property var pairedBtList: []
	property bool showSavedList: false
	property string expandedDevInfo: ""

	property var audioSinks: []
	property var audioSources: []
	property var monitorsList: []
	property string expandedResMon: ""
	property bool nightLightOn: false
	property int nightLightTemp: 4000

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
	property string ramInfo: "0 / 0 GiB"
	property int ramPct: 0
	property string diskRootInfo: "0 / 0 GiB"
	property int diskRootPct: 0
	property string diskSecInfo: "Not mounted"
	property string kernelVer: "Linux"
	property string uptimeStr: "0m"
	property var workspacesList: [{ "idx": 1, "active": true, "occupied": true }]
	property var popupNotifications: []

	property string currentSessionUser: (Quickshell.env("USER") || Quickshell.env("LOGNAME") || "user").toLowerCase()
	property var usersList: [currentSessionUser]
	property int selectedUserIdx: 0
	property string selectedUser: (usersList.length > 0 && selectedUserIdx >= 0 && selectedUserIdx < usersList.length) ? usersList[selectedUserIdx] : currentSessionUser
	property bool isSwitchingUser: !isGreeterMode && selectedUser !== currentSessionUser

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
	function paintArc(canvas, pct, strokeCol) {
		var ctx = canvas.getContext("2d"); ctx.reset()
		var cx = canvas.width / 2, cy = canvas.height / 2, r = (canvas.width / 2) - 3
		ctx.lineWidth = 2.6; ctx.lineCap = "round"
		ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2, false); ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.14); ctx.stroke()
		if (pct > 0.005) {
			var s = -Math.PI / 2, e = s + (Math.PI * 2 * Math.min(1, pct))
			ctx.beginPath(); ctx.arc(cx, cy, r, s, e, false); ctx.strokeStyle = strokeCol.toString(); ctx.stroke()
		}
	}
	function activateTrayItem(item, win, itemWidget, button) {
		let pos = itemWidget ? itemWidget.mapToItem(null, 0, itemWidget.height) : Qt.point(200, 48)
		if (button === Qt.RightButton) {
			if (item.hasMenu) item.display(win, pos.x, pos.y)
			else item.secondaryActivate()
		} else {
			if (item.onlyMenu && item.hasMenu) item.display(win, pos.x, pos.y)
			else item.activate()
		}
	}
	function cycleUser(step) {
		if (root.usersList.length <= 1) return
		let n = root.usersList.length
		root.selectedUserIdx = (root.selectedUserIdx + (step % n) + n) % n
		root.authError = false; root.lockPromptActive = true
	}
	function cleanExitSession(targetUser) {
		let sw = targetUser !== "" ? ("sudo -n /usr/bin/qs-session --switch '" + targetUser + "' 2>/dev/null || true; ") : "rm -f /tmp/qs_lock_active_$UID 2>/dev/null || true; "
		let clean = "pkill -u \"$UID\" -f '[t]heme-switcher.sh|[q]s-session --clipboard' 2>/dev/null || true; pkill -u \"$UID\" -x 'hypridle|wlsunset|wf-recorder' 2>/dev/null || true; command -v systemctl >/dev/null 2>&1 || pkill -u \"$UID\" -x 'wireplumber|pipewire-pulse|pipewire' 2>/dev/null || true; "
		let wmExit = "niri msg action quit -s 2>/dev/null || hyprctl dispatch exit 2>/dev/null || loginctl terminate-session $XDG_SESSION_ID 2>/dev/null || pkill -TERM -u \"$UID\" -x 'niri|Hyprland'"
		runCmd(sw + clean + wmExit)
	}
	function checkFirstRunNiri() {
		if (!root.firstRunDone && !root.isHyprland && !root.screenLocked) {
			root.firstRunDone = true
			runCmd("sed -i 's/\"firstRunDone\": *[a-z]*/\"firstRunDone\": true/' \"" + root.homeDir + "/.config/quickshell/colors.json\" \"" + root.homeDir + "/.config/wallust/templates/colors-quickshell.json\" 2>/dev/null || true; sleep 0.6 && niri msg action show-hotkey-overlay >/dev/null 2>&1")
		}
	}
	function closeCenterPill() {
		root.centerMode = "none"; root.sysSubmenu = ""; root.calSubmenu = ""; root.wifiPromptSsid = ""; root.expandedResMon = ""; root.showSavedList = false; root.expandedDevInfo = ""
	}
	function openSubmenu(sub) {
		root.wifiPromptSsid = ""; root.expandedResMon = ""; root.showSavedList = false; root.expandedDevInfo = ""
		root.sysSubmenu = sub
		if (sub === "cpu" || sub === "battery") sysPoll.running = true
		else if (sub === "net" || sub === "bt" || sub === "sound" || sub === "mic" || sub === "display") subPoll.running = true
	}
	function openLauncher() {
		if (root.centerMode === "launcher") root.closeCenterPill()
		else { root.searchQuery = ""; root.selectedAppIndex = 0; root.sysSubmenu = ""; root.calSubmenu = ""; root.wifiPromptSsid = ""; root.centerMode = "launcher" }
	}
	function openOverview() {
		if (root.centerMode === "overview") root.closeCenterPill()
		else { root.sysSubmenu = ""; root.calSubmenu = ""; root.wifiPromptSsid = ""; overviewPoll.running = true; root.centerMode = "overview" }
	}
	function openCalendar() {
		root.calMonth = (new Date()).getMonth(); root.calYear = (new Date()).getFullYear(); root.updateCalendar()
		root.sysSubmenu = ""; root.calSubmenu = ""; root.wifiPromptSsid = ""; root.centerMode = "calendar"
	}
	function openSystemPanel() {
		root.sysSubmenu = ""; root.calSubmenu = ""; root.wifiPromptSsid = ""; root.centerMode = "system"; sysPoll.running = true
	}
	function triggerOsd(mode) { root.osdMode = mode; osdTimer.restart() }
	function triggerLock() {
		root.closeCenterPill()
		let idx = root.usersList.indexOf(root.currentSessionUser)
		if (idx >= 0) root.selectedUserIdx = idx
		root.screenLocked = true
	}

	function setSinkVolume(pct) {
		let p = Math.max(0, Math.min(100, Math.round(pct)))
		if (root.sinkAudio) root.sinkAudio.volume = p / 100.0
		else { root.outVolPct = p; runCmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ " + p + "%") }
	}
	function setSourceVolume(pct) {
		let p = Math.max(0, Math.min(100, Math.round(pct)))
		if (root.sourceAudio) root.sourceAudio.volume = p / 100.0
		else { root.micVolPct = p; runCmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SOURCE@ " + p + "%") }
	}
	function toggleSinkMute() {
		if (root.sinkAudio) root.sinkAudio.muted = !root.sinkAudio.muted
		else { root.outMuted = !root.outMuted; runCmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") }
	}
	function toggleSourceMute() {
		if (root.sourceAudio) root.sourceAudio.muted = !root.sourceAudio.muted
		else { root.micMuted = !root.micMuted; runCmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle") }
	}
	function toggleWallpaperMode() {
		root.animWallpapers = !root.animWallpapers
		runCmd("\"" + root.homeDir + "/.config/wallpapers/theme-switcher.sh\" " + (root.animWallpapers ? "animated" : "static") + " &")
	}
	function toggleUiEffects() {
		root.cfgEnableEffects = !root.cfgEnableEffects
		let fxStr = root.cfgEnableEffects ? "true" : "false"
		let hyprCmd = root.isHyprland ? ("hyprctl keyword decoration:blur:enabled " + fxStr + " >/dev/null 2>&1; ") : ""
		runCmd(hyprCmd + "sed -i 's/\"uiEffects\": *[a-z]*/\"uiEffects\": " + fxStr + "/' \"" + root.homeDir + "/.config/quickshell/colors.json\" \"" + root.homeDir + "/.config/wallust/templates/colors-quickshell.json\" 2>/dev/null || true")
	}
	function togglePrimaryNetwork() {
		if (root.ethIface !== "" && (!root.hasWifiHw || root.ethConnected)) runCmd("nmcli dev " + (root.ethConnected ? "disconnect " : "connect ") + root.ethIface)
		else if (root.hasWifiHw) runCmd("nmcli radio wifi " + (root.wifiEnabled ? "off" : "on"))
		sysPoll.running = true
	}
	function applyNightLight() {
		if (root.nightLightOn) runCmd("pkill -x wlsunset 2>/dev/null; wlsunset -t " + root.nightLightTemp + " -T " + (root.nightLightTemp + 1) + " &")
		else runCmd("pkill -x wlsunset 2>/dev/null")
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

	Component.onCompleted: {
		updateCalendar()
		initPoll.running = true
		checkFirstRunNiri()
	}

	FileView {
		id: colorFile
		path: root.homeDir + "/.config/quickshell/colors.json"
		blockLoading: true; watchChanges: true
		onFileChanged: reload()
		onLoaded: {
			try {
				let d = JSON.parse(text())
				if (d.wallpaper) root.wallpaperPath = d.wallpaper
				if (d.wallMode) root.animWallpapers = (d.wallMode === "animated")
				if (d.uiEffects !== undefined && !root.isVM) root.cfgEnableEffects = Boolean(d.uiEffects)
				if (d.firstRunDone !== undefined) root.firstRunDone = Boolean(d.firstRunDone)
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
		target: root.sinkAudio
		function onVolumeChanged() { root.triggerOsd("volume") }
		function onMutedChanged() { root.triggerOsd("volume") }
	}
	Connections {
		target: root.sourceAudio
		function onVolumeChanged() { root.triggerOsd("mic") }
		function onMutedChanged() { root.triggerOsd("mic") }
	}

	Timer { id: osdTimer; interval: 2000; onTriggered: root.osdMode = "volume" }
	Timer { id: wsCollapseTimer; interval: 1400; onTriggered: root.wsExpanded = false }
	Timer { id: autoCloseTimer; interval: 4500; onTriggered: { if (root.centerMode !== "none" && root.wifiPromptSsid === "") root.closeCenterPill() } }
	Timer { id: popupTimer; interval: 5000; onTriggered: root.popupNotifications = [] }

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
	IpcHandler { target: "overview"; function toggle(): void { root.openOverview() } function close(): void { if (root.centerMode === "overview") root.closeCenterPill() } }
	IpcHandler { target: "controlcenter"; function toggle(): void { if (root.centerMode === "system") root.closeCenterPill(); else root.openSystemPanel() } }
	IpcHandler { target: "lock"; function lock(): void { root.triggerLock() } }
	IpcHandler { target: "theme"; function reload(): void { colorFile.reload() } }
	IpcHandler { target: "bar"; function toggle(): void { root.barVisible = !root.barVisible } }

	Process {
		id: initPoll
		command: ["bash", "-c", "
			u=$(awk -F: '$3>=1000 && $3<60000 && $1!=\"nobody\" && $1!=\"greeter\"{printf \"%s,\", tolower($1)}' /etc/passwd)
			printf '%s|%s|%s\n' \"$(awk -F': ' '/model name/{print $2; exit}' /proc/cpuinfo)\" \"$(uname -r)\" \"${u%,}\"
		"]
		stdout: SplitParser {
			onRead: data => {
				let p = data.trim().split("|")
				if (p.length >= 2) { root.cpuModel = p[0] || "CPU"; root.kernelVer = p[1] || "Linux" }
				if (p.length >= 3 && p[2] !== "") {
					let uArr = p[2].split(",").filter(x => x !== "")
					if (uArr.length > 0) {
						root.usersList = uArr
						let idx = uArr.indexOf(root.currentSessionUser)
						root.selectedUserIdx = idx >= 0 ? idx : 0
					}
				}
			}
		}
	}

	Process {
		id: overviewPoll
		command: ["bash", "-c", "
			if [[ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ]]; then
				hyprctl clients -j 2>/dev/null | awk 'BEGIN{RS=\"}\"}/\"address\":/{match($0,/\"address\": *\"[^\"]*\"/); addr=substr($0,RSTART+11,RLENGTH-12); gsub(/^\"|\"$/,\"\",addr); match($0,/\"id\": *[0-9-]+/); ws=substr($0,RSTART+5,RLENGTH-5); gsub(/[^0-9-]/,\"\",ws); match($0,/\"class\": *\"[^\"]*\"/); cls=substr($0,RSTART+9,RLENGTH-10); gsub(/^\"|\"$/,\"\",cls); match($0,/\"title\": *\"[^\"]*\"/); ttl=substr($0,RSTART+9,RLENGTH-10); gsub(/^\"|\"$/,\"\",ttl); if (ws > 0 && addr != \"\") printf \"%s^%s^%s^%s;\", ws, cls, ttl, addr}'
			elif [[ -n \"$NIRI_SOCKET\" ]]; then
				niri msg -j windows 2>/dev/null | awk 'BEGIN{RS=\"}\"}/\"id\":/{match($0,/\"id\": *[0-9]+/); id=substr($0,RSTART+5,RLENGTH-5); gsub(/[^0-9]/,\"\",id); match($0,/\"workspace_id\": *[0-9]+/); ws=substr($0,RSTART+15,RLENGTH-15); gsub(/[^0-9]/,\"\",ws); match($0,/\"app_id\": *\"[^\"]*\"/); cls=substr($0,RSTART+10,RLENGTH-11); gsub(/^\"|\"$/,\"\",cls); match($0,/\"title\": *\"[^\"]*\"/); ttl=substr($0,RSTART+9,RLENGTH-10); gsub(/^\"|\"$/,\"\",ttl); if (id != \"\") printf \"%s^%s^%s^%s;\", ws, cls, ttl, id}'
			fi
		"]
		stdout: SplitParser {
			onRead: data => {
				let r = data.trim().split(";"), arr = []
				for (let i = 0; i < r.length; i++) {
					let f = r[i].split("^")
					if (f.length >= 4 && f[3] !== "") arr.push({ "ws": f[0], "app": f[1], "title": f[2], "id": f[3] })
				}
				root.overviewWindows = arr
			}
		}
	}

	Process {
		id: fastPoll
		command: ["bash", "-c", "
			b=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%' || echo 100)
			fs=0
			if [[ -n \"$NIRI_SOCKET\" ]]; then
				ws=$(niri msg -j workspaces 2>/dev/null | awk 'BEGIN{RS=\"}\";ORS=\"\"}/\"idx\":/{match($0,/\"idx\":[0-9]+/);idx=substr($0,RSTART+6,RLENGTH-6);act=($0~/\"is_active\":true/)?\"1\":\"0\";occ=($0~/\"active_window_id\":null/)?\"0\":\"1\";print idx\":\"act\":\"occ\" \"}')
				niri msg focused-window 2>/dev/null | grep -qiE 'fullscreen.*yes|is_fullscreen.*true' && fs=1
			elif [[ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ]]; then
				act=$(hyprctl activeworkspace -j 2>/dev/null | awk -F': ' '/\"id\":/{gsub(/,/,\"\",$2);print $2;exit}')
				occ_l=$(hyprctl workspaces -j 2>/dev/null | awk 'BEGIN{RS=\"}\"}/\"windows\": *[1-9]/{match($0,/\"id\": *[0-9]+/);print substr($0,RSTART+5,RLENGTH-5)}')
				ws=\"\"; for i in 1 2 3 4 5; do a=0; [[ \"$i\" == \"$act\" ]] && a=1; o=0; echo \"$occ_l\" | grep -qx \"$i\" && o=1; ws+=\"$i:$a:$o \"; done
				hyprctl activewindow -j 2>/dev/null | grep -qE '\"fullscreen\": *(1|2|true)' && fs=1
			fi
			printf '%s|%s|%d\n' \"${b:-100}\" \"$ws\" \"$fs\"
		"]
		stdout: SplitParser {
			onRead: data => {
				let p = data.trim().split("|")
				if (p.length < 2) return
				let b = parseInt(p[0]) || 100
				if (root.lastBrightnessPct !== -1 && b !== root.lastBrightnessPct) root.triggerOsd("brightness")
				root.brightnessPct = b; root.lastBrightnessPct = b

				let wsRaw = p[1].trim()
				let items = wsRaw.split(/\s+/), list = [], cur = root.lastActiveWs
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
					if (root.lastWsSignature !== "" && wsRaw !== root.lastWsSignature) {
						root.lastActiveWs = cur; root.wsExpanded = true; wsCollapseTimer.restart()
					} else root.lastActiveWs = cur
					root.lastWsSignature = wsRaw
				}
				if (p.length >= 3) root.hasActiveFullWindow = (p[2] === "1")
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
				e_on=1; e_ip=$(ip -4 -o addr show dev \"$e_dev\" 2>/dev/null | awk '{print $4}' | head -n1); [[ -z \"$e_ip\" ]] && e_ip=\"Connected\"
			fi
			w_hw=0; nmcli -t -f TYPE dev 2>/dev/null | grep -qx 'wifi' && w_hw=1
			w_rad=$(nmcli radio wifi 2>/dev/null)
			w_con=$(nmcli -t -f TYPE,STATE,CONNECTION dev 2>/dev/null | awk -F: '$1==\"wifi\" && $2==\"connected\"{print $3; exit}')
			if [[ -n \"$w_con\" ]]; then net=\"$w_con\"; elif [[ \"$e_on\" -eq 1 ]]; then net=\"Ethernet\"; else net=\"Offline\"; fi
			bt_line=$(bluetoothctl list 2>/dev/null | grep '^Controller' | head -n1)
			if [[ -z \"$bt_line\" ]]; then bt_hw=0; bt_en=0; bt_name=\"No Adapter\"
			else
				bt_hw=1
				if rfkill list bluetooth 2>/dev/null | grep -q 'Soft blocked: yes' || ! bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then bt_en=0; bt_name=\"Off\"
				else bt_en=1; bt_c=$(bluetoothctl info 2>/dev/null | awk -F': ' '/Name:/{print $2; exit}'); bt_name=\"${bt_c:-On}\"; fi
			fi
			hp=0; hmic=0
			[[ \"$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | tr '[:upper:]' '[:lower:]')\" =~ (headphone|headset|bluez|earphone|buds) ]] && hp=1
			[[ \"$(wpctl inspect @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | tr '[:upper:]' '[:lower:]')\" =~ (headset|bluez|buds|headphone) ]] && hmic=1
			cpu_u=$(awk '/^cpu /{u=$2+$4; t=$2+$4+$5; if(t>0) printf \"%d\", (u*100)/t; else print 0}' /proc/stat)
			ram_s=$(free -m | awk '/^Mem:/{printf \"%.1f / %.1f GiB|%d\", $3/1024, $2/1024, ($3*100)/$2}')
			d_root=$(df -h / | awk 'NR==2{gsub(/%/,\"\",$5); printf \"%s / %s|%d\", $3, $2, $5}')
			d_sec=$(df -h | awk '$6 ~ /^\\/media\\//{printf \"%s: %s / %s (%s)\", $6, $3, $2, $5; exit}')
			bat_d=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1)
			if [[ -n \"$bat_d\" ]]; then
				ef=$(cat \"$bat_d/energy_full\" 2>/dev/null || cat \"$bat_d/charge_full\" 2>/dev/null || echo 100)
				efd=$(cat \"$bat_d/energy_full_design\" 2>/dev/null || cat \"$bat_d/charge_full_design\" 2>/dev/null || echo 100)
				b_h=\"$(( ef * 100 / (efd > 0 ? efd : 100) ))%\"
				b_p=$(awk -v p=\"$(cat \"$bat_d/power_now\" 2>/dev/null || echo 0)\" 'BEGIN{printf \"%.1f W\", p/1000000}')
				b_c=$(cat \"$bat_d/cycle_count\" 2>/dev/null || echo 0); b_t=$(cat \"$bat_d/technology\" 2>/dev/null || echo \"Li-ion\")
			else b_h=\"AC Power\"; b_p=\"0.0 W\"; b_c=\"N/A\"; b_t=\"Virtual / AC\"; fi
			dpms_off=0; grep -q '^Off$' /sys/class/drm/*/dpms 2>/dev/null && dpms_off=1
			printf '%d|%s|%d|%s|%d|%s|%s|%d|%d|%s|%d|%d|%d|%s|%s|%s|%s|%s|%s|%s|%s|%d\n' \"$((t/1000))\" \"${e_dev:-}\" \"$e_on\" \"$e_ip\" \"$w_hw\" \"${w_rad:-disabled}\" \"$net\" \"$bt_hw\" \"$bt_en\" \"$bt_name\" \"$hp\" \"$hmic\" \"${cpu_u:-10}\" \"$ram_s\" \"$d_root\" \"${d_sec:-No secondary drive}\" \"$(uptime -p 2>/dev/null | sed 's/^up //')\" \"$b_h\" \"$b_p\" \"$b_c\" \"$b_t\" \"$dpms_off\"
		"]
		stdout: SplitParser {
			onRead: data => {
				let p = data.trim().split("|")
				if (p.length >= 24) {
					root.cpuTemp = parseInt(p[0]) || 40; root.ethIface = p[1]; root.ethConnected = (p[2] === "1"); root.ethIp = p[3]
					root.hasWifiHw = (p[4] === "1"); root.wifiEnabled = (p[5] === "enabled") && root.hasWifiHw; root.netName = p[6]
					root.hasBtAdapter = (p[7] === "1"); root.btEnabled = (p[8] === "1"); root.btName = p[9]
					root.isHeadphones = (p[10] === "1"); root.isHeadsetMic = (p[11] === "1"); root.cpuUsage = parseInt(p[12]) || 0
					root.ramInfo = p[13]; root.ramPct = parseInt(p[14]) || 0; root.diskRootInfo = p[15]; root.diskRootPct = parseInt(p[16]) || 0
					root.diskSecInfo = p[17]; root.uptimeStr = p[18]; root.batHealth = p[19]; root.batPowerDraw = p[20]; root.batCycles = p[21]; root.batTech = p[22]
					root.isMonitorDpmsOff = (p[23] === "1")
				}
			}
		}
	}

	Process {
		id: subPoll
		command: ["bash", "-c", "
			sub=\"" + root.sysSubmenu + "\"
			if [[ \"$sub\" == \"net\" ]]; then
				nets=$(nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID,CHAN,RATE,BARS dev wifi list --rescan no 2>/dev/null | head -n 12 | awk -F: 'length($4)>0 {printf \"%s^%s^%s^%s^Ch %s • %s • %s • %s;\", ($1==\"*\"?\"1\":\"0\"), $2, ($3==\"\"?\"Open\":$3), $4, $5, $6, ($3==\"\"?\"Unsecured\":$3), $7}')
				saved=$(nmcli -t -f NAME,TYPE connection show 2>/dev/null | awk -F: '$2==\"802-11-wireless\"{printf \"%s;\", $1}')
				printf 'NET:%s\nSAVED:%s\n' \"$nets\" \"$saved\"
			elif [[ \"$sub\" == \"bt\" ]]; then
				bts=\"\"; paired=\"\"
				if bluetoothctl list 2>/dev/null | grep -q '^Controller'; then
					while read -r _ mac name; do
						[[ -z \"$mac\" ]] && continue
						info=$(bluetoothctl info \"$mac\" 2>/dev/null)
						con=0; echo \"$info\" | grep -q 'Connected: yes' && con=1
						prd=0; echo \"$info\" | grep -q 'Paired: yes' && prd=1
						icn=$(echo \"$info\" | awk -F': ' '/Icon:/{print $2; exit}')
						bat=$(echo \"$info\" | awk -F'[()]' '/Battery Percentage:/{print $2\"%\"; exit}')
						det=\"MAC: $mac • Type: ${icn:-Device}${bat:+ • Bat: $bat}\"
						bts+=\"${con}^${mac}^${name:-$mac}^${det};\"
						[[ \"$prd\" -eq 1 ]] && paired+=\"${mac}^${name:-$mac};\"
					done < <(bluetoothctl devices 2>/dev/null | grep -E '^Device ([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | head -n 12)
				fi
				printf 'BT:%s\nPAIRED:%s\n' \"$bts\" \"$paired\"
			elif [[ \"$sub\" == \"sound\" || \"$sub\" == \"mic\" ]]; then
				sinks=$(wpctl status 2>/dev/null | awk '/Sinks:/,/Sources:/' | grep -E '[0-9]+\\.' | while read -r l; do act=0; [[ \"$l\" == *\"*\"* ]] && act=1; c=$(echo \"$l\" | sed 's/^[^0-9]*//'); id=${c%%.*}; r=${c#*. }; printf '%s^%s^%d;' \"$id\" \"${r%% \\[vol*}\" \"$act\"; done)
				srcs=$(wpctl status 2>/dev/null | awk '/Sources:/,/Filters:|Streams:/' | grep -E '[0-9]+\\.' | while read -r l; do act=0; [[ \"$l\" == *\"*\"* ]] && act=1; c=$(echo \"$l\" | sed 's/^[^0-9]*//'); id=${c%%.*}; r=${c#*. }; printf '%s^%s^%d;' \"$id\" \"${r%% \\[vol*}\" \"$act\"; done)
				printf 'SINK:%s\nSRC:%s\n' \"$sinks\" \"$srcs\"
			elif [[ \"$sub\" == \"display\" ]]; then
				if [[ -n \"$NIRI_SOCKET\" ]]; then
					disp=$(niri msg outputs 2>/dev/null | awk '/^Output /{if(name!=\"\")printf \"%s^%s^%s^%s;\",name,cur,scale,modes; match($0,/\\([^)]+\\)/); name=substr($0,RSTART+1,RLENGTH-2); cur=\"1920x1080@60\"; scale=\"1.0\"; modes=\"\"; mcount=0} /\\(current\\)/{m=$1; sub(/\\..*@/,\"@\",m); cur=m; if(mcount<8){modes=modes (modes==\"\"?\"\":\",\") m; mcount++}} /^[[:space:]]+[0-9]+x[0-9]+@/ && !/\\(current\\)/{if(mcount<8){m=$1; sub(/\\..*@/,\"@\",m); if(index(modes,m)==0){modes=modes (modes==\"\"?\"\":\",\") m; mcount++}}} /Scale:/{scale=$2} END{if(name!=\"\")printf \"%s^%s^%s^%s;\",name,cur,scale,modes}')
				elif [[ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ]]; then
					disp=$(hyprctl monitors 2>/dev/null | awk '/^Monitor /{if(name!=\"\")printf \"%s^%s^%s^%s;\",name,cur,scale,modes; name=$2; cur=\"1920x1080@60\"; scale=\"1.0\"; modes=\"\"} /^[[:space:]]+[0-9]+x[0-9]+@/{m=$1; sub(/\\..*$/,\"\",m); cur=m} /^[[:space:]]+scale:/{scale=$2} /availableModes:/{for(i=2;i<=NF&&i<=9;i++){m=$i; sub(/\\..*Hz/,\"\",m); sub(/Hz/,\"\",m); modes=modes (modes==\"\"?\"\":\",\") m}} END{if(name!=\"\")printf \"%s^%s^%s^%s;\",name,cur,scale,modes}')
				fi
				printf 'DISP:%s\n' \"$disp\"
			fi
		"]
		stdout: SplitParser {
			onRead: data => {
				let l = data.trim()
				if (l.startsWith("NET:")) {
					let r = l.substring(4).split(";"), a = []
					for (let i = 0; i < r.length; i++) {
						let f = r[i].split("^")
						if (f.length >= 5) a.push({ "connected": f[0] === "1", "signal": f[1], "sec": f[2], "ssid": f[3], "id": f[3], "details": f[4] })
					}
					root.netList = a
				} else if (l.startsWith("SAVED:")) {
					let s = l.substring(6).split(";").filter(x => x.trim() !== ""), a = []
					for (let i = 0; i < s.length; i++) a.push({ "id": s[i], "name": s[i] })
					root.savedWifiList = a
				} else if (l.startsWith("BT:")) {
					let r = l.substring(3).split(";"), a = []
					for (let i = 0; i < r.length; i++) {
						let f = r[i].split("^")
						if (f.length >= 4) a.push({ "connected": f[0] === "1", "id": f[1], "ssid": f[2], "signal": "", "sec": "", "details": f[3] })
					}
					root.btList = a
				} else if (l.startsWith("PAIRED:")) {
					let r = l.substring(7).split(";"), a = []
					for (let i = 0; i < r.length; i++) {
						let f = r[i].split("^")
						if (f.length >= 2 && f[0] !== "") a.push({ "id": f[0], "name": f[1] })
					}
					root.pairedBtList = a
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
			raw=$(curl -s --max-time 5 'wttr.in/?format=%C~%t~%f~%w~%h~%p~%u~%P~%l' || true)
			IFS='~' read -r cond temp feels wind hum precip uv press loc <<< \"$raw\"
			[[ -z \"$temp\" || \"$raw\" == *Unknown* ]] && exit 0
			lc=\"${cond,,}\"; icon=\"󰖕\"
			if [[ \"$lc\" =~ (sun|clear) ]]; then icon=\"󰖙\"
			elif [[ \"$lc\" =~ (partly) ]]; then icon=\"󰖕\"
			elif [[ \"$lc\" =~ (cloud|overcast) ]]; then icon=\"󰖐\"
			elif [[ \"$lc\" =~ (rain|drizzle|shower) ]]; then icon=\"󰖗\"
			elif [[ \"$lc\" =~ (thunder|storm) ]]; then icon=\"󰖓\"
			elif [[ \"$lc\" =~ (snow|sleet|ice|blizzard) ]]; then icon=\"󰖘\"
			elif [[ \"$lc\" =~ (fog|mist|haze) ]]; then icon=\"󰖑\"; fi
			fc=$(curl -s --max-time 5 'wttr.in/?format=j1' 2>/dev/null | awk -F'\"' '
				/\"date\":/ && d<3 { d++; dt[d]=$4 }
				/\"maxtempC\":/ && mx<3 { mx++; maxc[mx]=$4 }
				/\"mintempC\":/ && mn<3 { mn++; minc[mn]=$4 }
				END { for(i=1;i<=d;i++) printf \"%s^+%s°C / +%s°C;\", (i==1?\"Today\":(i==2?\"Tomorrow\":dt[i])), minc[i], maxc[i] }
			' || true)
			printf '%s %s|%s • Temp: %s (Feels %s) • Wind: %s • Hum: %s|%s|%s|%s|%s • UV %s|%s|%s\n' \"$icon\" \"$temp\" \"$cond\" \"$temp\" \"$feels\" \"$wind\" \"$hum\" \"${loc%%,*}\" \"$wind\" \"$hum\" \"${precip:-0.0mm}\" \"${uv:-0}\" \"${press:-1013hPa}\" \"$fc\"
		"]
		stdout: SplitParser {
			onRead: data => {
				let p = data.trim().split("|")
				if (p.length >= 2 && p[0] !== "") {
					root.weatherShort = p[0]; root.weatherDetail = p[1]
					if (p.length >= 8) {
						root.weatherLoc = p[2] || "Local Area"
						root.weatherWind = p[3] || "--"; root.weatherHum = p[4] || "--"
						root.weatherPrecip = p[5] || "0 mm"; root.weatherPress = p[6] || "1013 hPa"
						let fRaw = p[7].split(";"), fArr = []
						for (let i = 0; i < fRaw.length; i++) {
							let kv = fRaw[i].split("^")
							if (kv.length >= 2 && kv[0] !== "") fArr.push({ "day": kv[0], "temps": kv[1] })
						}
						root.weatherForecast = fArr
					}
				}
			}
		}
	}

	Timer { interval: root.isVM ? 800 : 350; running: !root.screenLocked && !root.isMonitorDpmsOff; repeat: true; onTriggered: fastPoll.running = true }
	Timer { interval: 1800000; running: true; repeat: true; onTriggered: weatherProc.running = true }
	Timer {
		interval: 1000; running: true; repeat: true; triggeredOnStart: true
		property int tick: 0
		onTriggered: {
			let now = new Date()
			root.timeStr = Qt.formatDateTime(now, "HH:mm")
			root.dateStr = Qt.formatDateTime(now, "dd MMM")
			if (root.isRecording) root.recSeconds++
			if (tick === 2) { weatherProc.running = true; sysPoll.running = true }
			if (tick % 2 === 0 && root.activePlayer && !root.screenLocked && !root.isMonitorDpmsOff) {
				root.mediaProg = (root.activePlayer.length > 0) ? Math.min(1, Math.max(0, root.activePlayer.position / root.activePlayer.length)) : 0.25
			}
			if (root.centerMode === "system" && tick % 3 === 0) sysPoll.running = true
			else if (root.animWallpapers && tick % 12 === 0) sysPoll.running = true
			if (tick > 2 && tick % 15 === 0 && root.weatherShort.includes("--")) weatherProc.running = true
			if (tick % 4 === 0 && root.centerMode === "system" && root.sysSubmenu !== "") subPoll.running = true
			tick = (tick + 1) % 3600
		}
	}

	// 1A. NIRI OVERVIEW BLURRED BACKDROP LAYER
	Variants {
		model: Quickshell.screens
		PanelWindow {
			required property var modelData
			screen: modelData; visible: !root.isHyprland
			WlrLayershell.layer: WlrLayer.Background; WlrLayershell.namespace: "wallpaper-backdrop"
			WlrLayershell.exclusionMode: ExclusionMode.Ignore
			anchors { top: true; bottom: true; left: true; right: true }
			color: root.bg

			Image {
				id: backdropWall; anchors.fill: parent
				source: root.wallpaperPath !== "" ? (root.isVideoFile ? "file:///tmp/wall_frame.jpg" : "file://" + root.wallpaperPath) : ""
				fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false
				visible: !root.fxActive
			}
			MultiEffect {
				anchors.fill: parent; source: backdropWall
				visible: root.fxActive && root.wallpaperPath !== ""
				blurEnabled: visible; blurMax: 48; blur: 1.0
			}
			Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.35) }
		}
	}

	// 1B. NATIVE DESKTOP WALLPAPER
	Variants {
		model: Quickshell.screens
		PanelWindow {
			required property var modelData
			screen: modelData
			WlrLayershell.layer: WlrLayer.Background; WlrLayershell.namespace: "wallpaper"
			WlrLayershell.exclusionMode: ExclusionMode.Ignore
			anchors { top: true; bottom: true; left: true; right: true }
			color: root.bg

			Item {
				id: wallContainer; anchors.fill: parent

				NumberAnimation {
					id: wallFadeAnim; target: wallContainer; property: "opacity"; from: 0.2; to: 1.0
					duration: root.fxActive && root.cfgWallpaperTransition !== "none" ? root.cfgWallpaperTransitionMs : 0
					easing.type: Easing.OutCubic
				}
				NumberAnimation {
					id: wallZoomAnim; target: wallContainer; property: "scale"; from: root.cfgWallpaperTransition === "zoom" ? 1.04 : 1.0; to: 1.0
					duration: root.fxActive && root.cfgWallpaperTransition === "zoom" ? root.cfgWallpaperTransitionMs : 0
					easing.type: Easing.OutCubic
				}

				Connections {
					target: root
					function onWallpaperPathChanged() {
						if (root.fxActive && root.cfgWallpaperTransition !== "none") {
							wallFadeAnim.restart()
							if (root.cfgWallpaperTransition === "zoom") wallZoomAnim.restart()
						}
					}
					function onShouldPlayAnimationChanged() {
						if (!root.isVideoFile || !root.animWallpapers) { wallVideoPlayer.stop(); return }
						if (root.shouldPlayAnimation) wallVideoPlayer.play()
						else wallVideoPlayer.pause()
					}
				}

				Image {
					anchors.fill: parent; visible: !root.isVideoFile && !root.isAnimatedGif
					source: (!root.isVideoFile && !root.isAnimatedGif && root.wallpaperPath !== "") ? "file://" + root.wallpaperPath : ""
					fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false; smooth: true
				}
				AnimatedImage {
					anchors.fill: parent; visible: root.isAnimatedGif
					source: (root.isAnimatedGif && root.wallpaperPath !== "") ? "file://" + root.wallpaperPath : ""
					playing: visible && root.shouldPlayAnimation
					fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false; smooth: true
				}
				MediaPlayer {
					id: wallVideoPlayer
					source: (root.animWallpapers && root.isVideoFile && root.wallpaperPath !== "") ? "file://" + root.wallpaperPath : ""
					loops: MediaPlayer.Infinite; videoOutput: wallVideoOut
					onSourceChanged: {
						if (root.animWallpapers && root.isVideoFile && root.wallpaperPath !== "" && root.shouldPlayAnimation) play()
						else stop()
					}
				}
				VideoOutput {
					id: wallVideoOut; anchors.fill: parent; visible: root.animWallpapers && root.isVideoFile; fillMode: VideoOutput.PreserveAspectCrop
				}
			}
		}
	}

	// 2. INVISIBLE 40px TOP SPACER (Leaves 8px above bar and 8px below bar with Niri 16px gaps)
	Variants {
		model: Quickshell.screens
		PanelWindow {
			required property var modelData
			screen: modelData; visible: root.barVisible && !root.isGreeterMode
			WlrLayershell.layer: WlrLayer.Top; WlrLayershell.namespace: "waybar-spacer"
			WlrLayershell.exclusionMode: ExclusionMode.Normal; exclusiveZone: 40
			anchors { top: true; left: true; right: true }
			implicitHeight: 40; color: "transparent"
		}
	}

	// 3. CLICK-OUTSIDE BACKDROP LAYER
	Variants {
		model: Quickshell.screens
		PanelWindow {
			required property var modelData
			screen: modelData; visible: root.centerMode !== "none" && !root.screenLocked
			WlrLayershell.layer: WlrLayer.Top; WlrLayershell.namespace: "qs-backdrop"
			WlrLayershell.exclusionMode: ExclusionMode.Ignore
			anchors { top: true; bottom: true; left: true; right: true }
			color: "transparent"
			MouseArea {
				anchors.fill: parent
				acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
				onClicked: root.closeCenterPill()
			}
		}
	}

	// 4. DYNAMIC ISLAND TOP BAR (Center Pill Pinned Dead-Center, Left Pill Expands Leftward)
	Variants {
		model: Quickshell.screens
		PanelWindow {
			id: islandWin
			required property var modelData
			screen: modelData; visible: root.barVisible && !root.screenLocked
			WlrLayershell.layer: (root.centerMode === "none" && !centerPill.isHoverPreview && !leftPill.showMediaCard) ? WlrLayer.Top : WlrLayer.Overlay
			WlrLayershell.namespace: "waybar"; WlrLayershell.exclusionMode: ExclusionMode.Ignore
			WlrLayershell.keyboardFocus: (root.centerMode === "launcher" || root.wifiPromptSsid !== "") ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
			anchors { top: true }
			margins.top: 8
			implicitWidth: centerPill.width + (Math.max(leftPill.width, rightOsdPill.width) * 2) + 32
			implicitHeight: Math.max(leftPill.height, centerPill.height + (launcherListCard.visible ? (launcherListCard.height + 8) : 0), rightOsdPill.height) + 8
			color: "transparent"

			function grabKeyboardNow() {
				if (root.centerMode === "launcher" && !launcherSearchInput.activeFocus) launcherSearchInput.forceActiveFocus()
				else if (root.wifiPromptSsid !== "" && !wifiPwField.activeFocus) wifiPwField.forceActiveFocus()
			}

			Timer { id: focusTimer1; interval: 30; repeat: false; onTriggered: islandWin.grabKeyboardNow() }

			Connections {
				target: root
				function onCenterModeChanged() { if (root.centerMode === "launcher") { launcherSearchInput.text = ""; focusTimer1.restart() } }
				function onWifiPromptSsidChanged() { if (root.wifiPromptSsid !== "") focusTimer1.restart() }
			}

			// UNIFIED LEFT PILL (Anchored to left of centerPill -> expands strictly leftward!)
			Rectangle {
				id: leftPill
				anchors.top: parent.top
				anchors.right: centerPill.left
				anchors.rightMargin: 10
				property bool hasMedia: root.activePlayer !== null
				property bool showWsStrip: root.wsExpanded || (!hasMedia && leftHover.hovered)
				property bool showMediaCard: hasMedia && !root.wsExpanded && leftHover.hovered
				property bool showMediaCompact: hasMedia && !root.wsExpanded && !leftHover.hovered

				width: showMediaCard ? 330 : (showWsStrip ? (wsRow.implicitWidth + 16) : 40)
				height: showMediaCard ? 150 : 40
				radius: showMediaCard ? 22 : 20
				color: root.withAlpha(root.bg, root.panelAlpha)
				border.width: showMediaCard ? 2 : (showMediaCompact ? 0 : 1)
				border.color: showMediaCard ? root.color4 : root.withAlpha(root.color4, 0.6)
				clip: true
				Behavior on width { NumberAnimation { duration: root.animMs; easing.type: root.cfgIslandEasing } }
				Behavior on height { NumberAnimation { duration: root.animMs; easing.type: root.cfgIslandEasing } }
				HoverHandler { id: leftHover }

				Connections {
					target: root
					function onMediaProgChanged() { if (leftPill.showMediaCompact) mediaArcCanvas.requestPaint() }
					function onColor4Changed() { if (leftPill.showMediaCompact) mediaArcCanvas.requestPaint() }
				}

				MouseArea {
					anchors.fill: parent; acceptedButtons: Qt.NoButton
					onWheel: wheel => {
						let targetWs = Math.max(1, root.lastActiveWs + (wheel.angleDelta.y > 0 ? -1 : 1))
						root.wsExpanded = true; wsCollapseTimer.restart()
						root.runCmd((root.isHyprland ? "hyprctl dispatch workspace " : "niri msg action focus-workspace ") + targetWs)
					}
				}

				Text {
					anchors.centerIn: parent; visible: !leftPill.showWsStrip && !leftPill.hasMedia
					text: root.lastActiveWs.toString()
					color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.bold: true
				}

				Item {
					anchors.fill: parent; visible: leftPill.showMediaCompact
					onVisibleChanged: { if (visible) mediaArcCanvas.requestPaint() }
					Canvas {
						id: mediaArcCanvas; anchors.fill: parent
						onPaint: root.paintArc(mediaArcCanvas, root.mediaProg, root.color4)
					}
					Rectangle {
						anchors.centerIn: parent; width: 26; height: 26; radius: 13; color: root.color0; clip: true
						Image { anchors.fill: parent; source: (root.activePlayer && root.activePlayer.trackArtUrl) ? root.activePlayer.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; visible: source != "" }
						Text { anchors.centerIn: parent; visible: !root.activePlayer || !root.activePlayer.trackArtUrl; text: "󰝚"; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
					}
				}

				RowLayout {
					id: wsRow; anchors.centerIn: parent; visible: leftPill.showWsStrip; spacing: 6
					Repeater {
						model: root.workspacesList
						Rectangle {
							required property var modelData
							implicitWidth: 26; implicitHeight: 26; radius: 8
							color: modelData.active ? root.color4 : (modelData.occupied ? root.withAlpha(root.color2, 0.25) : Qt.rgba(1, 1, 1, 0.06))
							border.width: modelData.occupied && !modelData.active ? 1 : 0; border.color: root.color2
							Text { anchors.centerIn: parent; text: modelData.idx.toString(); color: modelData.active ? root.bg : (modelData.occupied ? root.color2 : root.color8); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true }
							MouseArea { anchors.fill: parent; onClicked: root.runCmd((root.isHyprland ? "hyprctl dispatch workspace " : "niri msg action focus-workspace ") + modelData.idx) }
						}
					}
				}

				ColumnLayout {
					anchors.fill: parent; anchors.margins: 10; visible: leftPill.showMediaCard; spacing: 8
					RowLayout {
						Layout.fillWidth: true; spacing: 10
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
							Rectangle { width: parent.width * root.mediaProg; height: parent.height; radius: 3; color: root.color6 }
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
						Repeater {
							model: ["prev", "play", "next"]
							Rectangle {
								required property string modelData
								implicitWidth: modelData === "play" ? 32 : 24; implicitHeight: modelData === "play" ? 32 : 24; radius: 8
								color: modelData === "play" ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
								Text {
									anchors.centerIn: parent
									text: modelData === "prev" ? "󰒮" : (modelData === "next" ? "󰒭" : ((root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing) ? "󰏤" : "󰐊"))
									color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: modelData === "play" ? 16 : 18
								}
								MouseArea {
									anchors.fill: parent
									onClicked: {
										if (!root.activePlayer) return
										if (modelData === "prev") root.activePlayer.previous()
										else if (modelData === "next") root.activePlayer.next()
										else root.activePlayer.togglePlaying()
									}
								}
							}
						}
					}
				}
			}

			// CENTER DYNAMIC ISLAND PILL (Morphs into 40px Search Bar when Launcher is open)
			Rectangle {
				id: centerPill
				anchors.top: parent.top
				anchors.horizontalCenter: parent.horizontalCenter

				property bool isHoverPreview: centerHover.hovered && root.centerMode === "none"
				property bool isCalOpen: root.centerMode === "calendar"
				property bool isSysOpen: root.centerMode === "system"
				property bool isLauncherOpen: root.centerMode === "launcher"
				property bool isOverviewOpen: root.centerMode === "overview"

				width: (isHoverPreview || isCalOpen || isSysOpen || isLauncherOpen || isOverviewOpen) ? 380 : (compactClockRow.implicitWidth + 28)
				height: isLauncherOpen ? 40 : (isOverviewOpen ? 400 : (isSysOpen ? (sysContainer.implicitHeight + 52) : (isCalOpen ? (calCardCol.implicitHeight + 52) : (isHoverPreview ? (calPreviewBox.implicitHeight + 52) : 40))))
				radius: 20
				color: root.withAlpha(root.bg, root.panelAlpha)
				border.width: (isCalOpen || isSysOpen || isLauncherOpen || isOverviewOpen) ? 2 : (isHoverPreview ? 0 : 1)
				border.color: (isCalOpen || isSysOpen || isLauncherOpen || isOverviewOpen) ? root.color4 : root.withAlpha(root.color4, 0.6)
				clip: true
				Behavior on width { NumberAnimation { duration: root.animMs; easing.type: root.cfgIslandEasing } }
				Behavior on height { NumberAnimation { duration: root.animMs; easing.type: root.cfgIslandEasing } }

				HoverHandler {
					id: centerHover
					onHoveredChanged: {
						if (hovered) autoCloseTimer.stop()
						else if (root.centerMode === "calendar" || root.centerMode === "system") autoCloseTimer.restart()
					}
				}

				MouseArea {
					anchors.fill: parent; visible: centerPill.isCalOpen || centerPill.isHoverPreview
					acceptedButtons: Qt.RightButton; onClicked: root.openSystemPanel()
				}

				// LAUNCHER 40px MORPHED SEARCH BAR (Directly inside centerPill without nested box)
				RowLayout {
					visible: centerPill.isLauncherOpen
					anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 8
					Text { text: "󰍉"; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
					TextInput {
						id: launcherSearchInput; Layout.fillWidth: true
						color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true; clip: true
						onTextChanged: { root.searchQuery = text; root.selectedAppIndex = 0 }
						Keys.onDownPressed: { if (root.selectedAppIndex < root.filteredApps.length - 1) root.selectedAppIndex++ }
						Keys.onUpPressed: { if (root.selectedAppIndex > 0) root.selectedAppIndex-- }
						Keys.onEscapePressed: root.closeCenterPill()
						Keys.onReturnPressed: { if (root.filteredApps.length > 0) { let a = root.filteredApps[root.selectedAppIndex]; root.closeCenterPill(); a.execute() } }
					}
				}

				// UNIFIED FIXED 40px TOP HEADER
				Item {
					id: topPillBar
					visible: !centerPill.isLauncherOpen && !centerPill.isOverviewOpen
					anchors { top: parent.top; left: parent.left; right: parent.right }
					height: 40

					Item {
						anchors.fill: parent
						visible: (!centerPill.isSysOpen || root.sysSubmenu === "") && (!centerPill.isCalOpen || root.calSubmenu === "")

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
								else if (mouse.button === Qt.RightButton) { if (root.centerMode === "system") root.closeCenterPill(); else root.openSystemPanel() }
								else if (mouse.button === Qt.MiddleButton) root.openLauncher()
							}
						}
					}

					RowLayout {
						visible: (centerPill.isSysOpen && root.sysSubmenu !== "") || (centerPill.isCalOpen && root.calSubmenu !== "")
						anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8

						Rectangle {
							implicitWidth: 24; implicitHeight: 24; radius: 7; color: Qt.rgba(1, 1, 1, 0.08)
							Text { anchors.centerIn: parent; text: "‹"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.bold: true }
							MouseArea {
								anchors.fill: parent
								onClicked: {
									if (centerPill.isCalOpen) root.calSubmenu = ""
									else { root.wifiPromptSsid = ""; root.expandedResMon = ""; root.showSavedList = false; root.expandedDevInfo = ""; root.sysSubmenu = "" }
								}
							}
						}
						Text {
							Layout.fillWidth: true
							text: centerPill.isCalOpen ? "Weather Forecast" : (({ "net": "Network", "bt": "Bluetooth", "tray": "System Tray Apps", "battery": "Battery Details", "sound": "Audio Output", "mic": "Audio Input", "display": "Display", "rec": "Screen Recorder", "cpu": "System Info", "power": "Power Menu" })[root.sysSubmenu] || "")
							color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true
						}
						Rectangle {
							visible: centerPill.isSysOpen && ((root.sysSubmenu === "net" && root.ethIface !== "") || (root.sysSubmenu === "bt" && root.hasBtAdapter) || root.sysSubmenu === "sound" || root.sysSubmenu === "mic")
							implicitWidth: 36; implicitHeight: 18; radius: 9
							property bool isOn: root.sysSubmenu === "net" ? root.ethConnected : (root.sysSubmenu === "bt" ? root.btEnabled : (root.sysSubmenu === "sound" ? !root.outMuted : !root.micMuted))
							color: isOn ? root.color4 : Qt.rgba(1, 1, 1, 0.15)
							Rectangle { width: 12; height: 12; radius: 6; anchors.verticalCenter: parent.verticalCenter; x: parent.isOn ? 20 : 4; color: parent.isOn ? root.bg : root.fg; Behavior on x { NumberAnimation { duration: 120 } } }
							MouseArea {
								anchors.fill: parent
								onClicked: {
									if (root.sysSubmenu === "net" && root.ethIface !== "") root.runCmd("nmcli dev " + (root.ethConnected ? "disconnect " : "connect ") + root.ethIface)
									else if (root.sysSubmenu === "bt" && root.hasBtAdapter) root.runCmd(root.btEnabled ? "bluetoothctl power off; rfkill block bluetooth" : "rfkill unblock bluetooth; bluetoothctl power on")
									else if (root.sysSubmenu === "sound") root.toggleSinkMute()
									else if (root.sysSubmenu === "mic") root.toggleSourceMute()
									sysPoll.running = true; subPoll.running = true
								}
							}
						}
						Rectangle {
							visible: centerPill.isSysOpen && root.sysSubmenu === "rec"; implicitWidth: 74; implicitHeight: 24; radius: 7; color: root.isRecording ? root.color1 : root.color4
							Text { anchors.centerIn: parent; text: root.isRecording ? "󰓛 Stop" : "󰻂 Start"; color: root.bg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true }
							MouseArea { anchors.fill: parent; onClicked: root.toggleRecording() }
						}
						Rectangle {
							visible: centerPill.isSysOpen && root.sysSubmenu === "power"; implicitWidth: 90; implicitHeight: 24; radius: 7; color: root.color1
							Text { anchors.centerIn: parent; text: "󰐥 Poweroff"; color: root.bg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true }
							MouseArea { anchors.fill: parent; onClicked: root.runCmd("loginctl poweroff || sudo -n poweroff || poweroff") }
						}
					}
				}

				// CALENDAR, NOTIFICATIONS & WEATHER SUBMENU
				ColumnLayout {
					id: calCardCol
					visible: centerPill.isHoverPreview || centerPill.isCalOpen
					anchors { top: topPillBar.bottom; left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10 }
					anchors.topMargin: 2; spacing: 8

					Item {
						id: calPreviewBox
						visible: root.calSubmenu === ""
						Layout.fillWidth: true; implicitHeight: calInnerCol.implicitHeight
						ColumnLayout {
							id: calInnerCol; anchors { left: parent.left; right: parent.right }
							spacing: 6
							RowLayout {
								Layout.fillWidth: true
								Rectangle {
									visible: centerPill.isCalOpen; implicitWidth: 24; implicitHeight: 24; radius: 7; color: Qt.rgba(1, 1, 1, 0.08)
									Text { anchors.centerIn: parent; text: "‹"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.bold: true }
									MouseArea {
										anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
										onClicked: mouse => {
											if (mouse.button === Qt.RightButton) root.openSystemPanel()
											else { if (root.calMonth === 0) { root.calMonth = 11; root.calYear-- } else root.calMonth--; root.updateCalendar() }
										}
									}
								}
								Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: Qt.formatDate(new Date(root.calYear, root.calMonth, 1), "MMMM yyyy"); color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true }
								Rectangle {
									visible: centerPill.isCalOpen; implicitWidth: 24; implicitHeight: 24; radius: 7; color: Qt.rgba(1, 1, 1, 0.08)
									Text { anchors.centerIn: parent; text: "›"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.bold: true }
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
										Layout.fillWidth: true; implicitHeight: 26; radius: 7; color: modelData.today ? root.color4 : "transparent"
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
						visible: centerPill.isCalOpen && root.calSubmenu === ""
						Layout.fillWidth: true; implicitHeight: 54; radius: 14
						color: wCardMouse.containsMouse ? Qt.lighter(root.color0, 1.12) : root.color0
						MouseArea {
							id: wCardMouse; anchors.fill: parent; hoverEnabled: true
							acceptedButtons: Qt.LeftButton | Qt.RightButton
							onClicked: { weatherProc.running = true; root.calSubmenu = "weather" }
						}
						Rectangle {
							id: wSumSq
							width: 34; height: 34; radius: 10
							anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
							color: root.withAlpha(root.color4, 0.2)
							Text { anchors.centerIn: parent; text: (root.weatherShort.split(" ")[0] || "󰖕"); color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16 }
						}
						ColumnLayout {
							anchors.left: wSumSq.right; anchors.leftMargin: 10
							anchors.right: parent.right; anchors.rightMargin: 10
							anchors.verticalCenter: parent.verticalCenter; spacing: 1
							Text { text: "Today's Weather  •  " + root.weatherShort; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
							Text { text: root.weatherDetail; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
						}
					}

					ColumnLayout {
						visible: centerPill.isCalOpen && root.calSubmenu === "weather"
						Layout.fillWidth: true; spacing: 8

						Rectangle {
							Layout.fillWidth: true; implicitHeight: 58; radius: 14; color: root.color0
							Rectangle {
								id: wHeroSq
								width: 38; height: 38; radius: 10
								anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
								color: root.withAlpha(root.color4, 0.22)
								Text { anchors.centerIn: parent; text: (root.weatherShort.split(" ")[0] || "󰖕"); color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18 }
							}
							ColumnLayout {
								anchors.left: wHeroSq.right; anchors.leftMargin: 10
								anchors.right: parent.right; anchors.rightMargin: 10
								anchors.verticalCenter: parent.verticalCenter; spacing: 2
								Text { text: root.weatherLoc + "  •  " + root.weatherShort; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
								Text { text: root.weatherDetail; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideRight }
							}
						}

						GridLayout {
							Layout.fillWidth: true; columns: 2; uniformCellWidths: true; rowSpacing: 8; columnSpacing: 8
							Repeater {
								model: [
									{ "icon": "󰖝", "l": "Wind", "v": root.weatherWind },
									{ "icon": "󰖎", "l": "Humidity", "v": root.weatherHum },
									{ "icon": "󰖗", "l": "Precip / UV", "v": root.weatherPrecip },
									{ "icon": "󰥔", "l": "Pressure", "v": root.weatherPress }
								]
								Rectangle {
									required property var modelData
									Layout.fillWidth: true; Layout.preferredWidth: 1; implicitHeight: 52; radius: 14; color: root.color0
									Rectangle {
										id: wGridSq
										width: 34; height: 34; radius: 10
										anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
										color: Qt.rgba(1, 1, 1, 0.08)
										Text { anchors.centerIn: parent; text: modelData.icon; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
									}
									ColumnLayout {
										anchors.left: wGridSq.right; anchors.leftMargin: 8
										anchors.right: parent.right; anchors.rightMargin: 8
										anchors.verticalCenter: parent.verticalCenter; spacing: 1
										Text { text: modelData.l; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideRight }
										Text { text: modelData.v; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
									}
								}
							}
						}

						Repeater {
							model: root.weatherForecast
							Rectangle {
								required property var modelData
								Layout.fillWidth: true; implicitHeight: 44; radius: 12; color: root.color0
								RowLayout {
									anchors.fill: parent; anchors.margins: 6; spacing: 8
									Rectangle {
										implicitWidth: 32; implicitHeight: 32; radius: 9; color: Qt.rgba(1, 1, 1, 0.08)
										Text { anchors.centerIn: parent; text: "󰃭"; color: root.color2; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14 }
									}
									Text { text: modelData.day; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true }
									Text { text: modelData.temps; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true; Layout.rightMargin: 6 }
								}
							}
						}
					}

					ColumnLayout {
						visible: centerPill.isCalOpen && root.calSubmenu === ""
						Layout.fillWidth: true; spacing: 6
						RowLayout {
							Layout.fillWidth: true
							Text { text: "Notifications (" + notifServer.trackedNotifications.values.length + ")"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true }
							Rectangle {
								implicitWidth: 68; implicitHeight: 22; radius: 7; color: Qt.rgba(1, 1, 1, 0.08)
								Text { anchors.centerIn: parent; text: "Clear all"; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.bold: true }
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
							Layout.fillWidth: true; implicitHeight: Math.min(170, Math.max(54, contentHeight)); clip: true; spacing: 6
							model: notifServer.trackedNotifications
							Text { anchors.centerIn: parent; visible: notifServer.trackedNotifications.values.length === 0; text: "No active notifications"; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11 }
							delegate: Rectangle {
								required property var modelData
								width: ListView.view.width; height: 54; radius: 12; color: root.color0
								RowLayout {
									anchors.fill: parent; anchors.margins: 8
									ColumnLayout {
										Layout.fillWidth: true; spacing: 2
										Text { text: modelData.summary || "Notification"; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
										Text { text: modelData.body || ""; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
									}
									Rectangle {
										implicitWidth: 22; implicitHeight: 22; radius: 7; color: Qt.rgba(1, 1, 1, 0.1)
										Text { anchors.centerIn: parent; text: "✕"; color: root.fg; font.pixelSize: 11 }
										MouseArea { anchors.fill: parent; onClicked: modelData.dismiss() }
									}
								}
							}
						}
					}
				}

				// WORKSPACE WINDOWS OVERVIEW
				ColumnLayout {
					visible: centerPill.isOverviewOpen; anchors.fill: parent; anchors.margins: 10; spacing: 8
					RowLayout {
						Layout.fillWidth: true
						Text { text: "󰕰  Workspace Windows Overview"; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true }
						Text { text: root.overviewWindows.length + " open"; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11 }
					}
					ListView {
						Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 6; model: root.overviewWindows
						Text { anchors.centerIn: parent; visible: root.overviewWindows.length === 0; text: "No open windows in workspaces"; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
						delegate: Rectangle {
							required property var modelData
							width: ListView.view.width; height: 46; radius: 12; color: ovMouse.containsMouse ? root.withAlpha(root.color4, 0.25) : root.color0
							border.width: ovMouse.containsMouse ? 1 : 0; border.color: root.color4
							RowLayout {
								anchors.fill: parent; anchors.margins: 8; spacing: 10
								Rectangle {
									implicitWidth: 26; implicitHeight: 26; radius: 8; color: root.color4
									Text { anchors.centerIn: parent; text: modelData.ws; color: root.bg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true }
								}
								ColumnLayout {
									Layout.fillWidth: true; spacing: 1
									Text { text: modelData.title || modelData.app; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
									Text { text: modelData.app; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
								}
							}
							MouseArea {
								id: ovMouse; anchors.fill: parent; hoverEnabled: true
								onClicked: {
									root.closeCenterPill()
									if (root.isHyprland) root.runCmd("hyprctl dispatch focuswindow address:" + modelData.id)
									else root.runCmd("niri msg action focus-window --id " + modelData.id)
								}
							}
						}
					}
				}

				// SYSTEM CONTROL CENTER
				Item {
					id: sysContainer
					visible: centerPill.isSysOpen
					anchors { top: topPillBar.bottom; left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10 }
					anchors.topMargin: 2
					implicitHeight: sysUnifiedCol.implicitHeight

					property real viewOffset: 0
					property real viewOpacity: 1.0

					NumberAnimation {
						id: subSlideAnim; target: sysContainer; property: "viewOffset"; to: 0
						duration: root.fxActive && root.cfgSubmenuAnimStyle === "slide" ? root.cfgSubmenuAnimMs : 0; easing.type: Easing.OutCubic
					}
					NumberAnimation {
						id: subFadeAnim; target: sysContainer; property: "viewOpacity"; from: 0.15; to: 1.0
						duration: root.fxActive && root.cfgSubmenuAnimStyle !== "none" ? root.cfgSubmenuAnimMs : 0; easing.type: Easing.OutCubic
					}

					Connections {
						target: root
						function onSysSubmenuChanged() {
							if (!root.fxActive || root.cfgSubmenuAnimStyle === "none") { sysContainer.viewOffset = 0; sysContainer.viewOpacity = 1.0; return }
							subFadeAnim.restart()
							if (root.cfgSubmenuAnimStyle === "slide") {
								subSlideAnim.from = root.sysSubmenu !== "" ? root.cfgSubmenuSlidePx : -root.cfgSubmenuSlidePx
								subSlideAnim.restart()
							}
						}
					}

					ColumnLayout {
						id: sysUnifiedCol
						opacity: sysContainer.viewOpacity
						transform: Translate { x: sysContainer.viewOffset }
						anchors { left: parent.left; right: parent.right }
						spacing: 8

						// 1. 2x2 QuickTiles Grid
						GridLayout {
							visible: root.sysSubmenu === ""
							Layout.fillWidth: true; columns: 2; uniformCellWidths: true; rowSpacing: 8; columnSpacing: 8
							Repeater {
								model: [
									{ "key": "net", "title": "Network", "icon": root.ethConnected ? "󰈀" : (root.wifiEnabled ? "󰤨" : "󰤭"), "sub": root.netName, "act": root.ethConnected || (root.wifiEnabled && root.netName !== "Offline"), "col": root.color4, "scol": root.color8 },
									{ "key": "bt", "title": "Bluetooth", "icon": "", "sub": root.btName, "act": root.btEnabled, "col": root.color4, "scol": root.color8 },
									{ "key": "tray", "title": "App Tray", "icon": SystemTray.items.values.length.toString(), "sub": "", "act": SystemTray.items.values.length > 0, "col": root.color4, "scol": root.color8 },
									{ "key": "battery", "title": "Battery", "icon": root.batCharging ? "󰂄" : "󰁹", "sub": root.batPct + "% • " + (root.batCharging ? "Charging" : "Ready"), "act": true, "col": root.withAlpha(root.color2, 0.25), "scol": root.color2 }
								]
								Rectangle {
									required property var modelData
									Layout.fillWidth: true; Layout.preferredWidth: 1; implicitHeight: 54; radius: 14
									color: tileBodyMouse.containsMouse ? Qt.lighter(root.color0, 1.12) : root.color0
									MouseArea {
										id: tileBodyMouse; anchors.fill: parent; hoverEnabled: true
										acceptedButtons: Qt.LeftButton | Qt.RightButton
										onClicked: {
											if (modelData.key === "net") root.runCmd("nmcli dev wifi rescan 2>/dev/null || true")
											root.openSubmenu(modelData.key)
										}
									}
									Rectangle {
										id: tileSq
										width: 34; height: 34; radius: 10
										anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
										color: modelData.act ? modelData.col : Qt.rgba(1, 1, 1, 0.08)
										Text {
											anchors.centerIn: parent; text: modelData.icon
											color: modelData.key === "battery" ? root.color2 : (modelData.act ? root.bg : root.fg)
											font.family: "JetBrainsMono Nerd Font"; font.pixelSize: modelData.key === "tray" ? 13 : 16; font.bold: true
										}
										MouseArea {
											anchors.fill: parent
											acceptedButtons: Qt.LeftButton | Qt.RightButton
											onClicked: mouse => {
												if (mouse.button === Qt.RightButton) root.openSubmenu(modelData.key)
												else if (modelData.key === "net") root.togglePrimaryNetwork()
												else if (modelData.key === "bt") {
													if (root.hasBtAdapter) {
														root.runCmd(root.btEnabled ? "bluetoothctl power off; rfkill block bluetooth" : "rfkill unblock bluetooth; bluetoothctl power on")
														sysPoll.running = true
													}
												} else root.openSubmenu(modelData.key)
											}
										}
									}
									ColumnLayout {
										anchors.left: tileSq.right; anchors.leftMargin: 8
										anchors.right: parent.right; anchors.rightMargin: 8
										anchors.verticalCenter: parent.verticalCenter; spacing: 1
										Text { text: modelData.title; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
										Text {
											visible: modelData.key !== "tray"
											text: modelData.sub; color: modelData.scol; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideRight
										}
										RowLayout {
											visible: modelData.key === "tray"; spacing: 4
											Repeater {
												model: SystemTray.items.values.slice(0, 4)
												Rectangle {
													id: miniTrayBtn
													required property var modelData
													implicitWidth: 20; implicitHeight: 20; radius: 6; color: Qt.rgba(1, 1, 1, 0.08)
													IconImage { anchors.centerIn: parent; implicitSize: 14; source: modelData.icon }
													MouseArea {
														anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
														onClicked: mouse => root.activateTrayItem(modelData, islandWin, miniTrayBtn, mouse.button)
													}
												}
											}
											Text { visible: SystemTray.items.values.length === 0; text: "Empty"; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 }
										}
									}
								}
							}
						}

						// 2. Separated Action Row
						RowLayout {
							visible: root.sysSubmenu === ""
							Layout.fillWidth: true; spacing: 8

							Rectangle {
								Layout.fillWidth: true; implicitHeight: 48; radius: 14
								color: recCardMouse.containsMouse ? Qt.lighter(root.color0, 1.12) : root.color0
								MouseArea {
									id: recCardMouse; anchors.fill: parent; hoverEnabled: true
									acceptedButtons: Qt.LeftButton | Qt.RightButton
									onClicked: root.openSubmenu("rec")
								}
								RowLayout {
									anchors.fill: parent; anchors.margins: 7; spacing: 7
									Rectangle {
										Layout.fillWidth: true; implicitHeight: 34; radius: 10; color: root.isRecording ? root.color1 : Qt.rgba(1, 1, 1, 0.08)
										RowLayout {
											anchors.centerIn: parent; spacing: 6
											Text { text: root.isRecording ? "󰓛" : "󰻂"; color: root.isRecording ? root.bg : root.color1; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
											Text { text: root.isRecording ? ("Stop • " + root.formatSec(root.recSeconds)) : "Record Screen"; color: root.isRecording ? root.bg : root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true }
										}
										MouseArea {
											anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
											onClicked: mouse => { if (mouse.button === Qt.RightButton) root.openSubmenu("rec"); else root.toggleRecording() }
										}
									}
									Rectangle {
										implicitWidth: 34; implicitHeight: 34; radius: 10; color: shotMouse.containsMouse ? root.color4 : Qt.rgba(1, 1, 1, 0.08)
										Text { anchors.centerIn: parent; text: "󰄄"; color: shotMouse.containsMouse ? root.bg : root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
										MouseArea {
											id: shotMouse; anchors.fill: parent; hoverEnabled: true
											acceptedButtons: Qt.LeftButton | Qt.RightButton
											onClicked: mouse => {
												if (mouse.button === Qt.RightButton) root.openSubmenu("rec")
												else { root.closeCenterPill(); root.runCmd("sleep 0.2; grim -g \"$(slurp)\" - | swappy -f -") }
											}
										}
									}
								}
							}

							Rectangle {
								implicitWidth: 89; implicitHeight: 48; radius: 14; color: root.color0
								RowLayout {
									anchors.fill: parent; anchors.margins: 7; spacing: 7
									Repeater {
										model: [
											{ "icon": "󰻠", "col": root.color4, "act": "cpu" },
											{ "icon": "󰐥", "col": root.color1, "act": "power" }
										]
										Rectangle {
											required property var modelData
											implicitWidth: 34; implicitHeight: 34; radius: 10
											color: sysPwrMouse.containsMouse ? modelData.col : Qt.rgba(1, 1, 1, 0.08)
											Text { anchors.centerIn: parent; text: modelData.icon; color: sysPwrMouse.containsMouse ? root.bg : modelData.col; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
											MouseArea { id: sysPwrMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.openSubmenu(modelData.act) }
										}
									}
								}
							}
						}

						// 3. Shared Interactive Slider Bars (Display hidden inside Display submenu to avoid duplicate bar)
						Repeater {
							model: ["display", "sound", "mic"]
							Rectangle {
								id: mainSliderCard
								required property string modelData
								visible: root.sysSubmenu === "" || (modelData !== "display" && root.sysSubmenu === modelData)
								Layout.fillWidth: true; implicitHeight: 48; radius: 14
								color: sliderCardMouse.containsMouse && root.sysSubmenu === "" ? Qt.lighter(root.color0, 1.12) : root.color0
								property int valPct: modelData === "display" ? root.brightnessPct : (modelData === "sound" ? root.outVolPct : root.micVolPct)
								property bool isMuted: modelData === "sound" ? root.outMuted : (modelData === "mic" ? root.micMuted : false)
								property bool isNight: modelData === "display" && root.nightLightOn
								property string iconTxt: modelData === "display" ? (isNight ? "󰖔" : "󰃠") : (modelData === "sound" ? (isMuted ? "󰖁" : (root.isHeadphones ? "󰋋" : "󰕾")) : (isMuted ? "󰍭" : (root.isHeadsetMic ? "󰋎" : "󰍬")))
								property string labelTxt: modelData === "display" ? (isNight ? "Display • Night Light" : "Display") : (modelData === "sound" ? "Sound" : "Mic")

								function applyRatio(r) {
									let cl = Math.max(0, Math.min(1, r))
									if (modelData === "display") {
										let p = Math.max(5, Math.round(cl * 100))
										root.brightnessPct = p; root.runCmd("brightnessctl s " + p + "%")
									} else if (modelData === "sound") root.setSinkVolume(cl * 100)
									else root.setSourceVolume(cl * 100)
								}

								MouseArea {
									id: sliderCardMouse; anchors.fill: parent; hoverEnabled: true
									acceptedButtons: Qt.LeftButton | Qt.RightButton
									onClicked: { if (root.sysSubmenu === "") root.openSubmenu(mainSliderCard.modelData) }
								}

								Rectangle {
									id: slIconSq
									width: 34; height: 34; radius: 10
									anchors.left: parent.left; anchors.leftMargin: 7; anchors.verticalCenter: parent.verticalCenter
									color: mainSliderCard.isMuted ? root.withAlpha(root.color1, 0.22) : (mainSliderCard.isNight ? root.withAlpha(root.color2, 0.25) : Qt.rgba(1, 1, 1, 0.08))
									Text {
										anchors.centerIn: parent; text: mainSliderCard.iconTxt
										color: mainSliderCard.isMuted ? root.color1 : (mainSliderCard.isNight ? root.color2 : root.color4)
										font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
									}
									MouseArea {
										anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
										onClicked: mouse => {
											if (mouse.button === Qt.RightButton) {
												root.openSubmenu(mainSliderCard.modelData)
											} else {
												if (mainSliderCard.modelData === "display") { root.nightLightOn = !root.nightLightOn; root.applyNightLight() }
												else if (mainSliderCard.modelData === "sound") root.toggleSinkMute()
												else root.toggleSourceMute()
											}
										}
									}
								}

								Rectangle {
									anchors.left: slIconSq.right; anchors.leftMargin: 7
									anchors.right: parent.right; anchors.rightMargin: 7
									anchors.verticalCenter: parent.verticalCenter
									height: 30; radius: 9; clip: true; color: Qt.rgba(1, 1, 1, 0.08)

									Rectangle {
										width: parent.width * Math.min(1, mainSliderCard.valPct / 100.0)
										height: parent.height; radius: 9
										color: mainSliderCard.isMuted ? root.color8 : root.withAlpha(root.color4, 0.78)
									}
									Text {
										anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
										text: mainSliderCard.labelTxt; color: root.fg
										style: Text.Outline; styleColor: root.withAlpha(root.bg, 0.7)
										font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true
									}
									Text {
										anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
										text: mainSliderCard.isMuted ? "Mute" : (mainSliderCard.valPct + "%"); color: root.fg
										style: Text.Outline; styleColor: root.withAlpha(root.bg, 0.7)
										font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true
									}
									MouseArea {
										anchors.fill: parent
										acceptedButtons: Qt.LeftButton | Qt.RightButton
										onPressed: mouse => {
											if (mouse.button === Qt.RightButton) root.openSubmenu(mainSliderCard.modelData)
											else mainSliderCard.applyRatio(mouse.x / width)
										}
										onPositionChanged: mouse => {
											if (pressed && (mouse.buttons & Qt.LeftButton)) mainSliderCard.applyRatio(mouse.x / width)
										}
									}
								}
							}
						}

						// 4. Shared Read-Only Status Bars (Battery & System Info)
						Repeater {
							model: root.sysSubmenu === "battery" ? [
								{ "icon": root.batCharging ? "󰂄" : "󰁹", "title": root.batCharging ? "Charging" : "Charge Level", "pct": root.batPct, "col": root.color2 }
							] : (root.sysSubmenu === "cpu" ? [
								{ "icon": "󰻠", "title": root.cpuModel + " (" + root.cpuTemp + "°C)", "pct": root.cpuUsage, "col": root.color4 },
								{ "icon": "󰍛", "title": "RAM • " + root.ramInfo, "pct": root.ramPct, "col": root.color2 },
								{ "icon": "󰋊", "title": "Root (/) • " + root.diskRootInfo, "pct": root.diskRootPct, "col": root.color6 }
							] : [])
							Rectangle {
								required property var modelData
								Layout.fillWidth: true; implicitHeight: 48; radius: 14; color: root.color0
								Rectangle {
									id: statBarSq
									width: 34; height: 34; radius: 10
									anchors.left: parent.left; anchors.leftMargin: 7; anchors.verticalCenter: parent.verticalCenter
									color: root.withAlpha(modelData.col, 0.22)
									Text { anchors.centerIn: parent; text: modelData.icon; color: modelData.col; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16 }
								}
								Rectangle {
									anchors.left: statBarSq.right; anchors.leftMargin: 7
									anchors.right: parent.right; anchors.rightMargin: 7
									anchors.verticalCenter: parent.verticalCenter
									height: 30; radius: 9; clip: true; color: Qt.rgba(1, 1, 1, 0.08)
									Rectangle { width: parent.width * (modelData.pct / 100.0); height: parent.height; radius: 9; color: root.withAlpha(modelData.col, 0.78) }
									Text {
										anchors.left: parent.left; anchors.leftMargin: 10
										anchors.right: statPctTxt.left; anchors.rightMargin: 8
										anchors.verticalCenter: parent.verticalCenter
										text: modelData.title; color: root.fg; elide: Text.ElideRight
										style: Text.Outline; styleColor: root.withAlpha(root.bg, 0.7)
										font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true
									}
									Text {
										id: statPctTxt
										anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
										text: modelData.pct + "%"; color: root.fg
										style: Text.Outline; styleColor: root.withAlpha(root.bg, 0.7)
										font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true
									}
								}
							}
						}

						// 5. Shared Toggle Cards
						Repeater {
							model: root.sysSubmenu === "battery" ? [
								{ "key": "wall", "icon": root.animWallpapers ? "󰕧" : "󰸉", "title": "Animated Wallpapers", "sub": root.animWallpapers ? (root.shouldPlayAnimation ? "Playing (day_animated / night_animated)" : "Paused (Fullscreen / Standby)") : "Off • Static Power Saving (day / night)", "extra": "Loaded: " + root.wallpaperLabel, "on": root.animWallpapers, "col": root.color4, "scol": root.animWallpapers ? root.color4 : root.color2 },
								{ "key": "fx", "icon": "󰂵", "title": "UI Blur & Animations", "sub": root.isVM ? "Disabled in VM Mode" : (root.fxActive ? "Active • Glass Blur & Smooth Transitions" : "Off • Solid Panels & Instant Transitions"), "extra": "", "on": root.fxActive, "col": root.color5, "scol": root.fxActive ? root.color5 : root.color8 }
							] : (root.sysSubmenu === "rec" ? [
								{ "key": "sys", "icon": "󰕾", "title": "Record System Audio", "sub": "", "extra": "", "on": root.recSysAudio, "col": root.color4, "scol": root.color8 },
								{ "key": "mic", "icon": "󰍬", "title": "Record Microphone", "sub": "", "extra": "", "on": root.recMicAudio, "col": root.color4, "scol": root.color8 },
								{ "key": "area", "icon": "󰩭", "title": "Select Screen Region (slurp)", "sub": "", "extra": "", "on": root.recAreaSelect, "col": root.color4, "scol": root.color8 }
							] : [])
							Rectangle {
								required property var modelData
								Layout.fillWidth: true; implicitHeight: modelData.extra !== "" ? 66 : (modelData.sub !== "" ? 52 : 46); radius: 14; color: root.color0
								MouseArea {
									anchors.fill: parent
									onClicked: {
										if (modelData.key === "wall") root.toggleWallpaperMode()
										else if (modelData.key === "fx") { if (!root.isVM) root.toggleUiEffects() }
										else if (modelData.key === "sys") root.recSysAudio = !root.recSysAudio
										else if (modelData.key === "mic") root.recMicAudio = !root.recMicAudio
										else if (modelData.key === "area") root.recAreaSelect = !root.recAreaSelect
									}
								}
								Rectangle {
									id: sharedTglSq
									width: 34; height: 34; radius: 10
									anchors.left: parent.left; anchors.leftMargin: 7; anchors.verticalCenter: parent.verticalCenter
									color: modelData.on ? modelData.col : Qt.rgba(1, 1, 1, 0.08)
									Text { anchors.centerIn: parent; text: modelData.icon; color: modelData.on ? root.bg : root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
								}
								Rectangle {
									id: sharedTglSw
									width: 36; height: 18; radius: 9
									anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
									color: modelData.on ? modelData.col : Qt.rgba(1, 1, 1, 0.15)
									Rectangle { width: 12; height: 12; radius: 6; anchors.verticalCenter: parent.verticalCenter; x: modelData.on ? 20 : 4; color: modelData.on ? root.bg : root.fg; Behavior on x { NumberAnimation { duration: 120 } } }
								}
								ColumnLayout {
									anchors.left: sharedTglSq.right; anchors.leftMargin: 8
									anchors.right: sharedTglSw.left; anchors.rightMargin: 8
									anchors.verticalCenter: parent.verticalCenter; spacing: 1
									Text { text: modelData.title; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
									Text { visible: modelData.sub !== ""; text: modelData.sub; color: modelData.scol; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideRight }
									Text { visible: modelData.extra !== ""; text: modelData.extra; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideMiddle }
								}
							}
						}

						// 6. Battery 2x2 Hardware Stats Grid
						GridLayout {
							visible: root.sysSubmenu === "battery"
							Layout.fillWidth: true; columns: 2; uniformCellWidths: true; rowSpacing: 8; columnSpacing: 8
							Repeater {
								model: [
									{ "icon": "󰂑", "l": "Battery Health", "v": root.batHealth },
									{ "icon": "󱐋", "l": "Power Draw", "v": root.batPowerDraw },
									{ "icon": "󰑖", "l": "Cycle Count", "v": root.batCycles },
									{ "icon": "󰂀", "l": "Technology", "v": root.batTech }
								]
								Rectangle {
									required property var modelData
									Layout.fillWidth: true; Layout.preferredWidth: 1; implicitHeight: 52; radius: 14; color: root.color0
									Rectangle {
										id: bStatSq
										width: 34; height: 34; radius: 10
										anchors.left: parent.left; anchors.leftMargin: 7; anchors.verticalCenter: parent.verticalCenter
										color: Qt.rgba(1, 1, 1, 0.08)
										Text { anchors.centerIn: parent; text: modelData.icon; color: root.color2; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
									}
									ColumnLayout {
										anchors.left: bStatSq.right; anchors.leftMargin: 8
										anchors.right: parent.right; anchors.rightMargin: 8
										anchors.verticalCenter: parent.verticalCenter; spacing: 1
										Text { text: modelData.l; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideRight }
										Text { text: modelData.v; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
									}
								}
							}
						}

						// 7. System Info Kernel & Secondary Drive Footer Card
						Rectangle {
							visible: root.sysSubmenu === "cpu"
							Layout.fillWidth: true; implicitHeight: 48; radius: 14; color: root.color0
							Rectangle {
								id: kernSq
								width: 34; height: 34; radius: 10
								anchors.left: parent.left; anchors.leftMargin: 7; anchors.verticalCenter: parent.verticalCenter
								color: Qt.rgba(1, 1, 1, 0.08)
								Text { anchors.centerIn: parent; text: "󰌽"; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16 }
							}
							ColumnLayout {
								anchors.left: kernSq.right; anchors.leftMargin: 8
								anchors.right: parent.right; anchors.rightMargin: 8
								anchors.verticalCenter: parent.verticalCenter; spacing: 1
								Text { text: "Kernel: " + root.kernelVer + "  •  Up: " + root.uptimeStr; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
								Text { text: "Secondary Drive: " + root.diskSecInfo; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideRight }
							}
						}

						// 8. Audio / Mic Devices List
						ColumnLayout {
							visible: root.sysSubmenu === "sound" || root.sysSubmenu === "mic"; Layout.fillWidth: true; spacing: 6
							Text { text: "Available Devices"; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true }
							Repeater {
								model: root.sysSubmenu === "sound" ? root.audioSinks : (root.sysSubmenu === "mic" ? root.audioSources : [])
								Rectangle {
									required property var modelData
									Layout.fillWidth: true; implicitHeight: 44; radius: 12
									color: modelData.active ? root.withAlpha(root.color4, 0.18) : root.color0
									border.width: modelData.active ? 1 : 0; border.color: root.color4
									RowLayout {
										anchors.fill: parent; anchors.margins: 6; spacing: 8
										Rectangle {
											implicitWidth: 32; implicitHeight: 32; radius: 9
											color: modelData.active ? root.color4 : Qt.rgba(1, 1, 1, 0.08)
											Text { anchors.centerIn: parent; text: root.sysSubmenu === "sound" ? "󰕾" : "󰍬"; color: modelData.active ? root.bg : root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
										}
										Text { text: modelData.name; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: modelData.active; elide: Text.ElideRight; Layout.fillWidth: true }
									}
									MouseArea { anchors.fill: parent; onClicked: { root.runCmd("wpctl set-default " + modelData.id); subPoll.running = true } }
								}
							}
						}

						// 9. Display Submenu (Active Monitor Bars Only + Night Light)
						ColumnLayout {
							visible: root.sysSubmenu === "display"; Layout.fillWidth: true; spacing: 8
							Repeater {
								model: root.sysSubmenu === "display" ? root.monitorsList : []
								Rectangle {
									required property var modelData
									required property int index
									Layout.fillWidth: true; implicitHeight: monCardCol.implicitHeight + 16; radius: 14; color: root.color0

									ColumnLayout {
										id: monCardCol
										anchors { top: parent.top; left: parent.left; right: parent.right; margins: 8 }
										spacing: 8

										Item {
											Layout.fillWidth: true; implicitHeight: 34
											Rectangle {
												id: monSq
												width: 34; height: 34; radius: 10
												anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
												color: root.withAlpha(root.color4, 0.2)
												Text { anchors.centerIn: parent; text: "󰍹"; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16 }
											}
											Rectangle {
												anchors.left: monSq.right; anchors.leftMargin: 7
												anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
												height: 30; radius: 9; clip: true; color: Qt.rgba(1, 1, 1, 0.08)
												Rectangle { width: parent.width * (root.brightnessPct / 100.0); height: parent.height; radius: 9; color: root.withAlpha(root.color2, 0.78) }
												Text {
													anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
													text: modelData.name + (root.monitorsList.length > 1 ? ("  •  #" + (index + 1)) : "")
													color: root.fg; style: Text.Outline; styleColor: root.withAlpha(root.bg, 0.7)
													font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true
												}
												Text {
													anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
													text: root.brightnessPct + "%"
													color: root.fg; style: Text.Outline; styleColor: root.withAlpha(root.bg, 0.7)
													font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true
												}
												MouseArea {
													anchors.fill: parent
													function setBri(mx) {
														let p = Math.max(5, Math.min(100, Math.round((mx / width) * 100)))
														root.brightnessPct = p; root.runCmd("brightnessctl s " + p + "%")
													}
													onPressed: mouse => setBri(mouse.x)
													onPositionChanged: mouse => { if (pressed) setBri(mouse.x) }
												}
											}
										}

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
													Layout.fillWidth: true; implicitHeight: 26; radius: 8
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

										Item {
											Layout.fillWidth: true; implicitHeight: 24
											RowLayout {
												anchors.fill: parent
												Text { text: "Resolution"; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
												RowLayout {
													spacing: 6
													Text { text: modelData.curMode.replace("@", " @ ") + " Hz"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true }
													Text { text: "󰅀"; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
												}
											}
											MouseArea { anchors.fill: parent; onClicked: root.expandedResMon = (root.expandedResMon === modelData.name ? "" : modelData.name) }
										}

										ColumnLayout {
											visible: root.expandedResMon === modelData.name; Layout.fillWidth: true; spacing: 4
											Repeater {
												model: (root.expandedResMon === modelData.name) ? modelData.modes : []
												Rectangle {
													required property string modelData
													property string monName: monCardCol.parent.modelData.name
													property string curScale: monCardCol.parent.modelData.scale
													property bool isCurrent: modelData === monCardCol.parent.modelData.curMode
													Layout.fillWidth: true; implicitHeight: 30; radius: 8
													color: isCurrent ? root.withAlpha(root.color4, 0.25) : Qt.rgba(1, 1, 1, 0.05)
													RowLayout {
														anchors.fill: parent; anchors.margins: 6
														Text { text: modelData.replace("@", " @ ") + " Hz"; color: parent.parent.isCurrent ? root.color4 : root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: parent.parent.isCurrent; Layout.fillWidth: true }
														Text { visible: parent.parent.isCurrent; text: "Active"; color: root.color2; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 }
													}
													MouseArea {
														anchors.fill: parent
														onClicked: {
															if (root.isHyprland) root.runCmd("hyprctl keyword monitor " + parent.monName + "," + modelData + ",auto," + parent.curScale)
															else root.runCmd("niri msg output \"" + parent.monName + "\" mode " + modelData)
															root.expandedResMon = ""; subPoll.running = true
														}
													}
												}
											}
										}
									}
								}
							}

							Rectangle {
								Layout.fillWidth: true; implicitHeight: 84; radius: 14; color: root.color0
								ColumnLayout {
									anchors.fill: parent; anchors.margins: 8; spacing: 8
									Item {
										Layout.fillWidth: true; implicitHeight: 34
										Rectangle {
											id: nlIcon
											width: 34; height: 34; radius: 10
											anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
											color: root.nightLightOn ? root.color2 : Qt.rgba(1, 1, 1, 0.08)
											Text { anchors.centerIn: parent; text: "󰖔"; color: root.nightLightOn ? root.bg : root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16 }
											MouseArea { anchors.fill: parent; onClicked: { root.nightLightOn = !root.nightLightOn; root.applyNightLight() } }
										}
										Rectangle {
											id: nlSw
											width: 36; height: 18; radius: 9
											anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
											color: root.nightLightOn ? root.color2 : Qt.rgba(1, 1, 1, 0.15)
											Rectangle { width: 12; height: 12; radius: 6; anchors.verticalCenter: parent.verticalCenter; x: root.nightLightOn ? 20 : 4; color: root.nightLightOn ? root.bg : root.fg; Behavior on x { NumberAnimation { duration: 120 } } }
											MouseArea { anchors.fill: parent; onClicked: { root.nightLightOn = !root.nightLightOn; root.applyNightLight() } }
										}
										Text {
											anchors.left: nlIcon.right; anchors.leftMargin: 10
											anchors.right: nlSw.left; anchors.rightMargin: 10
											anchors.verticalCenter: parent.verticalCenter
											text: "Night Light"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true
										}
									}
									Rectangle {
										Layout.fillWidth: true; implicitHeight: 28; radius: 9; clip: true; color: Qt.rgba(1, 1, 1, 0.08)
										Rectangle { width: parent.width * ((root.nightLightTemp - 2500) / 3500.0); height: parent.height; radius: 9; color: root.withAlpha(root.color2, 0.78) }
										Text {
											anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
											text: "Color Temperature"; color: root.fg
											style: Text.Outline; styleColor: root.withAlpha(root.bg, 0.7)
											font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true
										}
										Text {
											anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
											text: root.nightLightTemp + " K"; color: root.fg
											style: Text.Outline; styleColor: root.withAlpha(root.bg, 0.7)
											font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true
										}
										MouseArea {
											anchors.fill: parent
											function setKelvin(mx) {
												let r = Math.max(0, Math.min(1, mx / width))
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

						// 10. System Tray Submenu
						ColumnLayout {
							visible: root.sysSubmenu === "tray"; Layout.fillWidth: true; spacing: 6
							Rectangle {
								visible: SystemTray.items.values.length === 0; Layout.fillWidth: true; implicitHeight: 44; radius: 12; color: root.color0
								Text { anchors.centerIn: parent; text: "No applications in System Tray"; color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
							}
							Repeater {
								model: root.sysSubmenu === "tray" ? SystemTray.items.values : []
								Rectangle {
									id: traySubCard
									required property var modelData
									Layout.fillWidth: true; implicitHeight: 46; radius: 12; color: root.color0
									RowLayout {
										anchors.fill: parent; anchors.margins: 6; spacing: 10
										Rectangle {
											implicitWidth: 34; implicitHeight: 34; radius: 10; color: Qt.rgba(1, 1, 1, 0.08)
											IconImage { anchors.centerIn: parent; implicitSize: 20; source: modelData.icon }
										}
										Text { text: modelData.title || modelData.tooltipTitle || modelData.id || "Tray App"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
										Text { text: modelData.hasMenu ? "Menu / Open" : "Open"; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; Layout.rightMargin: 6 }
									}
									MouseArea {
										anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
										onClicked: mouse => root.activateTrayItem(modelData, islandWin, traySubCard, mouse.button)
									}
								}
							}
						}

						// 11. UNIFIED NETWORK & BLUETOOTH SUBMENU
						ColumnLayout {
							id: wirelessCol
							visible: root.sysSubmenu === "net" || root.sysSubmenu === "bt"
							Layout.fillWidth: true; spacing: 8

							property bool isNet: root.sysSubmenu === "net"
							property bool hasHw: isNet ? root.hasWifiHw : root.hasBtAdapter
							property bool isEn: isNet ? root.wifiEnabled : root.btEnabled
							property var devList: isNet ? (root.wifiEnabled ? root.netList : []) : (root.btEnabled ? root.btList : [])
							property var savedList: isNet ? root.savedWifiList : root.pairedBtList

							Rectangle {
								visible: wirelessCol.isNet
								Layout.fillWidth: true; implicitHeight: 50; radius: 14; color: root.color0
								Rectangle {
									id: ethSq
									width: 34; height: 34; radius: 10
									anchors.left: parent.left; anchors.leftMargin: 7; anchors.verticalCenter: parent.verticalCenter
									color: root.ethConnected ? root.color4 : Qt.rgba(1, 1, 1, 0.08)
									Text { anchors.centerIn: parent; text: "󰈀"; color: root.ethConnected ? root.bg : root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16 }
									MouseArea {
										anchors.fill: parent
										onClicked: { if (root.ethIface !== "") { root.runCmd("nmcli dev " + (root.ethConnected ? "disconnect " : "connect ") + root.ethIface); sysPoll.running = true } }
									}
								}
								Text {
									id: ethStTxt
									anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
									text: root.ethConnected ? "Connected" : "Offline"; color: root.ethConnected ? root.color4 : root.color8
									font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true
								}
								ColumnLayout {
									anchors.left: ethSq.right; anchors.leftMargin: 8
									anchors.right: ethStTxt.left; anchors.rightMargin: 8
									anchors.verticalCenter: parent.verticalCenter; spacing: 1
									Text { text: "Ethernet (" + (root.ethIface !== "" ? root.ethIface : "No port") + ")"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
									Text { text: root.ethIp; color: root.ethConnected ? root.color2 : root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideRight }
								}
							}

							Rectangle {
								Layout.fillWidth: true; implicitHeight: 50; radius: 14; color: root.color0
								Rectangle {
									id: wCtrlSq
									width: 34; height: 34; radius: 10
									anchors.left: parent.left; anchors.leftMargin: 7; anchors.verticalCenter: parent.verticalCenter
									color: wirelessCol.isEn ? root.color4 : Qt.rgba(1, 1, 1, 0.08)
									Text {
										anchors.centerIn: parent
										text: wirelessCol.isNet ? (wirelessCol.isEn ? "󰤨" : "󰤭") : ""
										color: wirelessCol.isEn ? root.bg : root.fg
										font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
									}
									MouseArea {
										anchors.fill: parent
										onClicked: {
											if (!wirelessCol.hasHw) return
											if (wirelessCol.isNet) root.runCmd("nmcli radio wifi " + (root.wifiEnabled ? "off" : "on"))
											else root.runCmd(root.btEnabled ? "bluetoothctl power off; rfkill block bluetooth" : "rfkill unblock bluetooth; bluetoothctl power on")
											sysPoll.running = true; subPoll.running = true
										}
									}
								}
								RowLayout {
									id: wRightCtrl
									anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 8
									Rectangle {
										visible: wirelessCol.hasHw && wirelessCol.isEn
										implicitWidth: 52; implicitHeight: 22; radius: 7; color: Qt.rgba(1, 1, 1, 0.08)
										Text { anchors.centerIn: parent; text: "Scan"; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.bold: true }
										MouseArea {
											anchors.fill: parent
											onClicked: {
												if (wirelessCol.isNet) root.runCmd("nmcli dev wifi rescan 2>/dev/null || true")
												else root.runCmd("bluetoothctl --timeout 5 scan on >/dev/null 2>&1 &")
												subPoll.running = true
											}
										}
									}
									Rectangle {
										visible: wirelessCol.isNet && wirelessCol.hasHw
										implicitWidth: 36; implicitHeight: 18; radius: 9
										color: root.wifiEnabled ? root.color4 : Qt.rgba(1, 1, 1, 0.15)
										Rectangle { width: 12; height: 12; radius: 6; anchors.verticalCenter: parent.verticalCenter; x: root.wifiEnabled ? 20 : 4; color: root.wifiEnabled ? root.bg : root.fg; Behavior on x { NumberAnimation { duration: 120 } } }
										MouseArea {
											anchors.fill: parent
											onClicked: { root.runCmd("nmcli radio wifi " + (root.wifiEnabled ? "off" : "on")); sysPoll.running = true; subPoll.running = true }
										}
									}
								}
								ColumnLayout {
									anchors.left: wCtrlSq.right; anchors.leftMargin: 8
									anchors.right: wRightCtrl.left; anchors.rightMargin: 8
									anchors.verticalCenter: parent.verticalCenter; spacing: 1
									Text { text: wirelessCol.isNet ? "Wi-Fi" : "Bluetooth"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
									Text {
										text: !wirelessCol.hasHw ? "Hardware adapter not present" : (!wirelessCol.isEn ? (wirelessCol.isNet ? "Wi-Fi Off" : "Bluetooth Off") : ("Available: " + wirelessCol.devList.length + " • " + (wirelessCol.isNet ? "Saved: " : "Paired: ") + wirelessCol.savedList.length))
										color: wirelessCol.isEn ? root.color8 : root.color1
										font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideRight
									}
								}
							}

							Rectangle {
								visible: wirelessCol.hasHw && wirelessCol.savedList.length > 0
								Layout.fillWidth: true; implicitHeight: savedCol.implicitHeight + 14; radius: 14; color: root.color0
								ColumnLayout {
									id: savedCol
									anchors { top: parent.top; left: parent.left; right: parent.right; margins: 7 }
									spacing: 6

									Item {
										Layout.fillWidth: true; implicitHeight: 24
										RowLayout {
											anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4
											Text {
												text: wirelessCol.isNet ? "Saved Networks" : "Paired Devices"
												color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true
											}
											RowLayout {
												spacing: 6
												Text { text: wirelessCol.savedList.length + " saved"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true }
												Text { text: "󰅀"; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
											}
										}
										MouseArea { anchors.fill: parent; onClicked: root.showSavedList = !root.showSavedList }
									}

									ColumnLayout {
										visible: root.showSavedList; Layout.fillWidth: true; spacing: 4
										Repeater {
											model: root.showSavedList ? wirelessCol.savedList : []
											Rectangle {
												required property var modelData
												Layout.fillWidth: true; implicitHeight: 32; radius: 8; color: Qt.rgba(1, 1, 1, 0.05)
												RowLayout {
													anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 6; spacing: 6
													Text { text: wirelessCol.isNet ? "󰆼" : ""; color: root.color6; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
													Text { text: modelData.name; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
													Rectangle {
														implicitWidth: 52; implicitHeight: 22; radius: 6; color: Qt.rgba(1, 1, 1, 0.08)
														Text { anchors.centerIn: parent; text: "Connect"; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.bold: true }
														MouseArea {
															anchors.fill: parent
															onClicked: {
																if (wirelessCol.isNet) root.runCmd("nmcli connection up id \"" + modelData.id + "\"")
																else root.runCmd("bluetoothctl connect " + modelData.id)
																subPoll.running = true
															}
														}
													}
													Rectangle {
														implicitWidth: 48; implicitHeight: 22; radius: 6; color: Qt.rgba(1, 1, 1, 0.08)
														Text { anchors.centerIn: parent; text: "Forget"; color: root.color1; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 }
														MouseArea {
															anchors.fill: parent
															onClicked: {
																if (wirelessCol.isNet) root.runCmd("nmcli connection delete id \"" + modelData.id + "\"")
																else root.runCmd("bluetoothctl remove " + modelData.id)
																subPoll.running = true
															}
														}
													}
												}
											}
										}
									}
								}
							}

							Rectangle {
								visible: wirelessCol.isNet && root.wifiPromptSsid !== ""
								Layout.fillWidth: true; implicitHeight: 70; radius: 12; color: root.color0; border.width: 1; border.color: root.color4
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
											implicitWidth: 58; implicitHeight: 22; radius: 6; color: root.color4
											Text { anchors.centerIn: parent; text: "Join"; color: root.bg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.bold: true }
											MouseArea { anchors.fill: parent; onClicked: { root.runCmd("nmcli dev wifi connect \"" + root.wifiPromptSsid + "\" password \"" + wifiPwField.text + "\""); wifiPwField.text = ""; root.wifiPromptSsid = "" } }
										}
									}
								}
							}

							Repeater {
								model: wirelessCol.devList
								Rectangle {
									required property var modelData
									property bool isExpanded: root.expandedDevInfo === modelData.id
									Layout.fillWidth: true; implicitHeight: isExpanded ? 74 : 44; radius: 12
									color: modelData.connected ? root.withAlpha(root.color4, 0.18) : root.color0
									border.width: modelData.connected ? 1 : 0; border.color: root.color4
									clip: true
									Behavior on implicitHeight { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

									ColumnLayout {
										anchors.fill: parent; anchors.margins: 6; spacing: 6
										RowLayout {
											Layout.fillWidth: true; spacing: 8
											Rectangle {
												implicitWidth: 32; implicitHeight: 32; radius: 9
												color: modelData.connected ? root.color4 : Qt.rgba(1, 1, 1, 0.08)
												Text {
													anchors.centerIn: parent
													text: wirelessCol.isNet ? "󰤨" : ""
													color: modelData.connected ? root.bg : root.fg
													font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15
												}
											}
											Item {
												Layout.fillWidth: true; implicitHeight: 32
												RowLayout {
													anchors.fill: parent; spacing: 6
													Text { text: modelData.ssid; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: modelData.connected; elide: Text.ElideRight; Layout.fillWidth: true }
													Text {
														text: modelData.connected ? "Disconnect" : (wirelessCol.isNet ? (modelData.signal + "%") : "Connect")
														color: modelData.connected ? root.color1 : (wirelessCol.isNet ? root.color8 : root.color4)
														font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.bold: !wirelessCol.isNet || modelData.connected
													}
												}
												MouseArea {
													anchors.fill: parent
													acceptedButtons: Qt.LeftButton | Qt.RightButton
													onClicked: mouse => {
														if (mouse.button === Qt.RightButton) {
															root.expandedDevInfo = (root.expandedDevInfo === modelData.id ? "" : modelData.id)
														} else if (wirelessCol.isNet) {
															if (modelData.connected) root.runCmd("nmcli con down id \"" + modelData.ssid + "\"")
															else {
																let isSaved = false
																for (let i = 0; i < root.savedWifiList.length; i++) if (root.savedWifiList[i].id === modelData.ssid) isSaved = true
																if (isSaved || modelData.sec === "Open" || modelData.sec === "" || modelData.sec === "--") root.runCmd("nmcli dev wifi connect \"" + modelData.ssid + "\"")
																else root.wifiPromptSsid = modelData.ssid
															}
															subPoll.running = true
														} else {
															root.runCmd("bluetoothctl " + (modelData.connected ? "disconnect " : "connect ") + modelData.id)
															subPoll.running = true
														}
													}
												}
											}
											Rectangle {
												implicitWidth: 26; implicitHeight: 26; radius: 7
												color: parent.parent.parent.isExpanded ? root.color4 : Qt.rgba(1, 1, 1, 0.08)
												Text { anchors.centerIn: parent; text: "󰋼"; color: parent.parent.parent.isExpanded ? root.bg : root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
												MouseArea {
													anchors.fill: parent
													onClicked: root.expandedDevInfo = (root.expandedDevInfo === modelData.id ? "" : modelData.id)
												}
											}
										}
										Rectangle {
											visible: parent.parent.isExpanded
											Layout.fillWidth: true; implicitHeight: 22; radius: 6; color: Qt.rgba(1, 1, 1, 0.06)
											Text {
												anchors.left: parent.left; anchors.leftMargin: 8
												anchors.right: parent.right; anchors.rightMargin: 8
												anchors.verticalCenter: parent.verticalCenter
												text: modelData.details; color: root.color6
												font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; elide: Text.ElideRight
											}
										}
									}
								}
							}
						}

						// 12. Power Menu Submenu
						ColumnLayout {
							visible: root.sysSubmenu === "power"; Layout.fillWidth: true; spacing: 6
							Repeater {
								model: [
									{ "icon": "󰑐", "label": "Reboot System", "cmd": "loginctl reboot || sudo -n reboot || reboot", "pause": false },
									{ "icon": "󰤄", "label": "Suspend", "cmd": "loginctl suspend || zzz", "pause": true },
									{ "icon": "󰒲", "label": "Hibernate", "cmd": "loginctl hibernate || ZZZ", "pause": true },
									{ "icon": "󰌾", "label": "Lock Screen", "cmd": "LOCK", "pause": false },
									{ "icon": "󰍃", "label": "Log Out", "cmd": "LOGOUT", "pause": false }
								]
								Rectangle {
									required property var modelData
									Layout.fillWidth: true; implicitHeight: 44; radius: 12; color: pwrItemMouse.containsMouse ? root.withAlpha(root.color4, 0.22) : root.color0
									RowLayout {
										anchors.fill: parent; anchors.margins: 5; spacing: 10
										Rectangle {
											implicitWidth: 34; implicitHeight: 34; radius: 10; color: Qt.rgba(1, 1, 1, 0.08)
											Text { anchors.centerIn: parent; text: modelData.icon; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
										}
										Text { text: modelData.label; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true }
									}
									MouseArea {
										id: pwrItemMouse; anchors.fill: parent; hoverEnabled: true
										onClicked: {
											if (modelData.pause) { root.isMonitorDpmsOff = true; root.triggerLock() }
											if (modelData.cmd === "LOCK") root.triggerLock()
											else if (modelData.cmd === "LOGOUT") root.cleanExitSession("")
											else root.runCmd(modelData.cmd)
										}
									}
								}
							}
						}
					}
				}
			}

			// DETACHED APP LAUNCHER LIST CARD (8px below the 40px Search Bar Pill)
			Rectangle {
				id: launcherListCard
				visible: centerPill.isLauncherOpen
				anchors.top: centerPill.bottom
				anchors.topMargin: 8
				anchors.horizontalCenter: centerPill.horizontalCenter
				width: 380
				height: Math.min(348, Math.max(58, appListView.contentHeight + 16))
				radius: 20
				color: root.withAlpha(root.bg, root.panelAlpha)
				border.width: 2
				border.color: root.color4
				clip: true
				Behavior on height { NumberAnimation { duration: root.animMs; easing.type: root.cfgIslandEasing } }

				ListView {
					id: appListView
					anchors.fill: parent; anchors.margins: 8
					clip: true; spacing: 4
					model: root.filteredApps
					currentIndex: root.selectedAppIndex

					Text {
						anchors.centerIn: parent
						visible: root.filteredApps.length === 0
						text: "No matching applications"
						color: root.color8; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
					}

					delegate: Rectangle {
						required property var modelData
						required property int index
						width: ListView.view.width
						height: 46
						radius: 10
						property bool isSel: index === root.selectedAppIndex
						color: isSel ? Qt.rgba(1, 1, 1, 0.09) : (appMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")

						// Left vertical pill accent bar on selected app (No outer border)
						Rectangle {
							visible: parent.isSel
							width: 3.5; height: 22; radius: 2
							anchors.left: parent.left; anchors.leftMargin: 4
							anchors.verticalCenter: parent.verticalCenter
							color: root.color6
						}

						RowLayout {
							anchors.fill: parent
							anchors.leftMargin: 13; anchors.rightMargin: 10
							spacing: 10

							Rectangle {
								implicitWidth: 32; implicitHeight: 32; radius: 8
								color: Qt.rgba(1, 1, 1, 0.06)
								IconImage { anchors.centerIn: parent; implicitSize: 22; source: Quickshell.iconPath(modelData.icon, true) }
							}

							ColumnLayout {
								Layout.fillWidth: true; spacing: 1
								Text {
									text: modelData.name
									color: root.fg
									font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true
									elide: Text.ElideRight; Layout.fillWidth: true
								}
								Text {
									visible: text !== ""
									text: modelData.genericName || modelData.comment || ""
									color: root.color8
									font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10
									elide: Text.ElideRight; Layout.fillWidth: true
								}
							}
						}

						MouseArea {
							id: appMouse; anchors.fill: parent; hoverEnabled: true
							onEntered: root.selectedAppIndex = index
							onClicked: { root.closeCenterPill(); modelData.execute() }
						}
					}
				}
			}

			// RIGHT OSD PILL (Anchored 10px to the right of centerPill)
			Rectangle {
				id: rightOsdPill
				anchors.top: parent.top
				anchors.left: centerPill.right
				anchors.leftMargin: 10
				width: 40; height: 40; radius: 20
				color: root.withAlpha(root.bg, root.panelAlpha)
				property real arcPct: root.osdMode === "brightness" ? (root.brightnessPct / 100.0) : (root.osdMode === "mic" ? (root.micMuted ? 0 : root.micVolPct / 100.0) : (root.outMuted ? 0 : root.outVolPct / 100.0))
				property string centerIcon: root.osdMode === "brightness" ? "󰃠" : (root.osdMode === "mic" ? (root.micMuted ? (root.isHeadsetMic ? "󰋐" : "󰍭") : (root.isHeadsetMic ? "󰋎" : "󰍬")) : (root.outMuted ? (root.isHeadphones ? "󰟎" : "󰖁") : (root.isHeadphones ? "󰋋" : "󰕾")))
				onArcPctChanged: osdCanvas.requestPaint()
				onCenterIconChanged: osdCanvas.requestPaint()

				Connections {
					target: root
					function onColor4Changed() { osdCanvas.requestPaint() }
					function onColor2Changed() { osdCanvas.requestPaint() }
					function onColor3Changed() { osdCanvas.requestPaint() }
				}

				Canvas {
					id: osdCanvas; anchors.fill: parent
					onPaint: root.paintArc(osdCanvas, rightOsdPill.arcPct, root.osdMode === "mic" ? root.color2 : (root.osdMode === "brightness" ? root.color3 : root.color4))
				}
				Text { anchors.centerIn: parent; text: rightOsdPill.centerIcon; color: ((root.osdMode === "volume" && root.outMuted) || (root.osdMode === "mic" && root.micMuted)) ? root.color1 : root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15; font.bold: true }
				MouseArea {
					anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
					onClicked: mouse => {
						if (mouse.button === Qt.RightButton) root.runCmd("pavucontrol")
						else if (root.osdMode === "mic") root.toggleSourceMute()
						else root.toggleSinkMute()
					}
					onWheel: wheel => {
						let up = wheel.angleDelta.y > 0
						if (root.osdMode === "brightness") root.runCmd("brightnessctl s 5%" + (up ? "+" : "-"))
						else if (root.osdMode === "mic") root.setSourceVolume(root.micVolPct + (up ? 5 : -5))
						else root.setSinkVolume(root.outVolPct + (up ? 5 : -5))
					}
				}
			}
		}
	}

	// 5. NOTIFICATION POPUP WINDOW
	Variants {
		model: Quickshell.screens
		PanelWindow {
			required property var modelData
			screen: modelData; visible: root.popupNotifications.length > 0 && root.centerMode === "none" && !root.screenLocked
			WlrLayershell.layer: WlrLayer.Overlay; WlrLayershell.namespace: "swaync-notification-window"
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
						Layout.fillWidth: true; implicitHeight: 68; radius: 16; color: root.withAlpha(root.color0, root.panelAlpha); border.width: 2; border.color: root.color4
						ColumnLayout {
							anchors.fill: parent; anchors.margins: 12; spacing: 3
							Text { text: modelData.summary || "Notification"; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
							Text { text: modelData.body || ""; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
						}
					}
				}
			}
		}
	}

	// 6. UNIFIED LOGIN & LOCKSCREEN (Uses system PAM "login", Draggable Carousel & Flashing Red Error)
	property bool authError: false
	property bool authBusy: false
	property bool lockPromptActive: false
	property string pendingPassword: ""
	property string lockDateFormatted: Qt.formatDateTime(new Date(), "dddd, MMMM d").toUpperCase()
	property bool showLiveLockWall: root.animWallpapers && root.cfgLockKeepAnimated && (root.isVideoFile || root.isAnimatedGif)

	property string lockWeatherMain: {
		let cond = (root.weatherDetail.split("•")[0] || "").trim()
		return root.weatherShort + (cond !== "" && !cond.includes("Fetching") ? ("   •   " + cond) : "")
	}
	property string lockWeatherSub: {
		let parts = root.weatherDetail.split("•")
		if (parts.length < 4) return ""
		return parts[1].trim() + "   •   󰖝 " + parts[2].replace("Wind:", "").trim() + "   •   󰖎 " + parts[3].replace("Hum:", "").trim()
	}

	PamContext {
		id: pamLock; config: "login"
		onResponseRequiredChanged: { if (responseRequired && root.authBusy) respond(root.pendingPassword) }
		onCompleted: result => {
			root.authBusy = false; root.pendingPassword = ""
			if (result === PamResult.Success) {
				root.runCmd("rm -f /tmp/qs_lock_active_$UID 2>/dev/null || true")
				root.isMonitorDpmsOff = false; root.screenLocked = false; root.isInitialLogin = false; root.authError = false; root.lockPromptActive = false
				root.checkFirstRunNiri()
			} else {
				root.authError = true; root.lockPromptActive = true
			}
		}
	}

	Process {
		id: switchAuthProc
		command: ["bash", "-c", "printf '%s\\n' \"$QS_PW\" | su -c true \"$QS_TARGET_USER\" >/dev/null 2>&1"]
		environment: ({ "QS_PW": root.pendingPassword, "QS_TARGET_USER": root.selectedUser })
		onExited: (code, status) => {
			root.authBusy = false; root.pendingPassword = ""
			if (code === 0) {
				root.authError = false
				root.cleanExitSession(root.selectedUser)
			} else {
				root.authError = true; root.lockPromptActive = true
			}
		}
	}

	Variants {
		model: Quickshell.screens
		PanelWindow {
			id: lockWin
			required property var modelData
			screen: modelData; visible: root.screenLocked
			WlrLayershell.layer: WlrLayer.Overlay; WlrLayershell.namespace: "lockscreen"
			WlrLayershell.exclusionMode: ExclusionMode.Ignore
			WlrLayershell.keyboardFocus: root.screenLocked ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
			anchors { top: true; bottom: true; left: true; right: true }
			color: root.showLiveLockWall ? "transparent" : root.bg

			Timer {
				interval: 250; running: lockWin.visible && !pwLockInput.activeFocus; repeat: true
				onTriggered: pwLockInput.forceActiveFocus()
			}

			onVisibleChanged: {
				if (visible) {
					root.isMonitorDpmsOff = false; root.lockPromptActive = false; root.authError = false
					root.lockDateFormatted = Qt.formatDateTime(new Date(), "dddd, MMMM d").toUpperCase()
					pwLockInput.text = ""
					pwLockInput.forceActiveFocus()
				}
			}

			Image {
				id: lockWall; anchors.fill: parent
				source: (!root.showLiveLockWall && root.wallpaperPath !== "") ? (root.isVideoFile ? "file:///tmp/wall_frame.jpg" : "file://" + root.wallpaperPath) : ""
				fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false
				visible: !root.showLiveLockWall && (!root.fxActive || root.cfgLockBlurMax <= 0)
			}

			MultiEffect {
				anchors.fill: parent; source: lockWall
				visible: !root.showLiveLockWall && root.fxActive && root.cfgLockBlurMax > 0 && root.wallpaperPath !== ""
				blurEnabled: visible; blurMax: root.cfgLockBlurMax; blur: 1.0
			}

			Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.38) }

			MouseArea {
				anchors.fill: parent
				onClicked: {
					root.lockPromptActive = true
					pwLockInput.forceActiveFocus()
				}
			}

			ColumnLayout {
				anchors.horizontalCenter: parent.horizontalCenter
				anchors.top: parent.top; anchors.topMargin: Math.round(parent.height * 0.13); spacing: 10

				Text { Layout.alignment: Qt.AlignHCenter; text: root.timeStr; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 84; font.weight: Font.Light }
				Text { Layout.alignment: Qt.AlignHCenter; text: root.lockDateFormatted; color: root.withAlpha(root.fg, 0.85); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.bold: true; font.letterSpacing: 6 }
				Text { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 8; text: root.lockWeatherMain; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 24; font.bold: true; font.letterSpacing: 2 }
				Text { Layout.alignment: Qt.AlignHCenter; visible: root.lockWeatherSub !== ""; text: root.lockWeatherSub; color: root.withAlpha(root.fg, 0.78); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.letterSpacing: 1.5 }
			}

			ColumnLayout {
				anchors.horizontalCenter: parent.horizontalCenter
				anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: Math.round(parent.height * 0.14); spacing: 6

				Text {
					Layout.alignment: Qt.AlignHCenter
					text: root.usersList.length > 1 ? "‹   SELECT USER   ›" : "USER"
					color: root.withAlpha(root.fg, 0.55); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.letterSpacing: 4
				}

				Item {
					id: carouselBox
					Layout.alignment: Qt.AlignHCenter
					implicitWidth: root.usersList.length > 1 ? 380 : 200
					implicitHeight: 32; clip: true

					property real dragOffset: 0
					property real pressStartX: 0
					property bool isDragging: false

					NumberAnimation {
						id: snapAnim; target: carouselBox; property: "dragOffset"; to: 0
						duration: 160; easing.type: Easing.OutCubic
					}

					Repeater {
						model: root.usersList.length > 1 ? [-1, 0, 1] : [0]
						Item {
							required property int modelData
							property int uIdx: {
								let n = root.usersList.length
								return n > 0 ? ((root.selectedUserIdx + modelData % n + n) % n) : 0
							}
							property string uName: root.usersList.length > 0 ? root.usersList[uIdx] : root.currentSessionUser
							property bool isCenter: modelData === 0
							property bool willDisconnect: !root.isInitialLogin && root.isSwitchingUser && uName === root.currentSessionUser

							width: 120; height: 32
							x: (carouselBox.width / 2 - width / 2) + (modelData * 126) + carouselBox.dragOffset
							scale: isCenter ? 1.0 : 0.82
							opacity: isCenter ? 1.0 : (willDisconnect ? 0.92 : 0.45)

							Behavior on x { enabled: !carouselBox.isDragging; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
							Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
							Behavior on opacity { NumberAnimation { duration: 160 } }

							Text {
								anchors.centerIn: parent
								text: parent.uName.toUpperCase()
								color: parent.willDisconnect ? root.color1 : (parent.isCenter ? root.fg : root.withAlpha(root.fg, 0.8))
								font.family: "JetBrainsMono Nerd Font"
								font.pixelSize: parent.isCenter ? 16 : 13
								font.bold: parent.isCenter || parent.willDisconnect
								font.letterSpacing: 3
								Behavior on color { ColorAnimation { duration: 140 } }
							}
						}
					}

					MouseArea {
						anchors.fill: parent; hoverEnabled: true
						onPressed: mouse => {
							snapAnim.stop()
							carouselBox.pressStartX = mouse.x
							carouselBox.isDragging = true
						}
						onPositionChanged: mouse => {
							if (!pressed || root.usersList.length <= 1) return
							let dx = mouse.x - carouselBox.pressStartX
							if (dx > 64) { root.cycleUser(-1); carouselBox.pressStartX = mouse.x; carouselBox.dragOffset = 0 }
							else if (dx < -64) { root.cycleUser(1); carouselBox.pressStartX = mouse.x; carouselBox.dragOffset = 0 }
							else carouselBox.dragOffset = dx
						}
						onReleased: mouse => {
							let totalDx = mouse.x - carouselBox.pressStartX
							carouselBox.isDragging = false
							if (Math.abs(totalDx) < 8) {
								if (root.usersList.length > 1 && mouse.x < width * 0.33) root.cycleUser(-1)
								else if (root.usersList.length > 1 && mouse.x > width * 0.67) root.cycleUser(1)
								else root.lockPromptActive = !root.lockPromptActive
							}
							snapAnim.restart()
							pwLockInput.forceActiveFocus()
						}
						onWheel: wheel => {
							if (root.usersList.length > 1) root.cycleUser(wheel.angleDelta.y > 0 ? -1 : 1)
						}
					}
				}

				Item {
					id: pwBoxContainer
					Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 8; implicitWidth: 230; implicitHeight: 34
					property bool showBar: root.lockPromptActive || pwLockInput.text.length > 0 || root.authError || root.authBusy
					opacity: showBar ? 1.0 : 0.0
					Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

					TextInput {
						id: pwLockInput
						anchors.fill: parent; anchors.bottomMargin: 6
						verticalAlignment: TextInput.AlignVCenter; horizontalAlignment: TextInput.AlignHCenter
						echoMode: TextInput.Password; passwordCharacter: "•"; color: root.fg
						font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18; font.letterSpacing: 6
						onTextChanged: {
							if (text.length > 0) { root.authError = false; root.lockPromptActive = true }
							else if (!root.authError && !root.authBusy) root.lockPromptActive = false
						}
						Keys.onLeftPressed: event => { if (text.length === 0 && root.usersList.length > 1) { root.cycleUser(-1); event.accepted = true } }
						Keys.onRightPressed: event => { if (text.length === 0 && root.usersList.length > 1) { root.cycleUser(1); event.accepted = true } }
						Keys.onEscapePressed: { text = ""; root.authError = false; root.lockPromptActive = false }
						Keys.onReturnPressed: {
							if (root.authBusy || text === "") return
							root.authError = false; root.authBusy = true; root.pendingPassword = text; text = ""
							if (root.isSwitchingUser || root.isGreeterMode) switchAuthProc.running = true
							else pamLock.start()
						}
					}

					Text {
						id: errStatusTxt
						anchors.centerIn: parent; anchors.verticalCenterOffset: -3
						visible: pwLockInput.text.length === 0 && (root.authError || root.authBusy)
						text: root.authBusy ? "VERIFYING..." : "WRONG PASSWORD"
						color: root.authBusy ? root.color4 : "#ff3b5c"
						font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true; font.letterSpacing: 3

						SequentialAnimation on opacity {
							running: root.authError && pwLockInput.text.length === 0
							loops: Animation.Infinite
							NumberAnimation { from: 1.0; to: 0.15; duration: 280; easing.type: Easing.InOutQuad }
							NumberAnimation { from: 0.15; to: 1.0; duration: 280; easing.type: Easing.InOutQuad }
							onRunningChanged: { if (!running) errStatusTxt.opacity = 1.0 }
						}
					}

					Rectangle {
						anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1.5
						color: root.authError ? "#ff3b5c" : ((pwLockInput.text.length > 0 || root.authBusy) ? root.color4 : root.withAlpha(root.fg, 0.6))
						Behavior on color { ColorAnimation { duration: 150 } }
					}
				}

				Text {
					Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 4
					visible: !root.isInitialLogin && root.isSwitchingUser
					text: "⚠ LOGGING IN AS " + root.selectedUser.toUpperCase() + " WILL DISCONNECT " + root.currentSessionUser.toUpperCase()
					color: root.color1; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.5
				}
			}

			RowLayout {
				anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.leftMargin: 32; anchors.bottomMargin: 26; spacing: 8
				Text { text: "SESSION"; color: root.withAlpha(root.fg, 0.6); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.letterSpacing: 2 }
				Text { text: "|"; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true }
				Text { text: root.isHyprland ? "HYPRLAND" : "NIRI"; color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2 }
			}

			Rectangle {
				visible: root.activePlayer !== null
				anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 20
				implicitWidth: lockMediaRow.implicitWidth + 24; implicitHeight: 38; radius: 19
				color: root.withAlpha(root.bg, 0.55); border.width: 1; border.color: root.withAlpha(root.color4, 0.4)

				RowLayout {
					id: lockMediaRow; anchors.centerIn: parent; spacing: 12
					Rectangle {
						implicitWidth: 24; implicitHeight: 24; radius: 6; color: root.color0; clip: true
						Image { anchors.fill: parent; source: (root.activePlayer && root.activePlayer.trackArtUrl) ? root.activePlayer.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; visible: source != "" }
						Text { anchors.centerIn: parent; visible: !root.activePlayer || !root.activePlayer.trackArtUrl; text: "󰝚"; color: root.color4; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
					}
					Text {
						Layout.maximumWidth: 200
						text: (root.activePlayer && root.activePlayer.trackTitle) ? (root.activePlayer.trackTitle + (root.activePlayer.trackArtist ? " — " + root.activePlayer.trackArtist : "")) : "Media Playing"
						color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; elide: Text.ElideRight
					}
					RowLayout {
						spacing: 10
						Repeater {
							model: ["prev", "play", "next"]
							Item {
								required property string modelData
								implicitWidth: 20; implicitHeight: 20
								Text {
									anchors.centerIn: parent
									text: modelData === "prev" ? "󰒮" : (modelData === "next" ? "󰒭" : ((root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing) ? "󰏤" : "󰐊"))
									color: modelData === "play" ? root.color4 : root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: modelData === "play" ? 15 : 14
								}
								MouseArea {
									anchors.fill: parent
									onClicked: {
										if (!root.activePlayer) return
										if (modelData === "prev") root.activePlayer.previous()
										else if (modelData === "next") root.activePlayer.next()
										else root.activePlayer.togglePlaying()
									}
								}
							}
						}
					}
				}
			}

			Item {
				id: lockPowerZone
				anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.rightMargin: 32; anchors.bottomMargin: 26
				implicitWidth: 110; implicitHeight: lockPowerHover.hovered ? lockPowerCol.implicitHeight : 22
				HoverHandler { id: lockPowerHover }

				ColumnLayout {
					id: lockPowerCol; anchors.right: parent.right; anchors.bottom: parent.bottom; spacing: 10
					Repeater {
						model: [
							{ "label": "HIBERNATE", "cmd": "loginctl hibernate || sudo -n ZZZ || ZZZ", "pause": true },
							{ "label": "SUSPEND", "cmd": "loginctl suspend || sudo -n zzz || zzz", "pause": true },
							{ "label": "REBOOT", "cmd": "loginctl reboot || sudo -n reboot || reboot", "pause": false }
						]
						Item {
							required property var modelData
							visible: lockPowerHover.hovered; Layout.alignment: Qt.AlignRight
							implicitWidth: pwrOptTxt.implicitWidth + 8; implicitHeight: 20
							Text {
								id: pwrOptTxt; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: modelData.label
								color: pwrOptMouse.containsMouse ? root.color4 : root.withAlpha(root.fg, 0.75)
								font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: pwrOptMouse.containsMouse; font.letterSpacing: 2
							}
							MouseArea {
								id: pwrOptMouse; anchors.fill: parent; hoverEnabled: true
								onClicked: { if (modelData.pause) root.isMonitorDpmsOff = true; root.runCmd(modelData.cmd) }
							}
						}
					}
					Item {
						Layout.alignment: Qt.AlignRight; implicitWidth: shutdownTxt.implicitWidth + 8; implicitHeight: 20
						Text {
							id: shutdownTxt; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "SHUTDOWN"
							color: shutdownMouse.containsMouse ? root.color1 : root.withAlpha(root.fg, 0.8)
							font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2
						}
						MouseArea { id: shutdownMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.runCmd("loginctl poweroff || sudo -n poweroff || poweroff") }
					}
				}
			}
		}
	}
}
