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
        if (root.menuOpen) {
            root.closeContextMenu();
        } else if (root.pendingAction !== "") {
            root.cancelPending();
        } else {
            root.screenState.overview = false;
        }
    }

    // ---- which workspaces to show ----
    // Workspaces come in groups of `shownCount` (5). Group 1 and the group
    // you are on are always shown; any other group only while it has a window.
    readonly property int shownCount: Math.max(1, Config.bar.workspaces.shown)
    readonly property var monitor: Hypr.monitorFor(root.screen)
    readonly property int activeWsId: GlobalConfig.bar.workspaces.perMonitorWorkspaces ? (monitor?.activeWorkspace?.id ?? 1) : Hypr.activeWsId
    readonly property int activeGroup: Math.floor((activeWsId - 1) / shownCount)

    property var workspaceIds: Array.from({
        length: shownCount
    }, (_, i) => i + 1)
    property var cellsData: [] // [{ wsId, count }]
    property string wsSig: ""
    property string cellSig: ""

    // One row per window. Kept as a ListModel (synced by address) so each
    // thumbnail survives refreshes - that is what lets it animate between
    // workspaces and keeps ScreencopyView's capture alive.
    ListModel {
        id: thumbModel
    }

    function clientFor(address: string): var {
        return Hypr.toplevels.values.find(t => t.address === address) ?? null;
    }

    function syncThumbs(list: var): void {
        const want = {};
        for (const t of list)
            want[t.address] = t;
        for (let i = thumbModel.count - 1; i >= 0; i--) {
            if (!want[thumbModel.get(i).address])
                thumbModel.remove(i);
        }
        const have = {};
        for (let i = 0; i < thumbModel.count; i++) {
            const row = thumbModel.get(i);
            have[row.address] = true;
            const t = want[row.address];
            if (row.wsId !== t.wsId || row.floating !== t.floating || Math.abs(row.relX - t.relX) > 0.5 || Math.abs(row.relY - t.relY) > 0.5 || Math.abs(row.w - t.w) > 0.5 || Math.abs(row.h - t.h) > 0.5)
                thumbModel.set(i, {
                    wsId: t.wsId,
                    relX: t.relX,
                    relY: t.relY,
                    w: t.w,
                    h: t.h,
                    floating: t.floating
                });
        }
        for (const t of list) {
            if (!have[t.address])
                thumbModel.append(t);
        }
    }

    // Reads Hyprland state and updates the workspace list, the cells and the
    // thumbnails - each only when something actually changed.
    function refreshData(): void {
        const sc = root.shownCount;
        const groups = {};
        groups[0] = true;
        groups[root.activeGroup] = true;
        const counts = {};
        const list = [];

        for (const t of Hypr.toplevels.values) {
            const wsId = t.workspace?.id ?? -1;
            const o = t.lastIpcObject;
            if (wsId < 1 || !o?.at || !o?.size)
                continue; // special workspaces / not mapped yet
            const rx = o.at[0] - root.screen.x;
            const ry = o.at[1] - root.screen.y;
            const x0 = Math.max(0, rx);
            const y0 = Math.max(0, ry);
            const x1 = Math.min(root.screen.width, rx + o.size[0]);
            const y1 = Math.min(root.screen.height, ry + o.size[1]);
            if (x1 - x0 < 1 || y1 - y0 < 1)
                continue;
            groups[Math.floor((wsId - 1) / sc)] = true;
            counts[wsId] = (counts[wsId] ?? 0) + 1;
            list.push({
                address: t.address,
                wsId: wsId,
                relX: x0,
                relY: y0,
                w: x1 - x0,
                h: y1 - y0,
                floating: o.floating === true
            });
        }

        const ids = [];
        for (const g of Object.keys(groups).map(Number).sort((a, b) => a - b)) {
            for (let i = 1; i <= sc; i++)
                ids.push(g * sc + i);
        }
        const idSig = ids.join(",");
        if (idSig !== root.wsSig) {
            root.wsSig = idSig;
            root.workspaceIds = ids;
        }

        const cells = ids.map(id => ({
                    wsId: id,
                    count: counts[id] ?? 0
                }));
        const cSig = cells.map(c => `${c.wsId}:${c.count}`).join(",");
        if (cSig !== root.cellSig) {
            root.cellSig = cSig;
            root.cellsData = cells;
        }

        root.syncThumbs(list);
    }

    // After we change something, Hyprland needs a moment to report it back.
    function refreshSoon(): void {
        soonTimer.restart();
        lateTimer.restart();
    }

    Timer {
        id: soonTimer
        interval: 150
        onTriggered: root.refreshData()
    }

    Timer {
        id: lateTimer
        interval: 600
        onTriggered: root.refreshData()
    }

    Timer {
        interval: 500
        running: root.active
        repeat: true
        onTriggered: root.refreshData()
    }

    Component.onCompleted: {
        forceActiveFocus();
        root.refreshData();
        Qt.callLater(() => root.scrollToActive(false));
    }

    // ---- deterministic grid geometry - computed directly, never read back
    //      from a child's implicit size ----
    // Cells are sized so two rows (groups) fit on screen; more than that scrolls.
    readonly property int columns: Math.min(5, shownCount)
    readonly property int rows: Math.max(1, Math.ceil(workspaceIds.length / columns))
    readonly property int fitRows: Math.min(rows, 2)
    readonly property real hMargin: 72
    readonly property real vMargin: 96
    readonly property real cellSpacing: Tokens.spacing.large

    readonly property real availW: Math.max(1, root.width - hMargin * 2 - cellSpacing * (columns - 1))
    readonly property real availH: Math.max(1, root.height - vMargin * 2 - cellSpacing * (fitRows - 1))
    readonly property real aspect: root.screen.height / root.screen.width
    readonly property real cellHByWidth: (availW / columns) * aspect
    readonly property real cellHByHeight: availH / fitRows
    readonly property real cellH: Math.min(cellHByWidth, cellHByHeight)
    readonly property real cellW: cellH / aspect
    readonly property real scaleF: cellW / root.screen.width

    readonly property real gridW: cellW * columns + cellSpacing * (columns - 1)
    readonly property real gridH: cellH * rows + cellSpacing * (rows - 1) // all rows
    readonly property real viewH: cellH * fitRows + cellSpacing * (fitRows - 1) // what is visible
    readonly property real gridX: (root.width - gridW) / 2
    readonly property real viewY: (root.height - viewH) / 2

    // Top-left of the cell grid in this item's coordinates (follows scrolling)
    function canvasOrigin(): point {
        return Qt.point(flick.x - flick.contentX + flick.pad, flick.y - flick.contentY + flick.pad);
    }

    // Position of a cell inside the scrolling canvas
    function cellLocal(wsId: int): point {
        const idx = root.workspaceIds.indexOf(wsId);
        if (idx < 0)
            return Qt.point(0, 0);
        return Qt.point((idx % root.columns) * (root.cellW + root.cellSpacing), Math.floor(idx / root.columns) * (root.cellH + root.cellSpacing));
    }

    function cellOrigin(wsId: int): point {
        const o = root.canvasOrigin();
        const l = root.cellLocal(wsId);
        return Qt.point(o.x + l.x, o.y + l.y);
    }

    function wsIdAtPoint(pt: point): var {
        if (pt.x < flick.x || pt.x > flick.x + flick.width || pt.y < flick.y || pt.y > flick.y + flick.height)
            return null;
        const o = root.canvasOrigin();
        const lx = pt.x - o.x;
        const ly = pt.y - o.y;
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

    // Bring the row of the active workspace into view
    function scrollToActive(animated: bool): void {
        const idx = root.workspaceIds.indexOf(root.activeWsId);
        const row = idx < 0 ? 0 : Math.floor(idx / root.columns);
        const rowTop = flick.pad + row * (root.cellH + root.cellSpacing);
        const maxY = Math.max(0, flick.contentHeight - flick.height);
        const target = Math.max(0, Math.min(maxY, rowTop - (flick.height - root.cellH) / 2));
        if (animated) {
            scrollAnim.to = target;
            scrollAnim.restart();
        } else {
            flick.contentY = target;
        }
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
        root.refreshSoon();
    }

    function killClient(client: var): void {
        const pid = client?.lastIpcObject?.pid;
        if (pid > 0)
            Quickshell.execDetached(["kill", "-9", `${pid}`]);
        root.refreshSoon();
    }

    function toggleFloating(client: var): void {
        if (!client)
            return;
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.float({ action = "toggle", window = "address:0x${client.address}" })` : `togglefloating address:0x${client.address}`);
        root.refreshSoon();
    }

    function togglePinned(client: var): void {
        if (!client)
            return;
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.pin({ action = "toggle", window = "address:0x${client.address}" })` : `pin address:0x${client.address}`);
        root.refreshSoon();
    }

    // mode: "fullscreen" | "maximized". Goes to the window first, then toggles.
    function fullscreenClient(client: var, mode: string): void {
        if (!client)
            return;
        root.focusClient(client);
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.fullscreen({ mode = "${mode}", action = "toggle", window = "address:0x${client.address}" })` : `fullscreen ${mode === "maximized" ? 1 : 0}`);
    }

    function moveClientToWorkspace(client: var, wsId: int): void {
        if (!client)
            return;
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.move({ window = "address:0x${client.address}", workspace = "${wsId}", follow = false })` : `movetoworkspacesilent ${wsId},address:0x${client.address}`);
        root.refreshSoon();
    }

    function repositionFloating(client: var, x: real, y: real): void {
        if (!client)
            return;
        const ix = Math.round(x), iy = Math.round(y);
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.move({ window = "address:0x${client.address}", x = ${ix}, y = ${iy} })` : `movewindowpixel exact ${ix} ${iy},address:0x${client.address}`);
        root.refreshSoon();
    }

    // The tiled window under the pointer, if the dragged window is tiled too
    // and the pointer is still over its own workspace. "" when there is none.
    function swapTargetAt(pt: point): string {
        if (!root.dragThumb || root.dragThumb.floating === true)
            return "";
        if (root.wsIdAtPoint(pt) !== root.dragHomeWsId)
            return "";
        const origin = root.cellOrigin(root.dragHomeWsId);
        for (let i = 0; i < thumbModel.count; i++) {
            const r = thumbModel.get(i);
            if (r.wsId !== root.dragHomeWsId || r.address === root.dragThumb.address || r.floating)
                continue;
            const x = origin.x + r.relX * root.scaleF;
            const y = origin.y + r.relY * root.scaleF;
            if (pt.x >= x && pt.x <= x + r.w * root.scaleF && pt.y >= y && pt.y <= y + r.h * root.scaleF)
                return r.address;
        }
        return "";
    }

    // Hyprland's swap acts on the focused window, so focus `a`, swap it with
    // `b`, then put focus back where it was.
    function swapClients(a: var, b: var): void {
        if (!a || !b || a.address === b.address)
            return;
        const prev = Hypr.toplevels.values.find(t => t.lastIpcObject?.focusHistoryID === 0);
        if (Hypr.usingLua) {
            Hypr.dispatch(`hl.dsp.focus({ window = "address:0x${a.address}" })`);
            Hypr.dispatch(`hl.dsp.window.swap({ target = "address:0x${b.address}" })`);
            if (prev && prev.address !== a.address)
                Hypr.dispatch(`hl.dsp.focus({ window = "address:0x${prev.address}" })`);
            else if (!prev)
                Hypr.dispatch(`hl.dsp.focus({ workspace = "${root.activeWsId}" })`);
        } else {
            Hypr.dispatch(`focuswindow address:0x${a.address}`);
            Hypr.dispatch(`swapwindow address:0x${b.address}`);
            if (prev && prev.address !== a.address)
                Hypr.dispatch(`focuswindow address:0x${prev.address}`);
            else if (!prev)
                Hypr.dispatch(`workspace ${root.activeWsId}`);
        }
        root.refreshSoon();
    }

    function dumpWorkspace(fromWs: int, toWs: int): void {
        const addrs = Hypr.toplevels.values.filter(t => t.workspace?.id === fromWs).map(t => t.address);
        for (const addr of addrs)
            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.move({ window = "address:0x${addr}", workspace = "${toWs}", follow = false })` : `movetoworkspacesilent ${toWs},address:0x${addr}`);
        root.refreshSoon();
    }

    function swapWorkspaces(wsA: int, wsB: int): void {
        const inA = Hypr.toplevels.values.filter(t => t.workspace?.id === wsA).map(t => t.address);
        const inB = Hypr.toplevels.values.filter(t => t.workspace?.id === wsB).map(t => t.address);
        for (const addr of inA)
            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.move({ window = "address:0x${addr}", workspace = "${wsB}", follow = false })` : `movetoworkspacesilent ${wsB},address:0x${addr}`);
        for (const addr of inB)
            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.move({ window = "address:0x${addr}", workspace = "${wsA}", follow = false })` : `movetoworkspacesilent ${wsA},address:0x${addr}`);
        root.refreshSoon();
    }

    function onCellClicked(wsId: int): void {
        if (root.pendingAction === "dump") {
            root.dumpWorkspace(root.pendingWs, wsId);
            root.cancelPending();
            return;
        }
        if (root.pendingAction === "swap") {
            root.swapWorkspaces(root.pendingWs, wsId);
            root.cancelPending();
            return;
        }
        if (root.pendingAction === "move") {
            root.moveClientToWorkspace(root.pendingClient, wsId);
            root.cancelPending();
            return;
        }
        root.switchToWorkspace(wsId);
    }

    // ---- drag state machine ----
    property string dragAddress: ""
    property var dragThumb: null // { address, client, relX, relY, w, h }
    property int dragHomeWsId: -1
    property point dragPressOffset: Qt.point(0, 0)
    property point dragStartPt: Qt.point(0, 0)
    property point dragPos: Qt.point(0, 0)
    property bool dragMoved: false
    property point dragPointer: Qt.point(0, 0)
    property string swapTarget: "" // address of the tiled window the dragged one would swap with
    readonly property var dragHoverWsId: dragThumb && dragMoved ? root.wsIdAtPoint(Qt.point(dragPos.x + dragThumb.w * scaleF / 2, dragPos.y + dragThumb.h * scaleF / 2)) : null

    function beginDrag(data: var, homeWsId: int, pt: point): void {
        const origin = root.cellOrigin(homeWsId);
        const itemX = origin.x + data.relX * root.scaleF;
        const itemY = origin.y + data.relY * root.scaleF;
        root.dragThumb = data;
        root.dragAddress = data.address;
        root.dragHomeWsId = homeWsId;
        root.dragPressOffset = Qt.point(pt.x - itemX, pt.y - itemY);
        root.dragPos = Qt.point(itemX, itemY);
        root.dragStartPt = pt;
        root.dragPointer = pt;
        root.swapTarget = "";
        root.dragMoved = false;
    }

    function updateDrag(pt: point): void {
        if (!root.dragThumb)
            return;
        if (!root.dragMoved && Math.hypot(pt.x - root.dragStartPt.x, pt.y - root.dragStartPt.y) > 6)
            root.dragMoved = true;
        root.dragPos = Qt.point(pt.x - root.dragPressOffset.x, pt.y - root.dragPressOffset.y);
        root.dragPointer = pt;
        root.swapTarget = root.dragMoved ? root.swapTargetAt(pt) : "";
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
            const floating = client?.lastIpcObject?.floating === true;
            if (root.swapTarget !== "") {
                // Dropped on another tiled window of the same workspace: swap places.
                root.swapClients(client, root.clientFor(root.swapTarget));
            } else if (targetWs !== null) {
                if (targetWs !== root.dragHomeWsId)
                    root.moveClientToWorkspace(client, targetWs);
                // A floating window lands exactly where it was dropped. Tiled
                // windows are placed by Hyprland's layout, so they can't be.
                if (floating) {
                    const origin = root.cellOrigin(targetWs);
                    const localX = (root.dragPos.x - origin.x) / root.scaleF;
                    const localY = (root.dragPos.y - origin.y) / root.scaleF;
                    root.repositionFloating(client, root.screen.x + localX, root.screen.y + localY);
                }
            }
        }
        root.dragThumb = null;
        root.dragAddress = "";
        root.dragHomeWsId = -1;
        root.dragMoved = false;
        root.swapTarget = "";
    }

    // ---- window menu (right-click a window) ----
    property bool menuOpen: false
    property var menuClient: null
    property int menuWsId: -1
    property point menuPos: Qt.point(0, 0)
    property var menuActions: []
    property string pendingAction: "" // "" | "dump" | "swap" | "move"
    property int pendingWs: -1
    property var pendingClient: null

    function cancelPending(): void {
        root.pendingAction = "";
        root.pendingWs = -1;
        root.pendingClient = null;
    }

    function openContextMenu(pt: point, client: var, wsId: int): void {
        if (!client)
            return;
        const o = client.lastIpcObject ?? {};
        const fs = o.fullscreen ?? 0;
        root.menuActions = [
            {
                id: "fullscreen",
                icon: "fullscreen",
                text: fs === 2 ? qsTr("Exit fullscreen") : qsTr("Fullscreen")
            },
            {
                id: "maximize",
                icon: "fit_screen",
                text: fs === 1 ? qsTr("Restore size") : qsTr("Maximize")
            },
            {
                id: "float",
                icon: "picture_in_picture_alt",
                text: o.floating ? qsTr("Tile") : qsTr("Float")
            },
            ...(o.floating ? [
                    {
                        id: "pin",
                        icon: "push_pin",
                        text: o.pinned ? qsTr("Unpin") : qsTr("Pin")
                    }
                ] : []),
            {
                id: "move",
                icon: "drive_file_move",
                text: qsTr("Move to workspace…")
            },
            {
                separator: true
            },
            {
                id: "dump",
                icon: "move_up",
                text: qsTr("Move workspace's windows to…")
            },
            {
                id: "swap",
                icon: "swap_horiz",
                text: qsTr("Swap workspace with…")
            },
            {
                separator: true
            },
            {
                id: "close",
                icon: "close",
                text: qsTr("Close")
            },
            {
                id: "kill",
                icon: "dangerous",
                text: qsTr("Force kill"),
                danger: true
            }
        ];
        root.menuClient = client;
        root.menuWsId = wsId;
        root.menuPos = pt;
        root.menuOpen = true;
    }

    function closeContextMenu(): void {
        root.menuOpen = false;
    }

    function runMenuAction(id: string): void {
        const client = root.menuClient;
        const wsId = root.menuWsId;
        root.closeContextMenu();
        switch (id) {
        case "fullscreen":
            root.fullscreenClient(client, "fullscreen");
            break;
        case "maximize":
            root.fullscreenClient(client, "maximized");
            break;
        case "float":
            root.toggleFloating(client);
            break;
        case "pin":
            root.togglePinned(client);
            break;
        case "move":
            root.pendingAction = "move";
            root.pendingClient = client;
            root.pendingWs = wsId;
            break;
        case "dump":
            root.pendingAction = "dump";
            root.pendingWs = wsId;
            break;
        case "swap":
            root.pendingAction = "swap";
            root.pendingWs = wsId;
            break;
        case "close":
            root.closeClient(client);
            break;
        case "kill":
            root.killClient(client);
            break;
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
                text: root.pendingAction === "swap" ? "swap_horiz" : root.pendingAction === "move" ? "drive_file_move" : "move_up"
                color: Colours.palette.m3onTertiaryContainer
            }

            StyledText {
                text: root.pendingAction === "dump" ? qsTr("Click a workspace to move workspace %1's windows there").arg(root.pendingWs) : root.pendingAction === "move" ? qsTr("Click a workspace to move this window there") : qsTr("Click a workspace to swap with workspace %1").arg(root.pendingWs)
                color: Colours.palette.m3onTertiaryContainer
            }

            IconButton {
                icon: "close"
                type: IconButton.Text
                implicitWidth: 28
                implicitHeight: 28
                onClicked: root.cancelPending()
            }
        }
    }

    // Scrollable area: cells, window previews and workspace badges share one
    // canvas, so they scroll together.
    Flickable {
        id: flick

        readonly property real pad: 8

        x: root.gridX - pad
        y: root.viewY - pad
        width: root.gridW + pad * 2
        height: root.viewH + pad * 2
        contentWidth: canvas.width + pad * 2
        contentHeight: canvas.height + pad * 2
        clip: true
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height + 1

        NumberAnimation {
            id: scrollAnim

            target: flick
            property: "contentY"
            duration: 260
            easing.type: Easing.OutCubic
        }

        Item {
            id: canvas

            x: flick.pad
            y: flick.pad
            width: root.gridW
            height: root.gridH

            // 1) workspace backgrounds
            Grid {
                columns: root.columns
                spacing: root.cellSpacing

                Repeater {
                    model: root.cellsData

                    delegate: WorkspaceCell {
                        required property var modelData

                        wsId: modelData.wsId
                        isActive: modelData.wsId === root.activeWsId
                        windowCount: modelData.count
                        width: root.cellW
                        height: root.cellH
                        overviewRoot: root
                    }
                }
            }

            // 2) window previews (animate between cells)
            Repeater {
                model: thumbModel

                delegate: WindowThumb {
                    client: root.clientFor(address)
                    overviewRoot: root
                    // While a tiled window is dragged over this one, this one slides
                    // into the dragged window's slot - exactly what a swap would do.
                    readonly property bool takesDraggedSlot: root.swapTarget !== "" && address === root.swapTarget

                    x: root.cellLocal(wsId).x + (takesDraggedSlot ? root.dragThumb.relX : relX) * root.scaleF
                    y: root.cellLocal(wsId).y + (takesDraggedSlot ? root.dragThumb.relY : relY) * root.scaleF
                    width: Math.max(1, (takesDraggedSlot ? root.dragThumb.w : w) * root.scaleF)
                    height: Math.max(1, (takesDraggedSlot ? root.dragThumb.h : h) * root.scaleF)
                }
            }

            // 3) workspace number badges, above the previews
            Repeater {
                model: root.cellsData

                delegate: StyledRect {
                    id: badge

                    required property var modelData

                    visible: modelData.count > 0
                    x: root.cellLocal(modelData.wsId).x + 6
                    y: root.cellLocal(modelData.wsId).y + 6
                    radius: Tokens.rounding.small
                    color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.85)
                    implicitWidth: badgeLabel.implicitWidth + Tokens.padding.small * 2
                    implicitHeight: badgeLabel.implicitHeight + Tokens.padding.extraSmall * 2

                    StyledText {
                        id: badgeLabel

                        anchors.centerIn: parent
                        text: badge.modelData.wsId
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                    }
                }
            }
        }
    }

    // Scroll position indicator
    Rectangle {
        visible: flick.interactive
        x: flick.x + flick.width + 8
        y: flick.y + flick.pad + (flick.contentY / flick.contentHeight) * (flick.height - flick.pad * 2)
        width: 4
        height: Math.max(24, (flick.height / flick.contentHeight) * (flick.height - flick.pad * 2))
        radius: 2
        color: Colours.palette.m3outline
        opacity: 0.6
    }

    // Window being dragged
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

    // Window menu, with a click-away layer behind it
    Item {
        visible: root.menuOpen
        anchors.fill: parent
        z: 100

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: root.closeContextMenu()
        }

        WindowMenu {
            actions: root.menuActions
            x: Math.max(8, Math.min(root.menuPos.x, root.width - width - 8))
            y: Math.max(8, Math.min(root.menuPos.y, root.height - height - 8))
            onTriggered: actionId => root.runMenuAction(actionId)
        }
    }
}
