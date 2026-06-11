claude --resume d802d2d0-454b-450f-bd87-533fb8547d3b
# Quickshell idle + lock

## How it works

| Layer | Default | Action |
|-------|---------|--------|
| Dim   | 2 min idle | Lower the laptop backlight to 30% (exact level restored on activity) |
| Lock  | 5 min idle | Engage the Wayland session lock (`ext-session-lock-v1`) |
| DPMS  | 30 s after lock | Power the screens off (`hyprctl dispatch dpms off`); any input wakes them |

Idle uses the native `IdleMonitor` (`ext-idle-notify-v1`) and honours idle
inhibitors (the bar's inhibitor toggle, media playback, etc.).

It also locks **before suspend/hibernate** automatically: it listens for logind's
`PrepareForSleep` D-Bus signal, so you wake up to the lock screen. No systemd unit
or hook is needed for this.

Files:
- `lock/LockState.qml` — singleton: session lock, dual PAM auth, dimming, DPMS,
  logind listener, IPC, reload persistence.
- `lock/LockSurface.qml` — per-screen lock UI (clock + password field).
- `lock/IdleDaemon.qml` — the idle monitors.
- Config (timeouts, dim level, PAM service names, backlight device) lives in
  `Theme.qml` under the `--- idle / lock ---` block.

## Required setup

### 1. PAM (the important part)

Create **two** PAM services, each with a **single** auth module. Splitting them is
what lets fingerprint and password authenticate concurrently — a single stacked
PAM service runs modules serially, which is exactly what causes the "press Enter
to fall through to fingerprint" behaviour.

```sh
sudo tee /etc/pam.d/quickshell-lock >/dev/null <<'EOF'
auth required pam_unix.so
EOF

sudo tee /etc/pam.d/quickshell-fprint >/dev/null <<'EOF'
auth required pam_fprintd.so
EOF
```

Your fingerprint must be enrolled (it already is if `fprintd-list "$USER"` shows a
finger). To enroll: `fprintd-enroll`.

Verify both services before relying on them:

```sh
pamtester quickshell-lock   "$USER" authenticate   # prompts for your password
pamtester quickshell-fprint "$USER" authenticate   # prompts for a finger swipe
```

(`pamtester` is in the `pam_wrapper`/`pamtester` package; optional but recommended.)

### 2. Lock keybind (Hyprland)

In `hyprland.conf`:

```ini
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd("qs ipc call lock lock"))
```

## Triggering the lock

- Idle timeout (automatic)
- Before suspend/hibernate (automatic, via logind `PrepareForSleep`)
- The control center **Lock** button (runs `loginctl lock-session`)
- `loginctl lock-session` from anywhere, or any desktop "lock" action — caught via
  the logind `Lock` D-Bus signal
- `qs ipc call lock lock` (keybind / scripts)
