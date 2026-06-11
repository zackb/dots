import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../"

Item {
    id: root

    // Apply a new wallpaper:
    //  - update Theme.wallpaper directly so the background swaps immediately,
    //  - persist the path to wallpaper.txt so the choice survives a reload
    //  - regenerate the matugen palette into colors.json, then force Theme to
    //    re-read it (matugen's atomic write are missed by FileView watch).
    function setWallpaper(path) {
        if (!path || path.length === 0)
            return
        Theme.wallpaper = path
        Quickshell.execDetached(["bash", "-c",
            'printf "%s" "$1" > ~/.config/quickshell/wallpaper.txt', "bash", path])
        matugen.command = ["matugen", "image", "--source-color-index", "0", path]
        matugen.running = true
    }

    Process {
        id: matugen
        onExited: (code, status) => {
            if (code === 0)
                Theme.reloadColors()
        }
    }

    IpcHandler {
        target: "wallpaper"

        function set(path: string): void { root.setWallpaper(path) }
        function get(): string { return Theme.wallpaper }
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            WlrLayershell.layer:         WlrLayer.Background
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors { top: true; bottom: true; left: true; right: true }
            color: "black"

            readonly property string source: Theme.wallpaper ? "file://" + Theme.wallpaper : ""

            // double-buffered crossfade
            property bool showA: true

            function apply(src) {
                const incoming = showA ? b : a
                incoming.source = src
            }

            onSourceChanged: apply(source)
            Component.onCompleted: apply(source)

            component Layer: Image {
                anchors.fill: parent
                fillMode:     Image.PreserveAspectCrop
                asynchronous: true
                cache:        false
                smooth:       true
                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
            }

            Layer {
                id: a
                z: win.showA ? 1 : 0
                opacity: win.showA ? 1 : 0
                onStatusChanged: if (status === Image.Ready && !win.showA) win.showA = true
            }

            Layer {
                id: b
                z: win.showA ? 0 : 1
                opacity: win.showA ? 0 : 1
                onStatusChanged: if (status === Image.Ready && win.showA) win.showA = false
            }
        }
    }
}
