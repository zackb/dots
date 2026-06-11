import Quickshell
import Quickshell.Wayland
import QtQuick
import "../"

// Each IdleMonitor is one layer and drives LockState. 
// respectInhibitors honours the bar's IdleInhibitor toggle (bar/Idle.qml) 
// and any media inhibitors.
// DPMS is NOT an idle monitor it is a timer inside
// LockState keyed off the locked state, so manual and idle locks blank the
// screen identically.
Item {
    // ensure the LockState singleton is instantiated at startup
    Component.onCompleted: { const _ = LockState.locked }

    // Layer 1: dim the screen
    IdleMonitor {
        respectInhibitors: true
        timeout: Theme.idleDimTimeout
        onIsIdleChanged: isIdle ? LockState.dim() : LockState.undim()
    }

    // Layer 2: lock the session (never auto-unlocks; unlock requires auth)
    IdleMonitor {
        respectInhibitors: true
        timeout: Theme.idleLockTimeout
        onIsIdleChanged: if (isIdle) LockState.engageLock()
    }
}
