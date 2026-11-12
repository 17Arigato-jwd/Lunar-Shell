// SPDX-License-Identifier: 0BSD
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components.containers
import qs.services
import "./notes" as Notes

// This compact surface uses the same Caelestia layer-window wrapper as the
// shell's own modules. It lives on the desktop layer; application windows stay
// above it, while OnDemand keyboard focus lets the editor accept text input.
Variants {
    model: Screens.screens.filter(s => GlobalConfig.forScreen(s.name).background.enabled)

    StyledWindow {
        id: win
        required property ShellScreen modelData
        screen: modelData
        name: "desktop-notes"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Notes.Preferences { id: prefs }

        anchors.left: prefs.position === "Top Left" || prefs.position === "Bottom Left"
        anchors.right: prefs.position === "Top Right" || prefs.position === "Bottom Right"
        anchors.top: prefs.position === "Top Left" || prefs.position === "Top Right"
        anchors.bottom: prefs.position === "Bottom Left" || prefs.position === "Bottom Right"
        margins {
            left: Tokens.padding.extraLargeIncreased
            right: Tokens.padding.extraLargeIncreased
            top: Tokens.padding.extraLargeIncreased
            bottom: Tokens.padding.extraLargeIncreased
        }
        implicitWidth: prefs.widgetWidth
        implicitHeight: notes.implicitHeight

        Notes.Widget {
            id: notes
            objectName: "caelestiaDesktopNotes"
            anchors.fill: parent
            preferences: prefs
        }
    }
}
