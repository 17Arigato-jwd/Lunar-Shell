pragma ComponentBehavior: Bound

import QtQuick

// One window preview inside a workspace cell. Position and size are set by
// the delegate in WorkspaceCell.qml. Left-drag moves the window to another
// workspace (state machine lives in Content.qml), a plain click focuses it,
// right-click opens the context menu.
Item {
    id: root

    // Not called "data": that is Item's default property, and redeclaring it
    // would stop child items from being attached.
    required property var entry // { client, relX, relY, w, h }
    required property real scaleF
    required property int homeWsId
    required property Item overviewRoot

    readonly property bool beingDragged: overviewRoot.dragThumb === entry && overviewRoot.dragMoved

    WindowThumbVisual {
        anchors.fill: parent

        client: root.entry.client
        active: root.overviewRoot.active
        dim: root.beingDragged
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        preventStealing: true

        function toOverview(mouse: var): point {
            return mapToItem(root.overviewRoot, mouse.x, mouse.y);
        }

        onPressed: mouse => {
            if (mouse.button === Qt.LeftButton)
                root.overviewRoot.beginDrag(root.entry, root.homeWsId, toOverview(mouse));
        }
        onPositionChanged: mouse => {
            if (pressedButtons & Qt.LeftButton)
                root.overviewRoot.updateDrag(toOverview(mouse));
        }
        onReleased: mouse => {
            if (mouse.button === Qt.LeftButton)
                root.overviewRoot.endDrag(toOverview(mouse));
        }
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.overviewRoot.openContextMenu(root, root.entry.client, root.homeWsId);
        }
    }
}
