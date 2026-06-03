import QtQuick
import "../"

Row {
    property string label: ""
    property string value: ""
    spacing: 2

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text:           label
        color:          Qt.alpha(Theme.textColor, 0.5)
        font.pixelSize: Theme.fontSize
        font.family:    Theme.nerdFont
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text:           value
        color:          Theme.textColor
        font.pixelSize: Theme.fontSize
        font.family:    Theme.font
    }
}
