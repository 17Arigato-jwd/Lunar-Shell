pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Blobs
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.effects
import qs.services

Item {
    id: root

    required property ScreenState screenState
    required property real maxHeight
    required property real targetWidth
    required property bool active

    readonly property int padding: Tokens.padding.extraLarge
    readonly property int rounding: Tokens.rounding.extraLarge

    readonly property var sections: [
        { title: "Apps & shell", icon: "apps", binds: [
            { keys: ["Super", "Q"], desc: "Terminal" },
            { keys: ["Super", "E"], desc: "File manager" },
            { keys: ["Copilot"], desc: "Launcher" },
            { keys: ["Super", "N"], desc: "Notification sidebar" },
            { keys: ["Power"], desc: "Session menu" }
        ] },
        { title: "Window", icon: "desktop_windows", binds: [
            { keys: ["Super", "C"], desc: "Close window" },
            { keys: ["Super", "F"], desc: "Fullscreen" },
            { keys: ["Super", "V"], desc: "Float toggle" },
            { keys: ["Super", "P"], desc: "Pseudotile" },
            { keys: ["Super", "M"], desc: "Exit Hyprland" },
            { keys: ["Alt", "Tab"], desc: "Cycle windows" }
        ] },
        { title: "Move & resize", icon: "open_with", binds: [
            { keys: ["Super", "Shift", "←→↑↓"], desc: "Move window" },
            { keys: ["Super", "Drag"], desc: "Move with mouse" },
            { keys: ["Super", "R-Drag"], desc: "Resize with mouse" }
        ] },
        { title: "Workspaces", icon: "dashboard", binds: [
            { keys: ["Super", "1–0"], desc: "Switch workspace" },
            { keys: ["Super", "Shift", "1–5"], desc: "Send window to ws" }
        ] },
        { title: "Screenshot", icon: "screenshot_monitor", binds: [
            { keys: ["Print"], desc: "Whole screen → clipboard" },
            { keys: ["Super", "Shift", "S"], desc: "Region → clipboard" }
        ] },
        { title: "Tools", icon: "build", binds: [
            { keys: ["Super", "Shift", "A"], desc: "This cheat sheet" },
            { keys: ["Super", "Shift", "V"], desc: "Clipboard history" }
        ] }
    ]

    implicitWidth: targetWidth
    width: targetWidth

    // Deterministic sizing: computed directly from maxHeight and fixed
    // constants below, NOT bubbled up through inner.implicitHeight (which,
    // through a Flickable wrapping a deeply-nested GridLayout, turned out
    // not to reliably reflect the capped gridArea height - the card kept
    // rendering at its full uncapped natural size regardless of maxHeight).
    readonly property real headerH: 40
    readonly property real dividerH: 1
    readonly property real gapV: Tokens.spacing.large
    readonly property real gridAreaH: Math.max(160, Math.min(grid.implicitHeight, root.maxHeight - root.padding * 2 - headerH - dividerH - gapV * 2))

    implicitHeight: root.padding * 2 + headerH + dividerH + gapV * 2 + gridAreaH
    height: implicitHeight

    focus: true
    Keys.onEscapePressed: root.screenState.cheatsheet = false

    Component.onCompleted: forceActiveFocus()

    // Purely for clipping the drifting background shapes to the panel's
    // rounded footprint - no fill/border of its own, the shared blob
    // background (see ContentWindow's PanelBg) already provides that.
    StyledClippingRect {
        anchors.fill: parent
        color: "transparent"
        radius: root.rounding

        BackgroundShapes {
            anchors.fill: parent
            drift: root.active
            count: 10
            minSize: 30
            maxSize: 100
        }
    }

    ColumnLayout {
        id: inner

        anchors.fill: parent
        anchors.margins: root.padding
        spacing: Tokens.spacing.large

        RowLayout {
            id: header

            Layout.fillWidth: true
            Layout.preferredHeight: root.headerH
            spacing: Tokens.spacing.small

            BlobGroup {
                id: badgeGroup
                color: Colours.palette.m3primaryContainer
                smoothing: Tokens.rounding.medium
                cornerFill: false

                Behavior on color {
                    CAnim {}
                }
            }

            BlobRect {
                id: badge
                implicitWidth: 36
                implicitHeight: 36
                group: badgeGroup
                radius: Tokens.rounding.medium

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "keyboard"
                    color: Colours.palette.m3onPrimaryContainer
                    fontStyle: Tokens.font.icon.medium
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Cheat sheet")
                font: Tokens.font.title.medium
            }

            StyledText {
                text: qsTr("Esc to close")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
            }
        }

        Rectangle {
            id: divider

            Layout.fillWidth: true
            height: 1
            color: Colours.palette.m3outlineVariant
        }

        VerticalFadeFlickable {
            id: gridScroll

            Layout.fillWidth: true
            Layout.preferredHeight: root.gridAreaH

            contentWidth: width
            contentHeight: grid.implicitHeight
            clip: true

            GridLayout {
                id: grid

                width: gridScroll.width
                columns: 3
                rowSpacing: Tokens.spacing.extraLarge
                columnSpacing: Tokens.spacing.extraLarge

                Repeater {
                    model: root.sections
                    delegate: ColumnLayout {
                        id: sectionCol

                        required property var modelData

                        Layout.alignment: Qt.AlignTop
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        RowLayout {
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                text: sectionCol.modelData.icon
                                color: Colours.palette.m3primary
                                fontStyle: Tokens.font.icon.medium
                            }

                            StyledText {
                                text: sectionCol.modelData.title
                                color: Colours.palette.m3primary
                                font: Tokens.font.label.large
                            }
                        }

                        Repeater {
                            model: sectionCol.modelData.binds
                            delegate: RowLayout {
                                id: bindRow

                                required property var modelData

                                Layout.fillWidth: true
                                spacing: Tokens.spacing.medium

                                RowLayout {
                                    spacing: Tokens.spacing.extraSmall

                                    Repeater {
                                        model: bindRow.modelData.keys
                                        delegate: StyledRect {
                                            id: keycap

                                            required property string modelData

                                            radius: Tokens.rounding.small
                                            color: Colours.palette.m3surfaceContainerHighest
                                            border.width: 1
                                            border.color: Colours.palette.m3outlineVariant
                                            implicitWidth: kc.implicitWidth + Tokens.padding.medium
                                            implicitHeight: kc.implicitHeight + Tokens.padding.small

                                            StyledText {
                                                id: kc
                                                anchors.centerIn: parent
                                                text: keycap.modelData
                                                font: Tokens.font.label.medium
                                            }
                                        }
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: bindRow.modelData.desc
                                    color: Colours.palette.m3onSurfaceVariant
                                    font: Tokens.font.body.small
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
