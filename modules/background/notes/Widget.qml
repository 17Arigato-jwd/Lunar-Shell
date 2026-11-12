// SPDX-License-Identifier: 0BSD
import QtQuick

NotesIndex {
    id: root
    indexWidth: root.preferences.indexWidth
    defaultRowHeight: 40
    writingHeight: root.preferences.editorHeight
    headingSize: root.preferences.titleSize
    bodySize: root.preferences.bodySize
    density: root.preferences.density
    listRows: root.preferences.listRows
    prependNewNotes: root.preferences.newNotePosition === "Top"
    counterMode: root.preferences.counterMode
    numbered: root.preferences.showNumbers
    paletteName: root.preferences.paletteName
    surfaceOpacity: root.preferences.surfaceOpacity
    layoutMode: root.preferences.layoutMode
}
