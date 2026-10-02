pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property bool active

    focus: true
    Keys.onEscapePressed: {
        if (root.pendingAction !== "") {
            root.pendingAction = "";
            root.pendingWs = -1;
        } else {
            root.screenState.overview = false;
        }
    }

    // ---- which workspaces to show (mirrors bar/components/workspaces/Workspaces.qml) ----
    readonly property int shownCount: Math.max(1, Config.bar.workspaces.shown)
    readonly property var monitor: Hypr.monitorFor(root.screen)
    readonly property int activeWsId: GlobalConfig.bar.workspaces.perMonitorWorkspaces ? (monitor?.activeWorkspace?.id ?? 1) : Hypr.activeWsId
    readonly property int groupOffset: Math.floor((activeWsId - 1) / shownCount) * shownCount
    readonly property var workspaceIds: Array.from({ length: shownCount }, (_, i) => groupOffset + i + 1)

    // Deliberately NOT a reactive binding to Hypr.toplevels.values: that
    // property changes on almost any Hyprland event (focus, title, etc,
    // not just things relevant here), and since Repeater can't diff a
    // plain JS array it would destroy and recreate every delegate on each
    // one - which never gives ScreencopyView's async capture negotiation
    // enough time to complete before being torn down again. Snapshot
    // instead, refreshed deliberately.
    property var cellsData: []

    function refreshCellsData(): void {
        root.cellsData = root.workspaceIds.map(wsId => ({
                    wsId,
                    toplevels: Hypr.toplevels.values.filter(t => t.workspace?.id === wsId).map(t => ({
                            client: t,
                            relX: t.lastIpcObject.at[0] - root.screen.x,
                            relY: t.lastIpcObject.at[1] - root.screen.y,
                            w: t.lastIpcObject.size[0],
                            h: t.lastIpcObject.size[1]
                        }))
                }));
    }

    Component.onCompleted: {
        forceActiveFocus();
        root.refreshCellsData();
    }

    Timer {
        interval: 1000
        running: root.active
        repeat: true
        onTriggered: root.refreshCellsData()
    }

    // ---- deterministic grid geometry - computed directly, never read back
    //      from a child's implicit size (lesson learned the hard way on the
    //      cheat sheet: that chain doesn't reliably propagate through
    //      several nested layout levels) ----
    readonly property int columns: Math.min(5, workspaceIds.length)
    readonly property int rows: Math.ceil(workspaceIds.length / columns)
    readonly property real hMargin: 72
    readonly property real vMargin: 96
    readonly property real cellSpacing: Tokens.spacing.large

    readonly property real availW: Math.max(1, root.width - hMargin * 2 - cellSpacing * (columns - 1))
    readonly property real availH: Math.max(1, root.height - vMargin * 2 - cellSpacing * (rows - 1))
    readonly property real aspect: root.screen.height / root.screen.width
    readonly property real cellHByWidth: (availW / columns) * aspect
    readonly property real cellHByHeight: availH / rows
    readonly property real cellH: Math.min(cellHByWidth, cellHByHeight)
    readonly property real cellW: cellH / aspect
    readonly property real scaleF: cellW / root.screen.width

    readonly property real gridW: cellW * columns + cellSpacing * (columns - 1)
    readonly property real gridH: cellH * rows + cellSpacing * (rows - 1)
    readonly property real gridX: (root.width - gridW) / 2
    readonly property real gridY: (root.height - gridH) / 2

    function cellOrigin(wsId: int): point {
        const idx = root.workspaceIds.indexOf(wsId);
        if (idx < 0)
            return Qt.point(0, 0);
        const col = idx % root.columns;
        const row = Math.floor(idx / root.columns);
        return Qt.point(root.gridX + col * (root.cellW + root.cellSpacing), root.gridY + row * (root.cellH + root.cellSpacing));
    }

    function wsIdAtPoint(pt: point): var {
        const lx = pt.x - root.gridX;
        const ly = pt.y - root.gridY;
        if (lx < 0 || ly < 0)
            return null;
        const col = Math.floor(lx / (root.cellW + root.cellSpacing));
        const row = Math.floor(ly / (root.cellH + root.cellSpacing));
        if (col < 0 || col >= root.columns || row < 0 || row >= root.rows)
            return null;
        if (lx - col * (root.cellW + root.cellSpacing) > root.cellW || ly - row * (root.cellH + root.cellSpacing) > root.cellH)
            return null; // in the gap between cells
        const idx = row * root.columns + col;
        return idx >= 0 && idx < root.workspaceIds.length ? root.workspaceIds[idx] : null;
    }

    // ---- Hyprland dispatch helpers (both dispatch syntaxes, matching
    //      modules/windowinfo/Buttons.qml's established convention) ----
    function switchToWorkspace(wsId: int): void {
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "${wsId}" })` : `workspace ${wsId}`);
        root.screenState.overview = false;
    }

    function focusClient(client: var): void {
        if (!client)
            return;
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "address:0x${client.address}" })` : `focuswindow address:0x${client.address}`);
        root.screenState.overview = false;
    }

    function closeClient(client: var): void {
        if (!client)
            return;
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.close({ window = "address:0x${client.address}" })` : `closewindow address:0x${client.address}`);
    }

    function moveClientToWorkspace(client: var, wsId: int): void {
        if (!client)
            return;
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.move({ window = "address:0x${client.address}", workspace = "${wsId}", follow = false })` : `movetoworkspacesilent ${wsId},address:0x${client.address}`);
    }

    function repositionFloating(client: var, x: real, y: real): void {
        if (!client)
            return;
        const ix = Math.round(x), iy = Math.round(y);
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.move({ window = "address:0x${client.address}", x = ${ix}, y = ${iy} })` : `movewindowpixel exact ${ix} ${iy},address:0x${client.address}`);
    }

    function dumpWorkspace(fromWs: int, toWs: int): void {
        const addrs = Hypr.toplevels.values.filter(t => t.workspace?.id === fromWs).map(t => t.address);
        for (const addr of addrs)
            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.move({ window = "address:0x${addr}", workspace = "${toWs}", follow = false })` : `movetoworkspacesilent ${toWs},address:0x${addr}`);
    }

    function swapWorkspaces(wsA: int, wsB: int): void {
        const inA = Hypr.toplevels.values.filter(t => t.workspace?.id === wsA).map(t => t.address);
        const inB = Hypr.toplevels.values.filter(t => t.workspace?.id === wsB).map(t => t.address);
        for (const addr of inA)
            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.move({ window = "address:0x${addr}", workspace = "${wsB}", follow = false })` : `movetoworkspacesilent ${wsB},address:0x${addr}`);
        for (const addr of inB)
            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.move({ window = "address:0x${addr}", workspace = "${wsA}", follow = false })` : `movetoworkspacesilent ${wsA},address:0x${addr}`);
    }

    function onCellClicked(wsId: int): void {
        if (root.pendingAction === "dump") {
            root.dumpWorkspace(root.pendingWs, wsId);
            root.pendingAction = "";
            root.pendingWs = -1;
            return;
        }
        if (root.pendingAction === "swap") {
            root.swapWorkspaces(root.pendingWs, wsId);
            root.pendingAction = "";
            root.pendingWs = -1;
            return;
        }
        root.switchToWorkspace(wsId);
    }

    // ---- drag state machine ----
    property var dragThumb: null // { client, relX, relY, w, h }
    property int dragHomeWsId: -1
    property point dragPressOffset: Qt.point(0, 0)
    property point dragStartPt: Qt.point(0, 0)
    property point dragPos: Qt.point(0, 0)
    property bool dragMoved: false
    readonly property var dragHoverWsId: dragThumb && dragMoved ? root.wsIdAtPoint(Qt.point(dragPos.x + dragThumb.w * scaleF / 2, dragPos.y + dragThumb.h * scaleF / 2)) : null

    function beginDrag(data: var, homeWsId: int, pt: point): void {
        const origin = root.cellOrigin(homeWsId);
        const itemX = origin.x + data.relX * root.scaleF;
        const itemY = origin.y + data.relY * root.scaleF;
        root.dragThumb = data;
        root.dragHomeWsId = homeWsId;
        root.dragPressOffset = Qt.point(pt.x - itemX, pt.y - itemY);
        root.dragPos = Qt.point(itemX, itemY);
        root.dragStartPt = pt;
        root.dragMoved = false;
    }

    function updateDrag(pt: point): void {
        if (!root.dragThumb)
            return;
        if (!root.dragMoved && Math.hypot(pt.x - root.dragStartPt.x, pt.y - root.dragStartPt.y) > 6)
            root.dragMoved = true;
        root.dragPos = Qt.point(pt.x - root.dragPressOffset.x, pt.y - root.dragPressOffset.y);
    }

    function endDrag(pt: point): void {
        if (!root.dragThumb)
            return;
        const client = root.dragThumb.client;
        if (!root.dragMoved) {
            root.focusClient(client);
        } else {
            const centre = Qt.point(root.dragPos.x + root.dragThumb.w * root.scaleF / 2, root.dragPos.y + root.dragThumb.h * root.scaleF / 2);
            const targetWs = root.wsIdAtPoint(centre);
            if (targetWs !== null && targetWs !== root.dragHomeWsId) {
                root.moveClientToWorkspace(client, targetWs);
            } else if (targetWs === root.dragHomeWsId && client.lastIpcObject.floating) {
                const origin = root.cellOrigin(root.dragHomeWsId);
                const localX = (root.dragPos.x - origin.x) / root.scaleF;
                const localY = (root.dragPos.y - origin.y) / root.scaleF;
                root.repositionFloating(client, root.screen.x + localX, root.screen.y + localY);
            }
        }
        root.dragThumb = null;
        root.dragHomeWsId = -1;
        root.dragMoved = false;
    }

    // ---- context menu (right-click a window) ----
    property var ctxClient: null
    property int ctxWsId: -1
    property string pendingAction: "" // "" | "dump" | "swap"
    property int pendingWs: -1

    function openContextMenu(item: Item, client: var, wsId: int): void {
        root.ctxClient = client;
        root.ctxWsId = wsId;
        ctxMenu.attachTo = item;
        ctxMenu.expanded = true;
    }

    MenuItem {
        id: closeMenuItem
        text: qsTr("Close")
        icon: "close"
    }

    MenuItem {
        id: dumpMenuItem
        text: qsTr("Move workspace's windows to…")
        icon: "move_up"
    }

    MenuItem {
        id: swapMenuItem
        text: qsTr("Swap workspace with…")
        icon: "swap_horiz"
    }

    Menu {
        id: ctxMenu
        attachTo: root
        attachSideX: Menu.Left
        attachSideY: Menu.Top
        thisSideX: Menu.Left
        thisSideY: Menu.Top
        items: [closeMenuItem, dumpMenuItem, swapMenuItem]

        onItemSelected: item => {
            if (item === closeMenuItem) {
                root.closeClient(root.ctxClient);
            } else if (item === dumpMenuItem) {
                root.pendingAction = "dump";
                root.pendingWs = root.ctxWsId;
            } else if (item === swapMenuItem) {
                root.pendingAction = "swap";
                root.pendingWs = root.ctxWsId;
            }
        }
    }

    // ---- visuals ----
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Colours.palette.m3scrim, 0.72)

        MouseArea {
            anchors.fill: parent
            onClicked: root.screenState.overview = false
        }
    }

    StyledRect {
        visible: root.pendingAction !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Tokens.padding.large
        radius: Tokens.rounding.large
        color: Colours.palette.m3tertiaryContainer
        implicitWidth: hintRow.implicitWidth + Tokens.padding.large * 2
        implicitHeight: hintRow.implicitHeight + Tokens.padding.medium * 2
        z: 20

        RowLayout {
            id: hintRow
            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: root.pendingAction === "dump" ? "move_up" : "swap_horiz"
                color: Colours.palette.m3onTertiaryContainer
            }

            StyledText {
                text: root.pendingAction === "dump" ? qsTr("Click a workspace to move workspace %1's windows there").arg(root.pendingWs) : qsTr("Click a workspace to swap with workspace %1").arg(root.pendingWs)
                color: Colours.palette.m3onTertiaryContainer
            }

            IconButton {
                icon: "close"
                type: IconButton.Text
                implicitWidth: 28
                implicitHeight: 28
                onClicked: {
                    root.pendingAction = "";
                    root.pendingWs = -1;
                }
            }
        }
    }

    Item {
        x: root.gridX
        y: root.gridY
        width: root.gridW
        height: root.gridH

        Grid {
            columns: root.columns
            spacing: root.cellSpacing

            Repeater {
                model: root.cellsData
                delegate: WorkspaceCell {
                    id: cell

                    required property var modelData

                    wsId: modelData.wsId
                    isActive: modelData.wsId === root.activeWsId
                    toplevels: modelData.toplevels
                    scaleF: root.scaleF
                    width: root.cellW
                    height: root.cellH
                    overviewRoot: root
                }
            }
        }
    }

    Loader {
        active: root.dragThumb !== null && root.dragMoved
        z: 1000
        x: root.dragPos.x
        y: root.dragPos.y
        width: root.dragThumb ? root.dragThumb.w * root.scaleF : 0
        height: root.dragThumb ? root.dragThumb.h * root.scaleF : 0

        sourceComponent: WindowThumbVisual {
            client: root.dragThumb?.client ?? null
            active: root.active
            opacity: 0.9
        }
    }
}
