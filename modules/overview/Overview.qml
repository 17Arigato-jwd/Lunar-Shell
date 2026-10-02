//  Overview — native Caelestia module.
//  A Windows-Task-View-style grid of every workspace (in the focused
//  monitor's group of Config.bar.workspaces.shown), each showing live
//  thumbnails of its windows. Click a window to jump to it, click empty
//  space in a workspace to switch to it, or drag a window's thumbnail to
//  move it to another workspace (or, for floating windows, reposition it
//  within the same workspace).
//  The visuals live in Wrapper.qml/Content.qml and are embedded directly in
//  the shared drawers window (see modules/drawers/Panels.qml), same as the
//  cheat sheet.
//  Toggle via the "overview" CustomShortcut (Super+Tab), or
//  `qs -c caelestia ipc call overview toggle`.

import Quickshell
import Quickshell.Io
import qs.components.misc
import qs.services

Scope {
    id: root

    function toggle(): void {
        const state = ShellState.forActive();
        if (!state)
            return;
        if (state.overview)
            state.overview = false;
        else
            root.open();
    }

    function open(): void {
        const state = ShellState.forActive();
        if (!state)
            return;
        // Full-screen takeover - clear anything else that'd be hidden behind it
        state.launcher = false;
        state.dashboard = false;
        state.sidebar = false;
        state.cheatsheet = false;
        state.overview = true;
    }

    function close(): void {
        const state = ShellState.forActive();
        if (state)
            state.overview = false;
    }

    IpcHandler {
        function toggle(): void {
            root.toggle();
        }

        function open(): void {
            root.open();
        }

        function close(): void {
            root.close();
        }

        target: "overview"
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "overview"
        description: "Toggle the workspace overview"
        onPressed: root.toggle()
    }
}
