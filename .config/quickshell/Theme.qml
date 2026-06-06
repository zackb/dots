pragma Singleton

import Quickshell
import QtQuick


Singleton {

    // size
    readonly property int barHeight:       24

    // typography
    readonly property int fontSize:         16
    readonly property string font:          "Cantarell"
    readonly property string nerdFont:      "MesloLGSDZ Nerd Font Mono"
    readonly property string textColor:     "#cdd6f4"

    // styling
    readonly property color capsuleBg:     Qt.alpha("#1e1e2e", 0.5)
}
