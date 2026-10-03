import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls

// Night light toggle for the OSD. Hovering for 5 seconds reveals a colour
// temperature slider (0-100 maps to 2500K-6500K).
Item {
    id: root

    property bool isActive: false
    property real currentTemp: 4000

    function applyTemp(temp: real): void {
        Quickshell.execDetached(["hyprsunset", "-t", String(Math.round(temp))]);
    }

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                hoverTimer.start();
            } else {
                hoverTimer.stop();
                tempSliderLoader.shouldBeActive = false;
            }
        }
    }

    Timer {
        id: hoverTimer

        interval: 5000
        onTriggered: tempSliderLoader.shouldBeActive = true
    }

    ColumnLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.medium

        IconButton {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Tokens.sizes.osd.sliderWidth
            implicitHeight: Tokens.sizes.osd.sliderWidth

            icon: root.isActive ? "brightness_3" : "dark_mode"
            font: Tokens.font.icon.builders.large.scale(0.85).build()
            radius: Tokens.rounding.large

            // Darker backdrop while the night light is off
            Rectangle {
                z: -1
                anchors.fill: parent
                radius: parent.radius
                color: root.isActive ? "transparent" : Qt.rgba(0, 0, 0, 0.4)
            }

            onClicked: {
                root.isActive = !root.isActive;
                if (root.isActive)
                    root.applyTemp(root.currentTemp);
                else
                    Quickshell.execDetached(["pkill", "hyprsunset"]);
            }
        }

        WrappedLoader {
            id: tempSliderLoader

            shouldBeActive: false

            sourceComponent: CustomMouseArea {
                function onWheel(event: WheelEvent) {
                    if (event.angleDelta.y > 0)
                        tempSlider.value = Math.min(tempSlider.to, tempSlider.value + 5);
                    else if (event.angleDelta.y < 0)
                        tempSlider.value = Math.max(tempSlider.from, tempSlider.value - 5);
                }

                implicitWidth: Tokens.sizes.osd.sliderWidth
                implicitHeight: Tokens.sizes.osd.sliderHeight

                FilledSlider {
                    id: tempSlider

                    anchors.fill: parent

                    icon: "thermostat"
                    from: 0
                    to: 100
                    value: 37.5 // 4000K

                    onMoved: {
                        root.currentTemp = 2500 + (value / 100) * 4000;
                        if (root.isActive)
                            root.applyTemp(root.currentTemp);
                    }
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
