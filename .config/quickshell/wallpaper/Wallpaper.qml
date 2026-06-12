import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.store
import qs.theme

Item {
    id: root

    // Apply a new wallpaper:
    //  - update Theme.wallpaper directly so the background swaps immediately,
    //  - persist the path to wallpaper.txt so the choice survives a reload.
    //    Written non-atomically (printf, not setText) on purpose: Theme watches
    //    this file and an atomic rename is missed by the FileView watch -- same
    //    quirk that makes matugen's colors.json writes need an explicit reload().
    //  - regenerate the matugen palette into colors.json, then force Theme to
    //    re-read it.
    function setWallpaper(path) {
        if (!path || path.length === 0)
            return
        Theme.wallpaper = path
        Quickshell.execDetached(["bash", "-c",
            'mkdir -p "$(dirname "$1")"; printf "%s" "$2" > "$1"',
            "bash", Store.path("wallpaper.txt"), path])
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

        // swap animation: fade | wipe | circle | dissolve | pixelate |
        //                 push | blinds | clock | ripple | random
        function setTransition(mode: string): void { Theme.wallpaperTransition = mode }
        function getTransition(): string { return Theme.wallpaperTransition }
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

            // ping-pong buffers: one image holds the wallpaper currently shown,
            // the other loads the incoming one. A shader blends from the shown
            // image to the incoming
            property bool aActive:   true   // which image is currently shown
            property bool animating: false  // true only while a swap is in flight
            property real progress:  0
            property string effect:  "fade"

            readonly property var effects: ["fade", "wipe", "circle", "dissolve",
                                            "pixelate", "push", "blinds", "clock", "ripple"]

            function pickEffect() {
                var e = Theme.wallpaperTransition
                if (e === "random")
                    e = effects[Math.floor(Math.random() * effects.length)]
                if (effects.indexOf(e) < 0)
                    e = "fade"
                effect = e
            }

            // Load `src` into the hidden buffer; the animation kicks off once
            // that image reports Ready (see WallImage.onStatusChanged).
            function swap(src) {
                var incoming = aActive ? bImg : aImg
                if (incoming.source == src)
                    return
                pickEffect()
                animating = true            // wake the ShaderEffectSources
                incoming.source = src
            }

            function beginAnim() {
                progress = 0
                anim.restart()
            }

            function endAnim() {
                aActive = !aActive          // incoming buffer is now the shown one
                progress = 0
                animating = false
            }

            onSourceChanged: swap(source)
            Component.onCompleted: swap(source)

            NumberAnimation {
                id: anim
                target: win
                property: "progress"
                from: 0; to: 1
                duration: Theme.wallpaperTransitionDuration
                easing.type: Easing.InOutQuad
                onFinished: win.endAnim()
            }

            component WallImage: Image {
                anchors.fill:  parent
                visible:       false        // only the ShaderEffect is drawn
                fillMode:      Image.PreserveAspectCrop
                asynchronous:  true
                cache:         false
                smooth:        true
            }

            WallImage {
                id: aImg
                onStatusChanged: if (status === Image.Ready && !win.aActive && win.animating) win.beginAnim()
            }
            WallImage {
                id: bImg
                onStatusChanged: if (status === Image.Ready && win.aActive && win.animating) win.beginAnim()
            }

            ShaderEffectSource {
                id: aSrc
                anchors.fill: parent
                sourceItem:   aImg
                hideSource:   true
                live:         win.animating
                visible:      false
            }
            ShaderEffectSource {
                id: bSrc
                anchors.fill: parent
                sourceItem:   bImg
                hideSource:   true
                live:         win.animating
                visible:      false
            }

            ShaderEffect {
                anchors.fill:   parent
                fragmentShader: Qt.resolvedUrl("shaders/" + win.effect + ".frag.qsb")
                property real     progress: win.progress
                property real     aspect:   width / height
                property variant  fromTex:  win.aActive ? aSrc : bSrc
                property variant  toTex:    win.aActive ? bSrc : aSrc
            }
        }
    }
}
