import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: backend

    // UI Orchestration Signals
    signal openMenuRequested
    signal closeMenuRequested

    property string searchText: ""

    property string myTerminal: "ghostty"

    function launchApp(desktopEntry) {
        var parts = [];

        if (desktopEntry.runInTerminal) {
            parts.push(myTerminal);
            parts.push("-e"); // "--" for kitty
        }

        parts = parts.concat(desktopEntry.command);

        Quickshell.execDetached({
            command: ["hyprctl", "dispatch", 'hl.dsp.exec_cmd("' + parts.join(" ") + '")'],
            workingDirectory: desktopEntry.workingDirectory
        });

        backend.closeMenuRequested();
    }

    IpcHandler {
        target: "launcher"
        function toggle() {
            backend.openMenuRequested();
        }
    }
}
