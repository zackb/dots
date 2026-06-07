pragma Singleton

import Quickshell
import QtQuick


Singleton {

    // size
    readonly property int barHeight:       24

    // typography
    readonly property int fontSize:         16
    readonly property string font:          "Cantarell"
    readonly property string nerdFont:      "MesloLGSDZ Nerd Font Mono"
    readonly property string textColor:     "#cdd6f4"

    // styling
    readonly property color capsuleBg:     Qt.alpha("#1e1e2e", 0.5)


    // cattpuccin mocha muave
    readonly property string primary: "#cba6f7"
    readonly property string on_primary: "#1e1534"
    readonly property string primary_container: "#332152"
    readonly property string on_primary_container: "#e8d5ff"
    readonly property string primary_fixed: "#e8d5ff"
    readonly property string on_primary_fixed: "#0d0620"
    readonly property string secondary: "#b4befe"
    readonly property string on_secondary: "#1e2150"
    readonly property string secondary_container: "#313467"
    readonly property string on_secondary_container: "#d8dbff"
    readonly property string secondary_fixed: "#d8dbff"
    readonly property string on_secondary_fixed: "#090b2a"
    readonly property string tertiary: "#f5c2e7"
    readonly property string on_tertiary: "#3d1a38"
    readonly property string tertiary_container: "#5a2d55"
    readonly property string on_tertiary_container: "#fce0f5"
    readonly property string surface: "#1e1e2e"
    readonly property string on_surface: "#cdd6f4"
    readonly property string surface_variant: "#45475a"
    readonly property string on_surface_variant: "#bac2de"
    readonly property string background: "#1e1e2e"
    readonly property string on_background: "#cdd6f4"
    readonly property string surface_container_lowest: "#181825"
    readonly property string surface_container_low: "#1e1e2e"
    readonly property string surface_container: "#24243c"
    readonly property string surface_container_high: "#313244"
    readonly property string surface_container_highest: "#45475a"
    readonly property string outline: "#6c7086"
    readonly property string critical: "#f38ba8"
    readonly property string on_critical: "#460b18"
    readonly property string source_color: "#cba6f7"
    readonly property string shadow: "#000000"
    readonly property string scrim: "#000000"
    readonly property string wallpaper: "/home/zackb/.local/share/wallpapers/4199401.jpg"
}
