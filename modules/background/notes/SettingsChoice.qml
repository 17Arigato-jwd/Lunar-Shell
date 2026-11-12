// SPDX-License-Identifier: 0BSD
pragma ComponentBehavior: Bound
import QtQuick
import Caelestia.Config
import qs.components
import qs.services

Column {
    id: root
    required property string label
    required property var choices
    required property string value
    signal chosen(string choice)
    property bool compact: false
    spacing: Tokens.spacing.small
    width: 360

    StyledText {
        id: labelText
        text: root.label
        color: Colours.palette.m3onSurface
        font: Tokens.font.body.medium
    }

    Flow {
        id: choicesFlow
        width: root.width
        spacing: Tokens.spacing.small
        Repeater {
            model: root.choices
            delegate: StyledRect {
                id: chip
                required property string modelData
                implicitWidth: chipLabel.implicitWidth + Tokens.padding.large * 2
                implicitHeight: 34
                radius: Tokens.rounding.full
                color: root.value === modelData ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerLow
                border.width: 1
                border.color: root.value === modelData ? Colours.palette.m3secondary : Colours.palette.m3outlineVariant

                StyledText {
                    id: chipLabel
                    anchors.centerIn: parent
                    text: chip.modelData
                    color: root.value === chip.modelData ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.large
                }
                StateLayer {
                    radius: parent.radius
                    color: Colours.palette.m3onSurface
                    onClicked: root.chosen(chip.modelData)
                }
            }
        }
    }
}
