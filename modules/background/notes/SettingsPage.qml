// SPDX-License-Identifier: 0BSD
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root
    required property var preferences
    signal backRequested()
    implicitWidth: preferences.widgetWidth
    implicitHeight: 640

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small
            IconButton {
                icon: "arrow_back"
                type: IconButton.Text
                onClicked: root.backRequested()
                Accessible.name: "Back to notes"
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    text: "Notes settings"
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.title.medium
                }
                StyledText {
                    text: "Layout, placement and appearance"
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }
            }
            IconButton {
                icon: "close"
                type: IconButton.Text
                onClicked: root.backRequested()
                Accessible.name: "Close settings"
            }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colours.palette.m3outlineVariant
        }

        Flickable {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: settingsColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: settingsColumn
                width: scroll.width - Tokens.padding.small
                spacing: Tokens.spacing.largeIncreased

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small
                    StyledText {
                        text: "PLACEMENT & LAYOUT"
                        color: Colours.palette.m3primary
                        font: Tokens.font.label.large
                    }
                    SettingsChoice {
                        Layout.fillWidth: true
                        label: "Desktop position"
                        choices: ["Top Left", "Top Right", "Bottom Left", "Bottom Right"]
                        value: root.preferences.position
                        onChosen: choice => root.preferences.update("position", choice)
                    }
                    SettingsChoice {
                        Layout.fillWidth: true
                        label: "Layout"
                        choices: ["Split", "Stacked"]
                        value: root.preferences.layoutMode
                        onChosen: choice => root.preferences.update("layoutMode", choice)
                    }
                    SettingsSlider {
                        Layout.fillWidth: true
                        label: "Widget width"
                        minimumValue: 460
                        maximumValue: 720
                        currentValue: root.preferences.widgetWidth
                        suffix: " px"
                        onValueEdited: value => root.preferences.update("widgetWidth", value)
                    }
                    SettingsSlider {
                        Layout.fillWidth: true
                        visible: root.preferences.layoutMode === "Split"
                        label: "Notes index width"
                        minimumValue: 110
                        maximumValue: 220
                        currentValue: root.preferences.indexWidth
                        suffix: " px"
                        onValueEdited: value => root.preferences.update("indexWidth", value)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small
                    StyledText {
                        text: "EDITOR"
                        color: Colours.palette.m3primary
                        font: Tokens.font.label.large
                    }
                    SettingsSlider {
                        Layout.fillWidth: true
                        label: "Editor height"
                        minimumValue: 100
                        maximumValue: 300
                        currentValue: root.preferences.editorHeight
                        suffix: " px"
                        onValueEdited: value => root.preferences.update("editorHeight", value)
                    }
                    SettingsSlider {
                        Layout.fillWidth: true
                        label: "Title size"
                        minimumValue: 16
                        maximumValue: 28
                        currentValue: root.preferences.titleSize
                        suffix: " px"
                        onValueEdited: value => root.preferences.update("titleSize", value)
                    }
                    SettingsSlider {
                        Layout.fillWidth: true
                        label: "Body text size"
                        minimumValue: 12
                        maximumValue: 22
                        currentValue: root.preferences.bodySize
                        suffix: " px"
                        onValueEdited: value => root.preferences.update("bodySize", value)
                    }
                    SettingsChoice {
                        Layout.fillWidth: true
                        label: "List density"
                        choices: ["Compact", "Comfortable", "Spacious"]
                        value: root.preferences.density
                        onChosen: choice => root.preferences.update("density", choice)
                    }
                    SettingsSlider {
                        Layout.fillWidth: true
                        label: "Visible notes in index"
                        minimumValue: 2
                        maximumValue: 8
                        currentValue: root.preferences.listRows
                        onValueEdited: value => root.preferences.update("listRows", value)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small
                    StyledText {
                        text: "APPEARANCE & BEHAVIOUR"
                        color: Colours.palette.m3primary
                        font: Tokens.font.label.large
                    }
                    SettingsChoice {
                        Layout.fillWidth: true
                        label: "Palette"
                        choices: ["Caelestia", "Cobalt", "Forest", "Paper"]
                        value: root.preferences.paletteName
                        onChosen: choice => root.preferences.update("paletteName", choice)
                    }
                    SettingsSlider {
                        Layout.fillWidth: true
                        label: "Surface opacity"
                        minimumValue: 65
                        maximumValue: 100
                        currentValue: root.preferences.surfaceOpacity * 100
                        suffix: "%"
                        onValueEdited: value => root.preferences.update("surfaceOpacity", value / 100)
                    }
                    SettingsChoice {
                        Layout.fillWidth: true
                        label: "New note placement"
                        choices: ["Top", "Bottom"]
                        value: root.preferences.newNotePosition
                        onChosen: choice => root.preferences.update("newNotePosition", choice)
                    }
                    SettingsChoice {
                        Layout.fillWidth: true
                        label: "Text counter"
                        choices: ["Off", "Words", "Characters"]
                        value: root.preferences.counterMode
                        onChosen: choice => root.preferences.update("counterMode", choice)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            text: "Number notes in the index"
                            color: Colours.palette.m3onSurface
                            font: Tokens.font.body.medium
                            Layout.fillWidth: true
                        }
                        StyledSwitch {
                            checked: root.preferences.showNumbers
                            onToggled: root.preferences.update("showNumbers", checked)
                            Accessible.name: "Number notes in the index"
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            text: "Show save status"
                            color: Colours.palette.m3onSurface
                            font: Tokens.font.body.medium
                            Layout.fillWidth: true
                        }
                        StyledSwitch {
                            checked: root.preferences.showStatus
                            onToggled: root.preferences.update("showStatus", checked)
                            Accessible.name: "Show save status"
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.preferences.status
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                    wrapMode: Text.Wrap
                }
                NoteButton {
                    text: "Reset all settings"
                    ink: Colours.palette.m3onSurface
                    paper: Colours.palette.m3surfaceContainerLow
                    accent: Colours.palette.m3secondaryContainer
                    line: Colours.palette.m3outlineVariant
                    accentInk: Colours.palette.m3onSecondaryContainer
                    onClicked: root.preferences.reset()
                }
            }
        }
    }
}
