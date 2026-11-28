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
  // USER CONFIGURATION & TUNING VARIABLES (BLUR, ANIMATIONS & POWER SAVING)
  // =========================================================================
  property bool cfgEnableBlur: !isVM
  property bool cfgEnableAnimations: true
  property int cfgIslandAnimMs: 120
  property int cfgIslandEasing: Easing.OutQuad
  property string cfgSubmenuAnimStyle: "fade"
  property int cfgSubmenuAnimMs: 100
  property int cfgSubmenuSlidePx: 14
  // Wallpaper transition: "swarm" (Silhouette + Swarm patches) | "crossfade" | "zoom" | "none"
  property string cfgWallpaperTransition: "swarm"
  property int cfgWallpaperTransitionMs: 2400
  property real cfgGlassOpacity: 0.76
  property real cfgSolidOpacity: 0.96
  property bool cfgLockKeepAnimated: true
  property int cfgLockBlurMax: 48
  property bool cfgPauseOnFullscreen: true
  property bool cfgPauseOnScreenOff: true
  property int cfgBarAutoCloseMs: 2000
  // =========================================================================

  // === REUSABLE UI COMPONENTS ===

  component QsText: Text {
    color: root.fg
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 12
  }

  component QsChip: Rectangle {
    id: chipRoot
    property string text: ""
    property color textCol: root.fg
    property color bgCol: root.subtleFill
    property int fontSize: 10
    property bool boldText: true
    signal chipClicked(int button)

    implicitWidth: Math.max(24, chipTxt.implicitWidth + 14)
    implicitHeight: 22
    radius: 7
    color: bgCol
    QsText { id: chipTxt; anchors.centerIn: parent; text: chipRoot.text; color: chipRoot.textCol; font.pixelSize: chipRoot.fontSize; font.bold: chipRoot.boldText }
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: mouse => chipRoot.chipClicked(mouse.button)
    }
  }

  component QsTile: Rectangle {
    id: tileRoot
    property string icon: ""
    property string iconSource: ""
    property string title: ""
    property string sub: ""
    property string extra: ""
    property string rightText: ""
    property bool active: false
    property bool highlighted: false
    property bool interactive: true
    property color accentCol: root.color4
    property color iconFg: active ? root.bg : root.fg
    property color subCol: active ? accentCol : root.color8
    property color rightCol: root.color4
    signal tileClicked(int button)
    signal iconClicked(int button)

    Layout.fillWidth: true
    implicitHeight: extra !== "" ? 64 : 52
    radius: 14
    color: highlighted ? root.withAlpha(accentCol, 0.18) : ((interactive && tMouse.containsMouse) ? root.cardHoverCol : root.color0)
    border.width: highlighted ? 1 : 0
    border.color: accentCol

    MouseArea {
      id: tMouse; anchors.fill: parent; enabled: tileRoot.interactive; hoverEnabled: tileRoot.interactive
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: mouse => tileRoot.tileClicked(mouse.button)
    }
    Rectangle {
      id: tSq; width: 34; height: 34; radius: 10
      anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
      color: tileRoot.active ? tileRoot.accentCol : root.subtleFill
      IconImage { anchors.centerIn: parent; visible: tileRoot.iconSource !== ""; implicitSize: 20; source: tileRoot.iconSource }
      QsText { anchors.centerIn: parent; visible: tileRoot.iconSource === ""; text: tileRoot.icon; color: tileRoot.iconFg; font.pixelSize: 15; font.bold: true }
      MouseArea {
        anchors.fill: parent; enabled: tileRoot.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => tileRoot.iconClicked(mouse.button)
      }
    }
    QsText {
      id: tRightTxt; visible: tileRoot.rightText !== ""
      anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
      text: tileRoot.rightText; color: tileRoot.rightCol; font.pixelSize: 10; font.bold: true
    }
    ColumnLayout {
      anchors.left: tSq.right; anchors.leftMargin: 8
      anchors.right: tRightTxt.visible ? tRightTxt.left : parent.right; anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter; spacing: 1
      QsText { text: tileRoot.title; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
      QsText { visible: tileRoot.sub !== ""; text: tileRoot.sub; color: tileRoot.subCol; font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideRight }
      QsText { visible: tileRoot.extra !== ""; text: tileRoot.extra; color: root.color8; font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideMiddle }
    }
  }

  component QsBar: Rectangle {
    id: barRoot
    property string icon: ""
    property string label: ""
    property int pct: 0
    property string rightText: pct + "%"
    property color accentCol: root.color4
    property color iconBg: root.withAlpha(accentCol, 0.22)
    property color iconFg: accentCol
    property bool interactive: false
    signal iconClicked(int button)
    signal barPressed(int button, real ratio)
    signal barMoved(real ratio)

    Layout.fillWidth: true; implicitHeight: 46; radius: 14
    color: (interactive && bCardMouse.containsMouse && root.sysSubmenu === "") ? root.cardHoverCol : root.color0

    MouseArea {
      id: bCardMouse; anchors.fill: parent; enabled: barRoot.interactive; hoverEnabled: barRoot.interactive
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: mouse => barRoot.barPressed(mouse.button, -1)
    }
    Rectangle {
      id: bSq; width: 34; height: 34; radius: 10
      anchors.left: parent.left; anchors.leftMargin: 7; anchors.verticalCenter: parent.verticalCenter
      color: barRoot.iconBg
      QsText { anchors.centerIn: parent; text: barRoot.icon; color: barRoot.iconFg; font.pixelSize: 16 }
      MouseArea {
        anchors.fill: parent; enabled: barRoot.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => barRoot.iconClicked(mouse.button)
      }
    }
    Rectangle {
      anchors.left: bSq.right; anchors.leftMargin: 7; anchors.right: parent.right; anchors.rightMargin: 7
      anchors.verticalCenter: parent.verticalCenter; height: 30; radius: 9; clip: true; color: root.subtleFill
      Rectangle { width: parent.width * Math.max(0, Math.min(1, barRoot.pct / 100.0)); height: parent.height; radius: 9; color: root.withAlpha(barRoot.accentCol, 0.78) }
      QsText {
        anchors.left: parent.left; anchors.leftMargin: 10; anchors.right: bRightTxt.left; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
        text: barRoot.label; elide: Text.ElideRight; style: Text.Outline; styleColor: root.withAlpha(root.bg, 0.7); font.pixelSize: 11; font.bold: true
      }
      QsText {
        id: bRightTxt; anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
        text: barRoot.rightText; style: Text.Outline; styleColor: root.withAlpha(root.bg, 0.7); font.pixelSize: 11; font.bold: true
      }
      MouseArea {
        anchors.fill: parent; enabled: barRoot.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => barRoot.barPressed(mouse.button, mouse.x / width)
        onPositionChanged: mouse => { if (pressed && (mouse.buttons & Qt.LeftButton)) barRoot.barMoved(mouse.x / width) }
      }
    }
  }

  component QsMediaControls: RowLayout {
    id: mcBtns
    property int btnSize: 24
    property int playSize: 32
    property int iconSize: 18
    property int playIconSize: 16
    property bool pillBg: true
    spacing: 22

    Repeater {
      model: ["prev", "play", "next"]
      Rectangle {
        required property string modelData
        property bool isPlay: modelData === "play"
        implicitWidth: isPlay ? mcBtns.playSize : mcBtns.btnSize
        implicitHeight: isPlay ? mcBtns.playSize : mcBtns.btnSize
        radius: 8
        color: (isPlay && mcBtns.pillBg) ? root.subtleFillHover : "transparent"
        QsText {
          anchors.centerIn: parent
          text: modelData === "prev" ? "󰒮" : (modelData === "next" ? "󰒭" : ((root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing) ? "󰏤" : "󰐊"))
          color: (!mcBtns.pillBg && parent.isPlay) ? root.color4 : root.fg
          font.pixelSize: parent.isPlay ? mcBtns.playIconSize : mcBtns.iconSize
        }
        MouseArea { anchors.fill: parent; onClicked: root.mediaAction(modelData) }
      }
    }
  }

  component QsWallMedia: Item {
    id: wmRoot
    property bool activeVideo: false
    property bool activeGif: false
    property bool active: activeVideo || activeGif
    property bool playing: false
    property string mediaPath: ""

    function syncVideo() {
      if (!activeVideo || mediaPath === "") { vPlayer.stop(); return }
      if (playing) vPlayer.play()
      else vPlayer.pause()
    }
    onPlayingChanged: syncVideo()
    onActiveVideoChanged: syncVideo()
    Component.onCompleted: syncVideo()

    AnimatedImage {
      anchors.fill: parent; visible: wmRoot.activeGif && wmRoot.playing
      source: (wmRoot.activeGif && wmRoot.mediaPath !== "") ? ("file://" + wmRoot.mediaPath) : ""
      playing: wmRoot.activeGif && wmRoot.playing
      fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false; smooth: true
    }
    MediaPlayer {
      id: vPlayer
      source: (wmRoot.activeVideo && wmRoot.mediaPath !== "") ? ("file://" + wmRoot.mediaPath) : ""
      loops: MediaPlayer.Infinite; videoOutput: vOut
      onSourceChanged: wmRoot.syncVideo()
    }
    VideoOutput {
      id: vOut; anchors.fill: parent; visible: wmRoot.activeVideo && wmRoot.playing
      fillMode: VideoOutput.PreserveAspectCrop
    }
  }

  component QsMetricCard: Rectangle {
    id: mcRoot
    property string icon: ""
    property string title: ""
    property string sub: ""
    property string valueText: ""
    property string timeLabel: "last 60 s"
    property string unitSuffix: "%"
    property real minBound: 0
    property real maxBound: 100
    property bool autoScale: true
    property var history: []
    property color accentCol: root.color4

    property real effMax: {
      if (!autoScale) return maxBound
      let mx = minBound + 10
      for (let i = 0; i < history.length; i++) if (history[i] > mx) mx = history[i]
      return mx <= 22 ? 25 : (mx <= 48 ? 50 : (mx <= 72 ? 75 : maxBound))
    }

    Layout.fillWidth: true; implicitHeight: 102; radius: 14; color: root.color0
    onHistoryChanged: { if (visible) graphCanvas.requestPaint() }
    onVisibleChanged: { if (visible) graphCanvas.requestPaint() }

    ColumnLayout {
      anchors.fill: parent; anchors.margins: 8; spacing: 4
      RowLayout {
        Layout.fillWidth: true; spacing: 8
        Rectangle {
          implicitWidth: 32; implicitHeight: 32; radius: 9; color: root.withAlpha(mcRoot.accentCol, 0.2)
          QsText { anchors.centerIn: parent; text: mcRoot.icon; color: mcRoot.accentCol; font.pixelSize: 15; font.bold: true }
        }
        ColumnLayout {
          Layout.fillWidth: true; spacing: 1
          QsText { text: mcRoot.title; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
          QsText { text: mcRoot.sub; color: root.color8; font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideRight }
        }
        QsText { text: mcRoot.valueText; color: mcRoot.accentCol; font.pixelSize: 15; font.bold: true }
      }

      Item {
        Layout.fillWidth: true; Layout.fillHeight: true
        Canvas {
          id: graphCanvas; anchors.fill: parent
          onPaint: {
            var ctx = getContext("2d"); ctx.reset()
            var w = width, h = height, padL = 30, padR = 6, padT = 5, padB = 4
            var gw = w - padL - padR, gh = h - padT - padB
            if (gw <= 4 || gh <= 4) return

            ctx.strokeStyle = root.subtleFillHover.toString()
            ctx.lineWidth = 1; ctx.setLineDash([3, 3]); ctx.beginPath()
            ctx.moveTo(padL, padT); ctx.lineTo(w - padR, padT)
            ctx.moveTo(padL, padT + gh * 0.5); ctx.lineTo(w - padR, padT + gh * 0.5)
            ctx.moveTo(padL, padT + gh); ctx.lineTo(w - padR, padT + gh)
            ctx.stroke(); ctx.setLineDash([])

            var raw = mcRoot.history
            if (!raw || raw.length === 0) return
            var pts = raw
            if (raw.length > 120) {
              pts = []
              var st = (raw.length - 1) / 119.0
              for (var s = 0; s < 120; s++) pts.push(raw[Math.round(s * st)])
            }
            var lo = mcRoot.minBound, hi = Math.max(lo + 1, mcRoot.effMax), n = pts.length, coords = []
            for (var i = 0; i < n; i++) {
              var norm = Math.max(0, Math.min(1, (pts[i] - lo) / (hi - lo)))
              coords.push({ x: padL + (n > 1 ? (i / (n - 1)) * gw : gw), y: padT + gh * (1.0 - norm) })
            }
            if (coords.length === 1) coords.unshift({ x: padL, y: coords[0].y })

            ctx.beginPath(); ctx.moveTo(coords[0].x, coords[0].y)
            for (var j = 0; j < coords.length - 1; j++) {
              ctx.quadraticCurveTo(coords[j].x, coords[j].y, (coords[j].x + coords[j + 1].x) * 0.5, (coords[j].y + coords[j + 1].y) * 0.5)
            }
            var last = coords[coords.length - 1]
            ctx.lineTo(last.x, last.y)
            ctx.lineWidth = 2.0; ctx.strokeStyle = mcRoot.accentCol.toString(); ctx.stroke()

            ctx.lineTo(last.x, padT + gh); ctx.lineTo(coords[0].x, padT + gh); ctx.closePath()
            var grad = ctx.createLinearGradient(0, padT, 0, padT + gh)
            grad.addColorStop(0, root.withAlpha(mcRoot.accentCol, 0.30).toString())
            grad.addColorStop(1, root.withAlpha(mcRoot.accentCol, 0.01).toString())
            ctx.fillStyle = grad; ctx.fill()

            ctx.beginPath(); ctx.arc(last.x, last.y, 3.2, 0, Math.PI * 2)
            ctx.fillStyle = mcRoot.accentCol.toString(); ctx.fill()
          }
        }
        QsText { anchors.left: parent.left; anchors.top: parent.top; text: Math.round(mcRoot.effMax) + mcRoot.unitSuffix; color: root.color8; font.pixelSize: 9 }
        QsText { anchors.left: parent.left; anchors.bottom: parent.bottom; text: Math.round(mcRoot.minBound) + mcRoot.unitSuffix; color: root.color8; font.pixelSize: 9 }
        QsText { anchors.right: parent.right; anchors.rightMargin: 6; anchors.top: parent.top; text: mcRoot.timeLabel; color: root.color8; font.pixelSize: 9 }
      }
    }
  }

  // === ENVIRONMENT, THEME & RUNTIME STATE ===

  property string homeDir: Quickshell.env("HOME")
  property string currentSessionUser: (Quickshell.env("USER") || Quickshell.env("LOGNAME") || "user").toLowerCase()
  property bool isVM: Quickshell.env("QSG_RENDER_LOOP") === "basic"
  property bool isHyprland: Quickshell.env("XDG_CURRENT_DESKTOP") === "Hyprland"
  property bool isGreeterMode: Quickshell.env("QS_GREETER") === "1"
  property bool isInitialLogin: Quickshell.env("QS_START_LOCKED") === "1" || isGreeterMode

  property bool blurActive: cfgEnableBlur && !isVM
  property bool animActive: cfgEnableAnimations
  property int animMs: animActive ? cfgIslandAnimMs : 0
  property real panelAlpha: blurActive ? cfgGlassOpacity : cfgSolidOpacity

  property string wallpaperPath: ""
  property string wallpaperFrame: ""
  property string wallpaperSilhouette: ""
  property string prevWallSource: ""
  property string liveMediaPath: ""
  property bool liveMediaIsVideo: false
  property bool liveMediaIsGif: false
  property bool prevWasLive: false
  property bool wallSwitching: false
  property bool wallTransitionActive: false
  property bool animWallpapers: false
  property bool firstRunDone: false
  property bool isVideoFile: wallpaperPath.toLowerCase().endsWith(".webm") || wallpaperPath.toLowerCase().endsWith(".mp4")
  property bool isAnimatedGif: !isVideoFile && (wallpaperPath.toLowerCase().endsWith(".gif") || (animWallpapers && wallpaperPath.toLowerCase().endsWith(".webp")))
  property string staticWallSource: wallpaperPath === "" ? "" : (isVideoFile ? (wallpaperFrame !== "" ? ("file://" + wallpaperFrame) : "") : ("file://" + wallpaperPath))
  property bool hasActiveFullWindow: false
  property bool isMonitorDpmsOff: false
  property bool shouldPlayAnimation: {
    if (!animWallpapers || (!isVideoFile && !isAnimatedGif)) return false
    if (screenLocked) return false
    if (cfgPauseOnScreenOff && isMonitorDpmsOff) return false
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
  property color color0: "#282a36"
  property color color1: "#f38ba8"
  property color color2: "#a6e3a1"
  property color color3: "#f9e2af"
  property color color4: "#89b4fa"
  property color color5: "#cba6f7"
  property color color6: "#94e2d5"
  property color color8: "#585b70"
  property bool isLightTheme: (0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b) > 0.5
  property color subtleFill: isLightTheme ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(1, 1, 1, 0.08)
  property color subtleFillHover: isLightTheme ? Qt.rgba(0, 0, 0, 0.13) : Qt.rgba(1, 1, 1, 0.14)
  property color cardHoverCol: isLightTheme ? Qt.darker(color0, 1.06) : Qt.lighter(color0, 1.12)

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
      if (!a.noDisplay && (q === "" || (a.name && a.name.toLowerCase().includes(q)) || (a.genericName && a.genericName.toLowerCase().includes(q)) || (a.comment && a.comment.toLowerCase().includes(q)))) res.push(a)
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

  property bool audioReady: false
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

  property bool hasBattery: UPower.displayDevice ? UPower.displayDevice.isLaptopBattery : false
  property bool canHibernate: false
  property int batPct: (UPower.displayDevice && UPower.displayDevice.isLaptopBattery) ? Math.round(UPower.displayDevice.percentage * 100) : 100
  property bool batCharging: UPower.displayDevice && UPower.displayDevice.state === UPowerDeviceState.Charging
  property string batHealth: "100%"
  property string batPowerDraw: "0.0 W"
  property string batCycles: "0"
  property string batTech: "Li-ion"
  property var batHistory: []
  property string batTimeLabel: {
    let mins = Math.max(0, (batHistory.length - 1) * 2)
    if (mins < 2) return "live"
    if (mins < 60) return "last " + mins + " m"
    let hrs = mins / 60.0
    return "last " + (hrs >= 10 ? Math.round(hrs) : hrs.toFixed(1)) + " h"
  }

  property bool isRecording: false
  property int recSeconds: 0
  property bool recSysAudio: true
  property bool recMicAudio: false
  property bool recAreaSelect: false

  property string cpuModel: "Processor"
  property string cpuThreads: "4 threads"
  property string cpuLoad: "0.20"
  property int cpuUsage: 0
  property int cpuTemp: 40
  property string ramInfo: "0 / 0 GiB"
  property string ramSlotsInfo: "System RAM"
  property int ramPct: 0
  property var cpuHistory: []
  property var tempHistory: []
  property var ramHistory: []

  property string diskRootInfo: "0 / 0 GiB"
  property int diskRootPct: 0
  property string diskSecInfo: "Not mounted"
  property string kernelVer: "Linux"
  property string uptimeStr: "0m"
  property var workspacesList: [{ "idx": 1, "active": true, "occupied": true }]
  property var popupNotifications: []

  property var usersList: [currentSessionUser]
  property int selectedUserIdx: 0
  property string selectedUser: (usersList.length > 0 && selectedUserIdx >= 0 && selectedUserIdx < usersList.length) ? usersList[selectedUserIdx] : currentSessionUser
  property bool isSwitchingUser: !isGreeterMode && selectedUser !== currentSessionUser

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
    return parts.length < 4 ? "" : (parts[1].trim() + "   •   󰖝 " + parts[2].replace("Wind:", "").trim() + "   •   󰖎 " + parts[3].replace("Hum:", "").trim())
  }

  property var activePlayer: {
    let list = Mpris.players.values
    if (!list || list.length === 0) return null
    for (let i = 0; i < list.length; i++) if (list[i].playbackState === MprisPlaybackState.Playing) return list[i]
    return list[0]
  }

  // === INTERNAL HELPERS: UTILITIES & RENDERING ===

  function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
  function runCmd(cmd) { Quickshell.execDetached(["bash", "-c", cmd]) }
  function shQuote(s) { return "'" + String(s || "").replace(/'/g, "'\\''") + "'" }
  function pushHist(arr, val, maxLen) {
    let a = arr ? arr.slice() : []
    a.push(val); if (a.length > (maxLen || 30)) a.shift()
    return a
  }
  function parseList(raw, minCols, fn) {
    let r = raw.split(";"), a = []
    for (let i = 0; i < r.length; i++) {
      let f = r[i].split("^")
      if (f.length >= minCols && f[0] !== "") {
        let item = fn(f)
        if (item !== null) a.push(item)
      }
    }
    return a
  }
  function formatSec(s) {
    let sec = Math.max(0, Math.floor(s || 0)), m = Math.floor(sec / 60), r = sec % 60
    return m + ":" + (r < 10 ? "0" + r : r)
  }
  function updateClock() {
    let now = new Date()
    root.timeStr = Qt.formatDateTime(now, "HH:mm")
    root.dateStr = Qt.formatDateTime(now, "dd MMM")
  }
  function saveJsonBool(key, val, extraCmd) {
    runCmd((extraCmd || "") + "sed -i 's/\"" + key + "\": *[a-z]*/\"" + key + "\": " + (val ? "true" : "false") + "/' \"" + root.homeDir + "/.config/quickshell/colors.json\" 2>/dev/null || true")
  }
  function paintArc(canvas, pct, strokeCol) {
    var ctx = canvas.getContext("2d"); ctx.reset()
    var cx = canvas.width / 2, cy = canvas.height / 2, r = (canvas.width / 2) - 3
    ctx.lineWidth = 2.6; ctx.lineCap = "round"
    ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2, false); ctx.strokeStyle = root.subtleFillHover.toString(); ctx.stroke()
    if (pct > 0.005) {
      var s = -Math.PI / 2
      ctx.beginPath(); ctx.arc(cx, cy, r, s, s + Math.PI * 2 * Math.min(1, pct), false); ctx.strokeStyle = strokeCol.toString(); ctx.stroke()
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

  // === INTERNAL HELPERS: SESSION, POWER, APPS & MEDIA ===

  function execPower(action) {
    if (action === "lock") { root.triggerLock(); return }
    if (action === "logout") { root.cleanExitSession(""); return }
    if (action === "suspend" || action === "hibernate") { root.isMonitorDpmsOff = true; root.triggerLock() }
    const cmds = {
      "poweroff": "loginctl poweroff 2>/dev/null || sudo -n poweroff 2>/dev/null || poweroff",
      "reboot": "loginctl reboot 2>/dev/null || sudo -n reboot 2>/dev/null || reboot",
      "suspend": "sleep 0.3; if { [ -f /etc/elogind/sleep.conf.d/10-installer-hibernate.conf ] || [ -f /etc/systemd/sleep.conf.d/10-installer-hibernate.conf ]; } && grep -qi discharging /sys/class/power_supply/BAT*/status 2>/dev/null; then loginctl suspend-then-hibernate 2>/dev/null || loginctl suspend; else loginctl suspend 2>/dev/null || sudo -n zzz 2>/dev/null || zzz; fi",
      "hibernate": "sleep 0.3; loginctl hibernate 2>/dev/null || sudo -n ZZZ 2>/dev/null || ZZZ"
    }
    if (cmds[action]) runCmd(cmds[action])
  }
  function cleanExitSession(targetUser) {
    let sw = targetUser !== "" ? ("sudo -n /usr/bin/qs-session --switch " + shQuote(targetUser) + " 2>/dev/null || true; ") : "rm -f /tmp/qs_lock_active_$UID 2>/dev/null || true; "
    let clean = "pkill -u \"$UID\" -f '[t]heming --daemon|[q]s-session --clipboard' 2>/dev/null || true; pkill -u \"$UID\" -x 'hypridle|wlsunset|wf-recorder' 2>/dev/null || true; command -v systemctl >/dev/null 2>&1 || pkill -u \"$UID\" -x 'wireplumber|pipewire-pulse|pipewire' 2>/dev/null || true; "
    let wmExit = "niri msg action quit -s 2>/dev/null || hyprctl dispatch exit 2>/dev/null || loginctl terminate-session $XDG_SESSION_ID 2>/dev/null || pkill -TERM -u \"$UID\" -x 'niri|Hyprland'"
    runCmd(sw + clean + wmExit)
  }
  function launchApp(a) {
    if (!a) return
    root.closeCenterPill()
    if (a.runInTerminal) {
      let cmd = (a.command && a.command.length > 0) ? ["kitty", "-e"].concat(a.command) : ["kitty", "-e", a.execString.replace(/%[fFuUdDnNickvm]/g, "").trim()]
      Quickshell.execDetached({ command: cmd, workingDirectory: a.workingDirectory || root.homeDir })
    } else a.execute()
  }
  function focusWorkspace(idx) {
    root.lastActiveWs = idx
    runCmd((root.isHyprland ? "hyprctl dispatch workspace " : "niri msg action focus-workspace ") + idx)
  }
  function mediaAction(act) {
    if (!root.activePlayer) return
    if (act === "prev") root.activePlayer.previous()
    else if (act === "next") root.activePlayer.next()
    else root.activePlayer.togglePlaying()
  }
  function activateTrayItem(item, win, itemWidget, button) {
    try {
      let pos = itemWidget ? itemWidget.mapToItem(null, 0, itemWidget.height) : Qt.point(200, 48)
      if (button === Qt.RightButton) { if (item.hasMenu) item.display(win, pos.x, pos.y); else item.secondaryActivate() }
      else { if (item.onlyMenu && item.hasMenu) item.display(win, pos.x, pos.y); else item.activate() }
    } catch (e) {}
  }
  function cycleUser(step) {
    if (root.usersList.length <= 1) return
    let n = root.usersList.length
    root.selectedUserIdx = (root.selectedUserIdx + (step % n) + n) % n
    root.authError = false; root.lockPromptActive = true
  }
  function checkFirstRunNiri() {
    if (!root.firstRunDone && !root.isHyprland && !root.screenLocked) {
      root.firstRunDone = true
      saveJsonBool("firstRunDone", true, "sleep 0.6 && niri msg action show-hotkey-overlay >/dev/null 2>&1 & ")
    }
  }

  // === INTERNAL HELPERS: PANEL NAVIGATION & LOCK ===

  function clearSubState() {
    root.wifiPromptSsid = ""; root.expandedResMon = ""; root.showSavedList = false; root.expandedDevInfo = ""
  }
  function closeCenterPill() {
    autoCloseTimer.stop(); clearSubState()
    root.centerMode = "none"; root.sysSubmenu = ""; root.calSubmenu = ""
  }
  function openSubmenu(sub) {
    clearSubState(); root.sysSubmenu = sub
    if (sub !== "") deferPollTimer.restart()
  }
  function openLauncher() {
    autoCloseTimer.stop()
    if (root.centerMode === "launcher") root.closeCenterPill()
    else { clearSubState(); root.searchQuery = ""; root.selectedAppIndex = 0; root.sysSubmenu = ""; root.calSubmenu = ""; root.centerMode = "launcher" }
  }
  function openOverview() {
    autoCloseTimer.stop()
    if (root.centerMode === "overview") root.closeCenterPill()
    else { clearSubState(); root.sysSubmenu = ""; root.calSubmenu = ""; root.centerMode = "overview"; deferPollTimer.restart() }
  }
  function openCalendar() {
    clearSubState(); root.calMonth = (new Date()).getMonth(); root.calYear = (new Date()).getFullYear(); root.updateCalendar()
    root.sysSubmenu = ""; root.calSubmenu = ""; root.centerMode = "calendar"
  }
  function openSystemPanel() {
    clearSubState(); root.sysSubmenu = ""; root.calSubmenu = ""; root.centerMode = "system"; deferPollTimer.restart()
  }
  function triggerOsd(mode) { if (!root.audioReady && mode !== "brightness") return; root.osdMode = mode; osdTimer.restart() }
  function triggerLock() {
    root.closeCenterPill()
    let idx = root.usersList.indexOf(root.currentSessionUser)
    if (idx >= 0) root.selectedUserIdx = idx
    root.screenLocked = true
  }

  // === INTERNAL HELPERS: HARDWARE, AUDIO, NETWORK & WALLPAPER ===

  function setBrightness(pct, showOsd) {
    let p = Math.max(5, Math.min(100, Math.round(pct)))
    root.brightnessPct = p
    if (showOsd) root.triggerOsd("brightness")
    runCmd("brightnessctl s " + p + "%")
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
  function syncLiveMedia() {
    if (root.animWallpapers && (root.isVideoFile || root.isAnimatedGif) && root.wallpaperPath !== "") {
      root.liveMediaPath = root.wallpaperPath
      root.liveMediaIsVideo = root.isVideoFile
      root.liveMediaIsGif = root.isAnimatedGif
    } else {
      root.liveMediaPath = ""
      root.liveMediaIsVideo = false
      root.liveMediaIsGif = false
    }
  }
  function finishWallTransition() {
    if (!root.wallTransitionActive && !root.prevWasLive && root.prevWallSource === "") return
    root.wallTransitionActive = false
    root.prevWasLive = false
    root.prevWallSource = ""
    root.syncLiveMedia()
  }
  function toggleWallpaperMode() {
    if (root.wallSwitching) return
    root.wallSwitching = true
    wallSwitchTimeout.restart()
    runCmd("theming " + (root.animWallpapers ? "static" : "animated"))
  }
  function toggleUiBlur() {
    if (root.isVM) return
    root.cfgEnableBlur = !root.cfgEnableBlur
    saveJsonBool("uiBlur", root.cfgEnableBlur, root.isHyprland ? ("hyprctl keyword decoration:blur:enabled " + (root.cfgEnableBlur ? "true" : "false") + " >/dev/null 2>&1; ") : "")
  }
  function toggleUiAnimations() {
    root.cfgEnableAnimations = !root.cfgEnableAnimations
    saveJsonBool("uiAnimations", root.cfgEnableAnimations, "")
  }
  function toggleEthernet() {
    if (root.ethIface === "") return
    runCmd("nmcli dev " + (root.ethConnected ? "disconnect " : "connect ") + root.ethIface)
    deferPollTimer.restart()
  }
  function toggleBluetooth() {
    if (!root.hasBtAdapter) return
    runCmd(root.btEnabled ? "bluetoothctl power off; rfkill block bluetooth" : "rfkill unblock bluetooth; bluetoothctl power on")
    deferPollTimer.restart()
  }
  function togglePrimaryNetwork() {
    if (root.ethIface !== "" && (!root.hasWifiHw || root.ethConnected)) toggleEthernet()
    else if (root.hasWifiHw) { runCmd("nmcli radio wifi " + (root.wifiEnabled ? "off" : "on")); deferPollTimer.restart() }
  }
  function applyNightLight() {
    if (root.nightLightOn) runCmd("pkill -u \"$UID\" -x wlsunset 2>/dev/null; wlsunset -t " + root.nightLightTemp + " -T " + (root.nightLightTemp + 1) + " &")
    else runCmd("pkill -u \"$UID\" -x wlsunset 2>/dev/null")
  }
  function toggleRecording() {
    if (root.isRecording) {
      runCmd("pkill -u \"$UID\" -INT -x wf-recorder; notify-send 'Screen Recorder' 'Saved in ~/Videos/Recordings'")
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

  // === INITIALIZATION, CONFIG WATCHER, IPC & TIMERS ===

  onIsMonitorDpmsOffChanged: { if (!isMonitorDpmsOff) updateClock() }
  onHasBatteryChanged: { if (hasBattery && batHistory.length === 0) batHistory = [batPct] }

  Component.onCompleted: {
    updateClock(); updateCalendar()
    if (hasBattery && batHistory.length === 0) batHistory = [batPct]
    initPoll.running = true; fastPoll.running = true
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
        root.wallSwitching = false
        wallSwitchTimeout.stop()
        let newWall = d.wallpaper ? String(d.wallpaper) : ""
        let newFrame = d.wallFrame !== undefined ? String(d.wallFrame) : ""
        let newIsVid = newWall.toLowerCase().endsWith(".webm") || newWall.toLowerCase().endsWith(".mp4")
        let newStatic = newWall !== "" ? (newIsVid ? (newFrame !== "" ? ("file://" + newFrame) : "") : ("file://" + newWall)) : ""
        if (d.silhouette !== undefined) root.wallpaperSilhouette = String(d.silhouette)
        if (newWall !== "" && newWall !== root.wallpaperPath) {
          if (root.wallTransitionActive) root.finishWallTransition()
          let wasLive = root.shouldPlayAnimation && root.liveMediaPath !== ""
          let doTrans = (root.wallpaperPath !== "" && root.animActive && root.cfgWallpaperTransition !== "none" && root.staticWallSource !== "" && newStatic !== "")
          if (doTrans) {
            root.prevWallSource = root.staticWallSource
            root.prevWasLive = wasLive
          }
          root.wallpaperFrame = newFrame
          root.wallpaperPath = newWall
          if (d.wallMode) root.animWallpapers = (d.wallMode === "animated")
          if (doTrans) root.wallTransitionActive = true
          else root.syncLiveMedia()
        } else {
          if (newFrame !== root.wallpaperFrame) root.wallpaperFrame = newFrame
          if (d.wallMode) root.animWallpapers = (d.wallMode === "animated")
          if (!root.wallTransitionActive) root.syncLiveMedia()
        }
        if (d.uiBlur !== undefined && !root.isVM) root.cfgEnableBlur = Boolean(d.uiBlur)
        if (d.uiAnimations !== undefined) root.cfgEnableAnimations = Boolean(d.uiAnimations)
        if (d.firstRunDone !== undefined) root.firstRunDone = Boolean(d.firstRunDone)
        if (d.background) root.bg = d.background
        if (d.foreground) root.fg = d.foreground
        let keys = ["color0", "color1", "color2", "color3", "color4", "color5", "color6", "color8"]
        for (let i = 0; i < keys.length; i++) if (d[keys[i]]) root[keys[i]] = d[keys[i]]
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

  Timer { id: osdTimer; interval: root.cfgBarAutoCloseMs; onTriggered: root.osdMode = "volume" }
  Timer { id: wsCollapseTimer; interval: root.cfgBarAutoCloseMs; onTriggered: root.wsExpanded = false }
  Timer { id: autoCloseTimer; interval: root.cfgBarAutoCloseMs; onTriggered: { if ((root.centerMode === "calendar" || root.centerMode === "system") && root.wifiPromptSsid === "") root.closeCenterPill() } }
  Timer { id: popupTimer; interval: 5000; onTriggered: root.popupNotifications = [] }
  Timer { id: evDebounce; interval: 35; repeat: false; onTriggered: fastPoll.running = true }
  Timer { id: wallSwitchTimeout; interval: 10000; onTriggered: root.wallSwitching = false }
  Timer {
    id: deferPollTimer; interval: 55; repeat: false
    onTriggered: {
      if (root.centerMode === "overview") overviewPoll.running = true
      else if (root.centerMode === "system") {
        if (root.sysSubmenu === "") sysPoll.running = true
        else if (root.sysSubmenu === "cpu") { sysPoll.running = true; statPoll.running = true }
        else if (root.sysSubmenu === "battery") {
          if (root.batHistory.length === 0) root.batHistory = [root.batPct]
          batPoll.running = true
        } else if (["net", "bt", "sound", "mic", "display"].indexOf(root.sysSubmenu) >= 0) subPoll.running = true
      }
    }
  }
  Timer {
    interval: 1500
    running: root.centerMode === "system" && root.sysSubmenu === "cpu" && !root.screenLocked && !root.isMonitorDpmsOff
    repeat: true; onTriggered: statPoll.running = true
  }
  Timer {
    interval: 120000; running: root.hasBattery; repeat: true
    onTriggered: root.batHistory = root.pushHist(root.batHistory, root.batPct, 720)
  }
  Timer {
    interval: 1500; running: true; repeat: false
    onTriggered: { weatherProc.running = true; sysPoll.running = true }
  }
  Timer {
    interval: 1800000; running: !root.isMonitorDpmsOff; repeat: true
    onTriggered: weatherProc.running = true
  }
  Timer {
    id: mainTimer
    property bool highFreq: root.isRecording || root.centerMode === "system" || (root.activePlayer !== null && root.activePlayer.playbackState === MprisPlaybackState.Playing)
    interval: (root.isMonitorDpmsOff && !root.isRecording) ? 60000 : (highFreq ? 1000 : 15000)
    running: true; repeat: true
    property int tick: 0
    onTriggered: {
      root.updateClock()
      if (root.isRecording) root.recSeconds++
      if (root.activePlayer && !root.screenLocked && !root.isMonitorDpmsOff) {
        root.mediaProg = (root.activePlayer.length > 0) ? Math.min(1, Math.max(0, root.activePlayer.position / root.activePlayer.length)) : 0.25
      }
      if (!root.isMonitorDpmsOff) {
        if (root.centerMode === "system" && tick % 3 === 0) sysPoll.running = true
        if (root.centerMode === "system" && root.sysSubmenu !== "" && tick % 4 === 0) subPoll.running = true
        if (root.weatherShort.includes("--") && tick > 0 && tick % (highFreq ? 300 : 20) === 0) weatherProc.running = true
      }
      if ((root.animWallpapers || root.isMonitorDpmsOff) && (!highFreq || tick % 15 === 0)) fastPoll.running = true
      tick = (tick + 1) % 3600
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
  IpcHandler { target: "overview"; function toggle(): void { root.openOverview() } function close(): void { if (root.centerMode === "overview") root.closeCenterPill() } }
  IpcHandler { target: "controlcenter"; function toggle(): void { if (root.centerMode === "system") root.closeCenterPill(); else root.openSystemPanel() } }
  IpcHandler { target: "lock"; function lock(): void { root.triggerLock() } }
  IpcHandler { target: "theme"; function reload(): void { colorFile.reload() } }
  IpcHandler { target: "bar"; function toggle(): void { root.barVisible = !root.barVisible } }

  // === SYSTEM POLLERS & EVENT STREAM ===

  Process {
    id: wmStream
    running: !root.screenLocked
    command: ["bash", "-c", "
      if [[ -n \"$NIRI_SOCKET\" ]]; then
        ( niri msg -j event-stream 2>/dev/null & udevadm monitor -u -s backlight 2>/dev/null & wait ) | grep --line-buffered -E 'Workspace|Window|backlight'
      elif [[ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ]] && command -v socat >/dev/null 2>&1; then
        ( socat -U - \"UNIX-CONNECT:${XDG_RUNTIME_DIR:-/run/user/$UID}/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock\" 2>/dev/null & udevadm monitor -u -s backlight 2>/dev/null & wait ) | grep --line-buffered -E 'workspace|fullscreen|activewindow|backlight'
      else
        while sleep 1.5; do echo tick; done
      fi
    "]
    stdout: SplitParser { onRead: data => evDebounce.restart() }
  }

  Process {
    id: initPoll
    command: ["bash", "-c", "
      u=$(awk -F: '$3>=1000 && $3<60000 && $1!=\"nobody\" && $1!=\"greeter\"{printf \"%s,\", tolower($1)}' /etc/passwd)
      ram_sl=$(udevadm info -e 2>/dev/null | awk -F= '
        /MEMORY_ARRAY_NUM_DEVICES=/{tot=$2}
        /MEMORY_DEVICE_[0-9]+_SIZE=/{used++; sz=int($2/1073741824); if(sz>0) s=(s?s\"+\":\"\") sz\"G\"}
        /MEMORY_DEVICE_[0-9]+_TYPE=/ && tp==\"\" && $2!=\"Unknown\"{tp=$2}
        END { if(used>0) printf \"%d/%d slots (%s%s)\", used, (tot>used?tot:used), s, (tp?\" \"tp:\"\") }
      ')
      [[ -z \"$ram_sl\" ]] && ram_sl=\"1/1 slot (Unified / VM)\"
      has_bat=0; for bd in /sys/class/power_supply/BAT*; do [[ -d \"$bd\" ]] && { has_bat=1; break; }; done
      can_hib=0
      grep -qw disk /sys/power/state 2>/dev/null && grep -qE '(^| )resume=' /proc/cmdline 2>/dev/null && ! grep -qE '(^| )hibernate=no( |$)' /proc/cmdline 2>/dev/null && ! grep -qE '\\[(integrity|confidentiality)\\]' /sys/kernel/security/lockdown 2>/dev/null && can_hib=1
      printf '%s|%s|%s|%s threads|%s|%d|%d\n' \"$(awk -F': ' '/model name/{print $2; exit}' /proc/cpuinfo)\" \"$(uname -r)\" \"${u%,}\" \"$(nproc 2>/dev/null || echo 4)\" \"$ram_sl\" \"$has_bat\" \"$can_hib\"
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
        if (p.length >= 4) root.cpuThreads = p[3]
        if (p.length >= 5) root.ramSlotsInfo = p[4]
        if (p.length >= 6) root.hasBattery = (p[5] === "1")
        root.audioReady = true
      }
    }
  }

  Process {
    id: statPoll
    command: ["bash", "-c", "
      t=40000
      for tz in /sys/class/thermal/thermal_zone*; do
        [[ -f \"$tz/type\" && -f \"$tz/temp\" ]] || continue
        case \"$(<\"$tz/type\")\" in *pkg*|*cpu*|*Tctl*|*k10temp*|*coretemp*) t=$(<\"$tz/temp\"); break ;; esac
      done
      [[ \"$t\" -eq 40000 && -f /sys/class/thermal/thermal_zone0/temp ]] && t=$(</sys/class/thermal/thermal_zone0/temp)
      cpu_u=$(awk -v f=\"/tmp/qs_cpu_$UID\" '/^cpu /{u=$2+$3+$4+$6+$7+$8; tot=u+$5+$9; if((getline < f)>0){du=u-$1; dt=tot-$2} else {du=u; dt=tot}; close(f); print u, tot > f; close(f); print (dt>0 ? int(du*100/dt) : 0); exit}' /proc/stat)
      read -r ld _ < /proc/loadavg
      ram_s=$(awk '/^MemTotal:/{mt=$2} /^MemAvailable:/{ma=$2} END{u=(mt-ma)/1048576; t=mt/1048576; printf \"%.1f / %.1f GiB|%d\", u, t, (mt>0 ? int((mt-ma)*100/mt) : 0)}' /proc/meminfo)
      printf '%d|%d|%s|%s\n' \"${cpu_u:-0}\" \"$((t/1000))\" \"$ld\" \"$ram_s\"
    "]
    stdout: SplitParser {
      onRead: data => {
        let p = data.trim().split("|")
        if (p.length >= 5) {
          let cu = parseInt(p[0]) || 0, ct = parseInt(p[1]) || 40, rp = parseInt(p[4]) || 0
          root.cpuUsage = cu; root.cpuTemp = ct; root.cpuLoad = p[2]; root.ramInfo = p[3]; root.ramPct = rp
          root.cpuHistory = root.pushHist(root.cpuHistory, cu, 30)
          root.tempHistory = root.pushHist(root.tempHistory, ct, 30)
          root.ramHistory = root.pushHist(root.ramHistory, rp, 30)
        }
        if (p.length >= 7) root.canHibernate = (p[6] === "1")
      }
    }
  }

  Process {
    id: batPoll
    command: ["bash", "-c", "
      bat_d=\"\"; for bd in /sys/class/power_supply/BAT*; do [[ -d \"$bd\" ]] && { bat_d=\"$bd\"; break; }; done
      if [[ -n \"$bat_d\" ]]; then
        ef=100; [[ -f \"$bat_d/energy_full\" ]] && ef=$(<\"$bat_d/energy_full\") || { [[ -f \"$bat_d/charge_full\" ]] && ef=$(<\"$bat_d/charge_full\"); }
        efd=100; [[ -f \"$bat_d/energy_full_design\" ]] && efd=$(<\"$bat_d/energy_full_design\") || { [[ -f \"$bat_d/charge_full_design\" ]] && efd=$(<\"$bat_d/charge_full_design\"); }
        b_h=\"$(( ef * 100 / (efd > 0 ? efd : 100) ))%\"
        pw=0; [[ -f \"$bat_d/power_now\" ]] && pw=$(<\"$bat_d/power_now\")
        b_p=$(awk -v p=\"$pw\" 'BEGIN{printf \"%.1f W\", p/1000000}')
        b_c=0; [[ -f \"$bat_d/cycle_count\" ]] && b_c=$(<\"$bat_d/cycle_count\")
        b_t=\"Li-ion\"; [[ -f \"$bat_d/technology\" ]] && b_t=$(<\"$bat_d/technology\")
      else b_h=\"AC Power\"; b_p=\"0.0 W\"; b_c=\"N/A\"; b_t=\"Virtual / AC\"; fi
      printf '%s|%s|%s|%s\n' \"$b_h\" \"$b_p\" \"$b_c\" \"$b_t\"
    "]
    stdout: SplitParser {
      onRead: data => {
        let p = data.trim().split("|")
        if (p.length >= 4) { root.batHealth = p[0]; root.batPowerDraw = p[1]; root.batCycles = p[2]; root.batTech = p[3] }
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
        root.overviewWindows = root.parseList(data.trim(), 4, f => f[3] !== "" ? ({ "ws": f[0], "app": f[1], "title": f[2], "id": f[3] }) : null)
      }
    }
  }

  Process {
    id: fastPoll
    environment: ({ "QS_ANIM": root.animWallpapers ? "1" : "0", "QS_DPMS": root.isMonitorDpmsOff ? "1" : "0" })
    command: ["bash", "-c", "
      b=100
      for bd in /sys/class/backlight/*; do
        if [[ -f \"$bd/brightness\" && -f \"$bd/max_brightness\" ]]; then
          max=$(<\"$bd/max_brightness\"); (( max > 0 )) && b=$(( $(<\"$bd/brightness\") * 100 / max ))
          break
        fi
      done
      fs=0; dpms=0
      if [[ -n \"$NIRI_SOCKET\" ]]; then
        ws=$(niri msg -j workspaces 2>/dev/null | awk 'BEGIN{RS=\"}\";ORS=\"\"}/\"idx\":/{match($0,/\"idx\":[0-9]+/);idx=substr($0,RSTART+6,RLENGTH-6);act=($0~/\"is_active\":true/)?\"1\":\"0\";occ=($0~/\"active_window_id\":null/)?\"0\":\"1\";print idx\":\"act\":\"occ\" \"}')
        [[ \"$QS_ANIM\" == \"1\" ]] && niri msg focused-window 2>/dev/null | grep -qiE 'fullscreen.*yes|is_fullscreen.*true' && fs=1
      elif [[ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ]]; then
        act=$(hyprctl activeworkspace -j 2>/dev/null | awk -F': ' '/\"id\":/{gsub(/,/,\"\",$2);print $2;exit}')
        occ_l=$(hyprctl workspaces -j 2>/dev/null | awk 'BEGIN{RS=\"}\"}/\"windows\": *[1-9]/{match($0,/\"id\": *[0-9]+/);print substr($0,RSTART+5,RLENGTH-5)}')
        ws=\"\"; for i in 1 2 3 4 5; do a=0; [[ \"$i\" == \"$act\" ]] && a=1; o=0; echo \"$occ_l\" | grep -qx \"$i\" && o=1; ws+=\"$i:$a:$o \"; done
        [[ \"$QS_ANIM\" == \"1\" ]] && hyprctl activewindow -j 2>/dev/null | grep -qE '\"fullscreen\": *(1|2|true)' && fs=1
      fi
      if [[ \"$QS_ANIM\" == \"1\" || \"$QS_DPMS\" == \"1\" ]]; then
        for df in /sys/class/drm/*/dpms; do [[ -f \"$df\" && \"$(<\"$df\")\" == \"Off\" ]] && { dpms=1; break; }; done
      fi
      printf '%s|%s|%d|%d\n' \"$b\" \"$ws\" \"$fs\" \"$dpms\"
    "]
    stdout: SplitParser {
      onRead: data => {
        let p = data.trim().split("|")
        if (p.length < 2) return
        let b = parseInt(p[0]) || 100
        if (root.lastBrightnessPct !== -1 && b !== root.lastBrightnessPct) root.triggerOsd("brightness")
        root.brightnessPct = b; root.lastBrightnessPct = b

        let wsRaw = p[1].trim(), items = wsRaw.split(/\s+/), list = [], cur = root.lastActiveWs
        for (let i = 0; i < items.length; i++) {
          let kv = items[i].split(":")
          if (kv.length === 3) {
            let idx = parseInt(kv[0]), act = kv[1] === "1"
            if (act) cur = idx
            list.push({ "idx": idx, "active": act, "occupied": kv[2] === "1" || act })
          }
        }
        if (list.length > 0) {
          list.sort((a, b) => a.idx - b.idx); root.workspacesList = list
          if (root.lastWsSignature !== "" && wsRaw !== root.lastWsSignature) { root.lastActiveWs = cur; root.wsExpanded = true; wsCollapseTimer.restart() }
          else root.lastActiveWs = cur
          root.lastWsSignature = wsRaw
        }
        if (p.length >= 3) root.hasActiveFullWindow = (p[2] === "1")
        if (p.length >= 4 && (root.animWallpapers || root.isMonitorDpmsOff)) root.isMonitorDpmsOff = (p[3] === "1")
      }
    }
  }

  Process {
    id: sysPoll
    command: ["bash", "-c", "
      eth_line=$(nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev 2>/dev/null | awk -F: '$2==\"ethernet\"{print $0; exit}')
      IFS=':' read -r e_dev _ e_st e_con <<< \"$eth_line\"
      e_on=0; e_ip=\"Disconnected\"
      if [[ \"$e_st\" == \"connected\" ]]; then
        e_on=1; e_ip=$(ip -4 -o addr show dev \"$e_dev\" 2>/dev/null | awk '{print $4; exit}'); [[ -z \"$e_ip\" ]] && e_ip=\"Connected\"
      fi
      w_hw=0; nmcli -t -f TYPE dev 2>/dev/null | grep -qx 'wifi' && w_hw=1
      w_rad=$(nmcli radio wifi 2>/dev/null)
      w_con=$(nmcli -t -f TYPE,STATE,CONNECTION dev 2>/dev/null | awk -F: '$1==\"wifi\" && $2==\"connected\"{print $3; exit}')
      if [[ -n \"$w_con\" ]]; then net=\"$w_con\"; elif [[ \"$e_on\" -eq 1 ]]; then net=\"Ethernet\"; else net=\"Offline\"; fi
      bt_line=$(bluetoothctl list 2>/dev/null | grep -m1 '^Controller')
      if [[ -z \"$bt_line\" ]]; then bt_hw=0; bt_en=0; bt_name=\"No Adapter\"
      else
        bt_hw=1
        if rfkill list bluetooth 2>/dev/null | grep -q 'Soft blocked: yes' || ! bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then bt_en=0; bt_name=\"Off\"
        else bt_en=1; bt_c=$(bluetoothctl info 2>/dev/null | awk -F': ' '/Name:/{print $2; exit}'); bt_name=\"${bt_c:-On}\"; fi
      fi
      hp=0; hmic=0
      [[ \"$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | tr '[:upper:]' '[:lower:]')\" =~ (headphone|headset|bluez|earphone|buds) ]] && hp=1
      [[ \"$(wpctl inspect @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | tr '[:upper:]' '[:lower:]')\" =~ (headset|bluez|buds|headphone) ]] && hmic=1
      d_root=$(df -h / | awk 'NR==2{gsub(/%/,\"\",$5); printf \"%s / %s|%d\", $3, $2, $5}')
      d_sec=$(df -h | awk '$6 ~ /^\\/media\\//{printf \"%s: %s / %s (%s)\", $6, $3, $2, $5; exit}')
      printf '%s|%d|%s|%d|%s|%s|%d|%d|%s|%d|%d|%s|%s|%s\n' \"${e_dev:-}\" \"$e_on\" \"$e_ip\" \"$w_hw\" \"${w_rad:-disabled}\" \"$net\" \"$bt_hw\" \"$bt_en\" \"$bt_name\" \"$hp\" \"$hmic\" \"$d_root\" \"${d_sec:-No secondary drive}\" \"$(uptime -p 2>/dev/null | sed 's/^up //')\"
    "]
    stdout: SplitParser {
      onRead: data => {
        let p = data.trim().split("|")
        if (p.length >= 15) {
          root.ethIface = p[0]; root.ethConnected = (p[1] === "1"); root.ethIp = p[2]
          root.hasWifiHw = (p[3] === "1"); root.wifiEnabled = (p[4] === "enabled") && root.hasWifiHw; root.netName = p[5]
          root.hasBtAdapter = (p[6] === "1"); root.btEnabled = (p[7] === "1"); root.btName = p[8]
          root.isHeadphones = (p[9] === "1"); root.isHeadsetMic = (p[10] === "1")
          root.diskRootInfo = p[11]; root.diskRootPct = parseInt(p[12]) || 0
          root.diskSecInfo = p[13]; root.uptimeStr = p[14]
        }
      }
    }
  }

  Process {
    id: subPoll
    environment: ({ "QS_SUB": root.sysSubmenu })
    command: ["bash", "-c", "
      sub=\"$QS_SUB\"
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
            bts+=\"${con}^${mac}^${name:-$mac}^MAC: $mac • Type: ${icn:-Device}${bat:+ • Bat: $bat};\"
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
        if (l.startsWith("NET:")) root.netList = root.parseList(l.substring(4), 5, f => ({ "connected": f[0] === "1", "signal": f[1], "sec": f[2], "ssid": f[3], "id": f[3], "details": f[4] }))
        else if (l.startsWith("SAVED:")) root.savedWifiList = root.parseList(l.substring(6), 1, f => ({ "id": f[0], "name": f[0] }))
        else if (l.startsWith("BT:")) root.btList = root.parseList(l.substring(3), 4, f => ({ "connected": f[0] === "1", "id": f[1], "ssid": f[2], "signal": "", "sec": "", "details": f[3] }))
        else if (l.startsWith("PAIRED:")) root.pairedBtList = root.parseList(l.substring(7), 2, f => ({ "id": f[0], "name": f[1] }))
        else if (l.startsWith("SINK:")) root.audioSinks = root.parseList(l.substring(5), 3, f => ({ "id": f[0], "name": f[1], "active": f[2] === "1" }))
        else if (l.startsWith("SRC:")) root.audioSources = root.parseList(l.substring(4), 3, f => ({ "id": f[0], "name": f[1], "active": f[2] === "1" }))
        else if (l.startsWith("DISP:")) root.monitorsList = root.parseList(l.substring(5), 4, f => {
          let mArr = f[3].split(",").filter(x => x !== "")
          return { "name": f[0], "curMode": f[1], "scale": f[2], "modes": mArr.length ? mArr : [f[1]] }
        })
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
            root.weatherLoc = p[2] || "Local Area"; root.weatherWind = p[3] || "--"; root.weatherHum = p[4] || "--"
            root.weatherPrecip = p[5] || "0 mm"; root.weatherPress = p[6] || "1013 hPa"
            root.weatherForecast = root.parseList(p[7], 2, f => ({ "day": f[0], "temps": f[1] }))
          }
        }
      }
    }
  }

  // === NIRI OVERVIEW BACKDROP ===

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
        id: backdropWall; anchors.fill: parent; source: root.staticWallSource
        fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true; visible: !root.blurActive
      }
      MultiEffect {
        anchors.fill: parent; source: backdropWall
        visible: root.blurActive && root.staticWallSource !== ""
        blurEnabled: visible; blurMax: 48; blur: 1.0
      }
      Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.35) }
    }
  }

  // === DESKTOP WALLPAPER & SILHOUETTE TRANSITION ENGINE ===

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

        Image {
          id: baseStaticWall; anchors.fill: parent
          source: root.staticWallSource
          fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true; smooth: true
        }

        Item {
          id: topMediaLayer; anchors.fill: parent
          visible: desktopMedia.playing || root.wallTransitionActive
          opacity: (root.wallTransitionActive && root.cfgWallpaperTransition !== "swarm") ? (1.0 - transLoader.progVal) : 1.0
          scale: (root.wallTransitionActive && root.cfgWallpaperTransition === "zoom") ? (1.0 + transLoader.progVal * 0.08) : 1.0
          layer.enabled: root.wallTransitionActive && root.cfgWallpaperTransition === "swarm" && transLoader.maskItem !== null
          layer.smooth: true
          layer.effect: MultiEffect {
            maskEnabled: true
            maskInverted: true
            maskSource: transLoader.maskItem
          }

          Image {
            anchors.fill: parent
            visible: root.wallTransitionActive && root.prevWallSource !== ""
            source: root.wallTransitionActive ? root.prevWallSource : ""
            fillMode: Image.PreserveAspectCrop; asynchronous: false; cache: false
          }
          QsWallMedia {
            id: desktopMedia; anchors.fill: parent
            activeVideo: root.liveMediaIsVideo
            activeGif: root.liveMediaIsGif
            playing: !root.screenLocked && !(root.cfgPauseOnScreenOff && root.isMonitorDpmsOff)
                     && (root.wallTransitionActive ? root.prevWasLive : root.shouldPlayAnimation)
            mediaPath: root.liveMediaPath
          }
        }

        Loader {
          id: transLoader; anchors.fill: parent
          property real progVal: item ? item.prog : 0.0
          property var maskItem: item ? item.maskCanvas : null
          active: root.wallTransitionActive && root.prevWallSource !== ""
          sourceComponent: Item {
            id: transRoot; anchors.fill: parent
            property alias maskCanvas: oldMaskCanvas
            property real prog: 0.0
            property int fgw: 360
            property int fgh: 202
            property int sw: root.isVM ? 480 : 640
            property int sh: Math.max(240, Math.min(440, Math.round(sw * (height > 0 ? height : 900) / Math.max(1, width > 0 ? width : 1440))))
            property int numInB: 120
            property int numOutB: 180
            property int lastInB: -1
            property int lastOutB: -1
            property real fillSz: 3.0
            property var contourPts: []
            property var inBuckets: []
            property var outBuckets: []
            property bool interiorClosed: false
            property bool outlineFinished: false
            property bool maskCleared: false
            property bool mapReady: false
            property bool started: false

            function traceContour(ctx, w, h, maxCount) {
              var pts = contourPts
              var n = maxCount > 0 ? Math.min(pts.length, maxCount) : pts.length
              if (n < 2) return false
              ctx.beginPath()
              ctx.moveTo(pts[0].u * w, pts[0].v * h)
              for (var i = 1; i < n; i++) ctx.lineTo(pts[i].u * w, pts[i].v * h)
              if (maxCount <= 0 || maxCount >= pts.length) ctx.closePath()
              return true
            }

            function buildSilhouetteMap() {
              if (mapReady) return
              var ftot = fgw * fgh, mask = new Uint8Array(ftot), sil = root.wallpaperSilhouette
              var imgW = baseStaticWall.implicitWidth > 0 ? baseStaticWall.implicitWidth : 1920
              var imgH = baseStaticWall.implicitHeight > 0 ? baseStaticWall.implicitHeight : 1080
              var scrW = width > 0 ? width : 1920, scrH = height > 0 ? height : 1080
              var sc = Math.max(scrW / imgW, scrH / imgH), dW = imgW * sc, dH = imgH * sc
              var cropU0 = Math.max(0.0, (dW - scrW) * 0.5 / dW), cropUSpan = Math.min(1.0 - cropU0, scrW / dW)
              var cropV0 = Math.max(0.0, (dH - scrH) * 0.5 / dH), cropVSpan = Math.min(1.0 - cropV0, scrH / dH)

              var activeCnt = 0
              if (sil && sil.length >= ftot) {
                for (var r = 1; r < fgh - 1; r++) {
                  var ro = r * fgw
                  for (var c = 1; c < fgw - 1; c++) if (sil.charCodeAt(ro + c) >= 56) { mask[ro + c] = 1; activeCnt++ }
                }
              }
              if (activeCnt < 150 || activeCnt > ftot * 0.85) {
                mask.fill(0)
                for (var r2 = 1; r2 < fgh - 1; r2++) {
                  var ro2 = r2 * fgw, dy2 = (r2 / fgh) - 0.5
                  for (var c2 = 1; c2 < fgw - 1; c2++) {
                    var dx2 = (c2 / fgw) - 0.5
                    if ((dx2 * dx2 * 2.8 + dy2 * dy2 * 3.2) < 0.16) mask[ro2 + c2] = 1
                  }
                }
              }

              // Contour tracing (Moore-Neighbor)
              var sx = -1, sy = -1
              for (var ry = 1; ry < fgh - 1 && sx < 0; ry++) {
                var rOff = ry * fgw
                for (var rx = 1; rx < fgw - 1; rx++) if (mask[rOff + rx] === 1) { sx = rx; sy = ry; break }
              }
              var rawLoop = []
              if (sx >= 0) {
                var ddx = [1, 1, 0, -1, -1, -1, 0, 1], ddy = [0, 1, 1, 1, 0, -1, -1, -1]
                var cx = sx, cy = sy, bDir = 4, firstDir = -1
                for (var step = 0; step < 16000; step++) {
                  rawLoop.push({ x: cx, y: cy })
                  var found = -1, startD = (bDir + 1) & 7
                  for (var k = 0; k < 8; k++) {
                    var dir = (startD + k) & 7
                    if (mask[(cy + ddy[dir]) * fgw + (cx + ddx[dir])] === 1) { found = dir; break }
                  }
                  if (found < 0) break
                  if (firstDir < 0) firstDir = found
                  else if (cx === sx && cy === sy && found === firstDir) { rawLoop.pop(); break }
                  cx += ddx[found]; cy += ddy[found]
                  bDir = (found + ((found & 1) ? 5 : 6)) & 7
                }
              }
              if (rawLoop.length > 480) {
                var sub = [], stride = rawLoop.length / 480.0
                for (var si = 0; si < 480; si++) sub.push(rawLoop[Math.floor(si * stride)])
                rawLoop = sub
              }
              for (var pass = 0; pass < 2 && rawLoop.length > 6; pass++) {
                var sm = [], rlen = rawLoop.length
                for (var bi = 0; bi < rlen; bi++) {
                  var p0 = rawLoop[(bi - 1 + rlen) % rlen], p1 = rawLoop[bi], p2 = rawLoop[(bi + 1) % rlen]
                  sm.push({ x: p0.x * 0.25 + p1.x * 0.50 + p2.x * 0.25, y: p0.y * 0.25 + p1.y * 0.50 + p2.y * 0.25 })
                }
                rawLoop = sm
              }

              var normLoop = [], invGw = 1.0 / (fgw - 1), invGh = 1.0 / (fgh - 1)
              for (var ni = 0; ni < rawLoop.length; ni++) {
                normLoop.push({
                  u: (rawLoop[ni].x * invGw - cropU0) / cropUSpan,
                  v: (rawLoop[ni].y * invGh - cropV0) / cropVSpan
                })
              }
              if (normLoop.length < 3) {
                for (var ei = 0; ei < 96; ei++) {
                  var ea = (ei / 96.0) * Math.PI * 2.0
                  normLoop.push({ u: 0.5 + Math.cos(ea) * 0.16, v: 0.5 + Math.sin(ea) * 0.22 })
                }
              }
              contourPts = normLoop

              // Distance Transform (2-pass Chamfer from exact silhouette contour)
              var dw = 180, dh = 101, dtot = dw * dh
              var dMask = new Uint8Array(dtot), dist = new Float32Array(dtot)
              dist.fill(100000.0)
              for (var dy0 = 0; dy0 < dh; dy0++) {
                var mr0 = Math.min(fgh - 1, dy0 * 2) * fgw, mr1 = Math.min(fgh - 1, dy0 * 2 + 1) * fgw, dr = dy0 * dw
                for (var dx0 = 0; dx0 < dw; dx0++) {
                  var mc0 = Math.min(fgw - 1, dx0 * 2), mc1 = Math.min(fgw - 1, dx0 * 2 + 1)
                  dMask[dr + dx0] = (mask[mr0 + mc0] | mask[mr0 + mc1] | mask[mr1 + mc0] | mask[mr1 + mc1])
                }
              }
              for (var by = 0; by < dh; by++) {
                var brow = by * dw
                for (var bx = 0; bx < dw; bx++) {
                  var bi0 = brow + bx
                  if (dMask[bi0] === 1 && (bx === 0 || bx === dw - 1 || by === 0 || by === dh - 1 ||
                      dMask[bi0 - 1] === 0 || dMask[bi0 + 1] === 0 || dMask[bi0 - dw] === 0 || dMask[bi0 + dw] === 0)) {
                    dist[bi0] = 0.0
                  }
                }
              }
              for (var fy0 = 0; fy0 < dh; fy0++) {
                var frow = fy0 * dw
                for (var fx0 = 0; fx0 < dw; fx0++) {
                  var fi = frow + fx0, fv = dist[fi]
                  if (fx0 > 0) fv = Math.min(fv, dist[fi - 1] + 1.0)
                  if (fy0 > 0) {
                    fv = Math.min(fv, dist[fi - dw] + 1.0)
                    if (fx0 > 0) fv = Math.min(fv, dist[fi - dw - 1] + 1.4142)
                    if (fx0 < dw - 1) fv = Math.min(fv, dist[fi - dw + 1] + 1.4142)
                  }
                  dist[fi] = fv
                }
              }
              var xMinC = Math.floor(cropU0 * (dw - 1)), xMaxC = Math.ceil((cropU0 + cropUSpan) * (dw - 1))
              var yMinC = Math.floor(cropV0 * (dh - 1)), yMaxC = Math.ceil((cropV0 + cropVSpan) * (dh - 1))
              var maxIn = 1.0, maxOut = 1.0
              for (var fy1 = dh - 1; fy1 >= 0; fy1--) {
                var rrow = fy1 * dw
                for (var fx1 = dw - 1; fx1 >= 0; fx1--) {
                  var ri = rrow + fx1, rv = dist[ri]
                  if (fx1 < dw - 1) rv = Math.min(rv, dist[ri + 1] + 1.0)
                  if (fy1 < dh - 1) {
                    rv = Math.min(rv, dist[ri + dw] + 1.0)
                    if (fx1 < dw - 1) rv = Math.min(rv, dist[ri + dw + 1] + 1.4142)
                    if (fx1 > 0) rv = Math.min(rv, dist[ri + dw - 1] + 1.4142)
                  }
                  dist[ri] = rv
                  if (fx1 >= xMinC && fx1 <= xMaxC && fy1 >= yMinC && fy1 <= yMaxC) {
                    if (dMask[ri] === 1) { if (rv > maxIn) maxIn = rv } else { if (rv > maxOut) maxOut = rv }
                  }
                }
              }

              // Dense fine swarm buckets strictly expanding from contour line (d = 0 -> t = 0)
              var inB = new Array(numInB), outB = new Array(numOutB)
              for (var i0 = 0; i0 < numInB; i0++) inB[i0] = []
              for (var o0 = 0; o0 < numOutB; o0++) outB[o0] = []

              var nx = root.isVM ? 230 : 300
              var ny = Math.max(120, Math.round(nx * sh / sw))
              var stepX = sw / nx, stepY = sh / ny
              fillSz = Math.max(stepX, stepY) * 1.28

              var rng = 4242 + activeCnt * 31
              function rand() { rng = (rng * 1664525 + 1013904223) >>> 0; return rng / 4294967296.0 }
              var s1 = rand() * 6.283, s2 = rand() * 6.283
              function fbm(u, v) {
                var n1 = Math.sin(u * 10.5 + v * 7.3 + s1) * Math.cos(u * 6.7 - v * 11.1 + s2)
                var n2 = Math.sin(u * 23.1 - v * 19.7 + s2 * 1.6) * Math.cos(u * 18.3 + v * 25.1 - s1)
                return (n1 * 0.62 + n2 * 0.38) * 0.5 + 0.5
              }
              function pack(x, y, code) {
                var px = Math.max(0, Math.min(sw - 1, Math.round(x)))
                var py = Math.max(0, Math.min(sh - 1, Math.round(y)))
                return (code << 20) | (py << 10) | px
              }

              for (var gy = 0; gy <= ny; gy++) {
                var baseY = (gy / ny) * sh, vS = gy / ny
                var vImg = cropV0 + vS * cropVSpan
                var my = Math.max(0, Math.min(fgh - 1, Math.round(vImg * (fgh - 1))))
                var dfy = Math.max(0.0, Math.min(dh - 1, vImg * (dh - 1)))
                var iy0 = Math.floor(dfy), iy1 = Math.min(dh - 1, iy0 + 1), wy = dfy - iy0
                for (var gx = 0; gx <= nx; gx++) {
                  var baseX = (gx / nx) * sw, uS = gx / nx
                  var uImg = cropU0 + uS * cropUSpan
                  var mx = Math.max(0, Math.min(fgw - 1, Math.round(uImg * (fgw - 1))))
                  var dfx = Math.max(0.0, Math.min(dw - 1, uImg * (dw - 1)))
                  var ix0 = Math.floor(dfx), ix1 = Math.min(dw - 1, ix0 + 1), wx = dfx - ix0
                  var dVal = (1 - wy) * ((1 - wx) * dist[iy0 * dw + ix0] + wx * dist[iy0 * dw + ix1]) +
                             wy * ((1 - wx) * dist[iy1 * dw + ix0] + wx * dist[iy1 * dw + ix1])
                  var org = fbm(uS, vS), jit = rand()
                  var sp1x = baseX + (rand() - 0.5) * stepX * 1.4, sp1y = baseY + (rand() - 0.5) * stepY * 1.4
                  var sp2x = baseX + (rand() - 0.5) * stepX * 1.4, sp2y = baseY + (rand() - 0.5) * stepY * 1.4
                  var fx = baseX + (rand() - 0.5) * stepX * 0.45, fy = baseY + (rand() - 0.5) * stepY * 0.45

                  if (mask[my * fgw + mx] === 1) {
                    var dIn = Math.min(1.0, dVal / maxIn)
                    var tIn = (dIn * (0.58 + org * 0.34 + jit * 0.24) + jit * 0.03) / 1.19
                    var bIn = Math.max(0, Math.min(numInB - 1, Math.floor(tIn * (numInB - 9))))
                    inB[bIn].push(pack(sp1x, sp1y, 0))
                    inB[Math.min(numInB - 1, bIn + 3)].push(pack(sp2x, sp2y, 1))
                    inB[Math.min(numInB - 1, bIn + 8)].push(pack(fx, fy, 2))
                  } else {
                    var dOut = Math.min(1.0, dVal / maxOut)
                    var tOut = (dOut * (0.60 + org * 0.32 + jit * 0.24) + jit * 0.02) / 1.18
                    var bOut = Math.max(0, Math.min(numOutB - 1, Math.floor(tOut * (numOutB - 10))))
                    outB[bOut].push(pack(sp1x, sp1y, 0))
                    outB[Math.min(numOutB - 1, bOut + 3)].push(pack(sp2x, sp2y, 1))
                    outB[Math.min(numOutB - 1, bOut + 9)].push(pack(fx, fy, 2))
                  }
                }
              }

              inBuckets = inB; outBuckets = outB
              lastInB = -1; lastOutB = -1; interiorClosed = false; outlineFinished = false; maskCleared = false; mapReady = true
            }

            Canvas {
              id: oldMaskCanvas; width: transRoot.sw; height: transRoot.sh
              visible: false; layer.enabled: root.cfgWallpaperTransition === "swarm"; layer.smooth: true
              onPaint: {
                var ctx = getContext("2d")
                if (!transRoot.mapReady || !transRoot.maskCleared) {
                  ctx.reset(); ctx.clearRect(0, 0, width, height); transRoot.maskCleared = true
                }
                if (!transRoot.mapReady || transRoot.prog < 0.20) return
                ctx.fillStyle = "#ffffff"
                if (transRoot.prog >= 0.985) { ctx.fillRect(0, 0, width, height); return }

                var s0 = 1.35, s1 = 1.95, s2 = transRoot.fillSz
                var h0 = s0 * 0.5, h1 = s1 * 0.5, h2 = s2 * 0.5

                function paintRange(bkts, fromB, toB) {
                  for (var b = fromB; b <= toB; b++) {
                    var arr = bkts[b]
                    if (!arr) continue
                    for (var i = 0; i < arr.length; i++) {
                      var v = arr[i], x = v & 1023, y = (v >> 10) & 1023, c = (v >> 20) & 3
                      if (c === 0) ctx.fillRect(x - h0, y - h0, s0, s0)
                      else if (c === 1) ctx.fillRect(x - h1, y - h1, s1, s1)
                      else ctx.fillRect(x - h2, y - h2, s2, s2)
                    }
                  }
                }

                // Phase 1: Inside swarm expanding from contour line inward (strictly clipped)
                var uIn = Math.max(0.0, Math.min(1.0, (transRoot.prog - 0.20) / 0.34))
                var targetIn = Math.min(transRoot.numInB - 1, Math.floor(uIn * transRoot.numInB))
                if (targetIn > transRoot.lastInB && !transRoot.interiorClosed) {
                  ctx.save()
                  if (transRoot.traceContour(ctx, width, height, 0)) {
                    ctx.clip()
                    paintRange(transRoot.inBuckets, transRoot.lastInB + 1, targetIn)
                    if (uIn >= 0.95) { ctx.fill(); transRoot.interiorClosed = true }
                  }
                  ctx.restore()
                  transRoot.lastInB = targetIn
                }

                // Phase 2: Outward swarm expanding from contour line to screen edges
                var uOut = Math.max(0.0, Math.min(1.0, (transRoot.prog - 0.54) / 0.44))
                if (uOut > 0.0) {
                  if (!transRoot.interiorClosed) {
                    ctx.save()
                    if (transRoot.traceContour(ctx, width, height, 0)) ctx.fill()
                    ctx.restore()
                    transRoot.interiorClosed = true
                  }
                  var eOut = 0.45 * uOut + 0.55 * uOut * uOut
                  var targetOut = Math.min(transRoot.numOutB - 1, Math.floor(eOut * transRoot.numOutB))
                  if (targetOut > transRoot.lastOutB) {
                    paintRange(transRoot.outBuckets, transRoot.lastOutB + 1, targetOut)
                    transRoot.lastOutB = targetOut
                  }
                }
              }
            }

            Canvas {
              id: outlineCanvas; anchors.fill: parent
              visible: root.cfgWallpaperTransition === "swarm" && transRoot.prog < 0.70
              opacity: transRoot.prog < 0.54 ? 1.0 : Math.max(0.0, 1.0 - (transRoot.prog - 0.54) / 0.16)
              onPaint: {
                var ctx = getContext("2d"); ctx.reset()
                if (!transRoot.mapReady) return
                var drawFrac = Math.min(1.0, transRoot.prog / 0.26)
                var maxPts = drawFrac >= 0.999 ? 0 : Math.max(2, Math.floor(transRoot.contourPts.length * drawFrac))
                if (transRoot.traceContour(ctx, width, height, maxPts)) {
                  ctx.strokeStyle = root.color4.toString()
                  ctx.lineWidth = 2.4; ctx.lineCap = "round"; ctx.lineJoin = "round"
                  ctx.stroke()
                }
                if (drawFrac >= 0.999) transRoot.outlineFinished = true
              }
            }

            NumberAnimation {
              id: swarmAnim; target: transRoot; property: "prog"; from: 0.0; to: 1.0
              duration: root.cfgWallpaperTransitionMs; easing.type: Easing.Linear
              onStopped: root.finishWallTransition()
            }
            Timer { interval: 3000; running: !transRoot.started; repeat: false; onTriggered: root.finishWallTransition() }
            onProgChanged: {
              if (root.cfgWallpaperTransition === "swarm") {
                if (transRoot.prog >= 0.20) oldMaskCanvas.requestPaint()
                if (!transRoot.outlineFinished) outlineCanvas.requestPaint()
              }
            }
            function startWhenReady() {
              if (started) return
              if (baseStaticWall.status === Image.Error) { root.finishWallTransition(); return }
              if (baseStaticWall.status === Image.Ready) {
                started = true
                if (root.cfgWallpaperTransition === "swarm") { buildSilhouetteMap(); oldMaskCanvas.requestPaint(); outlineCanvas.requestPaint() }
                swarmAnim.start()
              }
            }
            Connections { target: baseStaticWall; function onStatusChanged() { transRoot.startWhenReady() } }
            Component.onCompleted: startWhenReady()
          }
        }
      }
    }
  }

  // === TOP SPACER & CLICK-OUTSIDE BACKDROP ===

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

  Variants {
    model: Quickshell.screens
    PanelWindow {
      required property var modelData
      screen: modelData; visible: root.centerMode !== "none" && !root.screenLocked
      WlrLayershell.layer: WlrLayer.Top; WlrLayershell.namespace: "qs-backdrop"
      WlrLayershell.exclusionMode: ExclusionMode.Ignore
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton; onClicked: root.closeCenterPill() }
    }
  }

  // === DYNAMIC ISLAND TOP BAR ===

  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: islandWin
      required property var modelData
      screen: modelData; visible: root.barVisible && !root.screenLocked
      property bool panelExpanded: root.centerMode !== "none" || centerPill.isHoverPreview || leftPill.showMediaCard
      WlrLayershell.layer: !panelExpanded ? WlrLayer.Top : WlrLayer.Overlay
      WlrLayershell.namespace: "waybar"; WlrLayershell.exclusionMode: ExclusionMode.Ignore
      WlrLayershell.keyboardFocus: (root.centerMode === "launcher" || root.wifiPromptSsid !== "") ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
      anchors { top: true }
      margins.top: 8
      implicitWidth: 1080
      implicitHeight: panelExpanded ? 540 : 48
      color: "transparent"

      MouseArea { anchors.fill: parent; enabled: root.centerMode !== "none"; acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton; onClicked: root.closeCenterPill() }

      function grabKeyboardNow() {
        if (root.centerMode === "launcher" && !launcherSearchInput.activeFocus) launcherSearchInput.forceActiveFocus()
        else if (root.wifiPromptSsid !== "" && !wifiPwField.activeFocus) wifiPwField.forceActiveFocus()
      }

      Timer { id: focusTimer1; interval: 30; repeat: false; onTriggered: islandWin.grabKeyboardNow() }
      Timer { id: hoverPreviewTimer; interval: 90; repeat: false; onTriggered: centerPill.hoverPreviewReady = true }

      Connections {
        target: root
        function onCenterModeChanged() { if (root.centerMode === "launcher") { launcherSearchInput.text = ""; focusTimer1.restart() } }
        function onWifiPromptSsidChanged() { if (root.wifiPromptSsid !== "") focusTimer1.restart() }
      }

      // --- Left Pill (Workspaces & Media) ---
      Rectangle {
        id: leftPill
        anchors.top: parent.top; anchors.right: centerPill.left; anchors.rightMargin: 10
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
        HoverHandler { id: leftHover; onHoveredChanged: { if (hovered) { hoverPreviewTimer.stop(); centerPill.hoverPreviewReady = false } } }

        Connections {
          target: root
          function onMediaProgChanged() { if (leftPill.showMediaCompact) mediaArcCanvas.requestPaint() }
          function onColor4Changed() { if (leftPill.showMediaCompact) mediaArcCanvas.requestPaint() }
        }

        MouseArea {
          anchors.fill: parent; acceptedButtons: Qt.NoButton
          onWheel: wheel => {
            root.wsExpanded = true; wsCollapseTimer.restart()
            root.focusWorkspace(Math.max(1, root.lastActiveWs + (wheel.angleDelta.y > 0 ? -1 : 1)))
          }
        }

        QsText { anchors.centerIn: parent; visible: !leftPill.showWsStrip && !leftPill.hasMedia; text: root.lastActiveWs.toString(); color: root.color4; font.pixelSize: 14; font.bold: true }

        Item {
          anchors.fill: parent; visible: leftPill.showMediaCompact
          onVisibleChanged: { if (visible) mediaArcCanvas.requestPaint() }
          Canvas { id: mediaArcCanvas; anchors.fill: parent; onPaint: root.paintArc(mediaArcCanvas, root.mediaProg, root.color4) }
          Rectangle {
            anchors.centerIn: parent; width: 26; height: 26; radius: 13; color: root.color0; clip: true
            Image { anchors.fill: parent; source: (root.activePlayer && root.activePlayer.trackArtUrl) ? root.activePlayer.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; visible: source != "" }
            QsText { anchors.centerIn: parent; visible: !root.activePlayer || !root.activePlayer.trackArtUrl; text: "󰝚"; color: root.color4; font.pixelSize: 13 }
          }
        }

        RowLayout {
          id: wsRow; anchors.centerIn: parent; visible: leftPill.showWsStrip; spacing: 6
          Repeater {
            model: root.workspacesList
            Rectangle {
              required property var modelData
              implicitWidth: 26; implicitHeight: 26; radius: 8
              color: modelData.active ? root.color4 : (modelData.occupied ? root.withAlpha(root.color2, 0.25) : root.subtleFill)
              border.width: modelData.occupied && !modelData.active ? 1 : 0; border.color: root.color2
              QsText { anchors.centerIn: parent; text: modelData.idx.toString(); color: modelData.active ? root.bg : (modelData.occupied ? root.color2 : root.color8); font.bold: true }
              MouseArea { anchors.fill: parent; onClicked: root.focusWorkspace(modelData.idx) }
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
              QsText { anchors.centerIn: parent; visible: !root.activePlayer || !root.activePlayer.trackArtUrl; text: "󰝚"; color: root.color4; font.pixelSize: 26 }
            }
            ColumnLayout {
              Layout.fillWidth: true; spacing: 2
              QsText { text: (root.activePlayer && root.activePlayer.trackTitle) ? root.activePlayer.trackTitle : "Media Playing"; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
              QsText { text: (root.activePlayer && root.activePlayer.trackArtist) ? root.activePlayer.trackArtist : "Unknown Artist"; color: root.withAlpha(root.fg, 0.8); elide: Text.ElideRight; Layout.fillWidth: true }
              QsText { text: (root.activePlayer && root.activePlayer.identity) ? root.activePlayer.identity : "Player"; color: root.color8; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
            }
          }
          ColumnLayout {
            Layout.fillWidth: true; spacing: 3
            Rectangle {
              Layout.fillWidth: true; implicitHeight: 5; radius: 3; color: root.subtleFillHover
              Rectangle { width: parent.width * root.mediaProg; height: parent.height; radius: 3; color: root.color6 }
            }
            RowLayout {
              Layout.fillWidth: true
              QsText { text: root.activePlayer ? root.formatSec(root.activePlayer.position) : "0:00"; color: root.color8; font.pixelSize: 10 }
              Item { Layout.fillWidth: true }
              QsText { text: (root.activePlayer && root.activePlayer.length > 0) ? root.formatSec(root.activePlayer.length) : ""; color: root.color8; font.pixelSize: 10 }
            }
          }
          QsMediaControls { Layout.alignment: Qt.AlignHCenter }
        }
      }

      // --- Center Pill (Clock, Launcher, Calendar, Overview & Control Center) ---
      Rectangle {
        id: centerPill
        anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter

        property bool hoverPreviewReady: false
        property bool isHoverPreview: hoverPreviewReady && centerHover.hovered && !leftHover.hovered && root.centerMode === "none"
        property bool isCalOpen: root.centerMode === "calendar"
        property bool isSysOpen: root.centerMode === "system"
        property bool isLauncherOpen: root.centerMode === "launcher"
        property bool isOverviewOpen: root.centerMode === "overview"

        width: (isHoverPreview || isCalOpen || isSysOpen || isLauncherOpen || isOverviewOpen) ? 380 : (compactClockRow.implicitWidth + 28)
        height: (isLauncherOpen || isOverviewOpen) ? 392 : (isSysOpen ? (sysContainer.implicitHeight + 52) : (isCalOpen ? (calCardCol.implicitHeight + 52) : (isHoverPreview ? (calPreviewBox.implicitHeight + 52) : 40)))
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
            if (hovered) { autoCloseTimer.stop(); if (root.centerMode === "none" && !leftHover.hovered) hoverPreviewTimer.restart() }
            else { hoverPreviewTimer.stop(); centerPill.hoverPreviewReady = false; if ((root.centerMode === "calendar" || root.centerMode === "system") && root.wifiPromptSsid === "") autoCloseTimer.restart() }
          }
        }
        MouseArea {
          anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
          onClicked: mouse => { if (mouse.button === Qt.RightButton && (centerPill.isCalOpen || centerPill.isHoverPreview)) root.openSystemPanel() }
        }

        // Top Header Bar
        Item {
          id: topPillBar
          visible: !centerPill.isOverviewOpen
          anchors { top: parent.top; left: parent.left; right: parent.right }
          height: 40

          RowLayout {
            visible: centerPill.isLauncherOpen
            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 8
            QsText { text: "󰍉"; color: root.color4; font.pixelSize: 15 }
            TextInput {
              id: launcherSearchInput; Layout.fillWidth: true
              color: root.fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true; clip: true
              onTextChanged: { root.searchQuery = text; root.selectedAppIndex = 0 }
              Keys.onDownPressed: { if (root.selectedAppIndex < root.filteredApps.length - 1) root.selectedAppIndex++ }
              Keys.onUpPressed: { if (root.selectedAppIndex > 0) root.selectedAppIndex-- }
              Keys.onEscapePressed: root.closeCenterPill()
              Keys.onReturnPressed: { if (root.filteredApps.length > 0) root.launchApp(root.filteredApps[root.selectedAppIndex]) }
            }
          }
          Rectangle {
            visible: centerPill.isLauncherOpen
            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
            anchors.leftMargin: 12; anchors.rightMargin: 12; height: 1; color: root.subtleFill
          }

          Item {
            anchors.fill: parent
            visible: !centerPill.isLauncherOpen && (!centerPill.isSysOpen || root.sysSubmenu === "") && (!centerPill.isCalOpen || root.calSubmenu === "")
            RowLayout {
              id: compactClockRow; anchors.centerIn: parent; spacing: 8
              Rectangle { visible: notifServer.trackedNotifications.values.length > 0; implicitWidth: 7; implicitHeight: 7; radius: 4; color: root.color2 }
              QsText { text: root.timeStr; font.pixelSize: 13; font.bold: true }
              QsText { text: "•"; color: root.color8 }
              QsText { text: root.dateStr; color: root.color4; font.pixelSize: 13; font.bold: true }
              QsText { text: root.weatherShort; font.pixelSize: 13; font.bold: true }
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
            visible: !centerPill.isLauncherOpen && ((centerPill.isSysOpen && root.sysSubmenu !== "") || (centerPill.isCalOpen && root.calSubmenu !== ""))
            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8

            QsChip { text: "‹"; implicitWidth: 24; implicitHeight: 24; fontSize: 14; onChipClicked: { if (centerPill.isCalOpen) root.calSubmenu = ""; else root.openSubmenu("") } }
            QsText {
              Layout.fillWidth: true; font.pixelSize: 13; font.bold: true
              text: centerPill.isCalOpen ? "Weather Forecast" : (({ "net": "Network", "bt": "Bluetooth", "tray": "System Tray Apps", "battery": "Battery Details", "sound": "Audio Output", "mic": "Audio Input", "display": "Display", "rec": "Screen Recorder", "cpu": "System Info", "power": "Power Menu" })[root.sysSubmenu] || "")
            }
            Rectangle {
              visible: centerPill.isSysOpen && ((root.sysSubmenu === "net" && root.ethIface !== "") || (root.sysSubmenu === "bt" && root.hasBtAdapter) || root.sysSubmenu === "sound" || root.sysSubmenu === "mic")
              implicitWidth: 36; implicitHeight: 18; radius: 9
              property bool isOn: root.sysSubmenu === "net" ? root.ethConnected : (root.sysSubmenu === "bt" ? root.btEnabled : (root.sysSubmenu === "sound" ? !root.outMuted : !root.micMuted))
              color: isOn ? root.color4 : root.subtleFillHover
              Rectangle { width: 12; height: 12; radius: 6; anchors.verticalCenter: parent.verticalCenter; x: parent.isOn ? 20 : 4; color: parent.isOn ? root.bg : root.fg; Behavior on x { NumberAnimation { duration: 120 } } }
              MouseArea {
                anchors.fill: parent
                onClicked: {
                  if (root.sysSubmenu === "net") root.toggleEthernet()
                  else if (root.sysSubmenu === "bt") root.toggleBluetooth()
                  else if (root.sysSubmenu === "sound") root.toggleSinkMute()
                  else if (root.sysSubmenu === "mic") root.toggleSourceMute()
                }
              }
            }
            QsChip {
              visible: centerPill.isSysOpen && root.sysSubmenu === "rec"; implicitHeight: 24; fontSize: 11
              bgCol: root.isRecording ? root.color1 : root.color4; textCol: root.bg
              text: root.isRecording ? "󰓛 Stop" : "󰻂 Start"; onChipClicked: root.toggleRecording()
            }
            QsChip {
              visible: centerPill.isSysOpen && root.sysSubmenu === "power"; implicitHeight: 24; fontSize: 11
              bgCol: root.color1; textCol: root.bg; text: "󰐥 Poweroff"; onChipClicked: root.execPower("poweroff")
            }
          }
        }

        // App Launcher View
        ListView {
          id: appListView
          visible: centerPill.isLauncherOpen
          anchors { top: topPillBar.bottom; bottom: parent.bottom; left: parent.left; right: parent.right }
          anchors.margins: 10; anchors.topMargin: 6; clip: true; spacing: 4
          model: root.filteredApps; currentIndex: root.selectedAppIndex
          onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
          QsText { anchors.centerIn: parent; visible: root.filteredApps.length === 0; text: "No matching applications"; color: root.color8 }
          delegate: Rectangle {
            required property var modelData
            required property int index
            width: ListView.view.width; height: 46; radius: 10
            property bool isSel: index === root.selectedAppIndex
            color: isSel ? root.subtleFillHover : (appMouse.containsMouse ? root.subtleFill : "transparent")
            Rectangle { visible: parent.isSel; width: 3.5; height: 22; radius: 2; anchors.left: parent.left; anchors.leftMargin: 4; anchors.verticalCenter: parent.verticalCenter; color: root.color6 }
            RowLayout {
              anchors.fill: parent; anchors.leftMargin: 13; anchors.rightMargin: 10; spacing: 10
              Rectangle { implicitWidth: 32; implicitHeight: 32; radius: 8; color: root.subtleFill; IconImage { anchors.centerIn: parent; implicitSize: 22; source: Quickshell.iconPath(modelData.icon, true) } }
              ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                QsText { text: modelData.name; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                QsText { visible: text !== ""; text: modelData.genericName || modelData.comment || ""; color: root.color8; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
              }
            }
            MouseArea { id: appMouse; anchors.fill: parent; hoverEnabled: true; onEntered: root.selectedAppIndex = index; onClicked: root.launchApp(modelData) }
          }
        }

        // Calendar, Weather & Notifications View
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
                QsChip {
                  visible: centerPill.isCalOpen; text: "‹"; implicitWidth: 24; implicitHeight: 24; fontSize: 14
                  onChipClicked: btn => { if (btn === Qt.RightButton) root.openSystemPanel(); else { if (root.calMonth === 0) { root.calMonth = 11; root.calYear-- } else root.calMonth--; root.updateCalendar() } }
                }
                QsText { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: Qt.formatDate(new Date(root.calYear, root.calMonth, 1), "MMMM yyyy"); color: root.color4; font.pixelSize: 13; font.bold: true }
                QsChip {
                  visible: centerPill.isCalOpen; text: "›"; implicitWidth: 24; implicitHeight: 24; fontSize: 14
                  onChipClicked: btn => { if (btn === Qt.RightButton) root.openSystemPanel(); else { if (root.calMonth === 11) { root.calMonth = 0; root.calYear++ } else root.calMonth++; root.updateCalendar() } }
                }
              }
              GridLayout {
                Layout.fillWidth: true; columns: 7; rowSpacing: 4; columnSpacing: 4
                Repeater { model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]; QsText { required property string modelData; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: modelData; color: root.color8; font.pixelSize: 11; font.bold: true } }
                Repeater {
                  model: root.calendarDays
                  Rectangle {
                    required property var modelData
                    Layout.fillWidth: true; implicitHeight: 26; radius: 7; color: modelData.today ? root.color4 : "transparent"
                    QsText { anchors.centerIn: parent; text: modelData.day; color: modelData.today ? root.bg : root.fg; font.bold: modelData.today }
                  }
                }
              }
            }
            MouseArea {
              anchors.fill: parent; visible: centerPill.isHoverPreview; acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
              onClicked: mouse => { if (mouse.button === Qt.LeftButton) root.openCalendar(); else if (mouse.button === Qt.RightButton) root.openSystemPanel(); else if (mouse.button === Qt.MiddleButton) root.openLauncher() }
            }
          }

          QsTile {
            visible: centerPill.isCalOpen && root.calSubmenu === ""
            icon: root.weatherShort.split(" ")[0] || "󰖕"; active: true; accentCol: root.withAlpha(root.color4, 0.2); iconFg: root.color4
            title: "Today's Weather  •  " + root.weatherShort; sub: root.weatherDetail; subCol: root.fg
            onTileClicked: { weatherProc.running = true; root.calSubmenu = "weather" }
            onIconClicked: { weatherProc.running = true; root.calSubmenu = "weather" }
          }

          ColumnLayout {
            visible: centerPill.isCalOpen && root.calSubmenu === "weather"
            Layout.fillWidth: true; spacing: 8
            QsTile {
              interactive: false; active: true; accentCol: root.withAlpha(root.color4, 0.22); iconFg: root.color4
              icon: root.weatherShort.split(" ")[0] || "󰖕"; title: root.weatherLoc + "  •  " + root.weatherShort; sub: root.weatherDetail; subCol: root.color8
            }
            GridLayout {
              Layout.fillWidth: true; columns: 2; uniformCellWidths: true; rowSpacing: 8; columnSpacing: 8
              Repeater {
                model: [{ "icon": "󰖝", "l": "Wind", "v": root.weatherWind }, { "icon": "󰖎", "l": "Humidity", "v": root.weatherHum }, { "icon": "󰖗", "l": "Precip / UV", "v": root.weatherPrecip }, { "icon": "󰥔", "l": "Pressure", "v": root.weatherPress }]
                QsTile { required property var modelData; Layout.preferredWidth: 1; interactive: false; icon: modelData.icon; iconFg: root.color4; title: modelData.v; sub: modelData.l; subCol: root.color8 }
              }
            }
            Repeater {
              model: root.weatherForecast
              QsTile { required property var modelData; implicitHeight: 44; radius: 12; interactive: false; icon: "󰃭"; iconFg: root.color2; title: modelData.day; rightText: modelData.temps }
            }
          }

          ColumnLayout {
            visible: centerPill.isCalOpen && root.calSubmenu === ""
            Layout.fillWidth: true; spacing: 6
            RowLayout {
              Layout.fillWidth: true
              QsText { text: "Notifications (" + notifServer.trackedNotifications.values.length + ")"; font.bold: true; Layout.fillWidth: true }
              QsChip {
                text: "Clear all"; textCol: root.color4
                onChipClicked: btn => { if (btn === Qt.RightButton) root.openSystemPanel(); else { let l = notifServer.trackedNotifications.values; for (let i = l.length - 1; i >= 0; i--) l[i].dismiss(); root.popupNotifications = [] } }
              }
            }
            ListView {
              Layout.fillWidth: true; implicitHeight: Math.min(170, Math.max(54, contentHeight)); clip: true; spacing: 6
              model: notifServer.trackedNotifications
              QsText { anchors.centerIn: parent; visible: notifServer.trackedNotifications.values.length === 0; text: "No active notifications"; color: root.color8; font.pixelSize: 11 }
              delegate: Rectangle {
                required property var modelData
                width: ListView.view.width; height: 54; radius: 12; color: root.color0
                RowLayout {
                  anchors.fill: parent; anchors.margins: 8
                  ColumnLayout {
                    Layout.fillWidth: true; spacing: 2
                    QsText { text: modelData.summary || "Notification"; color: root.color4; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                    QsText { text: modelData.body || ""; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                  }
                  QsChip { text: "✕"; implicitWidth: 22; implicitHeight: 22; fontSize: 11; boldText: false; onChipClicked: modelData.dismiss() }
                }
              }
            }
          }
        }

        // Workspace Windows Overview View
        ColumnLayout {
          visible: centerPill.isOverviewOpen; anchors.fill: parent; anchors.margins: 10; spacing: 8
          RowLayout {
            Layout.fillWidth: true
            QsText { text: "󰕰  Workspace Windows Overview"; color: root.color4; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true }
            QsText { text: root.overviewWindows.length + " open"; color: root.color8; font.pixelSize: 11 }
          }
          ListView {
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 6; model: root.overviewWindows
            QsText { anchors.centerIn: parent; visible: root.overviewWindows.length === 0; text: "No open windows in workspaces"; color: root.color8 }
            delegate: QsTile {
              required property var modelData
              width: ListView.view.width; implicitHeight: 46; radius: 12
              icon: modelData.ws; active: true; title: modelData.title || modelData.app; sub: modelData.app; subCol: root.color8
              function focusWin() {
                root.closeCenterPill()
                root.runCmd(root.isHyprland ? ("hyprctl dispatch focuswindow address:" + modelData.id) : ("niri msg action focus-window --id " + modelData.id))
              }
              onTileClicked: focusWin()
              onIconClicked: focusWin()
            }
          }
        }

        // System Control Center View
        Item {
          id: sysContainer
          visible: centerPill.isSysOpen
          anchors { top: topPillBar.bottom; left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10 }
          anchors.topMargin: 2; implicitHeight: sysUnifiedCol.implicitHeight
          property real viewOffset: 0
          property real viewOpacity: 1.0

          NumberAnimation { id: subSlideAnim; target: sysContainer; property: "viewOffset"; to: 0; duration: root.animActive && root.cfgSubmenuAnimStyle === "slide" ? root.cfgSubmenuAnimMs : 0; easing.type: Easing.OutQuad }
          NumberAnimation { id: subFadeAnim; target: sysContainer; property: "viewOpacity"; from: 0.15; to: 1.0; duration: root.animActive && root.cfgSubmenuAnimStyle !== "none" ? root.cfgSubmenuAnimMs : 0; easing.type: Easing.OutQuad }

          Connections {
            target: root
            function onSysSubmenuChanged() {
              if (!root.animActive || root.cfgSubmenuAnimStyle === "none") { sysContainer.viewOffset = 0; sysContainer.viewOpacity = 1.0; return }
              subFadeAnim.restart()
              if (root.cfgSubmenuAnimStyle === "slide") { subSlideAnim.from = root.sysSubmenu !== "" ? root.cfgSubmenuSlidePx : -root.cfgSubmenuSlidePx; subSlideAnim.restart() }
            }
          }

          ColumnLayout {
            id: sysUnifiedCol
            opacity: sysContainer.viewOpacity
            transform: Translate { x: sysContainer.viewOffset }
            anchors { left: parent.left; right: parent.right }
            spacing: 6

            // QuickTiles Grid
            GridLayout {
              visible: root.sysSubmenu === ""
              Layout.fillWidth: true; columns: 2; uniformCellWidths: true; rowSpacing: 8; columnSpacing: 8
              Repeater {
                model: [
                  { "key": "net", "title": "Network", "icon": root.ethConnected ? "󰈀" : (root.wifiEnabled ? "󰤨" : "󰤭"), "sub": root.netName, "act": root.ethConnected || (root.wifiEnabled && root.netName !== "Offline"), "col": root.color4, "scol": root.color8 },
                  { "key": "bt", "title": "Bluetooth", "icon": "", "sub": root.btName, "act": root.btEnabled, "col": root.color4, "scol": root.color8 },
                  { "key": "tray", "title": "App Tray", "icon": SystemTray.items.values.length.toString(), "sub": SystemTray.items.values.length > 0 ? (SystemTray.items.values.length + " active") : "Empty", "act": SystemTray.items.values.length > 0, "col": root.color4, "scol": root.color8 },
                  { "key": "battery", "title": "Battery", "icon": root.batCharging ? "󰂄" : "󰁹", "sub": root.batPct + "% • " + (root.batCharging ? "Charging" : "Ready"), "act": true, "col": root.withAlpha(root.color2, 0.25), "scol": root.color2 }
                ]
                QsTile {
                  required property var modelData
                  Layout.preferredWidth: 1; implicitHeight: 54
                  icon: modelData.icon; title: modelData.title; sub: modelData.sub; active: modelData.act; accentCol: modelData.col; subCol: modelData.scol
                  iconFg: modelData.key === "battery" ? root.color2 : (modelData.act ? root.bg : root.fg)
                  onTileClicked: { if (modelData.key === "net") root.runCmd("nmcli dev wifi rescan 2>/dev/null || true"); root.openSubmenu(modelData.key) }
                  onIconClicked: btn => {
                    if (btn === Qt.RightButton) root.openSubmenu(modelData.key)
                    else if (modelData.key === "net") root.togglePrimaryNetwork()
                    else if (modelData.key === "bt") root.toggleBluetooth()
                    else root.openSubmenu(modelData.key)
                  }
                }
              }
            }

            // Recorder, Screenshot, System Info & Power Row
            RowLayout {
              visible: root.sysSubmenu === ""; Layout.fillWidth: true; spacing: 8
              Rectangle {
                Layout.fillWidth: true; implicitHeight: 48; radius: 14
                color: recCardMouse.containsMouse ? root.cardHoverCol : root.color0
                MouseArea { id: recCardMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: root.openSubmenu("rec") }
                RowLayout {
                  anchors.fill: parent; anchors.margins: 7; spacing: 7
                  Rectangle {
                    Layout.fillWidth: true; implicitHeight: 34; radius: 10; color: root.isRecording ? root.color1 : root.subtleFill
                    RowLayout {
                      anchors.centerIn: parent; spacing: 6
                      QsText { text: root.isRecording ? "󰓛" : "󰻂"; color: root.isRecording ? root.bg : root.color1; font.pixelSize: 15 }
                      QsText { text: root.isRecording ? ("Stop • " + root.formatSec(root.recSeconds)) : "Record Screen"; color: root.isRecording ? root.bg : root.fg; font.pixelSize: 11; font.bold: true }
                    }
                    MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: mouse => { if (mouse.button === Qt.RightButton) root.openSubmenu("rec"); else root.toggleRecording() } }
                  }
                  Rectangle {
                    implicitWidth: 34; implicitHeight: 34; radius: 10; color: shotMouse.containsMouse ? root.color4 : root.subtleFill
                    QsText { anchors.centerIn: parent; text: "󰄄"; color: shotMouse.containsMouse ? root.bg : root.fg; font.pixelSize: 15 }
                    MouseArea { id: shotMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: mouse => { if (mouse.button === Qt.RightButton) root.openSubmenu("rec"); else { root.closeCenterPill(); root.runCmd("sleep 0.2; grim -g \"$(slurp)\" - | swappy -f -") } } }
                  }
                }
              }
              Rectangle {
                implicitWidth: 89; implicitHeight: 48; radius: 14; color: root.color0
                RowLayout {
                  anchors.fill: parent; anchors.margins: 7; spacing: 7
                  Repeater {
                    model: [{ "icon": "󰻠", "col": root.color4, "act": "cpu" }, { "icon": "󰐥", "col": root.color1, "act": "power" }]
                    Rectangle {
                      required property var modelData
                      implicitWidth: 34; implicitHeight: 34; radius: 10; color: sysPwrMouse.containsMouse ? modelData.col : root.subtleFill
                      QsText { anchors.centerIn: parent; text: modelData.icon; color: sysPwrMouse.containsMouse ? root.bg : modelData.col; font.pixelSize: 15 }
                      MouseArea { id: sysPwrMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.openSubmenu(modelData.act) }
                    }
                  }
                }
              }
            }

            // Display, Sound & Mic Sliders
            Repeater {
              model: ["display", "sound", "mic"]
              QsBar {
                required property string modelData
                visible: root.sysSubmenu === "" || (modelData !== "display" && root.sysSubmenu === modelData)
                interactive: true
                property bool isMuted: modelData === "sound" ? root.outMuted : (modelData === "mic" ? root.micMuted : false)
                property bool isNight: modelData === "display" && root.nightLightOn
                pct: modelData === "display" ? root.brightnessPct : (modelData === "sound" ? root.outVolPct : root.micVolPct)
                icon: modelData === "display" ? (isNight ? "󰖔" : "󰃠") : (modelData === "sound" ? (isMuted ? "󰖁" : (root.isHeadphones ? "󰋋" : "󰕾")) : (isMuted ? "󰍭" : (root.isHeadsetMic ? "󰋎" : "󰍬")))
                label: modelData === "display" ? (isNight ? "Display • Night Light" : "Display") : (modelData === "sound" ? "Sound" : "Mic")
                rightText: isMuted ? "Mute" : (pct + "%")
                accentCol: isMuted ? root.color8 : root.color4
                iconBg: isMuted ? root.withAlpha(root.color1, 0.22) : (isNight ? root.withAlpha(root.color2, 0.25) : root.subtleFill)
                iconFg: isMuted ? root.color1 : (isNight ? root.color2 : root.color4)
                function setRatio(r) {
                  let cl = Math.max(0, Math.min(1, r))
                  if (modelData === "display") root.setBrightness(cl * 100, false)
                  else if (modelData === "sound") root.setSinkVolume(cl * 100)
                  else root.setSourceVolume(cl * 100)
                }
                onIconClicked: btn => { if (btn === Qt.RightButton) root.openSubmenu(modelData); else if (modelData === "display") { root.nightLightOn = !root.nightLightOn; root.applyNightLight() } else if (modelData === "sound") root.toggleSinkMute(); else root.toggleSourceMute() }
                onBarPressed: (btn, r) => { if (btn === Qt.RightButton || r < 0) { if (root.sysSubmenu === "") root.openSubmenu(modelData) } else setRatio(r) }
                onBarMoved: r => setRatio(r)
              }
            }

            // Battery & System Info Graphs
            Repeater {
              model: root.sysSubmenu === "battery" ? [
                { "icon": root.batCharging ? "󰂄" : "󰁹", "title": root.batCharging ? "Battery • Charging" : "Battery • Discharging", "sub": root.batHealth + " • " + root.batPowerDraw + " • Cycles: " + root.batCycles + " • " + root.batTech, "val": root.batPct + "%", "time": root.batTimeLabel, "unit": "%", "min": 0, "max": 100, "auto": false, "hist": root.batHistory, "col": root.color2 }
              ] : (root.sysSubmenu === "cpu" ? [
                { "icon": "󰻠", "title": root.cpuModel, "sub": "load " + root.cpuLoad + " • " + root.cpuThreads, "val": root.cpuUsage + "%", "time": "last 60 s", "unit": "%", "min": 0, "max": 100, "auto": true, "hist": root.cpuHistory, "col": root.color4 },
                { "icon": "󰔏", "title": "Temperature", "sub": root.cpuTemp < 55 ? "Cool • Optimal" : (root.cpuTemp < 75 ? "Normal Load" : "High Thermal"), "val": root.cpuTemp + " °C", "time": "last 60 s", "unit": "°C", "min": 25, "max": 95, "auto": false, "hist": root.tempHistory, "col": root.cpuTemp >= 75 ? root.color1 : root.color3 },
                { "icon": "󰍛", "title": "Memory", "sub": root.ramInfo + " • " + root.ramSlotsInfo, "val": root.ramPct + "%", "time": "last 60 s", "unit": "%", "min": 0, "max": 100, "auto": true, "hist": root.ramHistory, "col": root.color2 }
              ] : [])
              QsMetricCard {
                required property var modelData
                icon: modelData.icon; title: modelData.title; sub: modelData.sub; valueText: modelData.val
                timeLabel: modelData.time; unitSuffix: modelData.unit; minBound: modelData.min; maxBound: modelData.max
                autoScale: modelData.auto; history: modelData.hist; accentCol: modelData.col
              }
            }

            // Battery & Screen Recorder Controls
            GridLayout {
              visible: root.sysSubmenu === "battery"
              Layout.fillWidth: true; columns: 2; uniformCellWidths: true; rowSpacing: 8; columnSpacing: 8
              Repeater {
                model: [
                  { "key": "blur", "title": "UI Blur", "icon": "󰂵", "sub": root.isVM ? "Disabled in VM" : (root.blurActive ? "Glass Active" : "Solid Off"), "on": root.blurActive, "col": root.color5 },
                  { "key": "anim", "title": "Animations", "icon": "󰠠", "sub": root.animActive ? ("Smooth (" + root.cfgIslandAnimMs + "ms)") : "Instant (0ms)", "on": root.animActive, "col": root.color4 }
                ]
                QsTile {
                  required property var modelData
                  Layout.preferredWidth: 1; implicitHeight: 54; icon: modelData.icon; title: modelData.title; sub: modelData.sub; active: modelData.on; accentCol: modelData.col
                  onTileClicked: { if (modelData.key === "blur") root.toggleUiBlur(); else root.toggleUiAnimations() }
                  onIconClicked: { if (modelData.key === "blur") root.toggleUiBlur(); else root.toggleUiAnimations() }
                }
              }
            }
            Repeater {
              model: root.sysSubmenu === "battery" ? [
                { "key": "wall", "icon": root.animWallpapers ? "󰕧" : "󰸉", "title": "Animated Wallpapers", "sub": root.wallSwitching ? "Switching wallpaper..." : (root.animWallpapers ? (root.shouldPlayAnimation ? "Playing (day_animated / night_animated)" : "Paused (Fullscreen / Standby)") : "Off • Static Power Saving (day / night)"), "extra": "Loaded: " + root.wallpaperLabel, "on": root.animWallpapers, "col": root.color4, "scol": root.wallSwitching ? root.color3 : (root.animWallpapers ? root.color4 : root.color2) }
              ] : (root.sysSubmenu === "rec" ? [
                { "key": "sys", "icon": "󰕾", "title": "Record System Audio", "sub": root.recSysAudio ? "Enabled • Desktop Audio" : "Muted", "extra": "", "on": root.recSysAudio, "col": root.color4, "scol": root.recSysAudio ? root.color4 : root.color8 },
                { "key": "mic", "icon": "󰍬", "title": "Record Microphone", "sub": root.recMicAudio ? "Enabled • Voice Input" : "Muted", "extra": "", "on": root.recMicAudio, "col": root.color4, "scol": root.recMicAudio ? root.color4 : root.color8 },
                { "key": "area", "icon": "󰩭", "title": "Select Screen Region (slurp)", "sub": root.recAreaSelect ? "Custom Area Selection" : "Full Screen Recording", "extra": "", "on": root.recAreaSelect, "col": root.color4, "scol": root.recAreaSelect ? root.color4 : root.color8 }
              ] : [])
              QsTile {
                required property var modelData
                icon: modelData.icon; title: modelData.title; sub: modelData.sub; extra: modelData.extra; active: modelData.on; accentCol: modelData.col; subCol: modelData.scol
                function trigger() {
                  if (modelData.key === "wall") root.toggleWallpaperMode()
                  else if (modelData.key === "sys") root.recSysAudio = !root.recSysAudio
                  else if (modelData.key === "mic") root.recMicAudio = !root.recMicAudio
                  else if (modelData.key === "area") root.recAreaSelect = !root.recAreaSelect
                }
                onTileClicked: trigger()
                onIconClicked: trigger()
              }
            }

            // System Info Storage & Kernel Footer
            QsBar { visible: root.sysSubmenu === "cpu"; icon: "󰋊"; label: "Root (/) • " + root.diskRootInfo; pct: root.diskRootPct; accentCol: root.color6 }
            QsTile { visible: root.sysSubmenu === "cpu"; interactive: false; icon: "󰌽"; iconFg: root.color4; title: "Kernel: " + root.kernelVer + "  •  Up: " + root.uptimeStr; sub: "Secondary Drive: " + root.diskSecInfo; subCol: root.color8 }

            // Audio Devices Submenu
            ColumnLayout {
              visible: root.sysSubmenu === "sound" || root.sysSubmenu === "mic"; Layout.fillWidth: true; spacing: 6
              QsText { text: "Available Devices"; color: root.color8; font.pixelSize: 11; font.bold: true }
              Repeater {
                model: root.sysSubmenu === "sound" ? root.audioSinks : (root.sysSubmenu === "mic" ? root.audioSources : [])
                QsTile {
                  required property var modelData
                  implicitHeight: 44; radius: 12; icon: root.sysSubmenu === "sound" ? "󰕾" : "󰍬"
                  title: modelData.name; active: modelData.active; highlighted: modelData.active
                  function pick() { root.runCmd("wpctl set-default " + modelData.id); deferPollTimer.restart() }
                  onTileClicked: pick(); onIconClicked: pick()
                }
              }
            }

            // Display Submenu
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
                    QsBar {
                      interactive: true; icon: "󰍹"; accentCol: root.color2; iconBg: root.withAlpha(root.color4, 0.2); iconFg: root.color4
                      label: modelData.name + (root.monitorsList.length > 1 ? ("  •  #" + (index + 1)) : ""); pct: root.brightnessPct
                      onBarPressed: (btn, r) => { if (r >= 0) root.setBrightness(r * 100, false) }
                      onBarMoved: r => root.setBrightness(r * 100, false)
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
                          Layout.fillWidth: true; implicitHeight: 26; radius: 8; color: activeScale ? root.color2 : root.subtleFill
                          QsText { anchors.centerIn: parent; text: modelData + "x"; color: parent.activeScale ? root.bg : root.fg; font.pixelSize: 11; font.bold: true }
                          MouseArea {
                            anchors.fill: parent
                            onClicked: {
                              root.runCmd(root.isHyprland ? ("hyprctl keyword monitor " + parent.monName + "," + parent.curMode + ",auto," + modelData) : ("niri msg output " + root.shQuote(parent.monName) + " scale " + modelData))
                              deferPollTimer.restart()
                            }
                          }
                        }
                      }
                    }
                    Item {
                      Layout.fillWidth: true; implicitHeight: 24
                      RowLayout {
                        anchors.fill: parent
                        QsText { text: "Resolution"; color: root.color8; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                        RowLayout { spacing: 6; QsText { text: modelData.curMode.replace("@", " @ ") + " Hz"; font.pixelSize: 11; font.bold: true } QsText { text: "󰅀"; color: root.color4; font.pixelSize: 13 } }
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
                          Layout.fillWidth: true; implicitHeight: 30; radius: 8; color: isCurrent ? root.withAlpha(root.color4, 0.25) : root.subtleFill
                          RowLayout {
                            anchors.fill: parent; anchors.margins: 6
                            QsText { text: modelData.replace("@", " @ ") + " Hz"; color: parent.parent.isCurrent ? root.color4 : root.fg; font.pixelSize: 11; font.bold: parent.parent.isCurrent; Layout.fillWidth: true }
                            QsText { visible: parent.parent.isCurrent; text: "Active"; color: root.color2; font.pixelSize: 10 }
                          }
                          MouseArea {
                            anchors.fill: parent
                            onClicked: {
                              root.runCmd(root.isHyprland ? ("hyprctl keyword monitor " + parent.monName + "," + modelData + ",auto," + parent.curScale) : ("niri msg output " + root.shQuote(parent.monName) + " mode " + modelData))
                              root.expandedResMon = ""; deferPollTimer.restart()
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
              QsBar {
                interactive: true; icon: "󰖔"; label: root.nightLightOn ? "Night Light • Active" : "Night Light • Off"
                pct: Math.round(((root.nightLightTemp - 2500) / 3500.0) * 100); rightText: root.nightLightTemp + " K"
                accentCol: root.nightLightOn ? root.color2 : root.color8; iconBg: root.nightLightOn ? root.color2 : root.subtleFill; iconFg: root.nightLightOn ? root.bg : root.fg
                function setKelvin(r) { if (r < 0) return; root.nightLightTemp = Math.round((2500 + Math.max(0, Math.min(1, r)) * 3500) / 100) * 100; if (!root.nightLightOn) root.nightLightOn = true; root.applyNightLight() }
                onIconClicked: { root.nightLightOn = !root.nightLightOn; root.applyNightLight() }
                onBarPressed: (btn, r) => setKelvin(r); onBarMoved: r => setKelvin(r)
              }
            }

            // System Tray Submenu
            ColumnLayout {
              visible: root.sysSubmenu === "tray"; Layout.fillWidth: true; spacing: 6
              Rectangle { visible: SystemTray.items.values.length === 0; Layout.fillWidth: true; implicitHeight: 44; radius: 12; color: root.color0; QsText { anchors.centerIn: parent; text: "No applications in System Tray"; color: root.color8 } }
              Repeater {
                model: root.sysSubmenu === "tray" ? SystemTray.items.values : []
                QsTile {
                  id: traySubCard
                  required property var modelData
                  implicitHeight: 46; radius: 12; iconSource: modelData.icon
                  title: modelData.title || modelData.tooltipTitle || modelData.id || "Tray App"
                  rightText: modelData.hasMenu ? "Menu / Open" : "Open"
                  onTileClicked: btn => root.activateTrayItem(modelData, islandWin, traySubCard, btn)
                  onIconClicked: btn => root.activateTrayItem(modelData, islandWin, traySubCard, btn)
                }
              }
            }

            // Network & Bluetooth Submenu
            ColumnLayout {
              id: wirelessCol
              visible: root.sysSubmenu === "net" || root.sysSubmenu === "bt"
              Layout.fillWidth: true; spacing: 8
              property bool isNet: root.sysSubmenu === "net"
              property bool hasHw: isNet ? root.hasWifiHw : root.hasBtAdapter
              property bool isEn: isNet ? root.wifiEnabled : root.btEnabled
              property var devList: isNet ? (root.wifiEnabled ? root.netList : []) : (root.btEnabled ? root.btList : [])
              property var savedList: isNet ? root.savedWifiList : root.pairedBtList

              QsTile {
                visible: wirelessCol.isNet; icon: "󰈀"; active: root.ethConnected
                title: "Ethernet (" + (root.ethIface !== "" ? root.ethIface : "No port") + ")"
                sub: root.ethIp; subCol: root.ethConnected ? root.color2 : root.color8
                onTileClicked: root.toggleEthernet(); onIconClicked: root.toggleEthernet()
              }

              Rectangle {
                Layout.fillWidth: true; implicitHeight: 50; radius: 14; color: root.color0
                Rectangle {
                  id: wCtrlSq; width: 34; height: 34; radius: 10
                  anchors.left: parent.left; anchors.leftMargin: 7; anchors.verticalCenter: parent.verticalCenter
                  color: wirelessCol.isEn ? root.color4 : root.subtleFill
                  QsText { anchors.centerIn: parent; text: wirelessCol.isNet ? (wirelessCol.isEn ? "󰤨" : "󰤭") : ""; color: wirelessCol.isEn ? root.bg : root.fg; font.pixelSize: 16 }
                  MouseArea {
                    anchors.fill: parent
                    onClicked: {
                      if (!wirelessCol.hasHw) return
                      if (wirelessCol.isNet) { root.runCmd("nmcli radio wifi " + (root.wifiEnabled ? "off" : "on")); deferPollTimer.restart() }
                      else root.toggleBluetooth()
                    }
                  }
                }
                QsChip {
                  id: wRightScan; visible: wirelessCol.hasHw && wirelessCol.isEn
                  anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                  text: "Scan"; textCol: root.color4
                  onChipClicked: { root.runCmd(wirelessCol.isNet ? "nmcli dev wifi rescan 2>/dev/null || true" : "bluetoothctl --timeout 5 scan on >/dev/null 2>&1 &"); deferPollTimer.restart() }
                }
                ColumnLayout {
                  anchors.left: wCtrlSq.right; anchors.leftMargin: 8; anchors.right: wRightScan.visible ? wRightScan.left : parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 1
                  QsText { text: wirelessCol.isNet ? "Wi-Fi" : "Bluetooth"; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                  QsText {
                    text: !wirelessCol.hasHw ? "Hardware adapter not present" : (!wirelessCol.isEn ? (wirelessCol.isNet ? "Wi-Fi Off" : "Bluetooth Off") : ("Available: " + wirelessCol.devList.length + " • " + (wirelessCol.isNet ? "Saved: " : "Paired: ") + wirelessCol.savedList.length))
                    color: wirelessCol.isEn ? root.color8 : root.color1; font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideRight
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
                      QsText { text: wirelessCol.isNet ? "Saved Networks" : "Paired Devices"; color: root.color8; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                      RowLayout { spacing: 6; QsText { text: wirelessCol.savedList.length + " saved"; font.pixelSize: 11; font.bold: true } QsText { text: "󰅀"; color: root.color4; font.pixelSize: 13 } }
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.showSavedList = !root.showSavedList }
                  }
                  ColumnLayout {
                    visible: root.showSavedList; Layout.fillWidth: true; spacing: 4
                    Repeater {
                      model: root.showSavedList ? wirelessCol.savedList : []
                      Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; implicitHeight: 32; radius: 8; color: root.subtleFill
                        RowLayout {
                          anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 6; spacing: 6
                          QsText { text: wirelessCol.isNet ? "󰆼" : ""; color: root.color6; font.pixelSize: 13 }
                          QsText { text: modelData.name; font.pixelSize: 11; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                          QsChip { text: "Connect"; textCol: root.color4; bgCol: root.subtleFillHover; radius: 6; onChipClicked: { root.runCmd(wirelessCol.isNet ? ("nmcli connection up id " + root.shQuote(modelData.id)) : ("bluetoothctl connect " + modelData.id)); deferPollTimer.restart() } }
                          QsChip { text: "Forget"; textCol: root.color1; bgCol: root.subtleFillHover; radius: 6; boldText: false; onChipClicked: { root.runCmd(wirelessCol.isNet ? ("nmcli connection delete id " + root.shQuote(modelData.id)) : ("bluetoothctl remove " + modelData.id)); deferPollTimer.restart() } }
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
                  QsText { text: "Password for " + root.wifiPromptSsid; color: root.color4; font.pixelSize: 11; font.bold: true }
                  RowLayout {
                    Layout.fillWidth: true
                    TextInput {
                      id: wifiPwField; Layout.fillWidth: true; color: root.fg; echoMode: TextInput.Password; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                      Keys.onEscapePressed: { text = ""; root.wifiPromptSsid = "" }
                      onAccepted: { root.runCmd("nmcli dev wifi connect " + root.shQuote(root.wifiPromptSsid) + " password " + root.shQuote(text)); text = ""; root.wifiPromptSsid = "" }
                    }
                    QsChip { text: "Join"; textCol: root.bg; bgCol: root.color4; radius: 6; onChipClicked: { root.runCmd("nmcli dev wifi connect " + root.shQuote(root.wifiPromptSsid) + " password " + root.shQuote(wifiPwField.text)); wifiPwField.text = ""; root.wifiPromptSsid = "" } }
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
                  border.width: modelData.connected ? 1 : 0; border.color: root.color4; clip: true
                  Behavior on implicitHeight { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                  ColumnLayout {
                    anchors.fill: parent; anchors.margins: 6; spacing: 6
                    RowLayout {
                      Layout.fillWidth: true; spacing: 8
                      Rectangle {
                        implicitWidth: 32; implicitHeight: 32; radius: 9; color: modelData.connected ? root.color4 : root.subtleFill
                        QsText { anchors.centerIn: parent; text: wirelessCol.isNet ? "󰤨" : ""; color: modelData.connected ? root.bg : root.fg; font.pixelSize: 15 }
                      }
                      Item {
                        Layout.fillWidth: true; implicitHeight: 32
                        RowLayout {
                          anchors.fill: parent; spacing: 6
                          QsText { text: modelData.ssid; font.bold: modelData.connected; elide: Text.ElideRight; Layout.fillWidth: true }
                          QsText { text: modelData.connected ? "Disconnect" : (wirelessCol.isNet ? (modelData.signal + "%") : "Connect"); color: modelData.connected ? root.color1 : (wirelessCol.isNet ? root.color8 : root.color4); font.pixelSize: 10; font.bold: !wirelessCol.isNet || modelData.connected }
                        }
                        MouseArea {
                          anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
                          onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) root.expandedDevInfo = (root.expandedDevInfo === modelData.id ? "" : modelData.id)
                            else if (wirelessCol.isNet) {
                              if (modelData.connected) root.runCmd("nmcli con down id " + root.shQuote(modelData.ssid))
                              else {
                                let isSaved = root.savedWifiList.some(x => x.id === modelData.ssid)
                                if (isSaved || modelData.sec === "Open" || modelData.sec === "" || modelData.sec === "--") root.runCmd("nmcli dev wifi connect " + root.shQuote(modelData.ssid))
                                else root.wifiPromptSsid = modelData.ssid
                              }
                              deferPollTimer.restart()
                            } else { root.runCmd("bluetoothctl " + (modelData.connected ? "disconnect " : "connect ") + modelData.id); deferPollTimer.restart() }
                          }
                        }
                      }
                      QsChip {
                        implicitWidth: 26; implicitHeight: 26; fontSize: 13; boldText: false; text: "󰋼"
                        bgCol: parent.parent.parent.isExpanded ? root.color4 : root.subtleFill
                        textCol: parent.parent.parent.isExpanded ? root.bg : root.color4
                        onChipClicked: root.expandedDevInfo = (root.expandedDevInfo === modelData.id ? "" : modelData.id)
                      }
                    }
                    Rectangle {
                      visible: parent.parent.isExpanded; Layout.fillWidth: true; implicitHeight: 22; radius: 6; color: root.subtleFill
                      QsText { anchors.left: parent.left; anchors.leftMargin: 8; anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: modelData.details; color: root.color6; font.pixelSize: 10; elide: Text.ElideRight }
                    }
                  }
                }
              }
            }

            // Power Menu Submenu
            ColumnLayout {
              visible: root.sysSubmenu === "power"; Layout.fillWidth: true; spacing: 6
              Repeater {
                model: [{ "icon": "󰑐", "label": "Reboot System", "act": "reboot" }, { "icon": "󰤄", "label": "Suspend", "act": "suspend" }, { "icon": "󰒲", "label": "Hibernate", "act": "hibernate" }, { "icon": "󰌾", "label": "Lock Screen", "act": "lock" }, { "icon": "󰍃", "label": "Log Out", "act": "logout" }]
                QsTile { required property var modelData; visible: modelData.act !== "hibernate" || root.canHibernate; implicitHeight: 46; icon: modelData.icon; iconFg: root.color4; title: modelData.label; onTileClicked: root.execPower(modelData.act); onIconClicked: root.execPower(modelData.act) }
              }
            }
          }
        }
      }

      // --- Right Pill (Audio & Brightness OSD) ---
      Rectangle {
        id: rightOsdPill
        anchors.top: parent.top; anchors.left: centerPill.right; anchors.leftMargin: 10
        width: 40; height: 40; radius: 20; color: root.withAlpha(root.bg, root.panelAlpha)
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

        Canvas { id: osdCanvas; anchors.fill: parent; onPaint: root.paintArc(osdCanvas, rightOsdPill.arcPct, root.osdMode === "mic" ? root.color2 : (root.osdMode === "brightness" ? root.color3 : root.color4)) }
        QsText { anchors.centerIn: parent; text: rightOsdPill.centerIcon; color: ((root.osdMode === "volume" && root.outMuted) || (root.osdMode === "mic" && root.micMuted)) ? root.color1 : root.fg; font.pixelSize: 15; font.bold: true }
        MouseArea {
          anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
          onClicked: mouse => { if (mouse.button === Qt.RightButton) root.runCmd("pavucontrol"); else if (root.osdMode === "mic") root.toggleSourceMute(); else root.toggleSinkMute() }
          onWheel: wheel => {
            let delta = wheel.angleDelta.y > 0 ? 5 : -5
            if (root.osdMode === "brightness") root.setBrightness(root.brightnessPct + delta, true)
            else if (root.osdMode === "mic") root.setSourceVolume(root.micVolPct + delta)
            else root.setSinkVolume(root.outVolPct + delta)
          }
        }
      }
    }
  }

  // === NOTIFICATION POPUPS ===

  Variants {
    model: Quickshell.screens
    PanelWindow {
      required property var modelData
      screen: modelData; visible: root.popupNotifications.length > 0 && root.centerMode === "none" && !root.screenLocked
      WlrLayershell.layer: WlrLayer.Overlay; WlrLayershell.namespace: "swaync-notification-window"
      WlrLayershell.exclusionMode: ExclusionMode.Ignore
      anchors { top: true }
      margins.top: 56; implicitWidth: 360; implicitHeight: notifPopupCol.implicitHeight + 16; color: "transparent"
      ColumnLayout {
        id: notifPopupCol; anchors.fill: parent; anchors.margins: 8; spacing: 8
        Repeater {
          model: root.popupNotifications
          Rectangle {
            required property var modelData
            Layout.fillWidth: true; implicitHeight: 68; radius: 16; color: root.withAlpha(root.color0, root.panelAlpha); border.width: 2; border.color: root.color4
            ColumnLayout {
              anchors.fill: parent; anchors.margins: 12; spacing: 3
              QsText { text: modelData.summary || "Notification"; color: root.color4; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
              QsText { text: modelData.body || ""; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
            }
          }
        }
      }
    }
  }

  // === UNIFIED LOGIN & LOCKSCREEN ===

  PamContext {
    id: pamLock; config: "login"
    onResponseRequiredChanged: { if (responseRequired && root.authBusy) respond(root.pendingPassword) }
    onCompleted: result => {
      root.authBusy = false; root.pendingPassword = ""
      if (result === PamResult.Success) {
        root.runCmd("rm -f /tmp/qs_lock_active_$UID 2>/dev/null || true")
        root.isMonitorDpmsOff = false; root.screenLocked = false; root.isInitialLogin = false; root.authError = false; root.lockPromptActive = false
        root.checkFirstRunNiri()
      } else { root.authError = true; root.lockPromptActive = true }
    }
  }

  Process {
    id: switchAuthProc
    command: ["bash", "-c", "printf '%s\\n' \"$QS_PW\" | su -c true \"$QS_TARGET_USER\" >/dev/null 2>&1"]
    environment: ({ "QS_PW": root.pendingPassword, "QS_TARGET_USER": root.selectedUser })
    onExited: (code, status) => {
      root.authBusy = false; root.pendingPassword = ""
      if (code === 0) { root.authError = false; root.cleanExitSession(root.selectedUser) }
      else { root.authError = true; root.lockPromptActive = true }
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
      color: root.bg

      Loader {
        anchors.fill: parent
        active: root.screenLocked
        sourceComponent: Item {
          anchors.fill: parent

          Component.onCompleted: {
            root.isMonitorDpmsOff = false; root.lockPromptActive = false; root.authError = false
            root.lockDateFormatted = Qt.formatDateTime(new Date(), "dddd, MMMM d").toUpperCase()
            pwLockInput.text = ""; pwLockInput.forceActiveFocus()
          }
          Timer { interval: 250; running: !pwLockInput.activeFocus; repeat: true; onTriggered: pwLockInput.forceActiveFocus() }
          HoverHandler { onPointChanged: { if (root.isMonitorDpmsOff) root.isMonitorDpmsOff = false } }

          Image {
            id: lockWall; anchors.fill: parent; source: root.staticWallSource
            fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true
            visible: root.showLiveLockWall || !root.blurActive || root.cfgLockBlurMax <= 0
          }
          MultiEffect {
            anchors.fill: parent; source: lockWall
            visible: !root.showLiveLockWall && root.blurActive && root.cfgLockBlurMax > 0 && root.staticWallSource !== ""
            blurEnabled: visible; blurMax: root.cfgLockBlurMax; blur: 1.0
          }
          Loader {
            anchors.fill: parent
            active: root.showLiveLockWall && root.wallpaperPath !== ""
            sourceComponent: QsWallMedia {
              anchors.fill: parent
              activeVideo: root.isVideoFile; activeGif: root.isAnimatedGif
              playing: !root.isMonitorDpmsOff; mediaPath: root.wallpaperPath
            }
          }

          Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.38) }
          MouseArea { anchors.fill: parent; onClicked: { root.isMonitorDpmsOff = false; root.lockPromptActive = true; if (!pwLockInput.activeFocus) pwLockInput.forceActiveFocus() } }

          ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top; anchors.topMargin: Math.round(parent.height * 0.13); spacing: 10
            QsText { Layout.alignment: Qt.AlignHCenter; text: root.timeStr; font.pixelSize: 84; font.weight: Font.Light }
            QsText { Layout.alignment: Qt.AlignHCenter; text: root.lockDateFormatted; color: root.withAlpha(root.fg, 0.85); font.pixelSize: 14; font.bold: true; font.letterSpacing: 6 }
            QsText { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 8; text: root.lockWeatherMain; color: root.color4; font.pixelSize: 24; font.bold: true; font.letterSpacing: 2 }
            QsText { Layout.alignment: Qt.AlignHCenter; visible: root.lockWeatherSub !== ""; text: root.lockWeatherSub; color: root.withAlpha(root.fg, 0.78); font.pixelSize: 14; font.letterSpacing: 1.5 }
          }

          ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: Math.round(parent.height * 0.14); spacing: 6

            QsText { Layout.alignment: Qt.AlignHCenter; text: root.usersList.length > 1 ? "‹   SELECT USER   ›" : "USER"; color: root.withAlpha(root.fg, 0.55); font.pixelSize: 10; font.letterSpacing: 4 }

            Item {
              id: carouselBox
              Layout.alignment: Qt.AlignHCenter
              implicitWidth: root.usersList.length > 1 ? 380 : 200; implicitHeight: 32; clip: true
              property real dragOffset: 0; property real pressStartX: 0; property bool isDragging: false
              NumberAnimation { id: snapAnim; target: carouselBox; property: "dragOffset"; to: 0; duration: 160; easing.type: Easing.OutQuad }

              Repeater {
                model: root.usersList.length > 1 ? [-1, 0, 1] : [0]
                Item {
                  required property int modelData
                  property int uIdx: { let n = root.usersList.length; return n > 0 ? ((root.selectedUserIdx + modelData % n + n) % n) : 0 }
                  property string uName: root.usersList.length > 0 ? root.usersList[uIdx] : root.currentSessionUser
                  property bool isCenter: modelData === 0
                  property bool willDisconnect: !root.isInitialLogin && root.isSwitchingUser && uName === root.currentSessionUser
                  width: 120; height: 32
                  x: (carouselBox.width / 2 - width / 2) + (modelData * 126) + carouselBox.dragOffset
                  scale: isCenter ? 1.0 : 0.82; opacity: isCenter ? 1.0 : (willDisconnect ? 0.92 : 0.45)
                  Behavior on x { enabled: !carouselBox.isDragging; NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
                  Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
                  Behavior on opacity { NumberAnimation { duration: 160 } }
                  QsText {
                    anchors.centerIn: parent; text: parent.uName.toUpperCase()
                    color: parent.willDisconnect ? root.color1 : (parent.isCenter ? root.fg : root.withAlpha(root.fg, 0.8))
                    font.pixelSize: parent.isCenter ? 16 : 13; font.bold: parent.isCenter || parent.willDisconnect; font.letterSpacing: 3
                    Behavior on color { ColorAnimation { duration: 140 } }
                  }
                }
              }

              MouseArea {
                anchors.fill: parent; hoverEnabled: true
                onPressed: mouse => { snapAnim.stop(); carouselBox.pressStartX = mouse.x; carouselBox.isDragging = true }
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
                  snapAnim.restart(); if (!pwLockInput.activeFocus) pwLockInput.forceActiveFocus()
                }
                onWheel: wheel => { if (root.usersList.length > 1) root.cycleUser(wheel.angleDelta.y > 0 ? -1 : 1) }
              }
            }

            Item {
              id: pwBoxContainer
              Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 8; implicitWidth: 230; implicitHeight: 34
              opacity: (root.lockPromptActive || pwLockInput.text.length > 0 || root.authError || root.authBusy) ? 1.0 : 0.0
              Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

              TextInput {
                id: pwLockInput
                anchors.fill: parent; anchors.bottomMargin: 6
                verticalAlignment: TextInput.AlignVCenter; horizontalAlignment: TextInput.AlignHCenter
                echoMode: TextInput.Password; passwordCharacter: "•"; color: root.fg
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18; font.letterSpacing: 6
                onTextChanged: { root.isMonitorDpmsOff = false; if (text.length > 0) { root.authError = false; root.lockPromptActive = true } else if (!root.authError && !root.authBusy) root.lockPromptActive = false }
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
              QsText {
                id: errStatusTxt
                anchors.centerIn: parent; anchors.verticalCenterOffset: -3
                visible: pwLockInput.text.length === 0 && (root.authError || root.authBusy)
                text: root.authBusy ? "VERIFYING..." : "WRONG PASSWORD"
                color: root.authBusy ? root.color4 : "#ff3b5c"; font.pixelSize: 11; font.bold: true; font.letterSpacing: 3
                SequentialAnimation on opacity {
                  running: root.authError && pwLockInput.text.length === 0; loops: Animation.Infinite
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

            QsText {
              Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 4
              visible: !root.isInitialLogin && root.isSwitchingUser
              text: "⚠ LOGGING IN AS " + root.selectedUser.toUpperCase() + " WILL DISCONNECT " + root.currentSessionUser.toUpperCase()
              color: root.color1; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.5
            }
          }

          RowLayout {
            anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.leftMargin: 32; anchors.bottomMargin: 26; spacing: 8
            QsText { text: "SESSION"; color: root.withAlpha(root.fg, 0.6); font.pixelSize: 11; font.letterSpacing: 2 }
            QsText { text: "|"; color: root.color4; font.pixelSize: 11; font.bold: true }
            QsText { text: root.isHyprland ? "HYPRLAND" : "NIRI"; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2 }
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
                QsText { anchors.centerIn: parent; visible: !root.activePlayer || !root.activePlayer.trackArtUrl; text: "󰝚"; color: root.color4; font.pixelSize: 13 }
              }
              QsText {
                Layout.maximumWidth: 200; font.pixelSize: 11; elide: Text.ElideRight
                text: (root.activePlayer && root.activePlayer.trackTitle) ? (root.activePlayer.trackTitle + (root.activePlayer.trackArtist ? " — " + root.activePlayer.trackArtist : "")) : "Media Playing"
              }
              QsMediaControls { btnSize: 20; playSize: 20; iconSize: 14; playIconSize: 15; spacing: 10; pillBg: false }
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
                model: [{ "label": "HIBERNATE", "act": "hibernate" }, { "label": "SUSPEND", "act": "suspend" }, { "label": "REBOOT", "act": "reboot" }]
                Item {
                  required property var modelData
                  visible: lockPowerHover.hovered && (modelData.act !== "hibernate" || root.canHibernate); Layout.alignment: Qt.AlignRight
                  implicitWidth: pwrOptTxt.implicitWidth + 8; implicitHeight: 20
                  QsText { id: pwrOptTxt; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: pwrOptMouse.containsMouse ? root.color4 : root.withAlpha(root.fg, 0.75); font.pixelSize: 11; font.bold: pwrOptMouse.containsMouse; font.letterSpacing: 2 }
                  MouseArea { id: pwrOptMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.execPower(modelData.act) }
                }
              }
              Item {
                Layout.alignment: Qt.AlignRight; implicitWidth: shutdownTxt.implicitWidth + 8; implicitHeight: 20
                QsText { id: shutdownTxt; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "SHUTDOWN"; color: shutdownMouse.containsMouse ? root.color1 : root.withAlpha(root.fg, 0.8); font.pixelSize: 11; font.bold: true; font.letterSpacing: 2 }
                MouseArea { id: shutdownMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.execPower("poweroff") }
              }
            }
          }
        }
      }
    }
  }
}
