//  Cheat sheet — native Caelestia module.
//  The visuals live in Wrapper.qml/Content.qml and are embedded directly in
//  the shared drawers window (see modules/drawers/Panels.qml) so they can
//  pop up from the bottom of the screen exactly like the launcher, and so
//  they naturally stack below the session/power menu.
//  This file just keeps the external toggle surface alive:
//  `qs -c caelestia ipc call cheatsheet toggle` and the "cheatsheet"
//  CustomShortcut both still work unchanged.

import Quickshell
import Quickshell.Io
import qs.components.misc
import qs.services

Scope {
    id: root

    function toggle(): void {
        const state = ShellState.forActive();
        if (state)
            state.cheatsheet = !state.cheatsheet;
    }

    function open(): void {
        const state = ShellState.forActive();
        if (state)
            state.cheatsheet = true;
    }

    function close(): void {
        const state = ShellState.forActive();
        if (state)
            state.cheatsheet = false;
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

        target: "cheatsheet"
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "cheatsheet"
        description: "Toggle the cheat sheet"
        onPressed: root.toggle()
    }
}
