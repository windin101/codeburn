import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.kirigami 2.20 as Kirigami

ColumnLayout {
    id: root
    spacing: 6
    Layout.fillWidth: true

    property var tools: []
    property var skills: []
    property var subagents: []
    property var mcpServers: []
    property var colors: ({})

    property real maxTools: { var m = 0; var arr = root.tools || []; for (var i = 0; i < arr.length; i++) { if ((arr[i].calls || 0) > m) m = arr[i].calls || 0; } return m || 0.0001; }
    property real maxSkills: { var m = 0; var arr = root.skills || []; for (var i = 0; i < arr.length; i++) { if ((arr[i].cost || 0) > m) m = arr[i].cost || 0; } return m || 0.0001; }
    property real maxSubagents: { var m = 0; var arr = root.subagents || []; for (var i = 0; i < arr.length; i++) { if ((arr[i].cost || 0) > m) m = arr[i].cost || 0; } return m || 0.0001; }
    property real maxMcpServers: { var m = 0; var arr = root.mcpServers || []; for (var i = 0; i < arr.length; i++) { if ((arr[i].calls || 0) > m) m = arr[i].calls || 0; } return m || 0.0001; }

    Text {
        text: "TOOLING & AGENTS"
        font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
        font.bold: true
        color: Kirigami.Theme.textColor
        opacity: 0.6
    }

    TabBar {
        id: toolingTabBar
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(26, Kirigami.Theme.defaultFont.pointSize * 2.3)
        
        background: Item {}

        TabButton {
            text: "Tools (" + root.tools.length + ")"
            font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
            height: parent.height
        }
        TabButton {
            text: "Skills (" + root.skills.length + ")"
            font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
            height: parent.height
        }
        TabButton {
            text: "Subagents (" + root.subagents.length + ")"
            font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
            height: parent.height
        }
        TabButton {
            text: "MCP (" + root.mcpServers.length + ")"
            font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
            height: parent.height
        }
    }

    StackLayout {
        currentIndex: toolingTabBar.currentIndex
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(68, Kirigami.Theme.defaultFont.pointSize * 5.8)
        clip: true

        ColumnLayout {
            spacing: 3
            Text {
                visible: root.tools.length === 0
                text: "No tool calls"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize
                font.italic: true
                color: Kirigami.Theme.textColor
                opacity: 0.5
                Layout.leftMargin: 4
            }
            Repeater {
                model: root.tools ? root.tools.slice(0, 5) : []
                delegate: RowLayout {
                    Layout.fillWidth: true
                    Item {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
                        Layout.preferredHeight: 4
                        Layout.alignment: Qt.AlignVCenter
                        Rectangle { anchors.fill: parent; color: Kirigami.Theme.textColor; opacity: 0.1; radius: 2 }
                        Rectangle { height: parent.height; width: !modelData ? 0 : Math.min(parent.width, Math.max(0, parent.width * ((modelData.calls || 0) / root.maxTools))); color: root.colors.primaryBrand || Kirigami.Theme.highlightColor; radius: 2 }
                    }
                    Text { text: modelData ? (modelData.name || "") : ""; font.pointSize: Kirigami.Theme.defaultFont.pointSize; color: Kirigami.Theme.textColor; elide: Text.ElideRight; Layout.fillWidth: true; Layout.alignment: Qt.AlignBaseline }
                    Text { text: (modelData ? (modelData.calls || 0) : 0) + " calls"; font.pointSize: Kirigami.Theme.defaultFont.pointSize; color: Kirigami.Theme.textColor; opacity: 0.7; Layout.alignment: Qt.AlignRight | Qt.AlignBaseline }
                }
            }
            Item { Layout.fillHeight: true }
        }

        ColumnLayout {
            spacing: 3
            Text {
                visible: root.skills.length === 0
                text: "No skill usages"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize
                font.italic: true
                color: Kirigami.Theme.textColor
                opacity: 0.5
                Layout.leftMargin: 4
            }
            Repeater {
                model: root.skills ? root.skills.slice(0, 5) : []
                delegate: RowLayout {
                    Layout.fillWidth: true
                    Item {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
                        Layout.preferredHeight: 4
                        Layout.alignment: Qt.AlignVCenter
                        Rectangle { anchors.fill: parent; color: Kirigami.Theme.textColor; opacity: 0.1; radius: 2 }
                        Rectangle { height: parent.height; width: !modelData ? 0 : Math.min(parent.width, Math.max(0, parent.width * ((modelData.cost || 0) / root.maxSkills))); color: root.colors.primaryBrand || Kirigami.Theme.highlightColor; radius: 2 }
                    }
                    Text { text: modelData ? (modelData.name || "") : ""; font.pointSize: Kirigami.Theme.defaultFont.pointSize; color: Kirigami.Theme.textColor; elide: Text.ElideRight; Layout.fillWidth: true; Layout.alignment: Qt.AlignBaseline }
                    Text { text: (modelData ? (modelData.turns || 0) : 0) + " turns"; font.pointSize: Kirigami.Theme.defaultFont.pointSize - 0.5; color: Kirigami.Theme.textColor; opacity: 0.5; Layout.alignment: Qt.AlignRight | Qt.AlignBaseline }
                    Text { text: "$" + Number(modelData ? (modelData.cost || 0) : 0).toFixed(2); font.pointSize: Kirigami.Theme.defaultFont.pointSize; font.bold: true; color: Kirigami.Theme.textColor; Layout.alignment: Qt.AlignRight | Qt.AlignBaseline }
                }
            }
            Item { Layout.fillHeight: true }
        }

        ColumnLayout {
            spacing: 3
            Text {
                visible: root.subagents.length === 0
                text: "No subagents spawned"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize
                font.italic: true
                color: Kirigami.Theme.textColor
                opacity: 0.5
                Layout.leftMargin: 4
            }
            Repeater {
                model: root.subagents ? root.subagents.slice(0, 5) : []
                delegate: RowLayout {
                    Layout.fillWidth: true
                    Item {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
                        Layout.preferredHeight: 4
                        Layout.alignment: Qt.AlignVCenter
                        Rectangle { anchors.fill: parent; color: Kirigami.Theme.textColor; opacity: 0.1; radius: 2 }
                        Rectangle { height: parent.height; width: !modelData ? 0 : Math.min(parent.width, Math.max(0, parent.width * ((modelData.cost || 0) / root.maxSubagents))); color: root.colors.primaryBrand || Kirigami.Theme.highlightColor; radius: 2 }
                    }
                    Text { text: modelData ? (modelData.name || "") : ""; font.pointSize: Kirigami.Theme.defaultFont.pointSize; color: Kirigami.Theme.textColor; elide: Text.ElideRight; Layout.fillWidth: true; Layout.alignment: Qt.AlignBaseline }
                    Text { text: (modelData ? (modelData.calls || 0) : 0) + " calls"; font.pointSize: Kirigami.Theme.defaultFont.pointSize - 0.5; color: Kirigami.Theme.textColor; opacity: 0.5; Layout.alignment: Qt.AlignRight | Qt.AlignBaseline }
                    Text { text: "$" + Number(modelData ? (modelData.cost || 0) : 0).toFixed(2); font.pointSize: Kirigami.Theme.defaultFont.pointSize; font.bold: true; color: Kirigami.Theme.textColor; Layout.alignment: Qt.AlignRight | Qt.AlignBaseline }
                }
            }
            Item { Layout.fillHeight: true }
        }

        ColumnLayout {
            spacing: 3
            Text {
                visible: root.mcpServers.length === 0
                text: "No MCP interactions"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize
                font.italic: true
                color: Kirigami.Theme.textColor
                opacity: 0.5
                Layout.leftMargin: 4
            }
            Repeater {
                model: root.mcpServers ? root.mcpServers.slice(0, 5) : []
                delegate: RowLayout {
                    Layout.fillWidth: true
                    Item {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
                        Layout.preferredHeight: 4
                        Layout.alignment: Qt.AlignVCenter
                        Rectangle { anchors.fill: parent; color: Kirigami.Theme.textColor; opacity: 0.1; radius: 2 }
                        Rectangle { height: parent.height; width: !modelData ? 0 : Math.min(parent.width, Math.max(0, parent.width * ((modelData.calls || 0) / root.maxMcpServers))); color: root.colors.primaryBrand || Kirigami.Theme.highlightColor; radius: 2 }
                    }
                    Text { text: modelData ? (modelData.name || "") : ""; font.pointSize: Kirigami.Theme.defaultFont.pointSize; color: Kirigami.Theme.textColor; elide: Text.ElideRight; Layout.fillWidth: true; Layout.alignment: Qt.AlignBaseline }
                    Text { text: (modelData ? (modelData.calls || 0) : 0) + " calls"; font.pointSize: Kirigami.Theme.defaultFont.pointSize; color: Kirigami.Theme.textColor; opacity: 0.7; Layout.alignment: Qt.AlignRight | Qt.AlignBaseline }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }
}
