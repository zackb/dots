import Quickshell
import Quickshell.Io
import "./bar"
import "./bluetooth"
import "./mlb"

ShellRoot {

    property bool shellVisible: true

    IpcHandler {
        target: "shell"
        function toggle() {
            shellVisible = !shellVisible
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Bar {
            required property var modelData
            screen: modelData
        }
    }
    BluetoothPopup {}

    ScoreWidget {
        active: shellVisible
    }
}
