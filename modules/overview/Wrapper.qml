//  Overview — native Caelestia module.
//  Fills the screen (like a Task View), so unlike the launcher/cheat sheet
//  it doesn't need a slide-offset dance to compute its own size - it just
//  fills its parent and fades/scales in from the centre.

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property var panels

    readonly property bool shouldBeActive: screenState.overview

    anchors.fill: parent

    scale: shouldBeActive ? 1 : 0.97
    opacity: shouldBeActive ? 1 : 0
    visible: opacity > 0.001

    Behavior on scale {
        Anim {}
    }

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    Loader {
        anchors.fill: parent

        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            screen: root.screen
            screenState: root.screenState
            active: root.shouldBeActive
        }
    }
}
