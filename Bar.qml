import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

Scope {
Variants {
    model: Quickshell.screens;
    delegate: Component {
        PanelWindow {
            required property var modelData
            screen: modelData

            anchors {
                bottom: true
                left: true
                right: true
            }
            implicitHeight: 30
            RowLayout {
                anchors.fill: parent
                anchors.margins: 8

                Repeater {
                    model: Hyprland.workspaces
                    delegate: Text {
                        text: modelData.name
                        
                    }
                }
            Text {
                Layout.alignment: Qt.AlignCenter
                text: "Hello Fenyx"
            }

            Item {
                Layout.fillWidth: true
            }
            ClockWidget {
                Layout.alignment: Qt.AlignVCenter
            }

        }
        }

    }
}

}
