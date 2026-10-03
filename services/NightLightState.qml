pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Shared night light state. The OSD content is destroyed every time the OSD
// closes, so the state lives here instead of in the widget.
Singleton {
    id: root

    readonly property int minTemp: 2500
    readonly property int maxTemp: 6500

    property bool active: false
    property int temp: 4000
    // Slider position, 0..1: 0 = no filter (maxTemp), 1 = strongest (minTemp)
    readonly property real fraction: (maxTemp - temp) / (maxTemp - minTemp)

    function toggle(): void {
        if (active) {
            Quickshell.execDetached(["pkill", "-x", "hyprsunset"]);
            active = false;
        } else {
            Quickshell.execDetached(["hyprsunset", "-t", String(temp)]);
            active = true;
        }
    }

    function setTemp(kelvin: real): void {
        temp = Math.round(Math.max(minTemp, Math.min(maxTemp, kelvin)));
        if (active && !throttle.running)
            throttle.start();
    }

    function setFraction(f: real): void {
        setTemp(maxTemp - f * (maxTemp - minTemp));
    }

    // Pick up a hyprsunset that is already running (shell reload, started elsewhere)
    Process {
        command: ["pgrep", "-x", "hyprsunset"]
        running: true
        onExited: code => root.active = code === 0
    }

    // At most one update per interval while dragging or scrolling; always applies the latest value
    Timer {
        id: throttle

        interval: 50
        onTriggered: Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", String(root.temp)])
    }
}
