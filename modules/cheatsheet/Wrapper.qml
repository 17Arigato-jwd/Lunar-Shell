//  Cheat sheet — native Caelestia module.
//  Embedded in the shared drawers window (like the launcher) so it can pop
//  up from the bottom of the screen using the exact same motion, and so it
//  naturally stacks correctly against the session/power menu.

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property var panels

    readonly property bool shouldBeActive: screenState.cheatsheet

    // Breathing room reserved at the top only (e.g. so it doesn't crowd an
    // open dashboard) - the panel itself sits flush against the bottom
    // edge when open, same as the launcher.
    readonly property real restMargin: Tokens.padding.large

    // Cap it well short of the full screen height (whichever's tighter: a
    // fixed cap, or leaving room for the dashboard up top) - anything that
    // doesn't fit scrolls inside Content.qml instead of pushing off-screen.
    readonly property real maxHeight: {
        let max = Math.min(screen.height * 0.62, 640);
        if (screenState.dashboard)
            max = Math.min(max, screen.height - Config.border.thickness * 2 - restMargin - panels.dashboard.nonAnimHeight);
        return Math.max(max, 220);
    }

    readonly property real targetWidth: Math.min(screen.width - 90, 1120)

    property real offsetScale: shouldBeActive ? 0 : 1

    onShouldBeActiveChanged: {
        if (shouldBeActive)
            implicitHeight = Qt.binding(() => content.implicitHeight);
        else
            implicitHeight = implicitHeight; // Break binding during close anim
    }

    visible: offsetScale < 1
    anchors.bottomMargin: (-implicitHeight - 5) * offsetScale
    implicitHeight: content.implicitHeight
    implicitWidth: content.implicitWidth || root.targetWidth
    height: implicitHeight
    width: implicitWidth
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {}
    }

    Loader {
        id: content

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            screenState: root.screenState
            maxHeight: root.maxHeight
            targetWidth: root.targetWidth
            active: root.shouldBeActive
        }
    }
}
