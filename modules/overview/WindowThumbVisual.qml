pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Caelestia.Config
import qs.services

ClippingRectangle {
    id: root

    required property var client // HyprlandToplevel
    property bool active: true // gate live capture (perf: only while overview is open)
    property bool dim: false

    color: Colours.palette.m3surfaceContainerHigh
    radius: Tokens.rounding.small
    border.width: 1
    border.color: Colours.palette.m3outlineVariant
    opacity: dim ? 0.35 : 1

    IconImage {
        anchors.centerIn: parent
        implicitSize: Math.min(root.width, root.height) * 0.4
        source: root.client ? Quickshell.iconPath(root.client.lastIpcObject.class, "image-missing") : ""
    }

    ScreencopyView {
        anchors.fill: parent

        captureSource: root.client?.wayland ?? null
        live: root.active

        constraintSize.width: root.width
        constraintSize.height: root.height
    }
}
