import QtQuick
import Quickshell
import Quickshell.Io
import qs.store

Item {
    id: backend

    // UI Orchestration Signals
    signal openMenuRequested
    signal closeMenuRequested

    property string searchText: ""

    property string myTerminal: "ghostty"

    // Inline calculator (libqalculate). calcExpression is what we send to qalc;
    // calcResult is its terse output. calcActive gates the UI card.
    property string calcExpression: ""
    property string calcResult: ""
    readonly property bool calcActive: calcExpression !== ""

    // Returns the expression to evaluate, or "" if the query isn't a calculation.
    // A leading "=" forces calc mode (units, functions, conversions); otherwise we
    // auto-detect plain arithmetic (a digit AND an operator). qalc happily evaluates
    // non-math input, so this gate must decide before we ever run it.
    function calcQueryOf(text) {
        const t = text.trim();
        if (t.startsWith("="))
            return t.slice(1).trim();
        if (/[0-9]/.test(t) && /[+\-*/^%]/.test(t))
            return t;
        return "";
    }

    onSearchTextChanged: {
        const expr = calcQueryOf(backend.searchText);
        backend.calcExpression = expr;
        if (expr === "") {
            backend.calcResult = "";
            calcProc.running = false;
        } else {
            // restart the process so the new expression is evaluated
            calcProc.running = false;
            calcProc.running = true;
        }
    }

    Process {
        id: calcProc
        running: false
        command: ["qalc", "-t", backend.calcExpression]

        stdout: SplitParser {
            onRead: data => {
                const r = data.trim();
                if (r !== "")
                    backend.calcResult = r;
            }
        }
        stderr: SplitParser {
            onRead: data => console.log("qalc stderr:", data)
        }
    }

    function copyCalcResult() {
        if (backend.calcResult === "")
            return;
        Quickshell.execDetached(["wl-copy", "--", backend.calcResult]);
        backend.closeMenuRequested();
    }

    // Contacts: leading "@" forces contacts-only search; otherwise contacts blend
    // (capped, below apps) into normal results. Returns the query after "@", or
    // "" when not in contacts mode.
    function contactsQueryOf(text) {
        const t = text.trim();
        if (t.startsWith("@"))
            return t.slice(1).trim();
        return "";
    }
    function contactsMode(text) {
        return text.trim().startsWith("@");
    }

    // Compose an email to a contact via the system mailto: handler.
    function emailContact(email, uid) {
        if (!email)
            return;
        if (uid)
            recordUse(uid);
        Quickshell.execDetached(["xdg-open", "mailto:" + email]);
        backend.closeMenuRequested();
    }

    function copyValue(v) {
        if (!v)
            return;
        Quickshell.execDetached(["wl-copy", "--", v]);
        backend.closeMenuRequested();
    }

    // Per-desktop-entry usage for frecency ranking.
    // { "<DesktopEntry.id>": { count: N, last: <epochMs> } }
    property var usage: ({})

    // Persisted to disk; the launcher is the only writer.
    readonly property string _usageFile: "launcher_usage.json"
    Component.onCompleted: backend.usage = Store.readJson(backend._usageFile)

    function recordUse(id) {
        if (!id)
            return;
        const u = backend.usage[id] || { count: 0, last: 0 };
        u.count += 1;
        u.last = Date.now();
        // reassign so bindings (the launcher's sort) re-evaluate
        backend.usage = Object.assign({}, backend.usage, { [id]: u });
        Store.writeJson(backend._usageFile, backend.usage);
    }

    function _recencyWeight(ageMs) {
        const day = 86400000;
        if (ageMs < day)      return 1.0;
        if (ageMs < 3 * day)  return 0.7;
        if (ageMs < 7 * day)  return 0.5;
        if (ageMs < 30 * day) return 0.25;
        return 0.1;
    }

    function frecency(id) {
        const u = backend.usage[id];
        if (!u)
            return 0;
        return u.count * backend._recencyWeight(Date.now() - u.last);
    }

    function launchApp(desktopEntry) {
        backend.recordUse(desktopEntry.id);

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
