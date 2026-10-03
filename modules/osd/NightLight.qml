import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Night light toggle for the OSD. While the night light is on, hovering the
// button reveals a colour temperature slider (drag or scroll to change it).
Item {
    id: root

    property int hoverDelay: 800

    readonly property bool wantSlider: NightLightState.active && hover.hovered

    onWantSliderChanged: {
        if (wantSlider) {
            hoverTimer.restart();
        } else {
            hoverTimer.stop();
            tempSliderLoader.shouldBeActive = false;
        }
    }

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    HoverHandler {
        id: hover
    }

    Timer {
        id: hoverTimer

        interval: root.hoverDelay
        onTriggered: tempSliderLoader.shouldBeActive = root.wantSlider
    }

    ColumnLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.medium

        IconButton {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Tokens.sizes.osd.sliderWidth
            implicitHeight: Tokens.sizes.osd.sliderWidth

            icon: NightLightState.active ? "brightness_3" : "dark_mode"
            font: Tokens.font.icon.builders.large.scale(0.85).build()
            radius: Tokens.rounding.large

            // Off: no background, light glyph. On: filled.
            inactiveColour: NightLightState.active ? Colours.palette.m3primary : "transparent"
            inactiveOnColour: NightLightState.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface

            onClicked: NightLightState.toggle()
        }

        WrappedLoader {
            id: tempSliderLoader

            shouldBeActive: false

            sourceComponent: CustomMouseArea {
                function onWheel(event: WheelEvent) {
                    if (event.angleDelta.y > 0)
                        NightLightState.setFraction(NightLightState.fraction + 0.05);
                    else if (event.angleDelta.y < 0)
                        NightLightState.setFraction(NightLightState.fraction - 0.05);
                }

                implicitWidth: Tokens.sizes.osd.sliderWidth
                implicitHeight: Tokens.sizes.osd.sliderHeight

                FilledSlider {
                    anchors.fill: parent

                    icon: "thermostat"
                    value: NightLightState.fraction

                    onMoved: NightLightState.setFraction(value)
                }
            }
        }
    }

    // Same as the WrappedLoader in Content.qml, duplicated so this file stays
    // self-contained.
    component WrappedLoader: Loader {
        required property bool shouldBeActive

        asynchronous: true
        Layout.preferredHeight: shouldBeActive ? Tokens.sizes.osd.sliderHeight : 0
        opacity: shouldBeActive ? 1 : 0
        active: opacity > 0
        visible: active

        Behavior on Layout.preferredHeight {
            Anim {
                type: Anim.Emphasized
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }
}
