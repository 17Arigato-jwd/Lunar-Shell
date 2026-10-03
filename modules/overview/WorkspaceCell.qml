pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

StyledClippingRect {
    id: root

    required property int wsId
    required property bool isActive
    required property var toplevels // array of { client, relX, relY, w, h }
    required property real scaleF
    required property Item overviewRoot
    readonly property bool isDropTarget: overviewRoot.dragMoved && overviewRoot.dragHoverWsId === wsId && overviewRoot.dragHomeWsId !== wsId

    color: Colours.palette.m3surfaceContainerLow
    radius: Tokens.rounding.large
    border.width: isActive || isDropTarget ? 2 : 1
    border.color: isDropTarget ? Colours.palette.m3tertiary : isActive ? Colours.palette.m3primary : Colours.palette.m3outlineVariant

    Behavior on border.color {
        CAnim {}
    }

    StyledText {
        visible: root.toplevels.length === 0
        anchors.centerIn: parent
        text: root.wsId
        color: Colours.palette.m3outlineVariant
        font: Tokens.font.body.builders.large.size(48).weight(Font.Light).build()
    }

    StyledRect {
        visible: root.toplevels.length > 0
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 6
        radius: Tokens.rounding.small
        color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.85)
        implicitWidth: wsLabel.implicitWidth + Tokens.padding.small * 2
        implicitHeight: wsLabel.implicitHeight + Tokens.padding.extraSmall * 2
        z: 10

        StyledText {
            id: wsLabel
            anchors.centerIn: parent
            text: root.wsId
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.overviewRoot.onCellClicked(root.wsId)
    }

    Repeater {
        model: root.toplevels
        delegate: WindowThumb {
            required property var modelData
            entry: modelData
            scaleF: root.scaleF
            homeWsId: root.wsId
            overviewRoot: root.overviewRoot
            x: modelData.relX * root.scaleF
            y: modelData.relY * root.scaleF
            width: Math.max(1, modelData.w * root.scaleF)
            height: Math.max(1, modelData.h * root.scaleF)
        }
    }
}
