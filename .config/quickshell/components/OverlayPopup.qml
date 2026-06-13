// Shared base for click-dismissed popups.
// The Wayland surface is a full-screen transparent overlay so a backdrop can
// catch click-outside; it stays unmapped (visible:false) while closed so it
// doesn't steal pointer focus.
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    property var  barWindow
    property bool isOpen: false

    // Emitted when the user clicks outside the panel
    signal requestClose()

    screen: barWindow ? barWindow.screen : null
    visible: false

    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // Transparent backdrop click anywhere outside the panel to close.
    MouseArea {
        anchors.fill: parent
        onClicked: root.requestClose()
        z: -1
    }
}
