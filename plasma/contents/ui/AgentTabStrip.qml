import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: root
    implicitHeight: Math.max(48, Kirigami.Theme.defaultFont.pointSize * 4.4)
    Layout.fillWidth: true

    property var providers: []
    property var providerCosts: ({})
    property string activeProvider: "all"
    property var colors: ({})

    signal providerSelected(string provider)

    function getProviderLabel(key) {
        if (key === "all") return "All Tools";
        if (key === "claude") return "Claude";
        if (key === "cursor") return "Cursor";
        if (key === "codex") return "Codex";
        if (key === "devin") return "Devin";
        if (key === "gemini") return "Gemini";
        return key.charAt(0).toUpperCase() + key.slice(1);
    }

    function formatCost(cost) {
        if (!cost) return "$0.00";
        return "$" + Number(cost).toFixed(2);
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Button {
            id: leftArrow
            visible: flickable.contentWidth > flickable.width
            enabled: flickable.contentX > 0
            text: "<"
            flat: true
            Layout.preferredWidth: 20
            Layout.fillHeight: true
            onClicked: flickable.contentX = Math.max(0, flickable.contentX - 100)
        }

        Flickable {
            id: flickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: tabRow.width
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: tabRow
                height: parent.height
                spacing: 6
                padding: 4
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: root.providers
                    delegate: Button {
                        id: tabButton
                        height: parent.height - 8
                        flat: true
                        
                        leftPadding: 12
                        rightPadding: 12
                        topPadding: 4
                        bottomPadding: 4
                        
                        property bool isActive: root.activeProvider === modelData
                        
                        background: Rectangle {
                            color: tabButton.isActive 
                                ? root.colors.brandAccent 
                                : (tabButton.hovered ? Qt.rgba(128, 128, 128, 0.15) : "transparent")
                            radius: 6
                            border.color: tabButton.isActive ? "transparent" : Kirigami.Theme.focusColor
                            border.width: 1
                            opacity: tabButton.isActive ? 1.0 : 0.3
                        }

                        contentItem: ColumnLayout {
                            spacing: 1
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            
                            Text {
                                text: root.getProviderLabel(modelData)
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                                font.bold: tabButton.isActive
                                color: tabButton.isActive ? "#FFFFFF" : Kirigami.Theme.textColor
                                Layout.alignment: Qt.AlignHCenter
                            }
                            
                            Text {
                                text: root.formatCost(root.providerCosts[modelData])
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize - 2.5
                                font.family: "monospace"
                                color: tabButton.isActive ? "#FFFFFF" : Kirigami.Theme.textColor
                                opacity: tabButton.isActive ? 0.8 : 0.6
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }

                        onClicked: {
                            root.providerSelected(modelData);
                        }
                    }
                }
            }
        }

        Button {
            id: rightArrow
            visible: flickable.contentWidth > flickable.width
            enabled: flickable.contentX < (flickable.contentWidth - flickable.width - 2)
            text: ">"
            flat: true
            Layout.preferredWidth: 20
            Layout.fillHeight: true
            onClicked: flickable.contentX = Math.min(flickable.contentWidth - flickable.width, flickable.contentX + 100)
        }
    }
}
