// SPDX-License-Identifier: 0BSD
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root
    required property string label
    required property real currentValue
    required property real minimumValue
    required property real maximumValue
    property string suffix: ""
    property int precision: 0
    signal valueEdited(real value)
    spacing: Tokens.spacing.extraSmall
    implicitWidth: 360

    RowLayout {
        Layout.fillWidth: true
        StyledText {
            text: root.label
            color: Colours.palette.m3onSurface
            font: Tokens.font.body.medium
            Layout.fillWidth: true
        }
        StyledText {
            text: root.precision > 0 ? Number(root.currentValue).toFixed(root.precision) + root.suffix : Math.round(root.currentValue) + root.suffix
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
        }
    }

    StyledSlider {
        Layout.fillWidth: true
        from: 0
        to: 1
        value: root.maximumValue === root.minimumValue ? 0 : (root.currentValue - root.minimumValue) / (root.maximumValue - root.minimumValue)
        interactionOnMove: false
        onInteraction: fraction => root.valueEdited(root.minimumValue + fraction * (root.maximumValue - root.minimumValue))
    }
}
