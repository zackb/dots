// BluetoothPopup.qml
// A Wayland layer-shell popup window for Bluetooth management.
// Displays connected/paired devices, battery levels, scan toggle,
// and adapter power control. Triggered via IPC or keybind.

import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: root

    IpcHandler {
        target: "bluetooth"

        function toggle() {
            root.visible = !root.visible
            // When opening, kick off a fresh device scan
            if (root.visible && adapter) {
                adapter.discovering = true
                scanTimer.restart()
                cursorPosProcess.running = true
            }
        }
    }

    Process {
        id: cursorPosProcess
        command: ["hyprctl", "cursorpos"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var parts = data.split(", ")
                if (parts.length === 2) {
                    var cx = parseInt(parts[0])
                    var cy = parseInt(parts[1])
                    var newLeft = cx - (root.implicitWidth / 2)
                    root.margins.left = newLeft > 0 ? newLeft : 0
                    root.margins.top = cy + 10
                }
            }
        }
    }

    // ── Window geometry ────────────────────────────────────────────
    visible:   false
    implicitWidth:  340
    implicitHeight: contentCol.implicitHeight + 24

    anchors {
        top:   true
        left:  true
    }
    margins {
        top:   8
        left:  8
    }

    // Layer shell settings — float above everything, no keyboard grab
    WlrLayershell.layer:      WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode:            ExclusionMode.Ignore

    // Close on click-outside via an invisible full-screen underlay
    // (handled by the MouseArea below)

    // ── Bluetooth state ────────────────────────────────────────────
    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter

    // Scan auto-off timer (BlueZ scan is expensive — stop after 15s)
    Timer {
        id: scanTimer
        interval: 15000
        onTriggered: {
            if (root.adapter) root.adapter.discovering = false
        }
    }

    // ── AirPods battery via airstatus JSON ─────────────────────────
    // Requires: github.com/delphiki/AirStatus running as a systemd service
    // that writes to /tmp/airstatus.out
    property var airpodsBattery: null

    FileView {
        id: airstatusFile
        path: "/tmp/airstatus.out"
        // Poll every 30s — AirPods battery doesn't change fast
        onTextChanged: {
            try {
                var data = JSON.parse(airstatusFile.text)
                if (data.status === 1) {
                    root.airpodsBattery = data.charge
                } else {
                    root.airpodsBattery = null
                }
            } catch(e) {
                root.airpodsBattery = null
            }
        }
    }

    Timer {
        interval: 30000
        running: root.visible
        repeat: true
        onTriggered: airstatusFile.reload()
    }

    // ── Helper functions ───────────────────────────────────────────
    function deviceIcon(device) {
        // BlueZ icon names map to freedesktop icon names
        var icon = device.icon
        if (icon === "audio-headphones" || icon === "audio-headset")
            return "🎧"
        if (icon === "audio-card")
            return "🔊"
        if (icon === "input-keyboard")
            return "⌨️"
        if (icon === "input-mouse")
            return "🖱️"
        if (icon === "phone")
            return "📱"
        if (icon === "computer")
            return "💻"
        return "📡"
    }

    function batteryColor(pct) {
        if (pct > 50) return theme.batteryHigh
        if (pct > 20) return theme.batteryMid
        return theme.batteryLow
    }

    function batteryBar(pct) {
        // Return a small filled/empty block string
        var filled = Math.round(pct / 10)
        var bar = ""
        for (var i = 0; i < 10; i++) bar += (i < filled ? "█" : "░")
        return bar
    }

    // ── Theme ──────────────────────────────────────────────────────
    QtObject {
        id: theme
        property color bg:           "#1a1b26"
        property color bgElevated:   "#24253a"
        property color bgHover:      "#2d2e4a"
        property color border:       "#414868"
        property color text:         "#c0caf5"
        property color textDim:      "#565f89"
        property color textBright:   "#e0e5ff"
        property color accent:       "#7aa2f7"
        property color accentDim:    "#3b4261"
        property color connected:    "#9ece6a"
        property color disconnected: "#565f89"
        property color scanning:     "#e0af68"
        property color batteryHigh:  "#9ece6a"
        property color batteryMid:   "#e0af68"
        property color batteryLow:   "#f7768e"
        property color danger:       "#f7768e"
        property int   radius:       12
        property int   radiusSm:     8
        property int   fontSz:       13
        property int   fontSzSm:     11
    }

    // ── Root visual ────────────────────────────────────────────────
    color: "transparent"

    // Click-outside dismissal
    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
        z: -1
    }

    Rectangle {
        id: panel
        anchors {
            top:    parent.top
            right:  parent.right
        }
        width:  340
        height: contentCol.implicitHeight + 24
        color:  theme.bg
        radius: theme.radius
        border.color: theme.border
        border.width: 1

        // Drop shadow effect via layered rectangles
        Rectangle {
            anchors.fill:    parent
            anchors.margins: -1
            color:           "transparent"
            border.color:    Qt.rgba(0, 0, 0, 0.4)
            border.width:    1
            radius:          theme.radius + 1
            z:               -1
        }

        // ── Content ────────────────────────────────────────────────
        ColumnLayout {
            id: contentCol
            anchors {
                top:   parent.top
                left:  parent.left
                right: parent.right
                topMargin:    12
                leftMargin:   12
                rightMargin:  12
                bottomMargin: 12
            }
            spacing: 8

            // ── Header ─────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text:  "Bluetooth"
                    color: theme.textBright
                    font { pixelSize: 15; bold: true }
                }

                Item { Layout.fillWidth: true }

                // Scanning indicator
                Text {
                    visible: root.adapter && root.adapter.discovering
                    text:    "scanning…"
                    color:   theme.scanning
                    font.pixelSize: theme.fontSzSm
                }

                // Adapter power toggle
                Rectangle {
                    width:  44
                    height: 24
                    radius: 12
                    color:  (root.adapter && root.adapter.enabled)
                            ? theme.accent
                            : theme.bgElevated
                    border.color: theme.border
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text:  (root.adapter && root.adapter.enabled) ? "ON" : "OFF"
                        color: (root.adapter && root.adapter.enabled)
                               ? theme.bg
                               : theme.textDim
                        font { pixelSize: 10; bold: true }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.adapter)
                                root.adapter.enabled = !root.adapter.enabled
                        }
                    }
                }
            }

            // ── Divider ────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color:  theme.border
                opacity: 0.5
            }

            // ── No adapter state ───────────────────────────────────
            Text {
                visible:    !root.adapter
                text:       "No Bluetooth adapter found"
                color:      theme.textDim
                font.pixelSize: theme.fontSz
                Layout.alignment: Qt.AlignHCenter
            }

            // ── Adapter off state ──────────────────────────────────
            Text {
                visible:    root.adapter && !root.adapter.enabled
                text:       "Bluetooth is off"
                color:      theme.textDim
                font.pixelSize: theme.fontSz
                Layout.alignment: Qt.AlignHCenter
            }

            // ── Device list ────────────────────────────────────────
            ScrollView {
                id: deviceScroll
                visible:    root.adapter && root.adapter.enabled
                Layout.fillWidth: true
                Layout.maximumHeight: 350
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ColumnLayout {
                    width: deviceScroll.availableWidth
                    spacing: 4

// Section: Connected
                Repeater {
                    model: root.adapter ? root.adapter.devices.values : []
                    delegate: DeviceRow {
                        property var dev: modelData
                        visible: dev && dev.connected
                        device: dev
                        airpodsBattery: root.airpodsBattery
                        theme: theme
                        onDisconnect: { if(dev) dev.connected = false }
                    }
                }

                // Section header: Paired (not connected)
                Text {
                    property var pairedOnly: root.adapter
                         ? root.adapter.devices.values.filter(d => d.paired && !d.connected)
                         : []
                    visible:        pairedOnly.length > 0
                    text:           "PAIRED"
                    color:          theme.textDim
                    font { pixelSize: 10; letterSpacing: 1.5; bold: true }
                    Layout.topMargin: 4
                }

                Repeater {
                    model: root.adapter ? root.adapter.devices.values : []
                    delegate: DeviceRow {
                        property var dev: modelData
                        visible: dev && dev.paired && !dev.connected
                        device: dev
                        airpodsBattery: null
                        theme: theme
                        onConnect: { if(dev) dev.connected = true }
                        onForget: { if(dev) dev.forget() }
                    }
                }

                // Section header: Discovered (not paired)
                Text {
                    property var discovered: root.adapter
                        ? root.adapter.devices.values.filter(d => !d.paired)
                        : []
                    visible:        discovered.length > 0
                    text:           "NEARBY"
                    color:          theme.textDim
                    font { pixelSize: 10; letterSpacing: 1.5; bold: true }
                    Layout.topMargin: 4
                }

                Repeater {
                    model: root.adapter ? root.adapter.devices.values : []
                    delegate: DeviceRow {
                        property var dev: modelData
                        visible: dev && !dev.paired
                        device: dev
                        airpodsBattery: null
                        theme: theme
                        onPair: { if(dev) dev.pair() }
                    }
                }

                // Empty state when enabled but nothing found yet
                Text {
                    visible: root.adapter && root.adapter.enabled
                             && root.adapter.devices.values.length === 0
                    text:    "No devices found — scanning…"
                    color:   theme.textDim
                    font.pixelSize: theme.fontSz
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                }
            }
            }

            // ── Scan button ────────────────────────────────────────
            Rectangle {
                visible:  root.adapter && root.adapter.enabled
                Layout.fillWidth:  true
                height:   36
                radius:   theme.radiusSm
                color:    scanHover.containsMouse ? theme.bgHover : theme.bgElevated
                border.color: theme.border
                border.width: 1
                Layout.topMargin: 4

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text:  root.adapter && root.adapter.discovering
                               ? "⟳"
                               : "⊕"
                        color: theme.accent
                        font.pixelSize: 16

                        RotationAnimation on rotation {
                            running:  root.adapter && root.adapter.discovering
                            from:     0
                            to:       360
                            duration: 1500
                            loops:    Animation.Infinite
                        }
                    }

                    Text {
                        text:  root.adapter && root.adapter.discovering
                               ? "Stop scanning"
                               : "Scan for devices"
                        color: theme.text
                        font.pixelSize: theme.fontSz
                    }
                }

                MouseArea {
                    id:          scanHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.adapter) return
                        if (root.adapter.discovering) {
                            root.adapter.discovering = false
                            scanTimer.stop()
                        } else {
                            root.adapter.discovering = true
                            scanTimer.restart()
                        }
                    }
                }
            }
        }
    }
}
