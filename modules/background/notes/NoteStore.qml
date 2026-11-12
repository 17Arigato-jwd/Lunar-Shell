// SPDX-License-Identifier: 0BSD
import QtQml
import QtQml.Models
import Quickshell
import Quickshell.Io

QtObject {
    id: store
    property ListModel entries: ListModel {}
    readonly property int count: entries.count
    property int selected: -1
    property int nextId: 1
    property var deleted: []
    property string status: "LOADING"
    property bool ready: false
    property bool canPersist: false
    property bool restoring: false
    signal selectionChanged()
    signal contentEdited()

    // This is user data in Quickshell's per-shell data directory, not in the dotfiles repo.
    property var persistence: FileView {
        path: Quickshell.dataPath("notes.json")
        atomicWrites: true
        blockWrites: false
        onLoaded: store.restore(text())
        onLoadFailed: error => {
            console.warn("[caelestia-notes] Could not load notes; starting with defaults:", error);
            if (!store.ready)
                store.seedDefaults();
        }
        onSaved: {
            store.status = "SAVED LOCALLY";
        }
        onSaveFailed: error => {
            store.status = "SAVE FAILED";
            console.warn("[caelestia-notes] Could not save notes:", error);
        }
    }

    // Avoid writing the JSON file for every keystroke while the user is typing.
    property Timer saveTimer: Timer {
        interval: 250
        repeat: false
        onTriggered: store.saveNow()
    }

    function serial(value: int): string { return String(value).padStart(2, "0"); }

    function note(index: int): var {
        if (index < 0 || index >= count) return null;
        const item = entries.get(index);
        return { uid: item.uid, title: item.title, body: item.body, edited: item.edited };
    }

    function snapshot(): var {
        const result = [];
        for (let i = 0; i < count; i++) result.push(note(i));
        return result;
    }

    function restore(raw: string): void {
        let data;
        try {
            data = JSON.parse(raw);
        } catch (error) {
            ready = true;
            canPersist = false;
            status = "DATA ERROR — FILE PRESERVED";
            console.warn("[caelestia-notes] notes.json is not valid JSON. It was left untouched:", error);
            return;
        }
        if (!data || data.version !== 1 || !Array.isArray(data.notes)) {
            ready = true;
            canPersist = false;
            status = "DATA VERSION ERROR";
            console.warn("[caelestia-notes] Unsupported notes.json format; file was left untouched.");
            return;
        }

        restoring = true;
        entries.clear();
        let largestId = 0;
        for (const item of data.notes) {
            if (!item || typeof item.title !== "string" || typeof item.body !== "string")
                continue;
            const uid = Number.isInteger(item.uid) && item.uid > 0 ? item.uid : largestId + 1;
            largestId = Math.max(largestId, uid);
            entries.append({ uid: uid, title: item.title, body: item.body, edited: Boolean(item.edited) });
        }
        nextId = Number.isInteger(data.nextId) ? Math.max(data.nextId, largestId + 1) : largestId + 1;
        selected = count === 0 ? -1 : Math.max(0, Math.min(Number.isInteger(data.selected) ? data.selected : 0, count - 1));
        deleted = [];
        canPersist = true;
        ready = true;
        status = "SAVED LOCALLY";
        restoring = false;
    }

    function seedDefaults(): void {
        restoring = true;
        entries.clear();
        entries.append({ uid: 1, title: "Before I leave", body: "Pick up groceries\nCharge the headphones\nBack up the dotfiles", edited: false });
        entries.append({ uid: 2, title: "Useful commands", body: "hyprctl monitors\nwpctl status", edited: false });
        selected = 0;
        nextId = 3;
        deleted = [];
        canPersist = true;
        ready = true;
        restoring = false;
        persist();
    }

    function select(index: int): void {
        if (index < -1 || index >= count || index === selected) return;
        selected = index;
        selectionChanged();
    }

    function add(prepend: bool): void {
        const index = prepend ? 0 : count;
        if (prepend) deleted = deleted.map(function(entry) { return { note: entry.note, index: entry.index + 1 }; });
        entries.insert(index, { uid: nextId++, title: "", body: "", edited: false });
        // The newly inserted note may reuse the current numeric index (notably at Top).
        selected = index;
        selectionChanged();
        status = "UNSAVED CHANGES";
        contentEdited();
    }

    function edit(index: int, field: string, value: string): void {
        if (index < 0 || index >= count || (field !== "title" && field !== "body")) return;
        if (entries.get(index)[field] === value) return;
        entries.setProperty(index, field, value);
        entries.setProperty(index, "edited", true);
        status = "UNSAVED CHANGES";
        contentEdited();
    }

    function remove(index: int): void {
        const item = note(index);
        if (!item) return;
        deleted = deleted.concat([{ note: item, index: index }]);
        const oldSelected = selected;
        const next = oldSelected === index ? Math.min(index, count - 2) : oldSelected > index ? oldSelected - 1 : oldSelected;
        entries.remove(index);
        if (oldSelected === index || oldSelected > index) {
            // If the index number is reused after deletion, still notify the editor to reload.
            selected = next;
            selectionChanged();
        }
        status = "UNSAVED CHANGES";
        contentEdited();
    }

    function undo(): void {
        if (!deleted.length) return;
        const last = deleted[deleted.length - 1];
        deleted = deleted.slice(0, -1);
        const index = Math.min(last.index, count);
        entries.insert(index, last.note);
        selected = index;
        selectionChanged();
        status = "UNSAVED CHANGES";
        contentEdited();
    }

    function persist(): void {
        if (!ready || !canPersist || restoring) return;
        status = "SAVING...";
        saveTimer.restart();
    }

    function saveNow(): void {
        if (!ready || !canPersist || restoring) return;
        persistence.setText(JSON.stringify({ version: 1, nextId: nextId, selected: selected, notes: snapshot() }, null, 2));
    }

    onContentEdited: persist()
    onSelectionChanged: persist()
}
