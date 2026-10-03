pragma ComponentBehavior: Bound

import QtQuick

// One window preview. The delegate in Content.qml sets x/y/width/height from
// the model; the Behaviors below animate it whenever the window moves (inside
// a workspace or across workspaces, since one thumbnail layer spans all cells).
// Left-drag moves the window (state machine in Content.qml), a plain click
// focuses it, right-click opens the window menu.
Item {
    id: root

    // Model roles (ListModel in Content.qml)
    required property string address
    required property int wsId
    required property real relX
    required property real relY
    required property real w
    required property real h
    required property bool floating

    required property var client // HyprlandToplevel
    required property Item overviewRoot

    readonly property bool beingDragged: overviewRoot.dragAddress === address && overviewRoot.dragMoved

    // While swapping, the dragged window's old slot is taken over by the other window
    opacity: beingDragged && overviewRoot.swapTarget !== "" ? 0 : 1

    Behavior on opacity {
        NumberAnimation {
            duration: 120
        }
    }

    Behavior on x {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutCubic
        }
    }
    Behavior on y {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutCubic
        }
    }
    Behavior on width {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutCubic
        }
    }
    Behavior on height {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutCubic
        }
    }

    WindowThumbVisual {
        anchors.fill: parent

        client: root.client
        active: root.overviewRoot.active
        dim: root.beingDragged
        highlighted: (area.containsMouse && !root.overviewRoot.dragMoved && !root.overviewRoot.menuOpen) || root.overviewRoot.swapTarget === root.address
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        preventStealing: true

        function toOverview(mouse: var): point {
            return mapToItem(root.overviewRoot, mouse.x, mouse.y);
        }

        onPressed: mouse => {
            if (mouse.button === Qt.LeftButton)
                root.overviewRoot.beginDrag({
                    address: root.address,
                    client: root.client,
                    relX: root.relX,
                    relY: root.relY,
                    w: root.w,
                    h: root.h,
                    floating: root.floating
                }, root.wsId, toOverview(mouse));
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
                root.overviewRoot.openContextMenu(toOverview(mouse), root.client, root.wsId);
        }
    }
}
