import Quickshell
import Quickshell.Services.UPower
import QtQuick
import "../"

Capsule {
    id: root

    // The real battery, picked by sysfs name. We avoid UPower.displayDevice
    // because this machine exposes phantom USB-C power supplies that
    // skew the aggregate percentage.
    readonly property UPowerDevice bat: {
        const list = UPower.devices ? UPower.devices.values : []
        for (const d of list)
            if (d && d.type === UPowerDeviceType.Battery && d.nativePath === "BAT1")
                return d
        for (const d of list)
            if (d && d.isLaptopBattery)
                return d
        return UPower.displayDevice
    }

    // Quickshell reports percentage as a 0.0-1.0 fraction
    property int percentage: {
        if (!bat) return 0
        const p = bat.percentage
        return Math.round(p <= 1 ? p * 100 : p)
    }
    // Charging from UPower's line-power-derived global, NOT the battery's own
    // state: BAT1 firmware reports "discharging" even while on AC.
    property bool charging: !UPower.onBattery
    property bool clicked: false

    function batteryIcon() {
        if (charging) return "󰂄"
        if (percentage < 10) return "󰂎"
        if (percentage < 20) return "󰁺"
        if (percentage < 30) return "󰁻"
        if (percentage < 40) return "󰁼"
        if (percentage < 50) return "󰁽"
        if (percentage < 60) return "󰁾"
        if (percentage < 70) return "󰁿"
        if (percentage < 80) return "󰂀"
        if (percentage < 90) return "󰂁"
        return "󰂂"
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onTapped: (eventPoint, button) => {
            if (button === Qt.RightButton) {
                Quickshell.execDetached(["bash", Qt.resolvedUrl("scripts/battery.sh").toString().replace("file://", "")])
            } else {
                root.clicked = !root.clicked
            }
        }
    }

    contentItem: Row {
        id:               row
        spacing:          4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           batteryIcon()
            color:          root.percentage < 20 ? Theme.battery_low : Theme.textColor
            font.pixelSize: Theme.fontSize
            font.family:    Theme.nerdFont
        }

        Text {
            visible: clicked
            anchors.verticalCenter: parent.verticalCenter
            text:           Math.round(root.percentage ?? 0) + "%"
            color:          Qt.alpha(Theme.textColor, 0.8)
            font.pixelSize: Theme.fontSize
            font.family:    Theme.font
        }
    }
}
