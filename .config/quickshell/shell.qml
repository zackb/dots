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

    Bar{}
    BluetoothPopup {}

    ScoreWidget {
        active: shellVisible
    }
}
