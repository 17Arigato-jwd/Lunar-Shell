// SPDX-License-Identifier: 0BSD
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Column {
    id: editor
    required property NoteStore store
    property int noteIndex: store.selected
    property string writingFont: Tokens.font.body.medium.family
    property string titleFont: Tokens.font.title.medium.family
    property color ink: Colours.palette.m3onSurface
    property color titleInk: ink
    property color muted: Colours.palette.m3onSurfaceVariant
    property color rule: Colours.palette.m3outlineVariant
    property color accentInk: Colours.palette.m3onPrimary
    property color accent: Colours.palette.m3primary
    property int bodySize: 16
    property int titleSize: 18
    property int titleIndent: 0
    property int bodyHeight: 142
    property bool titleRule: true
    property bool syncing: false
    property string counterMode: "Off"
    readonly property int wordCount: body.text.trim() ? body.text.trim().split(/\s+/).length : 0
    readonly property int characterCount: body.text.replace(/[\uD800-\uDBFF][\uDC00-\uDFFF]/g, "_").length
    readonly property string statistics: counterMode === "Words" ? wordCount + (wordCount === 1 ? " word" : " words")
        : counterMode === "Characters" ? characterCount + (characterCount === 1 ? " character" : " characters") : ""
    property alias titleField: title
    property alias bodyField: body
    spacing: Tokens.spacing.medium

    function loadNote(): void {
        syncing = true;
        const note = store.note(noteIndex);
        title.text = note ? note.title : "";
        body.text = note ? note.body : "";
        syncing = false;
    }
    function focusTitle(): void { title.forceActiveFocus(); }
    onNoteIndexChanged: loadNote()
    Component.onCompleted: loadNote()
    Connections { target: editor.store; function onSelectionChanged(): void { editor.loadNote(); } }

    StyledTextField {
        id: title
        objectName: "noteTitle"
        x: editor.titleIndent
        width: editor.width - editor.titleIndent
        height: editor.titleSize + Tokens.padding.large * 2
        type: StyledTextField.Filled
        // Use StyledTextField’s native Caelestia padding; these are read-only in this shell build.
        radius: Tokens.rounding.medium
        maximumLength: 120
        font.family: editor.titleFont
        font.pixelSize: editor.titleSize
        color: editor.titleInk
        selectionColor: Qt.alpha(editor.accent, 0.4)
        selectedTextColor: editor.accentInk
        placeholderText: "Untitled note"
        placeholderTextColor: editor.muted
        selectByMouse: true
        Accessible.name: "Note title"
        onTextEdited: { if (!editor.syncing) editor.store.edit(editor.noteIndex, "title", text); }
    }

    ScrollView {
        id: scroll
        objectName: "writingArea"
        width: editor.width
        height: editor.bodyHeight
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        TextArea {
            id: body
            objectName: "noteBody"
            padding: Tokens.padding.medium
            width: scroll.availableWidth
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.PlainText
            font.family: editor.writingFont
            font.pixelSize: editor.bodySize
            color: editor.ink
            selectionColor: Qt.alpha(editor.accent, 0.4)
            selectedTextColor: editor.accentInk
            placeholderText: "Write something to remember…"
            placeholderTextColor: editor.muted
            selectByMouse: true
            activeFocusOnTab: true
            Accessible.name: "Note contents"
            background: StyledRect {
                color: Qt.alpha(Colours.palette.m3surfaceContainer, 0.45)
                radius: Tokens.rounding.medium
                border.width: body.activeFocus ? 1 : 0
                border.color: body.activeFocus ? editor.accent : editor.rule
            }
            onTextChanged: { if (!editor.syncing) editor.store.edit(editor.noteIndex, "body", text); }
        }
    }
}
