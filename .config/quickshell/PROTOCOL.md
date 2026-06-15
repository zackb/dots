# Backend Protocol

How the Fenriz shell (QML front-end) and its backend daemon (`backend/fenrizd`,
Go) talk to each other.

The daemon owns DBus names and OS facilities Quickshell can't host itself
(`org.freedesktop.ScreenSaver`, NetworkManager, sysfs, vdirsyncer stores, …) and
streams their state to the shell. The shell never sockets to it: the daemon is a
plain child process, events come up its **stdout**, commands go down its
**stdin**, both as newline-delimited JSON.

- Front-end: `backend/Backend.qml` (singleton `Backend`) — launches the daemon,
  parses the stream, exposes each service's state as a property.
- Wire format: `backend/internal/proto/proto.go`.
- Service contract: `backend/internal/service/service.go`.
- Daemon wiring + service registry: `backend/main.go`.

## Transport

The shell runs the daemon via a Quickshell `Process` and reads stdout with a
`SplitParser` (one message per line). One TCP-free, socket-free pipe in each
direction:

```
            ┌──────────────┐   events  (stdout, NDJSON)   ┌─────────────┐
            │   fenrizd    │ ───────────────────────────► │ Backend.qml │
            │  (Go daemon) │ ◄─────────────────────────── │  (shell)    │
            └──────────────┘  commands (stdin,  NDJSON)   └─────────────┘
```

Every message is a single line of JSON terminated by `\n`. A line that fails to
parse is silently dropped on both ends, so a partial or malformed line never
wedges the stream.

### Event (daemon → shell)

```json
{"service":"network","data":{ ... }}
```

| Field     | Type   | Meaning                                              |
|-----------|--------|------------------------------------------------------|
| `service` | string | which service emitted this; routes to a state slot   |
| `data`    | object | service-specific payload (see below); replaces state |

`data` is a **full snapshot**, not a delta — the shell assigns it wholesale to
the matching property. The daemon emits on change (and once at startup), so the
shell always holds the latest complete state for each service.

### Command (shell → daemon)

```json
{"service":"<name>","command":"<verb>","args":{ ... }}
```

| Field     | Type   | Meaning                                           |
|-----------|--------|---------------------------------------------------|
| `service` | string | target service name                               |
| `command` | string | verb the service understands                      |
| `args`    | object | optional; omitted when empty                      |

Inbound commands are routed to the service if it implements the optional
`Commander` interface (`Command(name string, args json.RawMessage)`). The
`clipboard` and `wifi` services are Commanders today; every other service is
emit-only, so the stream is mostly one-way (daemon → shell). The shell sends
commands via `Backend.command(service, verb, args)`, which writes one JSON line
to the daemon's stdin (the daemon `Process` sets `stdinEnabled: true`).

## Lifecycle

- **Startup.** The shell launches `backend/fenrizd`. Each service `Start`s and
  emits its initial state; the shell's properties begin at safe defaults
  (`Backend.qml`) until the first event arrives.
- **Shell exits.** Closing the shell closes the daemon's stdin → EOF, and the
  daemon is reparented; `watchParentDeath` (polls `getppid`) and the stdin EOF
  both trigger a clean shutdown. There is never an orphaned daemon.
- **Daemon dies.** `Backend.qml` resets every service slot to its default (so a
  stale `screensaver.inhibited` can't wedge idle off, etc.) and relaunches the
  daemon after 2 s.
- **A service fails to start.** The daemon logs a warning and continues with the
  others; that service simply never emits, and the shell keeps its default.

## Services

Each service has a stable `Name()` (the routing key) and emits a `data` payload.
The shell property each one feeds is in the last column.

### `screensaver`

Idle-inhibit broker. Owns `org.freedesktop.ScreenSaver` and
`org.gnome.ScreenSaver`; tracks `Inhibit`/`UnInhibit` from apps (browsers, VLC),
ignores audio-only inhibits, and drops inhibitors whose client falls off the bus.
Emits on every change. → `Backend.screensaverInhibited` / `screensaverInhibitors`

```json
{"inhibited":true,"count":1,
 "inhibitors":[{"cookie":1,"app":"firefox","reason":"Playing video"}]}
```

| Field        | Type   | Notes                                          |
|--------------|--------|------------------------------------------------|
| `inhibited`  | bool   | true while any inhibitor is active             |
| `count`      | int    | number of active inhibitors                    |
| `inhibitors[]`| array | one per request                               |
| ↳ `cookie`   | uint32 | handle returned to the inhibiting client       |
| ↳ `app`      | string | application name (basename)                    |
| ↳ `reason`   | string | reason string supplied by the client           |

### `network`

Primary NetworkManager connection. → `Backend.networkState`

```json
{"type":"wifi","ssid":"home-5g","signal":72,"iface":"wlan0"}
```

| Field    | Type   | Notes                                       |
|----------|--------|---------------------------------------------|
| `type`   | string | `"wifi"` \| `"ethernet"` \| `"none"`        |
| `ssid`   | string | active connection profile name              |
| `signal` | int    | 0–100; 100 for ethernet, 0 when down        |
| `iface`  | string | interface name                              |

### `wifi`

Wi-Fi scanning and management via `nmcli` (which brokers the WPA secret agent, so
passwords need no extra plumbing). Command-driven: it emits in response to a
command or the shell's open-popup poll, not on a D-Bus watch — the passive
indicator lives in `network`. → `Backend.wifiState`

```json
{"enabled":true,"connecting":false,"error":"",
 "networks":[{"ssid":"home-5g","signal":72,"secured":true,"active":true,"saved":true}]}
```

| Field        | Type   | Notes                                                  |
|--------------|--------|--------------------------------------------------------|
| `enabled`    | bool   | Wi-Fi radio on                                         |
| `connecting` | bool   | true while a connect is in flight                      |
| `error`      | string | last connect failure (nmcli message); `""` on success |
| `networks[]` | array  | visible APs, deduped by SSID, active-then-signal order |
| ↳ `ssid`     | string | network SSID                                           |
| ↳ `signal`   | int    | 0–100                                                  |
| ↳ `secured`  | bool   | has security (a password is required)                  |
| ↳ `active`   | bool   | currently connected                                    |
| ↳ `saved`    | bool   | a saved connection profile exists                      |

Commands (this service is a `Commander`): `scan` (rescan + re-list), `list`
(re-list only), `connect` `{"ssid":"…","password":"…"}` (password omitted for
open/saved networks), `forget` `{"ssid":"…"}` (deletes the saved profile), and
`radio` `{"on":true|false}` (toggle the Wi-Fi radio).

### `sysinfo`

CPU / memory / disk / temperature, sampled every 3 s from `/proc` + `/sys`.
→ `Backend.sysinfo`

```json
{"cpuModel":"AMD Ryzen 7","overallCpu":12,"memPercent":41,"diskPercent":63,
 "tempC":47,"cpuCores":[{"index":0,"pct":9,"freq":2800}],
 "memUsedMB":6500,"memTotalMB":16000,"memBuffMB":1200,"memAvailMB":9500,
 "diskUsedMB":210000,"diskTotalMB":500000,"diskAvailMB":290000}
```

| Field         | Type        | Notes                                  |
|---------------|-------------|----------------------------------------|
| `cpuModel`    | string      | model name                             |
| `overallCpu`  | int         | aggregate CPU %                        |
| `cpuCores[]`  | array       | per-core `{index, pct, freq}` (freq MHz)|
| `memPercent`  | int         | memory used %                          |
| `memUsedMB` … | int         | memory breakdown in MB                 |
| `diskPercent` | int         | disk used %                            |
| `diskUsedMB` …| int         | disk breakdown in MB                   |
| `tempC`       | int         | CPU temperature, °C                    |

### `backlight`

Screen brightness, watched live via inotify on the sysfs `brightness` file
(re-emits whenever `brightnessctl` or the kernel writes it). → `Backend.backlight`

```json
{"brightness":120,"max":255}
```

| Field        | Type | Notes                          |
|--------------|------|--------------------------------|
| `brightness` | int  | current raw value              |
| `max`        | int  | `max_brightness` of the device |

### `mlb`

Scoreboard for the configured team's game today; polls the MLB API (every ~2 min
while live, otherwise sleeps until near first pitch). → `Backend.mlbState`

```json
{"active":true,"class":"mlb-live","status":"Bot 7","tooltip":"…","stale":false,
 "home":{"abbr":"SEA","name":"Mariners","score":3,"logo":"…"},
 "away":{"abbr":"NYY","name":"Yankees","score":2,"logo":"…"}}
```

| Field     | Type   | Notes                                                       |
|-----------|--------|-------------------------------------------------------------|
| `active`  | bool   | false when there's no game today                            |
| `class`   | string | `mlb-live` \| `mlb-delay` \| `mlb-final` \| `mlb-pre` \| `mlb-idle` \| `mlb-error` |
| `status`  | string | short status line (inning, "Final", etc.)                   |
| `tooltip` | string | longer detail for hover                                     |
| `stale`   | bool   | last-known data re-shown during a fetch outage              |
| `home` / `away` | obj | `{abbr, name, score, logo}`                              |

### `calendar`

Upcoming events scanned from the local vdirsyncer `.ics` store, soonest first;
re-scanned on a slow ticker. → `Backend.calendarState`

```json
{"upcoming":[{"summary":"Standup","start":"2026-06-13T09:00:00-07:00",
  "end":"2026-06-13T09:15:00-07:00","allDay":false,"location":"",
  "calendar":"Work"}]}
```

| Field        | Type   | Notes                                   |
|--------------|--------|-----------------------------------------|
| `upcoming[]` | array  | events, soonest first                   |
| ↳ `summary`  | string | title                                   |
| ↳ `start`    | string | RFC3339                                 |
| ↳ `end`      | string | RFC3339; `""` when the event has no end |
| ↳ `allDay`   | bool   | all-day event                           |
| ↳ `location` | string | location                                |
| ↳ `calendar` | string | collection display name                 |

### `contacts`

Address book scanned from the local vdirsyncer `.vcf` store (the launcher filters
this list). Note this service's `data` is a **bare array**, not an object.
→ `Backend.contacts`

```json
[{"uid":"abc","name":"Jane Doe","org":"Acme",
  "emails":[{"type":"Work","value":"jane@acme.com"}],
  "phones":[{"type":"Cell","value":"+1…"}]}]
```

| Field      | Type   | Notes                                          |
|------------|--------|------------------------------------------------|
| `uid`      | string | stable id                                      |
| `name`     | string | display name                                   |
| `org`      | string | organization                                   |
| `emails[]` | array  | `{type, value}`; `type` e.g. Cell/Home/Work/"" |
| `phones[]` | array  | `{type, value}`                                |

### `clipboard`

Clipboard history. Captures every selection via two `wl-paste --watch`
subprocesses (text + image) that re-exec the daemon as `-clip-store`, dedupes by
content hash into an on-disk store (`~/.local/state/fenriz/clipboard/`), and
restores an entry with `wl-copy`. The launcher's `;` mode reads this list.
→ `Backend.clipboard`

```json
{"entries":[{"id":"<sha256>","mime":"text/plain;charset=utf-8",
  "preview":"git status","isImage":false,"size":10,"ts":1781422115400}]}
```

| Field       | Type   | Notes                                              |
|-------------|--------|----------------------------------------------------|
| `entries[]` | array  | most-recent-first                                  |
| ↳ `id`      | string | content sha256 (also the blob filename)            |
| ↳ `mime`    | string | MIME type; `image/*` for binary entries            |
| ↳ `preview` | string | single-line text preview; `""` for images          |
| ↳ `isImage` | bool   | true for binary/image entries                      |
| ↳ `size`    | int    | byte size of the value                             |
| ↳ `ts`      | int64  | unix millis, last seen/copied                      |

Commands (this service is a `Commander`): `copy` / `delete` take `{"id":"…"}`;
`wipe` clears all. `copy` restores the entry to the clipboard via `wl-copy`.

## Adding a service

1. Implement `service.Service` (`Name`, `Start`) in `backend/internal/<name>/`;
   emit your payload via the supplied `Emitter` on change and once at startup.
2. Register it in the `services` slice in `backend/main.go`.
3. In `Backend.qml`, add a default-valued state property and a routing branch in
   the `SplitParser.onRead` switch (and reset it in `onExited`).
4. (Optional) implement `service.Commander` to accept commands on stdin.
