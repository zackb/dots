// Glyph plus an optional value, the body every status capsule in the bar shares.
// The capsule's own handlers stay with it -- what a click means differs per
// widget, so only the presentation is shared.
import QtQuick
import qs.theme

Row {
    property string glyph: ""
    property color  glyphColor: Theme.textColor
    property string label: ""
    property bool   showLabel: false
    property int    labelSize: Theme.fontSize

    spacing: 4

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text:           glyph
        color:          glyphColor
        font.pixelSize: Theme.fontSize
        font.family:    Theme.nerdFont
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible:        showLabel
        text:           label
        color:          Qt.alpha(Theme.textColor, 0.8)
        font.pixelSize: labelSize
        font.family:    Theme.font
    }
}
