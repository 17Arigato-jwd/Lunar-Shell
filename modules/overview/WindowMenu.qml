import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// Right-click menu for a window preview. Sized from its content, so long
// labels are never cut off.
StyledRect {
    id: root

    // [{ id, icon, text, danger? }] or { separator: true }
    required property var actions

    signal triggered(string actionId)

    implicitWidth: col.implicitWidth + Tokens.padding.small * 2
    implicitHeight: col.implicitHeight + Tokens.padding.small * 2

    radius: Tokens.rounding.large
    color: Colours.palette.m3surfaceContainerHigh
    border.width: 1
    border.color: Colours.palette.m3outlineVariant

    // Swallow clicks so they don't fall through to the window underneath
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    ColumnLayout {
        id: col

        anchors.fill: parent
        anchors.margins: Tokens.padding.small
        spacing: 2

        Repeater {
            model: root.actions

            delegate: Item {
                id: row

                required property var modelData
                readonly property bool isSeparator: modelData.separator === true
                readonly property color fg: modelData.danger ? Colours.palette.m3error : Colours.palette.m3onSurface

                Layout.fillWidth: true
                implicitWidth: isSeparator ? 1 : content.implicitWidth + Tokens.padding.large * 2
                implicitHeight: isSeparator ? 9 : content.implicitHeight + Tokens.padding.medium * 2

                Rectangle {
                    visible: row.isSeparator
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 1
                    color: Colours.palette.m3outlineVariant
                }

                StyledRect {
                    visible: !row.isSeparator
                    anchors.fill: parent
                    radius: Tokens.rounding.small
                    color: mouse.containsMouse ? Colours.palette.m3surfaceContainerHighest : "transparent"
                }

                RowLayout {
                    id: content

                    visible: !row.isSeparator
                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.padding.large
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: row.modelData.icon ?? ""
                        color: row.fg
                    }

                    StyledText {
                        text: row.modelData.text ?? ""
                        color: row.fg
                    }
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    enabled: !row.isSeparator
                    hoverEnabled: true
                    onClicked: root.triggered(row.modelData.id)
                }
            }
        }
    }
}
