// SPDX-License-Identifier: 0BSD
import QtQml
import Quickshell
import Quickshell.Io

// User preferences are stored outside the dotfiles repo. Defaults track the
// Caelestia design tokens and are only written after the user changes a setting.
QtObject {
    id: prefs

    readonly property string dataFile: Quickshell.dataPath("notes-settings.json")
    property bool ready: false
    property bool canPersist: false
    property bool restoring: false
    property string status: "Loading settings"

    property string position: "Bottom Right"
    property string layoutMode: "Split"
    property int widgetWidth: 560
    property int indexWidth: 150
    property int editorHeight: 155
    property int titleSize: 20
    property int bodySize: 16
    property string density: "Comfortable"
    property int listRows: 4
    property string paletteName: "Caelestia"
    property real surfaceOpacity: 0.96
    property bool showNumbers: true
    property string newNotePosition: "Bottom"
    property string counterMode: "Off"
    property bool showStatus: true

    property var persistence: FileView {
        path: Quickshell.dataPath("notes-settings.json")
        atomicWrites: true
        blockWrites: false
        onLoaded: prefs.restore(text())
        onLoadFailed: error => {
            // Missing preferences is normal on first launch. Other file errors
            // are logged; defaults remain usable and are not written until the
            // user changes a setting.
            prefs.ready = true;
            prefs.canPersist = true;
            prefs.status = "Using defaults";
            console.info("[caelestia-notes] Preferences unavailable; using defaults:", error);
        }
        onSaved: prefs.status = "Settings saved"
        onSaveFailed: error => {
            prefs.status = "Settings save failed";
            console.warn("[caelestia-notes] Could not save notes settings:", error);
        }
    }

    property Timer saveTimer: Timer {
        interval: 180
        repeat: false
        onTriggered: prefs.saveNow()
    }

    function serialise(): var {
        return {
            version: 1,
            position: position,
            layoutMode: layoutMode,
            widgetWidth: widgetWidth,
            indexWidth: indexWidth,
            editorHeight: editorHeight,
            titleSize: titleSize,
            bodySize: bodySize,
            density: density,
            listRows: listRows,
            paletteName: paletteName,
            surfaceOpacity: surfaceOpacity,
            showNumbers: showNumbers,
            newNotePosition: newNotePosition,
            counterMode: counterMode,
            showStatus: showStatus
        };
    }

    function restore(raw: string): void {
        let data;
        try {
            data = JSON.parse(raw);
        } catch (error) {
            ready = true;
            canPersist = false;
            status = "Settings file is invalid";
            console.warn("[caelestia-notes] notes-settings.json is invalid; left untouched:", error);
            return;
        }
        if (!data || data.version !== 1) {
            ready = true;
            canPersist = false;
            status = "Unsupported settings version";
            console.warn("[caelestia-notes] Unsupported settings format; file left untouched.");
            return;
        }

        restoring = true;
        if (["Top Left", "Top Right", "Bottom Left", "Bottom Right"].includes(data.position)) position = data.position;
        if (["Split", "Stacked"].includes(data.layoutMode)) layoutMode = data.layoutMode;
        if (Number.isFinite(data.widgetWidth)) widgetWidth = clampInt(data.widgetWidth, 460, 720);
        if (Number.isFinite(data.indexWidth)) indexWidth = clampInt(data.indexWidth, 110, 220);
        if (Number.isFinite(data.editorHeight)) editorHeight = clampInt(data.editorHeight, 100, 300);
        if (Number.isFinite(data.titleSize)) titleSize = clampInt(data.titleSize, 16, 28);
        if (Number.isFinite(data.bodySize)) bodySize = clampInt(data.bodySize, 12, 22);
        if (["Compact", "Comfortable", "Spacious"].includes(data.density)) density = data.density;
        if (Number.isFinite(data.listRows)) listRows = clampInt(data.listRows, 2, 8);
        if (["Caelestia", "Cobalt", "Forest", "Paper"].includes(data.paletteName)) paletteName = data.paletteName;
        if (Number.isFinite(data.surfaceOpacity)) surfaceOpacity = Math.max(0.65, Math.min(1, data.surfaceOpacity));
        if (typeof data.showNumbers === "boolean") showNumbers = data.showNumbers;
        if (["Top", "Bottom"].includes(data.newNotePosition)) newNotePosition = data.newNotePosition;
        if (["Off", "Words", "Characters"].includes(data.counterMode)) counterMode = data.counterMode;
        if (typeof data.showStatus === "boolean") showStatus = data.showStatus;
        restoring = false;
        ready = true;
        canPersist = true;
        status = "Settings loaded";
    }

    function clampInt(value: real, minimum: int, maximum: int): int {
        return Math.max(minimum, Math.min(maximum, Math.round(value)));
    }

    function update(key: string, value: var): void {
        switch (key) {
        case "position": if (["Top Left", "Top Right", "Bottom Left", "Bottom Right"].includes(value)) position = value; break;
        case "layoutMode": if (["Split", "Stacked"].includes(value)) layoutMode = value; break;
        case "widgetWidth": widgetWidth = clampInt(value, 460, 720); break;
        case "indexWidth": indexWidth = clampInt(value, 110, 220); break;
        case "editorHeight": editorHeight = clampInt(value, 100, 300); break;
        case "titleSize": titleSize = clampInt(value, 16, 28); break;
        case "bodySize": bodySize = clampInt(value, 12, 22); break;
        case "density": if (["Compact", "Comfortable", "Spacious"].includes(value)) density = value; break;
        case "listRows": listRows = clampInt(value, 2, 8); break;
        case "paletteName": if (["Caelestia", "Cobalt", "Forest", "Paper"].includes(value)) paletteName = value; break;
        case "surfaceOpacity": surfaceOpacity = Math.max(0.65, Math.min(1, Number(value))); break;
        case "showNumbers": showNumbers = Boolean(value); break;
        case "newNotePosition": if (["Top", "Bottom"].includes(value)) newNotePosition = value; break;
        case "counterMode": if (["Off", "Words", "Characters"].includes(value)) counterMode = value; break;
        case "showStatus": showStatus = Boolean(value); break;
        default: return;
        }
        if (!restoring) {
            if (!canPersist) {
                status = "Reset settings to replace invalid file";
                return;
            }
            status = "Unsaved settings";
            saveTimer.restart();
        }
    }

    function reset(): void {
        restoring = true;
        position = "Bottom Right";
        layoutMode = "Split";
        widgetWidth = 560;
        indexWidth = 150;
        editorHeight = 155;
        titleSize = 20;
        bodySize = 16;
        density = "Comfortable";
        listRows = 4;
        paletteName = "Caelestia";
        surfaceOpacity = 0.96;
        showNumbers = true;
        newNotePosition = "Bottom";
        counterMode = "Off";
        showStatus = true;
        restoring = false;
        canPersist = true;
        status = "Saving defaults";
        saveTimer.restart();
    }

    function saveNow(): void {
        if (!canPersist || restoring) return;
        persistence.setText(JSON.stringify(serialise(), null, 2));
    }
}
