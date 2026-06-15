# Fenriz Quickshell

## Why?
The goal of this quickshell was to replace:
  - waybar
  - rofi / wofi
  - swaync
  - hyprpaper
  - hypridle
  - hyprlock
  - hyprpolkitagent
  - hyprwat
  - bluetui / blueman
  - cliphist

I love these tools and think basically everyone should use them. Don't be like me.
But I was willing to put in the work and more importantly, maintenance to unify my
hyprland desktop into a single setup.

## Idle Monitor

### How it works

| Layer | Default | Action |
|-------|---------|--------|
| Dim   | 2 min idle | Lower the laptop backlight to 30% (exact level restored on activity) |
| Lock  | 5 min idle | Engage the Wayland session lock (`ext-session-lock-v1`) |
| DPMS  | 30 s after lock | Power the screens off (`hyprctl dispatch dpms off`); any input wakes them |

Idle uses the native `IdleMonitor` (`ext-idle-notify-v1`) and honours idle
inhibitors two ways:
- **Wayland idle-inhibit protocol** (the bar's inhibitor toggle, mpv, fullscreen
  browser video) — via `IdleMonitor.respectInhibitors`.
- **DBus `org.freedesktop.ScreenSaver` / `org.gnome.ScreenSaver`** (windowed
  browser video, VLC, etc.) — via the Go backend daemon `backend/fenrizd`,
  which Quickshell launches. It owns those DBus names (Quickshell itself can't),
  brokers `Inhibit`/`UnInhibit`, ignores audio-only inhibits, drops inhibitors
  whose client disconnects, and streams the live state to the `Backend` singleton.
  `LockState` pauses dim+lock while any app inhibits. This is the inhibitor role
  hypridle used to play. If something else already owns the names, the daemon
  no-ops and idle works as normal.

It also locks **before suspend/hibernate** automatically: it listens for logind's
`PrepareForSleep` D-Bus signal, so you wake up to the lock screen. No systemd unit
or hook is needed for this.

Files:
- `lock/LockState.qml` — singleton: session lock, dual PAM auth, dimming, DPMS,
  logind listener, IPC, reload persistence.
- `lock/LockSurface.qml` — per-screen lock UI (clock + password field).
- `lock/IdleDaemon.qml` — the idle monitors (gated on both inhibitor sources).
- `backend/` — the Go backend daemon (`fenrizd`) and the `Backend` singleton
  that fronts it. Generic, service-based; currently hosts the ScreenSaver
  idle-inhibit broker. Built by the top-level `make` (needs the Go toolchain);
  the shell launches the binary and it exits with the shell. The wire protocol
  between the daemon and the shell is documented in [`PROTOCOL.md`](PROTOCOL.md).
- Config (timeouts, dim level, PAM service names, backlight device) lives in
  `Theme.qml` under the `--- idle / lock ---` block.

## Launcher

The `rofi`/`wofi` replacement (`launcher/`). Fuzzy app search with frecency
ranking, plus prefixed modes: `=` for an inline `qalc` calculator (auto-detected
for bare arithmetic too), `@` for the local address book, and `;` for clipboard
history. Open it with `qs ipc call launcher toggle`; `qs ipc call launcher
clipboard` jumps straight into clipboard mode (bind it to Super+V).

Clipboard history is owned by the `fenrizd` daemon — it captures every selection
via `wl-paste --watch`, dedupes into an on-disk store, and restores entries with
`wl-copy` (so it replaces `cliphist`; no separate daemon to autostart). In the
picker, Enter copies the entry, Shift+Delete removes it. Images show a copyable
`[image]` placeholder. See [`PROTOCOL.md`](PROTOCOL.md) (`clipboard` service).

## Dependencies

### Required

Runtime:
- **quickshell** — the shell host itself
- **Hyprland** — compositor; `hyprctl` drives DPMS, lock keybind, and app launching
- **polkit** — native agent (`Quickshell.Services.Polkit`, replaces hyprpolkitagent)
- **PipeWire** — audio sink/source control (`Quickshell.Services.Pipewire`)
- **NetworkManager** (`nmcli`) — network state over D-Bus, plus Wi-Fi
  scan/connect/forget/radio (`nmcli`), both through `fenrizd`
- **UPower** — battery widget (`Quickshell.Services.UPower`)
- **BlueZ** (`bluez`, `bluez-utils`) — bluetooth (`Quickshell.Bluetooth`)
- **PAM** + **fprintd** — lock-screen password and fingerprint auth (see PAM setup below)
- **brightnessctl** — backlight dim/restore and the brightness OSD
- **wl-clipboard** (`wl-copy`/`wl-paste`) — launcher copy actions and clipboard history
- **systemd / logind** — `loginctl` lock-session and `PrepareForSleep` suspend handling
- a **terminal** — `ghostty` by default, for launching `runInTerminal` desktop entries
  (override `myTerminal` in `launcher/LauncherBackend.qml`)

Build:
- **Go toolchain** — builds the backend daemon (`backend/fenrizd`)
- **qsb** — compiles the wallpaper shaders (`make shaders`)

### Optional

- **qalc** (the `libqalculate` CLI) — inline calculator in the launcher; without
  it, arithmetic queries simply return no result
- **pamtester** — verifying the PAM services during setup (recommended, not required)

## Required setup

### Build

```sh
make            # builds shaders + the backend daemon (backend/fenrizd)
```

`make backend` needs the Go toolchain; `make shaders` needs `qsb`. The shell
launches `fenrizd` automatically and it exits with the shell. Without it,
locking/dimming still work but DBus idle inhibitors (VLC, windowed browser
video) are not honoured.

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
