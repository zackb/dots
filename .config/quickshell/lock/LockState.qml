pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick
import qs.backend
import qs.compositor
import qs.store
import qs.theme

// Single source of truth for the idle/lock system. Owns the Wayland session
// lock, the two concurrent PAM contexts (password + fingerprint), idle
// dimming, DPMS, the logind Lock-signal listener, and reload persistence.
//
// IdleDaemon (idle monitors) and LockSurface (per-screen UI) both talk to this
// singleton and never to each other.
//
Singleton {
    id: root

    // public state
    readonly property bool   locked: _wantLocked
    property string fpHint: ""        // fingerprint hint, e.g. "Place finger"
    property string errorText: ""     // shown in red under the password field
    property bool   busy: false       // a password attempt is in flight

    // true while an app holds a DBus ScreenSaver idle inhibit
    // brokered by the Go backend daemon.
    // Wayland-protocol inhibits are handled separately by IdleMonitor.respectInhibitors.
    readonly property bool   externalInhibited: Backend.screensaverInhibited

    // private
    property bool   _wantLocked: false   // drives the lock object's `locked`
    property string _pendingPassword: ""
    property bool   _unlocking: false
    property bool   _dimmed: false
    property int    _savedBrightness: -1
    property bool   _dpmsBlanked: false
    property bool   _gazeScanning: false   // true while the bounded face-scan window is open

    WlSessionLock {
        id: sessionLock
        locked: root._wantLocked     // declarative; re-locks fine on toggle
        LockSurface {}
    }

    // Locking
    function engageLock() {
        if (root._wantLocked) return

        // reset all auth state up front -- do not depend on lock notify signals
        root._unlocking = false
        root.errorText = ""
        root.fpHint = ""
        root._pendingPassword = ""
        root.busy = false

        root._wantLocked = true       // engages the WlSessionLock + surfaces

        // start listening for a finger immediately; the password field drives
        // the password context on submit.
        const ok = fingerprintCtx.start()
        console.log("lock engaged; fingerprintCtx.start ->", ok)

        _startGazeWindow()            // open a bounded face-scan window

        dpmsTimer.restart()           // blank screens dpmsAfterLock later
        _persist()
    }

    // Tear everything down and release the compositor lock.
    function _disengageLock() {
        passwordCtx.abort()
        fingerprintCtx.abort()
        _stopGaze()
        fpRestart.stop()
        dpmsTimer.stop()
        _dpmsForceOn()
        root._pendingPassword = ""
        root.busy = false

        root._wantLocked = false      // sends unlock to the compositor

        // keep logind's view in sync with our state
        Quickshell.execDetached(["loginctl", "unlock-session"])
        _persist()
    }

    // qs ipc call lock lock
    IpcHandler {
        target: "lock"
        function lock() { root.engageLock() }
        function isLocked(): bool { return root.locked }
    }

    // Dual PAM authentication.
    //   passwordCtx    -> service "quickshell-lock"  (pam_unix only)
    //   fingerprintCtx -> service "quickshell-fprint" (pam_fprintd only)
    // Each PamContext is its own subprocess, so they run in parallel and
    // whichever returns Success first unlocks.
    PamContext {
        id: passwordCtx
        config: Theme.pamPasswordConfig
        onPamMessage: {
            if (responseRequired) respond(root._pendingPassword)
        }
        onCompleted: result => {
            console.log("password completed:", result)
            root.busy = false
            root._pendingPassword = ""
            if (result === PamResult.Success) {
                root._authSuccess()
            } else {
                root.errorText = (result === PamResult.MaxTries)
                    ? "Too many attempts" : "Incorrect password"
            }
        }
        onError: err => {
            console.log("pass: failed with", err)
            root.busy = false
            root.errorText = "Authentication error"
        }
    }

    PamContext {
        id: fingerprintCtx
        config: Theme.pamFingerprintConfig
        onPamMessage: {
            console.log("fingerprint message:", message)
            root.fpHint = message
        }
        onCompleted: result => {
            console.log("fingerprint result =", result)
            if (result === PamResult.Success) {
                root._authSuccess()
            } else if (!root._unlocking && root.locked) {
                // wrong/failed finger: keep listening
                fpRestart.restart()
            }
        }
        onError: err => {
            console.log("fprint: failed with", err)
            if (!root._unlocking && root.locked) fpRestart.restart()
        }
    }

    // restart fingerprint listening after a failed swipe (small delay so a
    // misbehaving device can't spin a tight loop)
    Timer {
        id: fpRestart
        interval: 500
        onTriggered: if (!root._unlocking && root.locked) fingerprintCtx.start()
    }

    // Drop a possibly-stale fprintd claim and re-arm a fresh verify. Used on
    // resume from suspend, where the in-flight verify is torn down without a
    // clean completion and the device is left wedged ("already in use").
    function _restartFingerprint() {
        if (root._unlocking || !root.locked) return
        fpRestart.stop()
        fingerprintCtx.abort()      // release the stale claim
        fpRestart.restart()         // 500ms later: start() a fresh verify
    }

    // Gaze (face) auth via pam_gaze -> service "quickshell-gaze". Like the
    // fingerprint context each pam_authenticate is one blocking camera scan that
    // returns success/failure, so we retry within a bounded window (gazeWindow)
    // and stop until the next wake -- the camera is not held on the whole lock.
    PamContext {
        id: gazeCtx
        config: Theme.pamGazeConfig
        onCompleted: result => {
            console.log("gaze result =", result)
            if (result === PamResult.Success) {
                root._authSuccess()
            } else if (root._gazeScanning && !root._unlocking && root.locked) {
                gazeRestart.restart()   // another scan within the open window
            }
        }
        onError: err => {
            console.log("gaze: failed with", err)
            if (root._gazeScanning && !root._unlocking && root.locked) gazeRestart.restart()
        }
    }

    // re-arm a face scan after a failed attempt (small delay so a fast-failing
    // scan can't tight-loop; a real scan attempt takes ~seconds anyway)
    Timer {
        id: gazeRestart
        interval: 500
        onTriggered: if (root._gazeScanning && !root._unlocking && root.locked) gazeCtx.start()
    }

    // closes the scan window: after this fires, no more face scanning until the
    // next wake re-opens it
    Timer {
        id: gazeWindow
        interval: Theme.gazeScanWindow * 1000
        onTriggered: root._stopGaze()
    }

    // Open a bounded face-scan window: start scanning now and arm the closer.
    // No-op when unlocking or not locked.
    function _startGazeWindow() {
        if (!Theme.gazeEnabled || root._unlocking || !root.locked) return
        root._gazeScanning = true
        gazeCtx.abort()             // drop any stale claim before a fresh scan
        gazeCtx.start()
        gazeWindow.restart()
    }

    function _stopGaze() {
        root._gazeScanning = false
        gazeWindow.stop()
        gazeRestart.stop()
        gazeCtx.abort()
    }

    // called by LockSurface when the user submits the password field
    function submitPassword(pw) {
        if (root.busy || root._unlocking) return
        root.errorText = ""
        root._pendingPassword = pw
        root.busy = true
        if (!passwordCtx.start()) {
            root.busy = false
            root._pendingPassword = ""
            root.errorText = "Could not start authentication"
        }
    }

    function _authSuccess() {
        if (root._unlocking) return
        root._unlocking = true
        root.errorText = ""
        root.fpHint = ""
        _disengageLock()
    }

    // Idle dimming (hardware backlight). Reads the current raw value, saves
    // it, then sets a fraction of it; restores the exact value on activity.
    Process {
        id: readBrightness
        command: ["cat", "/sys/class/backlight/" + Theme.backlightDevice + "/brightness"]
        stdout: SplitParser {
            onRead: data => {
                const cur = parseInt(data)
                // user may have already un-dimmed before this async read landed
                if (!root._dimmed || isNaN(cur) || cur <= 0) return
                root._savedBrightness = cur
                const target = Math.max(1, Math.round(cur * Theme.idleDimFraction))
                Quickshell.execDetached(["brightnessctl", "-d", Theme.backlightDevice,
                                         "-q", "set", String(target)])
                root._persist()
            }
        }
    }

    function dim() {
        if (root._dimmed) return
        root._dimmed = true
        readBrightness.running = true     // read -> save -> set (async)
    }

    function undim() {
        if (!root._dimmed) return
        root._dimmed = false
        if (root._savedBrightness > 0) {
            Quickshell.execDetached(["brightnessctl", "-d", Theme.backlightDevice,
                                     "-q", "set", String(root._savedBrightness)])
        }
        root._savedBrightness = -1
        root._persist()
    }

    // DPMS (screen power), via the compositor's IPC (Compositor.dpms).
    function dpmsOff() {
        // Never blank an unlocked session. The blank timer only exists to power
        // screens off *while locked*; if we are not locked (e.g. a stray timer
        // left over from a reload race re-engaging on stale persisted state),
        // blanking would be unrecoverable -- the wake IdleMonitor is gated on
        // `locked`, so nothing would turn the screen back on. See _disengageLock.
        if (!root.locked) return
        if (root._dpmsBlanked) return
        root._dpmsBlanked = true
        Compositor.dpms(false)
    }
    function dpmsOn() {
        if (!root._dpmsBlanked) return
        _dpmsForceOn()
    }
    // Force screens on regardless of our cached _dpmsBlanked belief. Used at
    // startup/reload, on resume, and on unlock -- points where the hardware
    // DPMS state may not match ours (a reload resets _dpmsBlanked to false
    // while the screen is physically still off), so the guarded dpmsOn() would
    // wrongly short-circuit and leave the session bricked.
    function _dpmsForceOn() {
        root._dpmsBlanked = false
        Compositor.dpms(true)
    }

    // blank the screens dpmsAfterLock seconds after the lock engages
    Timer {
        id: dpmsTimer
        interval: Theme.dpmsAfterLock * 1000
        onTriggered: root.dpmsOff()
    }

    // While locked, any activity wakes the screens and restarts the blank countdown.
    IdleMonitor {
        enabled: root.locked
        respectInhibitors: true
        timeout: 2
        onIsIdleChanged: {
            if (!isIdle) {
                root.dpmsOn()
                dpmsTimer.restart()
                if (!root._gazeScanning) root._startGazeWindow()  // re-scan on wake
            }
        }
    }

    // logind D-Bus listener. Two reasons to lock:
    //   * Session.Lock     -> `loginctl lock-session`, the control-center Lock
    //                         button, and desktop "lock" actions.
    //   * PrepareForSleep(true) -> logind broadcasts this right before the
    //                         system suspends/hibernates, so we lock on the way
    //                         into sleep. Replaces hypridle's before_sleep_cmd;
    //                         no systemd unit needed.
    // We monitor the whole login1 destination because Session.Lock is emitted
    // on the concrete session path (not the /session/auto alias) and
    // PrepareForSleep is emitted on the Manager.
    Process {
        id: logindMonitor
        running: true
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("Session.Lock "))
                    root.engageLock()
                else if (line.includes("PrepareForSleep") && line.includes("true"))
                    root.engageLock()
                else if (line.includes("PrepareForSleep") && line.includes("false")) {
                    // resume from suspend: wake the screens (replaces hypridle's
                    // after_sleep_cmd) and, if still locked, restart the blank
                    // countdown rather than leaving them off.
                    root._dpmsForceOn()
                    if (root.locked) {
                        dpmsTimer.restart()
                        // The fprintd verify that was live before suspend gets torn
                        // down across the sleep without a clean onCompleted/onError,
                        // leaving the device claimed but not listening. Both our own
                        // context and other PAM clients (sudo/hyprlock) then see
                        // "device already in use". Re-arm a fresh verify so the claim
                        // is valid again (and releases cleanly on unlock).
                        root._restartFingerprint()
                        root._startGazeWindow()  // re-arm face scan on resume
                    }
                }
            }
        }
    }

    // Reload / crash persistence. A Quickshell config reload destroys this
    // singleton and the WlSessionLock; with an ext-session-lock the compositor
    // keeps the session locked until a new lock client re-attaches. We persist
    // enough to re-engage the lock (so you can still authenticate) and to undo
    // a dim that was active when the reload happened.
    readonly property string _stateFile: "lockstate.json"
    // Always wake the screens when this singleton (re)starts. A reload resets
    // _dpmsBlanked to false while the hardware may still be DPMS-off (e.g. the
    // lid-open path triggers `qs ipc call shell reload`), so force them on first
    // -- otherwise the stale guard would leave the session bricked.
    Component.onCompleted: { root._dpmsForceOn(); root._restoreState() }

    function _persist() {
        Store.writeJson(root._stateFile, {
            locked: root._wantLocked,
            dimmed: root._dimmed,
            savedBrightness: root._savedBrightness
        })
    }

    function _restoreState() {
        const s = Store.readJson(root._stateFile, null)
        if (!s) return
        // undo a dim that was in effect when we were reloaded
        if (s.dimmed && s.savedBrightness > 0) {
            Quickshell.execDetached(["brightnessctl", "-d", Theme.backlightDevice,
                                     "-q", "set", String(s.savedBrightness)])
            root._dimmed = false
            root._savedBrightness = -1
        }
        // re-attach to a still-held compositor lock so the user can unlock
        if (s.locked) root.engageLock()
    }
}
