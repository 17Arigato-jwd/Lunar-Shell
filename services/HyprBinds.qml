pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Builds the cheat sheet from Hyprland's live bind list (`hyprctl binds -j`),
// so it can never go out of date with hyprland.lua.
//
// Label a bind in hyprland.lua with
//     hl.bind("SUPER + Q", hl.dsp.exec_cmd("kitty"), { description = "Apps & shell: Terminal" })
// The text before ": " is the section, the rest is the row label. Binds that
// share a description are merged into one row (Super 1-0, Super Shift arrows,
// and so on). Binds without a description are listed at the bottom under
// "No description" so gaps are visible instead of silently missing.
Singleton {
    id: root

    // [{ title, icon, binds: [{ keys: [...], desc }] }] - the same shape the
    // cheat sheet used to hardcode.
    property var sections: []

    readonly property var sectionIcons: ({
            "Apps & shell": "apps",
            "Window": "desktop_windows",
            "Move & resize": "open_with",
            "Workspaces": "dashboard",
            "Special workspaces": "layers",
            "Screenshot": "screenshot_monitor",
            "Tools": "build",
            "Hardware keys": "keyboard",
            "No description": "help"
        })

    // Display names for single keys (everything else is just capitalised).
    readonly property var keyLabels: ({
            "left": "\u2190",
            "right": "\u2192",
            "up": "\u2191",
            "down": "\u2193",
            "mouse:272": "Drag",
            "mouse:273": "R-Drag",
            "XF86PowerOff": "Power",
            "XF86AudioRaiseVolume": "Vol +",
            "XF86AudioLowerVolume": "Vol \u2212",
            "XF86AudioMute": "Mute",
            "XF86Launch6": "Mic",
            "XF86MonBrightnessUp": "Bright +",
            "XF86MonBrightnessDown": "Bright \u2212"
        })

    // Whole-combo overrides, keyed by "Mod+Mod+key".
    readonly property var comboLabels: ({
            "Super+Shift+F23": ["Copilot"]
        })

    function refresh(): void {
        if (!proc.running)
            proc.running = true;
    }

    function modNames(mask) {
        const out = [];
        if (mask & 64)
            out.push("Super");
        if (mask & 4)
            out.push("Ctrl");
        if (mask & 8)
            out.push("Alt");
        if (mask & 1)
            out.push("Shift");
        return out;
    }

    function keyLabel(key) {
        if (keyLabels[key] !== undefined)
            return keyLabels[key];
        if (key.length === 1)
            return key.toUpperCase();
        return key.charAt(0).toUpperCase() + key.slice(1);
    }

    // Several keys that differ only in the last key -> one chip (1-0, A-J, arrows).
    function mergeKeys(raws) {
        const arrows = ["left", "right", "up", "down"];
        let allArrows = true;
        let allSingle = true;
        for (let i = 0; i < raws.length; i++) {
            if (arrows.indexOf(raws[i]) < 0)
                allArrows = false;
            if (raws[i].length !== 1)
                allSingle = false;
        }
        if (allArrows) {
            let s = "";
            for (let i = 0; i < arrows.length; i++) {
                if (raws.indexOf(arrows[i]) >= 0)
                    s += keyLabels[arrows[i]];
            }
            return s;
        }
        if (allSingle) {
            const digits = "1234567890";
            let sequential = true;
            for (let i = 1; i < raws.length; i++) {
                const a = raws[i - 1];
                const b = raws[i];
                let next;
                if (digits.indexOf(a) >= 0 && digits.indexOf(b) >= 0)
                    next = digits.indexOf(b) === digits.indexOf(a) + 1;
                else
                    next = b.toLowerCase().charCodeAt(0) === a.toLowerCase().charCodeAt(0) + 1;
                if (!next) {
                    sequential = false;
                    break;
                }
            }
            if (sequential)
                return keyLabel(raws[0]) + "\u2013" + keyLabel(raws[raws.length - 1]);
        }
        const labels = [];
        for (let i = 0; i < raws.length; i++)
            labels.push(keyLabel(raws[i]));
        return labels.join(" / ");
    }

    function rowKeys(items) {
        // Drop exact duplicates (e.g. two dispatchers bound to Alt+Tab).
        const uniq = [];
        const seen = {};
        for (let i = 0; i < items.length; i++) {
            const id = items[i].mods.join("+") + "+" + items[i].key;
            if (!seen[id]) {
                seen[id] = true;
                uniq.push(items[i]);
            }
        }
        const mods = uniq[0].mods;
        const modsId = mods.join("+");
        let sameMods = true;
        for (let i = 1; i < uniq.length; i++) {
            if (uniq[i].mods.join("+") !== modsId)
                sameMods = false;
        }

        if (uniq.length === 1) {
            const canon = mods.concat([uniq[0].key]).join("+");
            if (comboLabels[canon] !== undefined)
                return comboLabels[canon];
            return mods.concat([keyLabel(uniq[0].key)]);
        }
        if (sameMods) {
            const raws = [];
            for (let i = 0; i < uniq.length; i++)
                raws.push(uniq[i].key);
            return mods.concat([mergeKeys(raws)]);
        }
        // Different modifiers: show the combos as alternatives.
        const out = [];
        for (let i = 0; i < uniq.length; i++) {
            if (i > 0)
                out.push("/");
            const combo = uniq[i].mods.concat([keyLabel(uniq[i].key)]);
            for (let j = 0; j < combo.length; j++)
                out.push(combo[j]);
        }
        return out;
    }

    function build(binds) {
        const groups = [];
        const index = {};
        for (let i = 0; i < binds.length; i++) {
            const b = binds[i];
            if (b.release || b.longPress)
                continue;
            let key = b.key;
            if (!key && b.keycode)
                key = "code:" + b.keycode;
            if (!key)
                continue;

            const d = (b.description || "").trim();
            let section = "No description";
            let desc = "(no description)";
            if (d) {
                const c = d.indexOf(": ");
                if (c > 0) {
                    section = d.slice(0, c);
                    desc = d.slice(c + 2);
                } else {
                    section = "Other";
                    desc = d;
                }
            }

            // Only described binds merge; undescribed ones stay one row each.
            const gk = d ? section + "\u0000" + desc : "#" + i;
            if (index[gk] === undefined) {
                index[gk] = groups.length;
                groups.push({
                    section: section,
                    desc: desc,
                    items: []
                });
            }
            groups[index[gk]].items.push({
                mods: modNames(b.modmask),
                key: key
            });
        }

        const sections = [];
        const sIndex = {};
        for (let i = 0; i < groups.length; i++) {
            const g = groups[i];
            if (sIndex[g.section] === undefined) {
                sIndex[g.section] = sections.length;
                sections.push({
                    title: g.section,
                    icon: sectionIcons[g.section] !== undefined ? sectionIcons[g.section] : "keyboard",
                    binds: []
                });
            }
            sections[sIndex[g.section]].binds.push({
                keys: rowKeys(g.items),
                desc: g.desc
            });
        }

        // Keep "No description" last.
        const at = sIndex["No description"];
        if (at !== undefined && at !== sections.length - 1)
            sections.push(sections.splice(at, 1)[0]);
        return sections;
    }

    Process {
        id: proc

        command: ["hyprctl", "binds", "-j"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.sections = root.build(JSON.parse(text));
                } catch (e) {
                    console.warn("HyprBinds: could not read hyprctl output:", e);
                }
            }
        }
    }

    // Hyprland reloads its config when hyprland.lua changes; follow it.
    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "configreloaded")
                root.refresh();
        }
    }
}
