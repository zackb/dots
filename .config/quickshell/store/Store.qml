pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Centralized runtime-state plumbing for the shell.
//
//   * path(name)           -- resolves a bare file name to
//                             ~/.local/state/fenriz/<name> (XDG_STATE_HOME).
//
//   * readJson / writeJson -- safe, synchronous JSON read/write so modules don't
//                             each re-implement a FileView + JSON.parse/try-catch.
//
// Files that need a *live* view (watchChanges) should take path() from here and
// own their own FileView (Theme's wallpaper watcher). Likewise, writes that
// must be seen by an inotify watcher have to be non-atomic.
Singleton {
    id: root

    // ~/.local/state/fenriz - created on startup below.
    readonly property string dir: {
        const xdg = Quickshell.env("XDG_STATE_HOME")
        const base = (xdg && xdg.length > 0)
            ? xdg
            : Quickshell.env("HOME") + "/.local/state"
        return base + "/fenriz"
    }

    // Absolute path to a state file.
    function path(name: string): string {
        return root.dir + "/" + name
    }

    // Read and parse a JSON state file. Returns `fallback` (default {}) when the
    // file is missing or contains invalid JSON. Synchronous (blockLoading).
    //
    // Uses a throwaway FileView per call on purpose: a reused FileView keeps the
    // last successfully-loaded text when a new path fails to load, so a missing
    // file would leak the previous caller's data.
    function readJson(name, fallback) {
        if (fallback === undefined)
            fallback = ({})
        const fv = _reader.createObject(root, { path: root.path(name) })
        let result = fallback
        try {
            const t = fv.text()
            if (t && t.length > 0)
                result = JSON.parse(t)
        } catch (e) {
        }
        fv.destroy()
        return result
    }

    // Serialize `obj` and write it to a JSON state file (atomically). The caller
    // is the only writer of its own file, so reusing one handle is safe here.
    function writeJson(name, obj): void {
        _writer.path = root.path(name)
        _writer.setText(JSON.stringify(obj))
    }

    // Ensure the state dir exists so the first write doesn't race a missing dir.
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.dir])

    Component {
        id: _reader
        FileView {
            blockLoading: true   // text() returns contents synchronously
            printErrors: false   // missing file is an expected case, not an error
        }
    }

    // Shared write handle. atomicWrites guards against a half-written file on a
    // crash mid-write.
    FileView {
        id: _writer
        blockLoading: true
        atomicWrites: true
        printErrors: false
    }
}
