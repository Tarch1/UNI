import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

ShellRoot {
	id: root

	property string homeDir: Quickshell.env("HOME")
	property bool isVM: Quickshell.env("QSG_RENDER_LOOP") === "basic"
	property color bg: "#1e1e2e"
	property color fg: "#cdd6f4"
	property color color1: "#f38ba8"
	property color color4: "#89b4fa"
	property string timeStr: Qt.formatDateTime(new Date(), "HH:mm")
	property bool authError: false
	property bool authBusy: false

	FileView {
		path: root.homeDir + "/.config/quickshell/colors.json"
		blockLoading: true
		onLoaded: {
			try {
				let d = JSON.parse(text())
				if (d.background) root.bg = d.background
				if (d.foreground) root.fg = d.foreground
				if (d.color1) root.color1 = d.color1
				if (d.color4) root.color4 = d.color4
			} catch (e) {}
		}
	}

	Timer {
		interval: 1000
		running: true
		repeat: true
		onTriggered: root.timeStr = Qt.formatDateTime(new Date(), "HH:mm")
	}

	PamContext {
		id: pam
		config: "quickshell"
		onResponseRequiredChanged: {
			if (responseRequired && root.authBusy) {
				respond(root.pendingPassword)
			}
		}
		onCompleted: result => {
			root.authBusy = false
			if (result === PamResult.Success) {
				sessionLock.locked = false
				Qt.quit()
			} else {
				root.authError = true
			}
		}
	}

	property string pendingPassword: ""

	function submitPassword(pw) {
		if (root.authBusy || pw === "") return
		root.authError = false
		root.authBusy = true
		root.pendingPassword = pw
		pam.start()
	}

	WlSessionLock {
		id: sessionLock
		locked: true

		WlSessionLockSurface {
			id: surface
			color: root.bg

			// Cattura istantanea dello schermo via GPU (wlr-screencopy)
			ScreencopyView {
				id: screenCapture
				anchors.fill: parent
				captureSource: surface.screen
				live: false
				visible: root.isVM
			}

			// Blur GPU (attivo solo su PC reale, spento in VM)
			MultiEffect {
				anchors.fill: parent
				source: screenCapture
				visible: !root.isVM
				blurEnabled: !root.isVM
				blurMax: 48
				blur: 1.0
			}

			// Leggero velo scuro per contrasto testo
			Rectangle {
				anchors.fill: parent
				color: Qt.rgba(0, 0, 0, 0.25)
			}

			// Orologio (identico a hyprlock.conf: 64px, offset -80 dal centro)
			Text {
				anchors.horizontalCenter: parent.horizontalCenter
				anchors.verticalCenter: parent.verticalCenter
				anchors.verticalCenterOffset: -80
				text: root.timeStr
				color: root.fg
				font.family: "JetBrainsMono Nerd Font"
				font.pixelSize: 64
				font.bold: true
			}

			// Campo Password a pillola (250x50, bordo 3px color4)
			Rectangle {
				width: 250
				height: 50
				radius: 25
				anchors.horizontalCenter: parent.horizontalCenter
				anchors.verticalCenter: parent.verticalCenter
				anchors.verticalCenterOffset: 20
				color: root.bg
				border.width: 3
				border.color: root.authError ? root.color1 : root.color4

				TextInput {
					id: pwInput
					anchors.fill: parent
					anchors.leftMargin: 20
					anchors.rightMargin: 20
					verticalAlignment: TextInput.AlignVCenter
					horizontalAlignment: TextInput.AlignHCenter
					echoMode: TextInput.Password
					passwordCharacter: "●"
					color: root.fg
					font.family: "JetBrainsMono Nerd Font"
					font.pixelSize: 18
					focus: true
					Component.onCompleted: forceActiveFocus()
					onTextChanged: root.authError = false
					Keys.onReturnPressed: {
						let pw = text
						text = ""
						root.submitPassword(pw)
					}
				}

				Text {
					anchors.centerIn: parent
					visible: pwInput.text.length === 0
					text: root.authError ? "Wrong password..." : "Password..."
					color: root.authError ? root.color1 : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.5)
					font.family: "JetBrainsMono Nerd Font"
					font.pixelSize: 15
					font.italic: true
				}
			}
		}
	}
}
