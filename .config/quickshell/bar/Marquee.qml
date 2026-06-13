import QtQuick
import qs.theme

// Horizontal hover-scroll text: stays static until hovered, then scrolls the
// overflowing text back and forth. Falls back to a plain (clipped) label when
// the text fits within maxWidth.
Item {
    id: root

    property string text: ""
    property int    maxWidth: 220
    property color  color: Theme.textColor
    property string fontFamily: Theme.font
    property int    fontPixelSize: Theme.fontSize
    property bool   bold: false
    property bool   hovered: false

    // Unclamped text width; independent of maxWidth, safe for callers to allocate against.
    readonly property real naturalWidth: label.implicitWidth

    readonly property bool overflowing: label.implicitWidth > maxWidth
    readonly property bool scrolling: hovered && overflowing

    implicitWidth:  Math.min(label.implicitWidth, maxWidth)
    implicitHeight: label.implicitHeight
    clip: true

    Text {
        id: label
        text:           root.text
        color:          root.color
        font.family:    root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.bold:      root.bold
        anchors.verticalCenter: parent.verticalCenter
        x: 0
    }

    // Reset position whenever scrolling stops or the text changes.
    onScrollingChanged: if (!scrolling) label.x = 0
    onTextChanged:      label.x = 0

    SequentialAnimation {
        running: root.scrolling
        loops:   Animation.Infinite

        PauseAnimation { duration: 600 }
        NumberAnimation {
            target: label; property: "x"
            from: 0; to: Math.min(0, root.width - label.implicitWidth)
            duration: Math.max(1, label.implicitWidth - root.width) * 18
            easing.type: Easing.Linear
        }
        PauseAnimation { duration: 600 }
        NumberAnimation {
            target: label; property: "x"
            from: Math.min(0, root.width - label.implicitWidth); to: 0
            duration: Math.max(1, label.implicitWidth - root.width) * 18
            easing.type: Easing.Linear
        }
    }
}
