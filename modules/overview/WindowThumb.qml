pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    required property var data // { client, relX, relY, w, h }
    required property real scaleF
    required property int homeWsId
    required property Item overviewRoot

    // TEMPORARY DIAGNOSTIC - x/y/width/height deliberately NOT set here.
    // WorkspaceCell.qml's delegate instantiation now sets them externally
    // instead (matching the pattern already proven to work for
    // WorkspaceCell itself, which gets width/height assigned externally
    // by Content.qml rather than computing them from its own required
    // properties).

    Rectangle {
        anchors.fill: parent
        color: "lime"
        opacity: 0.5
        border.width: 2
        border.color: "red"
    }
}
