pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Background of one workspace. The window previews live in a separate layer
// in Content.qml so they can animate between cells.
StyledClippingRect {
    id: root

    required property int wsId
    required property bool isActive
    required property int windowCount
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
        visible: root.windowCount === 0
        anchors.centerIn: parent
        text: root.wsId
        color: Colours.palette.m3outlineVariant
        font: Tokens.font.body.builders.large.size(48).weight(Font.Light).build()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.overviewRoot.onCellClicked(root.wsId)
    }
}
