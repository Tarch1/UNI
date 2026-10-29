import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications

ShellRoot {
	id: root

	property string homeDir: Quickshell.env("HOME")
	property bool isVM: Quickshell.env("QSG_RENDER_LOOP") === "basic"
	property bool isHyprland: Quickshell.env("XDG_CURRENT_DESKTOP") === "Hyprland"

	// Palette dinamica caricata da Wallust (~/.config/quickshell/colors.json)
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

	// Stato globale UI e servizi
	property bool ccVisible: false
	property bool launcherVisible: false
	property bool powerExpanded: false
	property bool dndEnabled: false
	property string clockText: ""
	property string weatherText: ""
	property int cpuTemp: 40
	property int brightnessPct: 100
	property string netStatus: "󰈀  LAN"
	property string btStatus: " On"
	property var workspacesList: [
		{ "idx": 1, "active": true },
		{ "idx": 2, "active": false },
		{ "idx": 3, "active": false },
		{ "idx": 4, "active": false }
	]
	property var popupNotifications: []

	function withAlpha(c, a) {
		return Qt.rgba(c.r, c.g, c.b, a)
	}

	function runCmd(cmd) {
		Quickshell.execDetached(["bash", "-c", cmd])
	}

	function triggerLock() {
		root.ccVisible = false
		root.launcherVisible = false
		if (root.isVM) {
			runCmd("env -u LIBGL_ALWAYS_SOFTWARE QSG_RHI_BACKEND=opengl QSG_RENDER_LOOP=basic quickshell -p ~/.config/quickshell/lock")
		} else {
			runCmd("env QSG_RHI_BACKEND=opengl quickshell -p ~/.config/quickshell/lock")
		}
	}

	// Live-reload dei colori e dello sfondo generati da Wallust
	FileView {
		id: colorFile
		path: root.homeDir + "/.config/quickshell/colors.json"
		watchChanges: true
		onFileChanged: reload()
		onLoaded: {
			try {
				let d = JSON.parse(text())
				if (d.wallpaper !== undefined) root.wallpaperPath = d.wallpaper
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

	// Binding reattivo ai nodi audio Pipewire (Zero CPU polling)
	PwObjectTracker {
		objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
	}

	// Server Notifiche Desktop
	NotificationServer {
		id: notifServer
		onNotification: function(n) {
			n.tracked = true
			if (!root.dndEnabled) {
				let arr = root.popupNotifications.slice()
				arr.unshift(n)
				if (arr.length > 4) arr.pop()
				root.popupNotifications = arr
				popupTimer.restart()
			}
		}
	}

	Timer {
		id: popupTimer
		interval: 5000
		repeat: false
		onTriggered: root.popupNotifications = []
	}

	// IPC Handlers per Mod+Space (launcher) e Mod+N (controlcenter)
	IpcHandler {
		target: "launcher"
		function toggle(): void {
			root.launcherVisible = !root.launcherVisible
			if (root.launcherVisible) root.ccVisible = false
		}
	}

	IpcHandler {
		target: "controlcenter"
		function toggle(): void {
			root.ccVisible = !root.ccVisible
			if (root.ccVisible) root.launcherVisible = false
		}
	}

	// Timer orologio e stato hardware leggero (ogni 5s)
	Process {
		id: sysPoll
		command: ["bash", "-c", "
			t=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 40000)
			b=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%' || echo 100)
			w=$(nmcli -t -f TYPE,STATE,CONNECTION dev 2>/dev/null | grep ':connected:' | head -n1)
			if [[ \"$w\" == wifi:* ]]; then
				sig=$(nmcli -f IN-USE,SIGNAL dev wifi 2>/dev/null | awk '/^\\*/{print $2}' | head -n1)
				net=\"  ${sig:-100}%\"
			elif [[ -n \"$w\" ]]; then
				net=\"󰈀  LAN\"
			else
				net=\"󰤭  Offline\"
			fi
			if rfkill list bluetooth 2>/dev/null | grep -q 'Soft blocked: yes'; then
				bt=\" Off\"
			else
				bt=\" On\"
			fi
			printf '%d|%d|%s|%s\n' \"$((t/1000))\" \"${b:-100}\" \"$net\" \"$bt\"
		"]
		stdout: SplitParser {
			onRead: data => {
				let p = data.trim().split("|")
				if (p.length >= 4) {
					root.cpuTemp = parseInt(p[0]) || 40
					root.brightnessPct = parseInt(p[1]) || 100
					root.netStatus = p[2]
					root.btStatus = p[3]
				}
			}
		}
	}

	// Poller Workspaces (compatibile Niri e Hyprland)
	Process {
		id: wsPoll
		command: ["bash", "-c", "
			if [[ -n \"$NIRI_SOCKET\" ]]; then
				niri msg -j workspaces 2>/dev/null | awk '
				BEGIN { RS=\"}\"; ORS=\"\" }
				/\"idx\":/ {
					match($0, /\"idx\":[0-9]+/); idx=substr($0, RSTART+6, RLENGTH-6);
					act = ($0 ~ /\"is_active\":true/) ? \"1\" : \"0\";
					print idx \":\" act \" \";
				}'
			elif [[ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ]]; then
				act=$(hyprctl activeworkspace -j 2>/dev/null | grep -oE '\"id\": *[0-9]+' | head -n1 | awk '{print $2}')
				for i in 1 2 3 4 5; do
					if [[ \"$i\" == \"$act\" ]]; then printf '%s:1 ' \"$i\"; else printf '%s:0 ' \"$i\"; fi
				done
			fi
		"]
		stdout: SplitParser {
			onRead: data => {
				let items = data.trim().split(/\s+/)
				let list = []
				for (let i = 0; i < items.length; i++) {
					let kv = items[i].split(":")
					if (kv.length === 2) {
						list.push({ "idx": parseInt(kv[0]), "active": kv[1] === "1" })
					}
				}
				if (list.length > 0) {
					list.sort((a, b) => a.idx - b.idx)
					root.workspacesList = list
				}
			}
		}
	}

	Timer {
		interval: 1000
		running: true
		repeat: true
		triggeredOnStart: true
		property int tick: 0
		onTriggered: {
			root.clockText = Qt.formatDateTime(new Date(), "  HH:mm     dd MMM")
			wsPoll.running = true
			if (tick % 5 === 0) sysPoll.running = true
			tick = (tick + 1) % 1800
		}
	}

	// Meteo ogni 30 minuti (come in Waybar)
	Process {
		id: weatherProc
		command: ["curl", "-s", "wttr.in/?format=1"]
		stdout: SplitParser {
			onRead: data => {
				let w = data.trim()
				if (w.length > 0 && w.length < 25 && !w.includes("Unknown")) root.weatherText = w
			}
		}
	}
	Timer {
		interval: 1800000
		running: true
		repeat: true
		triggeredOnStart: true
		onTriggered: weatherProc.running = true
	}

	// =========================================================
	// 1. SFONDO DESKTOP NATIVO (Sostituisce awww / hyprpaper)
	// =========================================================
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

			Image {
				anchors.fill: parent
				source: root.wallpaperPath !== "" ? "file://" + root.wallpaperPath : ""
				fillMode: Image.PreserveAspectCrop
				asynchronous: true
				smooth: true
			}
		}
	}

	// =========================================================
	// 2. BARRA SUPERIORE A PILLOLA (Sostituisce Waybar)
	// =========================================================
	Variants {
		model: Quickshell.screens
		PanelWindow {
			required property var modelData
			screen: modelData
			WlrLayershell.layer: WlrLayer.Top
			WlrLayershell.namespace: "waybar"
			anchors { top: true; left: true; right: true }
			margins { top: 8; left: 15; right: 15 }
			implicitHeight: 40
			color: "transparent"

			Rectangle {
				anchors.fill: parent
				radius: 20
				color: root.withAlpha(root.bg, root.isVM ? 0.95 : 0.85)
				border.width: 2
				border.color: root.color4

				// SINISTRA: WORKSPACES
				RowLayout {
					anchors.left: parent.left
					anchors.leftMargin: 14
					anchors.verticalCenter: parent.verticalCenter
					spacing: 6

					Repeater {
						model: root.workspacesList
						Rectangle {
							required property var modelData
							width: 26
							height: 26
							radius: 13
							color: wsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"

							Text {
								anchors.centerIn: parent
								text: modelData.active ? "" : ""
								color: modelData.active ? root.color2 : root.fg
								font.family: "JetBrainsMono Nerd Font"
								font.pixelSize: 13
								font.bold: true
							}

							MouseArea {
								id: wsMouse
								anchors.fill: parent
								hoverEnabled: true
								onClicked: {
									if (root.isHyprland) {
										root.runCmd("hyprctl dispatch workspace " + modelData.idx)
									} else {
										root.runCmd("niri msg action focus-workspace " + modelData.idx)
									}
								}
							}
						}
					}
				}

				// CENTRO: OROLOGIO & METEO
				RowLayout {
					anchors.centerIn: parent
					spacing: 12

					Rectangle {
						height: 30
						width: clkTxt.implicitWidth + 20
						radius: 15
						color: clkMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"

						Text {
							id: clkTxt
							anchors.centerIn: parent
							text: root.clockText
							color: root.color4
							font.family: "JetBrainsMono Nerd Font"
							font.pixelSize: 13
							font.bold: true
						}

						MouseArea {
							id: clkMouse
							anchors.fill: parent
							hoverEnabled: true
							onClicked: {
								root.ccVisible = !root.ccVisible
								if (root.ccVisible) root.launcherVisible = false
							}
						}
					}

					Text {
						visible: root.weatherText !== ""
						text: root.weatherText
						color: root.fg
						font.family: "JetBrainsMono Nerd Font"
						font.pixelSize: 13
						font.bold: true
					}
				}

				// DESTRA: MODULI HARDWARE + POWER DRAWER
				RowLayout {
					anchors.right: parent.right
					anchors.rightMargin: 12
					anchors.verticalCenter: parent.verticalCenter
					spacing: 10

					// Temperatura
					Text {
						text: (root.cpuTemp >= 80 ? " " : " ") + root.cpuTemp + "°C"
						color: root.cpuTemp >= 80 ? root.color1 : root.fg
						font.family: "JetBrainsMono Nerd Font"
						font.pixelSize: 13
						font.bold: true
					}

					// Luminosità
					Text {
						text: "󰃠 " + root.brightnessPct + "%"
						color: root.fg
						font.family: "JetBrainsMono Nerd Font"
						font.pixelSize: 13
						font.bold: true
						MouseArea {
							anchors.fill: parent
							onWheel: wheel => {
								if (wheel.angleDelta.y > 0) root.runCmd("brightnessctl s 5%+")
								else root.runCmd("brightnessctl s 5%-")
								sysPoll.running = true
							}
						}
					}

					// Audio Sink (Pipewire)
					Text {
						property var sink: Pipewire.defaultAudioSink
						property int vol: (sink && sink.audio) ? Math.round(sink.audio.volume * 100) : 0
						property bool muted: (sink && sink.audio) ? sink.audio.muted : false
						text: muted ? "󰖁 Muto" : ("󰕾 " + vol + "%")
						color: root.fg
						font.family: "JetBrainsMono Nerd Font"
						font.pixelSize: 13
						font.bold: true
						MouseArea {
							anchors.fill: parent
							acceptedButtons: Qt.LeftButton | Qt.RightButton
							onClicked: mouse => {
								if (mouse.button === Qt.RightButton) root.runCmd("pavucontrol")
								else root.runCmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
							}
							onWheel: wheel => {
								if (wheel.angleDelta.y > 0) root.runCmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+")
								else root.runCmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")
							}
						}
					}

					// Microfono (Pipewire)
					Text {
						property var src: Pipewire.defaultAudioSource
						property int vol: (src && src.audio) ? Math.round(src.audio.volume * 100) : 0
						property bool muted: (src && src.audio) ? src.audio.muted : false
						text: muted ? " Muto" : (" " + vol + "%")
						color: root.fg
						font.family: "JetBrainsMono Nerd Font"
						font.pixelSize: 13
						font.bold: true
						MouseArea {
							anchors.fill: parent
							acceptedButtons: Qt.LeftButton | Qt.RightButton
							onClicked: mouse => {
								if (mouse.button === Qt.RightButton) root.runCmd("pavucontrol")
								else root.runCmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
							}
						}
					}

					// Bluetooth
					Text {
						text: root.btStatus
						color: root.fg
						font.family: "JetBrainsMono Nerd Font"
						font.pixelSize: 13
						font.bold: true
						MouseArea {
							anchors.fill: parent
							acceptedButtons: Qt.LeftButton | Qt.RightButton
							onClicked: mouse => {
								if (mouse.button === Qt.RightButton) root.runCmd("blueman-manager")
								else { root.runCmd("rfkill toggle bluetooth"); sysPoll.running = true }
							}
						}
					}

					// Rete
					Text {
						text: root.netStatus
						color: root.fg
						font.family: "JetBrainsMono Nerd Font"
						font.pixelSize: 13
						font.bold: true
						MouseArea {
							anchors.fill: parent
							acceptedButtons: Qt.LeftButton | Qt.RightButton
							onClicked: mouse => {
								if (mouse.button === Qt.RightButton) root.runCmd("kitty -e nmtui")
								else { root.runCmd("nmcli radio wifi toggle"); sysPoll.running = true }
							}
						}
					}

					// Batteria (UPower)
					Text {
						property var bat: UPower.displayDevice
						visible: bat && bat.isLaptopBattery
						property int pct: bat ? Math.round(bat.percentage * 100) : 100
						property bool charging: bat && bat.state === UPowerDeviceState.Charging
						text: (charging ? "󰂄 " : "󰁹 ") + pct + "%"
						color: pct <= 15 && !charging ? root.color1 : (pct <= 30 && !charging ? "#ff9e64" : root.fg)
						font.family: "JetBrainsMono Nerd Font"
						font.pixelSize: 13
						font.bold: true
					}

					// Power Drawer (espandibile come group/power di Waybar)
					RowLayout {
						spacing: 4

						Rectangle {
							width: 28; height: 28; radius: 14
							color: pwrMainMouse.containsMouse ? root.color4 : "transparent"
							Text {
								anchors.centerIn: parent
								text: "󰐥"
								color: pwrMainMouse.containsMouse ? root.bg : root.color1
								font.family: "JetBrainsMono Nerd Font"
								font.pixelSize: 15
								font.bold: true
							}
							MouseArea {
								id: pwrMainMouse
								anchors.fill: parent
								hoverEnabled: true
								onClicked: root.powerExpanded = !root.powerExpanded
							}
						}

						Repeater {
							model: root.powerExpanded ? [
								{ "icon": "󰌾", "cmd": "LOCK" },
								{ "icon": "󰤄", "cmd": "loginctl suspend" },
								{ "icon": "󰒲", "cmd": "loginctl hibernate" },
								{ "icon": "󰑐", "cmd": "loginctl reboot" },
								{ "icon": "󰐥", "cmd": "loginctl poweroff" }
							] : []
							Rectangle {
								required property var modelData
								width: 28; height: 28; radius: 14
								color: subPwrMouse.containsMouse ? root.color4 : "transparent"
								Text {
									anchors.centerIn: parent
									text: modelData.icon
									color: subPwrMouse.containsMouse ? root.bg : root.fg
									font.family: "JetBrainsMono Nerd Font"
									font.pixelSize: 15
								}
								MouseArea {
									id: subPwrMouse
									anchors.fill: parent
									hoverEnabled: true
									onClicked: {
										root.powerExpanded = false
										if (modelData.cmd === "LOCK") root.triggerLock()
										else root.runCmd(modelData.cmd)
									}
								}
							}
						}
					}
				}
			}
		}
	}

	// =========================================================
	// 3. POPUP NOTIFICHE (Toast in alto)
	// =========================================================
	PanelWindow {
		visible: root.popupNotifications.length > 0 && !root.ccVisible
		WlrLayershell.layer: WlrLayer.Overlay
		WlrLayershell.namespace: "swaync-notification-window"
		anchors { top: true }
		margins.top: 58
		implicitWidth: 400
		implicitHeight: notifPopupCol.implicitHeight + 16
		color: "transparent"

		ColumnLayout {
			id: notifPopupCol
			anchors.fill: parent
			anchors.margins: 8
			spacing: 8

			Repeater {
				model: root.popupNotifications
				Rectangle {
					required property var modelData
					Layout.fillWidth: true
					implicitHeight: 74
					radius: 15
					color: root.withAlpha(root.color0, root.isVM ? 0.95 : 0.85)
					border.width: 2
					border.color: root.color4

					ColumnLayout {
						anchors.fill: parent
						anchors.margins: 12
						spacing: 4
						Text {
							text: modelData.summary || "Notification"
							color: root.color4
							font.family: "JetBrainsMono Nerd Font"
							font.pixelSize: 14
							font.bold: true
							elide: Text.ElideRight
							Layout.fillWidth: true
						}
						Text {
							text: modelData.body || ""
							color: root.fg
							font.family: "JetBrainsMono Nerd Font"
							font.pixelSize: 12
							elide: Text.ElideRight
							Layout.fillWidth: true
						}
					}
				}
			}
		}
	}

	// =========================================================
	// 4. CONTROL CENTER (Sostituisce Swaync - Mod+N)
	// =========================================================
	PanelWindow {
		visible: root.ccVisible
		WlrLayershell.layer: WlrLayer.Top
		WlrLayershell.namespace: "swaync-control-center"
		anchors { top: true }
		margins.top: 58
		implicitWidth: 400
		implicitHeight: 580
		color: "transparent"

		Rectangle {
			anchors.fill: parent
			radius: 20
			color: Qt.rgba(30/255, 30/255, 46/255, root.isVM ? 0.95 : 0.65)
			border.width: 2
			border.color: root.color4

			ColumnLayout {
				anchors.fill: parent
				anchors.margins: 15
				spacing: 12

				// Header + Clear
				RowLayout {
					Layout.fillWidth: true
					Text {
						text: "Notifications"
						color: root.fg
						font.family: "JetBrainsMono Nerd Font"
						font.pixelSize: 20
						font.bold: true
						Layout.fillWidth: true
					}
					Rectangle {
						width: 90; height: 32; radius: 10
						color: clrMouse.containsMouse ? root.color4 : "transparent"
						border.width: 1; border.color: root.color4
						Text {
							anchors.centerIn: parent
							text: "󰎟 Clear"
							color: clrMouse.containsMouse ? root.bg : root.color4
							font.family: "JetBrainsMono Nerd Font"
							font.pixelSize: 13
							font.bold: true
						}
						MouseArea {
							id: clrMouse
							anchors.fill: parent
							hoverEnabled: true
							onClicked: {
								let list = notifServer.trackedNotifications.values
								for (let i = list.length - 1; i >= 0; i--) list[i].dismiss()
								root.popupNotifications = []
							}
						}
					}
				}

				// Griglia 5 Pulsanti Rapidi (DND, Screenshot, Mic, Lock, Power)
				Rectangle {
					Layout.fillWidth: true
					height: 68
					radius: 15
					color: root.color0
					RowLayout {
						anchors.fill: parent
						anchors.margins: 8
						spacing: 6

						Repeater {
							model: [
								{ "label": "󰖖", "act": "DND" },
								{ "label": "󰄄", "act": "SHOT" },
								{ "label": "󰍬", "act": "MIC" },
								{ "label": "󰌾", "act": "LOCK" },
								{ "label": "󰐥", "act": "PWR" }
							]
							Rectangle {
								required property var modelData
								Layout.fillWidth: true
								Layout.fillHeight: true
								radius: 12
								property bool activeState: (modelData.act === "DND" && root.dndEnabled)
								color: gridBtnMouse.containsMouse || activeState ? root.color4 : "transparent"
								Text {
									anchors.centerIn: parent
									text: modelData.label
									color: gridBtnMouse.containsMouse || parent.activeState ? root.bg : root.fg
									font.family: "JetBrainsMono Nerd Font"
									font.pixelSize: 22
									font.bold: true
								}
								MouseArea {
									id: gridBtnMouse
									anchors.fill: parent
									hoverEnabled: true
									onClicked: {
										if (modelData.act === "DND") root.dndEnabled = !root.dndEnabled
										else if (modelData.act === "SHOT") { root.ccVisible = false; root.runCmd("sleep 0.2; grim -g \"$(slurp)\" - | swappy -f -") }
										else if (modelData.act === "MIC") root.runCmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
										else if (modelData.act === "LOCK") root.triggerLock()
										else if (modelData.act === "PWR") { root.ccVisible = false; root.powerExpanded = true }
									}
								}
							}
						}
					}
				}

				// Widget Volume Slider
				Rectangle {
					Layout.fillWidth: true
					height: 48
					radius: 15
					color: root.color0
					RowLayout {
						anchors.fill: parent
						anchors.leftMargin: 15; anchors.rightMargin: 15
						spacing: 12
						Text {
							text: "󰕾"
							color: root.color4
							font.family: "JetBrainsMono Nerd Font"
							font.pixelSize: 20
						}
						Rectangle {
							Layout.fillWidth: true
							height: 10
							radius: 5
							color: Qt.rgba(1, 1, 1, 0.1)
							property real pct: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) ? Math.min(1, Pipewire.defaultAudioSink.audio.volume) : 0
							Rectangle {
								width: parent.width * parent.pct
								height: parent.height
								radius: 5
								color: root.color4
							}
							MouseArea {
								anchors.fill: parent
								onClicked: mouse => {
									let v = Math.max(0, Math.min(1, mouse.x / width))
									if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) Pipewire.defaultAudioSink.audio.volume = v
								}
							}
						}
					}
				}

				// Widget Backlight Slider
				Rectangle {
					Layout.fillWidth: true
					height: 48
					radius: 15
					color: root.color0
					RowLayout {
						anchors.fill: parent
						anchors.leftMargin: 15; anchors.rightMargin: 15
						spacing: 12
						Text {
							text: "󰃠"
							color: root.color4
							font.family: "JetBrainsMono Nerd Font"
							font.pixelSize: 20
						}
						Rectangle {
							Layout.fillWidth: true
							height: 10
							radius: 5
							color: Qt.rgba(1, 1, 1, 0.1)
							Rectangle {
								width: parent.width * (root.brightnessPct / 100.0)
								height: parent.height
								radius: 5
								color: root.color4
							}
							MouseArea {
								anchors.fill: parent
								onClicked: mouse => {
									let p = Math.max(5, Math.min(100, Math.round((mouse.x / width) * 100)))
									root.brightnessPct = p
									root.runCmd("brightnessctl s " + p + "%")
								}
							}
						}
					}
				}

				// Lista Notifiche
				ListView {
					Layout.fillWidth: true
					Layout.fillHeight: true
					clip: true
					spacing: 8
					model: notifServer.trackedNotifications
					delegate: Rectangle {
						required property var modelData
						width: ListView.view.width
						height: 68
						radius: 15
						color: root.color0

						RowLayout {
							anchors.fill: parent
							anchors.margins: 12
							ColumnLayout {
								Layout.fillWidth: true
								spacing: 2
								Text {
									text: modelData.summary || "Notification"
									color: root.color4
									font.family: "JetBrainsMono Nerd Font"
									font.pixelSize: 13
									font.bold: true
									elide: Text.ElideRight
									Layout.fillWidth: true
								}
								Text {
									text: modelData.body || ""
									color: root.fg
									font.family: "JetBrainsMono Nerd Font"
									font.pixelSize: 12
									elide: Text.ElideRight
									Layout.fillWidth: true
								}
							}
							Rectangle {
								width: 24; height: 24; radius: 12
								color: root.color1
								Text {
									anchors.centerIn: parent
									text: "✕"
									color: root.fg
									font.pixelSize: 12
									font.bold: true
								}
								MouseArea {
									anchors.fill: parent
									onClicked: modelData.dismiss()
								}
							}
						}
					}
				}
			}
		}
	}

	// =========================================================
	// 5. APP LAUNCHER (Sostituisce Fuzzel - Mod+Space)
	// =========================================================
	PanelWindow {
		id: launcherWin
		visible: root.launcherVisible
		WlrLayershell.layer: WlrLayer.Overlay
		WlrLayershell.namespace: "launcher"
		WlrLayershell.keyboardFocus: root.launcherVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
		implicitWidth: 460
		implicitHeight: 420
		color: "transparent"

		property string searchQuery: ""
		property int selectedIndex: 0

		onVisibleChanged: {
			if (visible) {
				searchQuery = ""
				selectedIndex = 0
				searchInput.text = ""
				searchInput.forceActiveFocus()
			}
		}

		property var filteredApps: {
			let all = DesktopEntries.applications.values
			let q = searchQuery.toLowerCase().trim()
			let res = []
			for (let i = 0; i < all.length; i++) {
				let app = all[i]
				if (q === "" || (app.name && app.name.toLowerCase().includes(q)) || (app.genericName && app.genericName.toLowerCase().includes(q))) {
					res.push(app)
				}
			}
			return res
		}

		Rectangle {
			anchors.fill: parent
			radius: 15
			color: root.withAlpha(root.bg, root.isVM ? 0.96 : 0.90)
			border.width: 2
			border.color: root.color4

			ColumnLayout {
				anchors.fill: parent
				anchors.margins: 20
				spacing: 12

				// Barra di ricerca
				Rectangle {
					Layout.fillWidth: true
					height: 40
					radius: 10
					color: root.color0
					border.width: 1
					border.color: root.color4

					RowLayout {
						anchors.fill: parent
						anchors.leftMargin: 12; anchors.rightMargin: 12
						Text {
							text: "> "
							color: root.color2
							font.family: "JetBrainsMono Nerd Font"
							font.pixelSize: 15
							font.bold: true
						}
						TextInput {
							id: searchInput
							Layout.fillWidth: true
							color: root.fg
							font.family: "JetBrainsMono Nerd Font"
							font.pixelSize: 15
							font.bold: true
							clip: true
							onTextChanged: {
								launcherWin.searchQuery = text
								launcherWin.selectedIndex = 0
							}
							Keys.onDownPressed: {
								if (launcherWin.selectedIndex < launcherWin.filteredApps.length - 1) launcherWin.selectedIndex++
							}
							Keys.onUpPressed: {
								if (launcherWin.selectedIndex > 0) launcherWin.selectedIndex--
							}
							Keys.onEscapePressed: root.launcherVisible = false
							Keys.onReturnPressed: {
								if (launcherWin.filteredApps.length > 0) {
									let app = launcherWin.filteredApps[launcherWin.selectedIndex]
									root.launcherVisible = false
									app.execute()
								}
							}
						}
					}
				}

				// Lista Applicazioni
				ListView {
					id: appListView
					Layout.fillWidth: true
					Layout.fillHeight: true
					clip: true
					spacing: 4
					model: launcherWin.filteredApps
					currentIndex: launcherWin.selectedIndex

					delegate: Rectangle {
						required property var modelData
						required property int index
						width: ListView.view.width
						height: 36
						radius: 8
						property bool isSel: index === launcherWin.selectedIndex
						color: isSel ? root.withAlpha(root.color8, 0.9) : (appMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")

						RowLayout {
							anchors.fill: parent
							anchors.leftMargin: 10; anchors.rightMargin: 10
							spacing: 10

							IconImage {
								implicitSize: 22
								source: Quickshell.iconPath(modelData.icon, true)
							}

							Text {
								text: modelData.name
								color: parent.parent.isSel ? root.color2 : root.fg
								font.family: "JetBrainsMono Nerd Font"
								font.pixelSize: 14
								font.bold: true
								elide: Text.ElideRight
								Layout.fillWidth: true
							}
						}

						MouseArea {
							id: appMouse
							anchors.fill: parent
							hoverEnabled: true
							onClicked: {
								root.launcherVisible = false
								modelData.execute()
							}
						}
					}
				}
			}
		}
	}
}
