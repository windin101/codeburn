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
                model: root.tools ? root.tools.slice(0, 3) : []
                delegate: RowLayout {
                    Layout.fillWidth: true
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
                model: root.skills ? root.skills.slice(0, 3) : []
                delegate: RowLayout {
                    Layout.fillWidth: true
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
                model: root.subagents ? root.subagents.slice(0, 3) : []
                delegate: RowLayout {
                    Layout.fillWidth: true
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
                model: root.mcpServers ? root.mcpServers.slice(0, 3) : []
                delegate: RowLayout {
                    Layout.fillWidth: true
                    Text { text: modelData ? (modelData.name || "") : ""; font.pointSize: Kirigami.Theme.defaultFont.pointSize; color: Kirigami.Theme.textColor; elide: Text.ElideRight; Layout.fillWidth: true; Layout.alignment: Qt.AlignBaseline }
                    Text { text: (modelData ? (modelData.calls || 0) : 0) + " calls"; font.pointSize: Kirigami.Theme.defaultFont.pointSize; color: Kirigami.Theme.textColor; opacity: 0.7; Layout.alignment: Qt.AlignRight | Qt.AlignBaseline }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }
}
