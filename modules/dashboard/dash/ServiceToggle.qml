import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components.controls
import qs.services

// Icon button whose on/off state is polled from a shell snippet.
IconButton {
    id: root

    // Shell snippet that prints ON or OFF.
    required property string statusScript
    // Script run with bash when the button is clicked.
    required property string toggleScript
    property int pollInterval: 2000

    property bool isActive: false

    inactiveColour: isActive ? Colours.palette.m3primary : (activeFocus ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer)
    inactiveOnColour: isActive ? Colours.palette.m3onPrimary : (activeFocus ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface)
    radius: pressed ? Tokens.rounding.medium : activeFocus ? Tokens.rounding.extraLarge : Tokens.rounding.largeIncreased
    font: Tokens.font.icon.builders.large.scale(1.3).build()

    onClicked: {
        // Optimistic flip; the next poll corrects it if the script failed.
        isActive = !isActive;
        Quickshell.execDetached(["bash", toggleScript]);
    }

    Component.onCompleted: poller.running = true

    Process {
        id: poller

        command: ["bash", "-c", root.statusScript]

        stdout: SplitParser {
            onRead: data => {
                const status = data.trim();
                if (status === "ON")
                    root.isActive = true;
                else if (status === "OFF")
                    root.isActive = false;
            }
        }
    }

    Timer {
        interval: root.pollInterval
        running: root.visible
        repeat: true
        onTriggered: {
            poller.running = false;
            poller.running = true;
        }
    }
}
