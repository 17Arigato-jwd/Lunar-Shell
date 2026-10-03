import "dash"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.utils

GridLayout {
    id: root

    required property ScreenState screenState
    required property FileDialog facePicker

    rowSpacing: Tokens.spacing.medium
    columnSpacing: Tokens.spacing.medium

    // USER COMPONENT
    Rect {
        Layout.row: 0
        Layout.column: 2
        Layout.columnSpan: 3
        Layout.preferredWidth: Tokens.sizes.dashboard.userWidth
        Layout.fillHeight: true

        radius: Tokens.rounding.extraLarge

        User {
            id: user

            screenState: root.screenState
            facePicker: root.facePicker
        }
    }

    // ROW 0: NAS BUTTON + WEATHER WIDGET
    RowLayout {
        Layout.row: 0
        Layout.column: 0
        Layout.columnSpan: 2
        Layout.preferredHeight: weather.implicitHeight
        spacing: Tokens.spacing.medium

        ServiceToggle {
            // Same width as the clock container below
            Layout.preferredWidth: dateTime.implicitWidth
            Layout.fillHeight: true

            icon: "storage"
            statusScript: "mount | grep -q '/mnt/ATPBR-Data' && echo ON || echo OFF"
            toggleScript: `${Paths.home}/scripts/mount_nas.sh`
        }

        Rect {
            Layout.preferredWidth: Tokens.sizes.dashboard.weatherWidth
            Layout.fillHeight: true

            radius: Tokens.rounding.extraLarge * 1.5

            SmallWeather {
                id: weather
            }
        }
    }

    // ROW 1: CLOCK + TAILSCALE BUTTON
    ColumnLayout {
        Layout.row: 1
        Layout.column: 0
        Layout.preferredWidth: dateTime.implicitWidth
        Layout.maximumWidth: dateTime.implicitWidth
        Layout.fillHeight: true

        implicitWidth: dateTime.implicitWidth
        spacing: Tokens.spacing.medium

        Rect {
            Layout.fillWidth: true
            Layout.fillHeight: true

            radius: Tokens.rounding.large

            DateTime {
                id: dateTime

                anchors.centerIn: parent
            }
        }

        ServiceToggle {
            Layout.fillWidth: true
            Layout.preferredHeight: Tokens.sizes.session.button

            icon: "home"
            statusScript: "tailscale status | grep -q 'stopped' && echo OFF || echo ON"
            toggleScript: `${Paths.home}/scripts/tailscale_toggle.sh`
        }
    }

    // CALENDAR
    Rect {
        Layout.row: 1
        Layout.column: 1
        Layout.columnSpan: 3
        Layout.fillWidth: true
        Layout.preferredHeight: calendar.implicitHeight

        radius: Tokens.rounding.extraLarge

        Calendar {
            id: calendar

            screenState: root.screenState
        }
    }

    // RESOURCES
    Rect {
        Layout.row: 1
        Layout.column: 4
        Layout.preferredWidth: resources.implicitWidth
        Layout.fillHeight: true

        radius: Tokens.rounding.large

        Resources {
            id: resources
        }
    }

    // MEDIA PLAYER
    Rect {
        Layout.row: 0
        Layout.column: 5
        Layout.rowSpan: 2
        Layout.preferredWidth: media.implicitWidth
        Layout.fillHeight: true

        radius: Tokens.rounding.extraLarge * 2

        Media {
            id: media
        }
    }

    component Rect: StyledRect {
        color: Colours.tPalette.m3surfaceContainer
    }
}
