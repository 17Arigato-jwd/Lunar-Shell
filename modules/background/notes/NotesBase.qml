// SPDX-License-Identifier: 0BSD
pragma ComponentBehavior: Bound
import QtQuick
import Caelestia.Config
import qs.components
import qs.services

FocusScope {
    id: root
    required property var preferences
    property alias noteStore: store
    readonly property int noteCount: store.count
    readonly property int selectedIndex: store.selected

    property string paletteName: preferences.paletteName
    readonly property bool nativePalette: paletteName === "Caelestia"
    readonly property color paper: nativePalette ? Colours.palette.m3surfaceContainerLow
        : paletteName === "Cobalt" ? "#101827"
        : paletteName === "Forest" ? "#121e19" : "#f4ecdd"
    readonly property color ink: nativePalette ? Colours.palette.m3onSurface
        : paletteName === "Cobalt" ? "#e5edfa"
        : paletteName === "Forest" ? "#e4eee7" : "#2d2923"
    readonly property color accent: nativePalette ? Colours.palette.m3primary
        : paletteName === "Cobalt" ? "#82afff"
        : paletteName === "Forest" ? "#8abb9c" : "#9a4824"
    readonly property color muted: nativePalette ? Colours.palette.m3onSurfaceVariant : blend(paper, ink, 0.65)
    readonly property color rule: nativePalette ? Colours.palette.m3outlineVariant : blend(paper, accent, 0.45)
    readonly property color accentInk: nativePalette ? Colours.palette.m3onPrimary : contrastingInk(accent)
    readonly property color softFill: nativePalette ? Colours.palette.m3surfaceContainer : blend(paper, ink, 0.10)

    property string monoFont: Tokens.font.body.small.family
    property string sansFont: Tokens.font.body.medium.family
    property int writingHeight: preferences.editorHeight
    property int headingSize: preferences.titleSize
    property int bodySize: preferences.bodySize
    property string density: preferences.density
    property int listRows: preferences.listRows
    property bool prependNewNotes: preferences.newNotePosition === "Top"
    property string counterMode: preferences.counterMode
    property bool numbered: preferences.showNumbers
    property int defaultRowHeight: 40
    property int defaultRowGap: 7
    property real surfaceOpacity: preferences.surfaceOpacity
    readonly property int noteRowHeight: defaultRowHeight + (density === "Compact" ? -8 : density === "Spacious" ? 8 : 0)
    readonly property int noteRowGap: Math.max(0, defaultRowGap + (density === "Compact" ? -3 : density === "Spacious" ? 3 : 0))
    readonly property int noteListHeight: listRows * noteRowHeight + (listRows - 1) * noteRowGap
    signal notesEdited()

    NoteStore {
        id: store
        onContentEdited: root.notesEdited()
    }

    function blend(a: color, b: color, amount: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * amount, a.g + (b.g - a.g) * amount, a.b + (b.b - a.b) * amount, 1);
    }
    function linear(channel: real): real { return channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4); }
    function contrastingInk(background: color): color {
        return 0.2126 * linear(background.r) + 0.7152 * linear(background.g) + 0.0722 * linear(background.b) > 0.179 ? Qt.rgba(10 / 255, 10 / 255, 10 / 255, 1) : Qt.rgba(245 / 255, 245 / 255, 240 / 255, 1);
    }
    function snapshot(): var { return store.snapshot(); }
    function selectNote(index: int): void { store.select(index); }
}
