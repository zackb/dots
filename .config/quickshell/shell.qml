import Quickshell
import Quickshell.Io
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

    BluetoothPopup {}

    ScoreWidget {
        active: shellVisible
    }
}
