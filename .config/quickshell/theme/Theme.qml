pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.store


Singleton {
    id: themeRoot

    // static
    readonly property int barHeight:       24
    readonly property int fontSize:        16
    readonly property string font:         "Cantarell"
    readonly property string nerdFont:     "MesloLGSDZ Nerd Font Mono"
    readonly property string ligatureFont: "Material Symbols Rounded"
    readonly property int radius:          12
    readonly property int radius_sm:       8
    readonly property int font_size_sm:    11

    // idle / lock
    // timeouts are in seconds
    readonly property int    idleDimTimeout:       120    // dim the screen after 2 min idle
    readonly property real   idleDimFraction:      0.30   // dim to 30% of the current level
    readonly property int    idleLockTimeout:      300    // lock after 5 min idle
    readonly property int    dpmsAfterLock:        30     // power screens off 30s after locking
    // PAM service names: /etc/pam.d/<name>.
    // two services so fingerprint + password race concurrently
    readonly property string pamPasswordConfig:    "quickshell-lock"
    readonly property string pamFingerprintConfig: "quickshell-fprint"
    // hardware backlight device used for idle dimming
    readonly property string backlightDevice:      "amdgpu_bl1"
    // lock screen background: blurred wallpaper + darkening scrim
    readonly property int    lockBlurMax:          64     // max blur radius (px)
    readonly property real   lockScrimOpacity:     0.35   // 0 = none, 1 = black

    // default wallpaper lives here; overridden live and across reloads by
    // wallpaper.txt, written by the `wallpaper` IPC.
    readonly property string defaultWallpaper: "/home/zackb/.local/share/wallpapers/4199401.jpg"
    property string wallpaper: defaultWallpaper

    // wallpaper swap animation. One of the shaders in wallpaper/shaders/
    // ("fade", "wipe", "circle", "dissolve", "pixelate", "push", "blinds",
    // "clock", "ripple") or "random" to pick a different one on every swap.
    property string wallpaperTransition: "random"
    readonly property int wallpaperTransitionDuration: 800

    // utility status colors
    readonly property color connected:    "#a6e3a1"
    readonly property color warning:      "#f9e2af"
    readonly property color battery_high: "#a6e3a1"
    readonly property color battery_mid:  "#f9e2af"
    readonly property color battery_low:  "#f38ba8"

    // matugen override.
    // matugen image --source-color-index 0 "$wall"
    // remove colors.json to revert to Catppuccin Mocha Mauve defaults.
    // call reloadColors() to force re-read
    FileView {
        id: colorFile
        path: Quickshell.shellPath("colors.json")
        watchChanges: true
        onTextChanged: themeRoot._loadColors()
        onLoaded:      themeRoot._loadColors()
    }

    property var _c: ({})

    function _loadColors() {
        try { _c = JSON.parse(colorFile.text()) }
        catch(e) { _c = {} }
    }

    // force a re-read of colors.json
    function reloadColors() {
        colorFile.reload()
    }

    // wallpaper path persistence (live-reloads when wallpaper.txt changes)
    FileView {
        id: wallpaperFile
        path: Store.path("wallpaper.txt")
        watchChanges: true
        onTextChanged: themeRoot._loadWallpaper()
    }

    function _loadWallpaper() {
        const p = wallpaperFile.text().trim()
        themeRoot.wallpaper = p.length > 0 ? p : themeRoot.defaultWallpaper
    }

    Component.onCompleted: {
        _loadColors()
        _loadWallpaper()
    }

    // Palette: Catppuccin Mocha Mauve defaults
    readonly property string primary:                   _c.primary                   || "#cba6f7"
    readonly property string on_primary:                _c.on_primary                || "#1e1534"
    readonly property string primary_container:         _c.primary_container         || "#332152"
    readonly property string on_primary_container:      _c.on_primary_container      || "#e8d5ff"
    readonly property string primary_fixed:             _c.primary_fixed             || "#e8d5ff"
    readonly property string on_primary_fixed:          _c.on_primary_fixed          || "#0d0620"
    readonly property string secondary:                 _c.secondary                 || "#b4befe"
    readonly property string on_secondary:              _c.on_secondary              || "#1e2150"
    readonly property string secondary_container:       _c.secondary_container       || "#313467"
    readonly property string on_secondary_container:    _c.on_secondary_container    || "#d8dbff"
    readonly property string secondary_fixed:           _c.secondary_fixed           || "#d8dbff"
    readonly property string on_secondary_fixed:        _c.on_secondary_fixed        || "#090b2a"
    readonly property string tertiary:                  _c.tertiary                  || "#f5c2e7"
    readonly property string on_tertiary:               _c.on_tertiary               || "#3d1a38"
    readonly property string tertiary_container:        _c.tertiary_container        || "#5a2d55"
    readonly property string on_tertiary_container:     _c.on_tertiary_container     || "#fce0f5"
    readonly property string surface:                   _c.surface                   || "#1e1e2e"
    readonly property string on_surface:                _c.on_surface                || "#cdd6f4"
    readonly property string surface_variant:           _c.surface_variant           || "#45475a"
    readonly property string on_surface_variant:        _c.on_surface_variant        || "#bac2de"
    readonly property string background:                _c.background                || "#1e1e2e"
    readonly property string on_background:             _c.on_background             || "#cdd6f4"
    readonly property string surface_container_lowest:  _c.surface_container_lowest  || "#181825"
    readonly property string surface_container_low:     _c.surface_container_low     || "#1e1e2e"
    readonly property string surface_container:         _c.surface_container         || "#24243c"
    readonly property string surface_container_high:    _c.surface_container_high    || "#313244"
    readonly property string surface_container_highest: _c.surface_container_highest || "#45475a"
    readonly property string outline:                   _c.outline                   || "#6c7086"
    readonly property string critical:                  _c.critical                  || "#f38ba8"
    readonly property string on_critical:               _c.on_critical               || "#460b18"
    readonly property string source_color:              _c.source_color              || "#cba6f7"
    readonly property string shadow:                                                    "#000000"
    readonly property string scrim:                                                     "#000000"

    // derived
    readonly property string textColor:       on_surface
    readonly property color  popupBg:         Qt.alpha(surface, 0.95)
    readonly property color  popupBorder:     surface_container_highest
    readonly property color  capsuleBg:       Qt.alpha(surface, 0.5)
    readonly property color  capsuleBgHover:  Qt.alpha(primary_container, 0.85)
}
