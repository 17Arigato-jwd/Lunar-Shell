// SPDX-License-Identifier: 0BSD
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

NotesBase {
    id: root
    property int indexWidth: preferences.indexWidth
    property string layoutMode: preferences.layoutMode
    property bool settingsOpen: false
    implicitWidth: preferences.widgetWidth
    implicitHeight: settingsOpen ? settingsPage.implicitHeight
        : layoutMode === "Split"
            ? Math.max(root.noteListHeight + 106, root.writingHeight + root.headingSize + root.bodySize + 142)
            : Math.min(root.noteListHeight, 180) + root.writingHeight + root.headingSize + root.bodySize + 255
    visible: root.noteStore.ready

    StyledRect {
        id: surface
        objectName: "notesSurface"
        anchors.fill: parent
        color: Qt.alpha(root.paper, root.surfaceOpacity)
        border.color: root.nativePalette ? Colours.palette.m3outlineVariant : root.rule
        border.width: 1
        radius: Tokens.rounding.extraLarge
    }

    Item {
        id: header
        visible: !root.settingsOpen
        x: Tokens.padding.large
        y: Tokens.padding.medium
        width: root.width - 2 * Tokens.padding.large
        height: 40

        Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            StyledText {
                text: "Notes"
                color: root.ink
                font: Tokens.font.title.medium
            }
            StyledText {
                text: root.noteCount + (root.noteCount === 1 ? " note" : " notes")
                color: root.muted
                font: Tokens.font.label.small
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.small
            NoteButton {
                text: "+ New"
                ink: root.ink
                paper: root.paper
                accent: root.accent
                line: root.rule
                accentInk: root.accentInk
                onClicked: {
                    root.noteStore.add(root.prependNewNotes);
                    Qt.callLater(() => editor.focusTitle());
                }
            }
            IconButton {
                id: settingsButton
                icon: "settings"
                type: IconButton.Text

                // Keep the gear visibly selected while settings are open.
                isToggle: true
                checked: root.settingsOpen

                // Stronger feedback for hover, press, and selected states.
                color: root.settingsOpen
                    ? Qt.alpha(Colours.palette.m3primary, 0.22)
                    : pressed
                        ? Qt.alpha(Colours.palette.m3onSurface, 0.16)
                        : hovered
                            ? Qt.alpha(Colours.palette.m3onSurface, 0.10)
                            : "transparent"
                radius: Tokens.rounding.medium

                Accessible.name: "Notes settings"
                onClicked: root.settingsOpen = !root.settingsOpen
            }
        }
    }

    StyledRect {
        x: 0
        y: 53
        width: root.width
        height: 1
        color: root.rule
        visible: !root.settingsOpen
    }

    // Split layout: index on the left, editor on the right.
    Item {
        id: splitLayout
        x: 1
        y: 54
        width: root.width - 2
        height: root.height - 99
        visible: !root.settingsOpen && root.layoutMode === "Split"

        Item {
            id: indexPanel
            x: 0
            y: 0
            width: Math.min(root.width * 0.40, root.indexWidth)
            height: parent.height

            StyledText {
                x: Tokens.padding.medium
                y: Tokens.padding.medium
                text: "Your notes"
                color: root.muted
                font: Tokens.font.label.medium
            }
            NoteList {
                id: splitList
                objectName: "noteList"
                x: 1
                y: 42
                width: indexPanel.width - 2
                height: Math.min(root.noteListHeight, Math.max(0, indexPanel.height - 44))
                maxHeight: height
                store: root.noteStore
                rowHeight: root.noteRowHeight
                spacing: root.noteRowGap
                flat: true
                flatHighlight: true
                wrapLabels: true
                numbered: root.numbered
                writingFont: root.monoFont
                ink: root.ink
                paper: root.paper
                accent: root.accent
                rule: root.rule
                accentInk: root.accentInk
                markerInk: root.accent
            }
            StyledRect {
                anchors.right: parent.right
                width: 1
                height: parent.height
                color: root.rule
            }
        }

        Column {
            id: editorColumn
            x: indexPanel.width + Tokens.padding.large
            y: Tokens.padding.large
            width: root.width - x - Tokens.padding.large
            spacing: Tokens.spacing.medium

            StyledText {
                text: root.selectedIndex < 0 ? "Select a note" : "Note " + root.noteStore.serial(root.selectedIndex + 1)
                color: root.muted
                font: Tokens.font.label.medium
            }
            StyledText {
                objectName: "textCount"
                visible: root.counterMode !== "Off"
                width: parent.width
                text: editor.statistics
                color: root.muted
                font: Tokens.font.label.small
            }
            NoteEditor {
                id: editor
                width: parent.width
                store: root.noteStore
                titleSize: root.headingSize
                bodySize: root.bodySize
                bodyHeight: root.writingHeight
                counterMode: root.counterMode
                writingFont: root.sansFont
                titleFont: root.sansFont
                ink: root.ink
                titleInk: root.ink
                muted: root.muted
                accent: root.accent
                accentInk: root.accentInk
                rule: root.rule
            }
        }
    }

    // Stacked layout: full-width index above the editor, useful for narrower or
    // taller desktop placements.
    Column {
        id: stackedLayout
        x: Tokens.padding.large
        y: 62
        width: root.width - 2 * Tokens.padding.large
        spacing: Tokens.spacing.medium
        visible: !root.settingsOpen && root.layoutMode === "Stacked"

        Column {
            width: parent.width
            spacing: Tokens.spacing.small
            StyledText {
                text: "Your notes"
                color: root.muted
                font: Tokens.font.label.medium
            }
            NoteList {
                objectName: "noteListStacked"
                width: parent.width
                height: Math.min(root.noteListHeight, 150)
                maxHeight: height
                store: root.noteStore
                rowHeight: root.noteRowHeight
                spacing: root.noteRowGap
                flat: true
                flatHighlight: true
                wrapLabels: true
                numbered: root.numbered
                writingFont: root.monoFont
                ink: root.ink
                paper: root.paper
                accent: root.accent
                rule: root.rule
                accentInk: root.accentInk
                markerInk: root.accent
            }
        }

        Column {
            width: parent.width
            spacing: Tokens.spacing.small
            StyledText {
                text: root.selectedIndex < 0 ? "Select a note" : "Note " + root.noteStore.serial(root.selectedIndex + 1)
                color: root.muted
                font: Tokens.font.label.medium
            }
            StyledText {
                visible: root.counterMode !== "Off"
                width: parent.width
                text: editor.statistics
                color: root.muted
                font: Tokens.font.label.small
            }
            NoteEditor {
                id: stackedEditor
                width: parent.width
                store: root.noteStore
                titleSize: root.headingSize
                bodySize: root.bodySize
                bodyHeight: root.writingHeight
                counterMode: root.counterMode
                writingFont: root.sansFont
                titleFont: root.sansFont
                ink: root.ink
                titleInk: root.ink
                muted: root.muted
                accent: root.accent
                accentInk: root.accentInk
                rule: root.rule
            }
        }
    }

    SettingsPage {
        id: settingsPage
        anchors.fill: parent
        visible: root.settingsOpen
        preferences: root.preferences
        onBackRequested: root.settingsOpen = false
    }

    StyledRect {
        visible: !root.settingsOpen && root.preferences.showStatus
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 38
        width: root.width
        height: 1
        color: root.rule
    }
    StyledText {
        visible: !root.settingsOpen && root.preferences.showStatus
        x: Tokens.padding.large
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.padding.medium
        text: root.noteStore.status
        color: root.muted
        font: Tokens.font.label.small
    }
}
