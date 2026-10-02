pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Column {
    id: root

    required property ScreenState screenState

    padding: Tokens.padding.large
    rightPadding: CUtils.clamp(padding - Config.border.thickness, 0, padding)
    spacing: Tokens.spacing.large

    SessionButton {
        id: logout
        icon: Config.session.icons.logout
        command: Config.session.commands.logout
        KeyNavigation.up: windows_boot
        KeyNavigation.down: lock_session
        Component.onCompleted: forceActiveFocus()
        Connections {
            function onLauncherChanged(): void {
                if (!root.screenState.launcher)
                    logout.forceActiveFocus();
            }
            target: root.screenState
        }
    }

    SessionButton {
        id: lock_session
        icon: "lock"
        command: ["loginctl", "lock-session"]
        KeyNavigation.up: logout
        KeyNavigation.down: screen_off
    }

    SessionButton {
        id: screen_off
        icon: "tv_off"
        command: ["bash", "-c", "sleep 0.5 && hyprctl dispatch dpms off"]
        KeyNavigation.up: lock_session
        KeyNavigation.down: suspend_idle
    }

    SessionButton {
        id: suspend_idle
        icon: "bolt"
        command: ["/home/varchas/scripts/suspend_idle.sh"]
        KeyNavigation.up: screen_off
        KeyNavigation.down: suspend_deep
    }

    AnimatedImage {
        width: Tokens.sizes.session.button
        height: Tokens.sizes.session.button
        sourceSize.width: width * ((QsWindow.window as QsWindow)?.devicePixelRatio ?? 1)

        playing: visible
        asynchronous: true
        speed: Config.general.sessionGifSpeed
        source: Paths.absolutePath(Config.paths.sessionGif)
        fillMode: AnimatedImage.PreserveAspectFit
    }

    SessionButton {
        id: suspend_deep
        icon: "sleep"
        command: ["/home/varchas/scripts/suspend_deep.sh"]
        KeyNavigation.up: suspend_idle
        KeyNavigation.down: shutdown
    }

    SessionButton {
        id: shutdown
        icon: Config.session.icons.shutdown
        command: Config.session.commands.shutdown
        flushClipboard: true
        KeyNavigation.up: suspend_deep
        KeyNavigation.down: reboot
    }

    SessionButton {
        id: reboot
        icon: Config.session.icons.reboot
        command: Config.session.commands.reboot
        flushClipboard: true
        KeyNavigation.up: shutdown
        KeyNavigation.down: windows_boot
    }

    SessionButton {
        id: windows_boot
        icon: "󰍲"
        anchors.verticalCenterOffset: 2
        command: ["bash", "-c", "sudo efibootmgr -n 0001 && systemctl reboot"]
        flushClipboard: true
        KeyNavigation.up: reboot
        KeyNavigation.down: logout
    }

    component SessionButton: IconButton {
        id: button

        required property list<string> command
        property bool flushClipboard: false

        function exec(): void {
            root.screenState.session = false;
            if (flushClipboard)
                Quickshell.execDetached(["bash", `${Paths.home}/.config/hypr/scripts/clipboard-flush.sh`]);
            if (!SessionManager.exec(command))
                Quickshell.execDetached(command);
        }

        implicitWidth: Tokens.sizes.session.button
        implicitHeight: Tokens.sizes.session.button

        inactiveColour: activeFocus ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer
        inactiveOnColour: activeFocus ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
        radius: pressed ? Tokens.rounding.medium : activeFocus ? Tokens.rounding.extraLarge : Tokens.rounding.largeIncreased
        font: Tokens.font.icon.builders.large.scale(1.3).build()
        onClicked: exec()

        Keys.onEnterPressed: exec()
        Keys.onReturnPressed: exec()
        Keys.onEscapePressed: root.screenState.session = false
        Keys.onPressed: event => {
            if (!Config.session.vimKeybinds)
                return;

            if (event.modifiers & Qt.ControlModifier) {
                if ((event.key === Qt.Key_J || event.key === Qt.Key_N) && KeyNavigation.down) {
                    KeyNavigation.down.focus = true;
                    event.accepted = true;
                } else if ((event.key === Qt.Key_K || event.key === Qt.Key_P) && KeyNavigation.up) {
                    KeyNavigation.up.focus = true;
                    event.accepted = true;
                }
            } else if (event.key === Qt.Key_Tab && KeyNavigation.down) {
                KeyNavigation.down.focus = true;
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                if (KeyNavigation.up) {
                    KeyNavigation.up.focus = true;
                    event.accepted = true;
                }
            }
        }
    }
}
