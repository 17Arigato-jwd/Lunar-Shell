//  Clipboard history — native Caelestia module.
//  Drop this folder into ~/.config/quickshell/caelestia/modules/clipboard/
//  and add `Clipboard {}` to the root shell.qml (see chat for the diff).
//  Toggle via the "clipboard" CustomShortcut or `qs -c caelestia ipc call clipboard toggle`.
//  Backend: cliphist (install it) + wl-clipboard.
//
//  Pinned entries are written to ~/.local/state/caelestia/clipboard-pins.txt
//  (one preview line per entry). ~/.config/hypr/scripts/clipboard-flush.sh
//  reads that same file and wipes every *other* cliphist entry - wire it up
//  to run before shutdown/reboot (see modules/session/Content.qml) to keep
//  pinned clips around while flushing the rest.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Caelestia.Blobs
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.components.misc
import qs.services
import qs.utils

Scope {
    id: root

    property var entries: []
    property var pinned: []
    property bool pinsLoaded: false
    property string query: ""
    property int sel: 0

    // id -> local file path of a decoded thumbnail; id -> true while decoding
    property var imageCache: ({})
    property var pendingThumbs: ({})

    readonly property var filtered: {
        const q = query.toLowerCase();
        const list = entries.filter(e => e.preview.toLowerCase().includes(q));
        // Pinned entries float to the top; otherwise preserve cliphist order
        return list.slice().sort((a, b) => {
            const pa = root.pinned.includes(a.preview) ? 0 : 1;
            const pb = root.pinned.includes(b.preview) ? 0 : 1;
            return pa - pb;
        });
    }

    // The screen state currently focused - used purely to stay out of the
    // way of the session/power menu (see below). Cross-surface layer
    // ordering against another quickshell window isn't reliably
    // controllable in Wayland, so instead of fighting it, this module
    // simply won't open over an active session menu, and closes itself if
    // the session menu is opened while it's already showing.
    readonly property ScreenState activeScreenState: ShellState.forActive()

    function isPinned(preview: string): bool {
        return pinned.includes(preview);
    }

    function togglePin(preview: string): void {
        pinned = pinned.includes(preview) ? pinned.filter(p => p !== preview) : [...pinned, preview];
        savePins();
    }

    function savePins(): void {
        if (!pinsLoaded)
            return;
        pinStorage.setText(pinned.length ? `${pinned.join("\n")}\n` : "");
    }

    function shQuote(s: string): string {
        return `'${s.replace(/'/g, "'\\''")}'`;
    }

    // jpeg's own format name isn't its usual extension; everything else
    // (png, gif, bmp, tiff, webp) matches cliphist's format string as-is
    function extFor(format: string): string {
        return format === "jpeg" ? "jpg" : format;
    }

    function thumbPath(entry: var): string {
        return `${Paths.clipboardimagecache}/${entry.id}.${extFor(entry.format)}`;
    }

    // Decode an image entry's bytes to a small cache file once, then reuse
    // it. `proc` is the delegate's own Process instance so decodes for
    // different rows never collide.
    function decodeThumb(entry: var, proc: var): void {
        if (!entry.isImage || root.imageCache[entry.id] || root.pendingThumbs[entry.id])
            return;
        root.pendingThumbs = Object.assign({}, root.pendingThumbs, { [entry.id]: true });
        const path = thumbPath(entry);
        proc.entryId = entry.id;
        proc.destPath = path;
        proc.command = ["sh", "-c", `mkdir -p ${shQuote(Paths.clipboardimagecache)} && printf '%s' "$1" | cliphist decode > ${shQuote(path)}`, "_", entry.line];
        proc.running = true;
    }

    function refresh(): void {
        listProc.running = true;
    }

    function close(): void {
        if (loader.item)
            loader.item.requestClose();
        else
            loader.activeAsync = false;
    }

    function openSafely(): void {
        if (activeScreenState?.session)
            return;
        refresh();
        loader.activeAsync = true;
    }

    function toggleSafely(): void {
        if (loader.active)
            close();
        else
            openSafely();
    }

    function activate(i: int): void {
        if (i < 0 || i >= filtered.length)
            return;
        copyProc.command = ["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "_", filtered[i].line];
        copyProc.running = true;
        close();
    }

    function deleteEntry(i: int): void {
        if (i < 0 || i >= filtered.length)
            return;
        const entry = filtered[i];
        const rmThumb = entry.isImage ? ` && rm -f ${shQuote(thumbPath(entry))}` : "";
        deleteProc.command = ["sh", "-c", `printf '%s' "$1" | cliphist delete${rmThumb}`, "_", entry.line];
        deleteProc.running = true;
        entries = entries.filter(e => e.line !== entry.line);
        if (sel >= filtered.length)
            sel = Math.max(0, filtered.length - 1);
    }

    function clearAll(): void {
        const toRemove = entries.filter(e => !pinned.includes(e.preview));
        if (toRemove.length === 0)
            return;
        const script = toRemove.map(e => {
            const del = `printf '%s' ${shQuote(e.line)} | cliphist delete`;
            return e.isImage ? `${del}; rm -f ${shQuote(thumbPath(e))}` : del;
        }).join("\n");
        clearProc.command = ["sh", "-c", script];
        clearProc.running = true;
        entries = entries.filter(e => pinned.includes(e.preview));
        sel = 0;
    }

    // Defer to the session/power menu: if it opens while we're showing, get
    // out of the way, and don't pop up over it either.
    Connections {
        target: root.activeScreenState
        function onSessionChanged(): void {
            if (root.activeScreenState?.session)
                root.close();
        }
    }

    FileView {
        id: pinStorage

        printErrors: false
        path: `${Paths.state}/clipboard-pins.txt`
        onLoaded: {
            root.pinned = text().split("\n").map(s => s.trim()).filter(s => s.length > 0);
            root.pinsLoaded = true;
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.pinsLoaded = true;
                Qt.callLater(() => setText(""));
            }
        }
    }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            id: coll
            onStreamFinished: {
                const imgRe = /^\[\[ binary data ([\d.]+ ?\w*) (\w+) (\d+)x(\d+) \]\]$/;
                const out = [];
                for (const raw of coll.text.split("\n")) {
                    if (!raw.trim())
                        continue;
                    const tab = raw.indexOf("\t");
                    const id = tab >= 0 ? parseInt(raw.slice(0, tab), 10) : -1;
                    const preview = tab >= 0 ? raw.slice(tab + 1) : raw;
                    const m = imgRe.exec(preview);
                    if (m) {
                        out.push({ line: raw, preview, id, isImage: true, size: m[1], format: m[2], width: parseInt(m[3], 10), height: parseInt(m[4], 10) });
                    } else {
                        out.push({ line: raw, preview, id, isImage: false });
                    }
                }
                root.entries = out;
            }
        }
    }

    Process {
        id: copyProc
    }

    Process {
        id: deleteProc
    }

    Process {
        id: clearProc
    }

    LazyLoader {
        id: loader

        StyledWindow {
            id: win
            name: "clipboard"

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            property bool closing: false
            property bool shown: false

            function requestClose(): void {
                if (closing)
                    return;
                closing = true;
                shown = false;
                closeTimer.restart();
            }

            Component.onCompleted: shown = true

            Timer {
                id: closeTimer
                interval: 550
                onTriggered: loader.activeAsync = false
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Colours.palette.m3shadow, 0.45)
                opacity: win.shown ? 1 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: win.requestClose()
                }
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: win.requestClose()
            }

            StyledClippingRect {
                id: card
                anchors.centerIn: parent
                width: 640
                radius: Tokens.rounding.large
                color: Colours.palette.m3surfaceContainer
                border.width: 1
                border.color: Colours.palette.m3outlineVariant
                implicitHeight: content.implicitHeight + Tokens.padding.large * 2

                // Wobbly pop in/out: scale + a little rotational wiggle,
                // both settling with a springy overshoot.
                scale: win.shown ? 1 : 0.82
                rotation: win.shown ? 0 : -8
                opacity: win.shown ? 1 : 0

                Behavior on scale {
                    SpringAnimation {
                        spring: 3.2
                        damping: 0.28
                        mass: 0.9
                    }
                }

                Behavior on rotation {
                    SpringAnimation {
                        spring: 2.6
                        damping: 0.22
                        mass: 1
                    }
                }

                Behavior on opacity {
                    Anim {
                        type: Anim.FastEffects
                    }
                }

                Elevation {
                    anchors.fill: parent
                    radius: parent.radius
                    z: -1
                    level: 3
                }

                BackgroundShapes {
                    anchors.fill: parent
                    drift: false
                    count: 8
                    minSize: 24
                    maxSize: 90
                }

                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    id: content
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.medium

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        BlobGroup {
                            id: badgeGroup
                            color: Colours.palette.m3primaryContainer
                            smoothing: Tokens.rounding.medium
                            cornerFill: false

                            Behavior on color {
                                CAnim {}
                            }
                        }

                        BlobRect {
                            id: badge
                            implicitWidth: 32
                            implicitHeight: 32
                            group: badgeGroup
                            radius: Tokens.rounding.medium

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "content_paste"
                                color: Colours.palette.m3onPrimaryContainer
                                fontStyle: Tokens.font.icon.medium
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Clipboard")
                            font: Tokens.font.title.small
                        }

                        IconTextButton {
                            visible: root.entries.some(e => !root.pinned.includes(e.preview))
                            type: IconTextButton.Text
                            icon: "delete_sweep"
                            text: qsTr("Clear all")
                            font: Tokens.font.label.medium
                            onClicked: root.clearAll()
                        }
                    }

                    SearchBar {
                        id: search
                        Layout.fillWidth: true
                        placeholderText: qsTr("Search…")

                        Component.onCompleted: forceActiveFocus()
                        onTextChanged: {
                            root.query = text;
                            root.sel = 0;
                        }
                        Keys.onDownPressed: root.sel = Math.min(root.sel + 1, root.filtered.length - 1)
                        Keys.onUpPressed: root.sel = Math.max(root.sel - 1, 0)
                        Keys.onReturnPressed: root.activate(root.sel)
                        Keys.onEnterPressed: root.activate(root.sel)
                        Keys.onEscapePressed: win.requestClose()
                    }

                    StyledText {
                        visible: root.filtered.length === 0
                        Layout.fillWidth: true
                        Layout.topMargin: Tokens.spacing.small
                        Layout.bottomMargin: Tokens.spacing.small
                        text: root.entries.length === 0 ? qsTr("No history yet — is cliphist installed and running?") : qsTr("No matches")
                        color: Colours.palette.m3onSurfaceVariant
                        horizontalAlignment: Text.AlignHCenter
                    }

                    VerticalFadeListView {
                        id: list
                        visible: root.filtered.length > 0
                        Layout.fillWidth: true
                        implicitHeight: Math.min(root.filtered.reduce((h, e) => h + (e.isImage ? 64 : 38) + Tokens.spacing.extraSmall, 0), 380)
                        clip: true
                        spacing: Tokens.spacing.extraSmall
                        model: root.filtered
                        currentIndex: root.sel
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: StyledRect {
                            id: delegateRoot

                            required property int index
                            required property var modelData

                            readonly property string thumbSrc: modelData.isImage ? (root.imageCache[modelData.id] ?? "") : ""

                            width: ListView.view.width
                            height: modelData.isImage ? 64 : 38
                            radius: Tokens.rounding.small
                            color: index === root.sel ? Colours.palette.m3surfaceContainerHighest : "transparent"

                            onModelDataChanged: {
                                if (modelData.isImage)
                                    root.decodeThumb(modelData, thumbProc);
                            }
                            Component.onCompleted: {
                                if (modelData.isImage)
                                    root.decodeThumb(modelData, thumbProc);
                            }

                            Process {
                                id: thumbProc
                                property int entryId: -1
                                property string destPath: ""
                                onExited: code => { // qmllint disable signal-handler-parameters
                                    const pending = Object.assign({}, root.pendingThumbs);
                                    delete pending[entryId];
                                    root.pendingThumbs = pending;
                                    if (code === 0)
                                        root.imageCache = Object.assign({}, root.imageCache, { [entryId]: destPath });
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: root.sel = delegateRoot.index
                                onClicked: root.activate(delegateRoot.index)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.padding.medium
                                anchors.rightMargin: Tokens.padding.small
                                spacing: Tokens.spacing.small

                                StyledClippingRect {
                                    visible: delegateRoot.modelData.isImage
                                    Layout.preferredWidth: 48
                                    Layout.preferredHeight: 48
                                    radius: Tokens.rounding.small
                                    color: Colours.palette.m3surfaceContainerHighest
                                    border.width: 1
                                    border.color: Colours.palette.m3outlineVariant

                                    Image {
                                        anchors.fill: parent
                                        source: delegateRoot.thumbSrc ? `file://${delegateRoot.thumbSrc}` : ""
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize.width: 96
                                        sourceSize.height: 96
                                        asynchronous: true
                                        cache: false
                                        visible: status === Image.Ready
                                    }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        visible: !delegateRoot.thumbSrc
                                        text: "image"
                                        color: Colours.palette.m3onSurfaceVariant
                                        fontStyle: Tokens.font.icon.medium
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: delegateRoot.modelData.isImage ? qsTr("Image · %1×%2 · %3").arg(delegateRoot.modelData.width).arg(delegateRoot.modelData.height).arg(delegateRoot.modelData.size) : delegateRoot.modelData.preview
                                    elide: Text.ElideRight
                                }

                                MaterialIcon {
                                    visible: delegateRoot.index === root.sel
                                    text: "content_copy"
                                    color: Colours.palette.m3onSurfaceVariant
                                    fontStyle: Tokens.font.icon.small
                                }

                                IconButton {
                                    implicitWidth: 26
                                    implicitHeight: 26
                                    type: IconButton.Text
                                    isToggle: true
                                    checked: root.isPinned(delegateRoot.modelData.preview)
                                    icon: "push_pin"

                                    onClicked: root.togglePin(delegateRoot.modelData.preview)
                                }

                                IconButton {
                                    visible: delegateRoot.index === root.sel
                                    implicitWidth: 26
                                    implicitHeight: 26
                                    type: IconButton.Text
                                    icon: "close"

                                    onClicked: root.deleteEntry(delegateRoot.index)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        function toggle(): void {
            root.toggleSafely();
        }

        function open(): void {
            root.openSafely();
        }

        function close(): void {
            root.close();
        }

        target: "clipboard"
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "clipboard"
        description: "Toggle clipboard history"
        onPressed: root.toggleSafely()
    }
}
