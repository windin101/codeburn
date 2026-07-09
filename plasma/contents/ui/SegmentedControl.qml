import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: control
    implicitHeight: Math.max(28, Kirigami.Theme.defaultFont.pointSize * 2.5)
    Layout.fillWidth: true

    property var model: []
    property int currentIndex: 0
    property var colors: ({})

    signal indexSelected(int index)

    Rectangle {
        anchors.fill: parent
        color: Kirigami.Theme.textColor
        opacity: 0.05
        radius: 6
    }

    // Sliding indicator
    Rectangle {
        id: indicator
        y: 2
        height: parent.height - 4
        width: (control.width - 4) / Math.max(1, control.model.length)
        x: 2 + control.currentIndex * width
        color: Kirigami.Theme.isDarkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(255, 255, 255, 0.85)
        radius: 5
        border.color: Kirigami.Theme.isDarkMode ? Qt.rgba(255, 255, 255, 0.1) : Qt.rgba(0, 0, 0, 0.05)
        border.width: 1
        
        Behavior on x {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 2
        spacing: 0

        Repeater {
            model: control.model
            delegate: Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Text {
                    anchors.centerIn: parent
                    text: modelData
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize
                    font.bold: control.currentIndex === index
                    color: Kirigami.Theme.textColor
                    opacity: control.currentIndex === index ? 1.0 : 0.6
                    
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        control.currentIndex = index;
                        control.indexSelected(index);
                        if (typeof root !== "undefined" && typeof root.checkCacheAndFetch === "function") {
                            root.checkCacheAndFetch(true, false);
                        }
                    }
                }
            }
        }
    }
}
