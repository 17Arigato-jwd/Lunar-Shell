// SPDX-License-Identifier: 0BSD
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import Caelestia.Config
import qs.components
import qs.services

Button {
    id: control
    property color ink: Colours.palette.m3onSurface
    property color paper: Colours.palette.m3surfaceContainerLow
    property color accent: Colours.palette.m3primary
    property color line: Colours.palette.m3outlineVariant
    property color accentInk: Colours.palette.m3onPrimary
    property color markerInk: accent
    property bool selected: false
    property bool leftAligned: false
    property bool framed: true
    property bool marker: false
    property bool wrapLabel: false
    property int inset: 10

    implicitWidth: Math.max(34, label.implicitWidth + 2 * inset)
    implicitHeight: Math.max(34, label.implicitHeight + 16)
    padding: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    font.family: Tokens.font.body.medium.family
    font.pixelSize: Tokens.font.body.medium.pointSize
    Accessible.name: text

    background: StyledRect {
        color: control.selected ? Qt.alpha(control.accent, 0.18)
            : control.down ? Qt.alpha(control.accent, 0.14)
            : control.hovered ? Qt.alpha(control.ink, 0.06) : control.paper
        radius: Tokens.rounding.medium
        border.width: control.visualFocus ? 2 : control.framed ? 1 : 0
        border.color: control.visualFocus ? control.accent : control.line
        Rectangle {
            visible: control.marker && control.selected
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 5
            height: 5
            radius: Tokens.rounding.full
            color: control.markerInk
        }
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    contentItem: StyledText {
        id: label
        leftPadding: control.inset
        rightPadding: control.inset
        text: control.text
        font: control.font
        color: control.selected ? control.accent : control.ink
        horizontalAlignment: control.leftAligned ? Text.AlignLeft : Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: control.wrapLabel ? Text.Wrap : Text.NoWrap
        maximumLineCount: control.wrapLabel ? 2 : 1
        elide: control.wrapLabel ? Text.ElideNone : Text.ElideRight
    }
}
