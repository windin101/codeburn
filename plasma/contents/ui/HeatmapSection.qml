import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.kirigami 2.20 as Kirigami

ColumnLayout {
    id: root
    spacing: 8
    Layout.fillWidth: true

    property var historyData: []
    property double maxHistoryCost: 0.1
    property var payload: null
    property var colors: ({})
    property string displayMetric: "cost"

    function getAverageCost() {
        if (root.historyData.length === 0) return 0;
        var total = 0;
        for (var i = 0; i < root.historyData.length; i++) {
            total += root.historyData[i].cost;
        }
        return total / root.historyData.length;
    }

    SegmentedControl {
        id: insightSwitcher
        model: ["Trend", "Calendar", "Stats", "Optimize"]
        colors: root.colors
    }

    StackLayout {
        id: insightStack
        currentIndex: insightSwitcher.currentIndex
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(115, Kirigami.Theme.defaultFont.pointSize * 9.5)

        Item {
            id: trendView
            Layout.fillWidth: true
            Layout.fillHeight: true

            Text {
                visible: root.historyData.length === 0
                anchors.centerIn: parent
                text: "No historical data available"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize
                color: Kirigami.Theme.textColor
                opacity: 0.6
            }

            Row {
                anchors.fill: parent
                anchors.bottom: parent.bottom
                spacing: 3
                visible: root.historyData.length > 0

                Repeater {
                    model: root.historyData
                    delegate: Rectangle {
                        width: (trendView.width - (root.historyData.length * 3)) / Math.max(1, root.historyData.length)
                        height: Math.max(4, (modelData.cost / Math.max(0.01, root.maxHistoryCost)) * (trendView.height - 16))
                        anchors.bottom: parent.bottom
                        color: (plasmoid.configuration.dailyBudget > 0 && modelData.cost > plasmoid.configuration.dailyBudget && root.displayMetric === "cost") ? root.colors.semanticWarning : root.colors.brandAccent
                        opacity: hoverArea.containsMouse ? 1.0 : 0.7
                        radius: 2

                        MouseArea {
                            id: hoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            ToolTip.visible: containsMouse
                            ToolTip.text: modelData.date + "\n" + (root.displayMetric === "tokens" ? (modelData.inputTokens + modelData.outputTokens).toLocaleString() + " tok" : "$" + Number(modelData.cost).toFixed(2))
                        }
                    }
                }
            }

            // Dotted target line
            Row {
                visible: plasmoid.configuration.dailyBudget > 0 && root.historyData.length > 0 && root.displayMetric === "cost"
                anchors.left: parent.left
                anchors.right: parent.right
                y: Math.max(0, parent.height - Math.max(4, (plasmoid.configuration.dailyBudget / Math.max(0.01, root.maxHistoryCost)) * (parent.height - 16)))
                height: 2
                spacing: 4
                clip: true
                
                Repeater {
                    model: parent.width > 0 ? Math.floor(parent.width / 8) : 0
                    delegate: Rectangle {
                        width: 4
                        height: 2
                        color: root.colors.semanticWarning
                        opacity: 0.8
                    }
                }
            }
        }

        Item {
            id: calView
            Layout.fillWidth: true
            Layout.fillHeight: true

            Text {
                visible: root.historyData.length === 0
                anchors.centerIn: parent
                text: "No historical data available"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize
                color: Kirigami.Theme.textColor
                opacity: 0.6
            }

            GridLayout {
                anchors.centerIn: parent
                columns: 8
                rowSpacing: 4
                columnSpacing: 4
                visible: root.historyData.length > 0

                Repeater {
                    model: root.historyData
                    delegate: Rectangle {
                        width: 12
                        height: 12
                        radius: 2
                        
                        color: {
                            if (root.displayMetric === "tokens") {
                                var t = modelData.inputTokens + modelData.outputTokens;
                                if (t === 0) return root.colors.warmSurface;
                                return root.colors.brandAccent;
                            } else {
                                if (modelData.cost === 0) return root.colors.warmSurface;
                                return root.colors.brandAccent;
                            }
                        }
                        
                        opacity: {
                            if (root.displayMetric === "tokens") {
                                var t = modelData.inputTokens + modelData.outputTokens;
                                if (t === 0) return 0.2;
                                return Math.min(1.0, 0.3 + (t / 1e6));
                            } else {
                                if (modelData.cost === 0) return 0.2;
                                return Math.min(1.0, 0.3 + (modelData.cost / 5));
                            }
                        }

                        MouseArea {
                            id: calHover
                            anchors.fill: parent
                            hoverEnabled: true
                            ToolTip.visible: containsMouse
                            ToolTip.text: modelData.date + "\n" + (root.displayMetric === "tokens" ? (modelData.inputTokens + modelData.outputTokens).toLocaleString() + " tok" : "$" + Number(modelData.cost).toFixed(2))
                        }
                    }
                }
            }
        }

        ColumnLayout {
            spacing: 6
            Layout.fillWidth: true

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Average Daily Cost"; font.pointSize: Kirigami.Theme.defaultFont.pointSize; color: Kirigami.Theme.textColor; opacity: 0.6 }
                Item { Layout.fillWidth: true }
                Text { text: "$" + getAverageCost().toFixed(2); font.pointSize: Kirigami.Theme.defaultFont.pointSize; font.bold: true; color: Kirigami.Theme.textColor }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: "One-Shot Rate"; font.pointSize: Kirigami.Theme.defaultFont.pointSize; color: Kirigami.Theme.textColor; opacity: 0.6 }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.payload && root.payload.current.oneShotRate ? (Number(root.payload.current.oneShotRate * 100).toFixed(0) + "%") : "N/A"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize
                    font.bold: true
                    color: Kirigami.Theme.textColor
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Cache Hit Rate"; font.pointSize: Kirigami.Theme.defaultFont.pointSize; color: Kirigami.Theme.textColor; opacity: 0.6 }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.payload ? (Number(root.payload.current.cacheHitPercent).toFixed(1) + "%") : "N/A"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize
                    font.bold: true
                    color: Kirigami.Theme.textColor
                }
            }
        }

        ColumnLayout {
            spacing: 6
            Layout.fillWidth: true

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Potential Savings"; font.pointSize: Kirigami.Theme.defaultFont.pointSize; color: Kirigami.Theme.textColor; opacity: 0.6 }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.payload ? ("$" + Number(root.payload.optimize.savingsUSD).toFixed(2)) : "$0.00"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize
                    font.bold: true
                    color: root.colors.semanticSuccess
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Optimization Findings"; font.pointSize: Kirigami.Theme.defaultFont.pointSize; color: Kirigami.Theme.textColor; opacity: 0.6 }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.payload ? root.payload.optimize.findingCount + " findings" : "0 findings"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize
                    font.bold: true
                    color: Kirigami.Theme.textColor
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Routing Waste (Avoidable)"; font.pointSize: Kirigami.Theme.defaultFont.pointSize; color: Kirigami.Theme.textColor; opacity: 0.6 }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.payload ? ("$" + Number(root.payload.current.routingWaste.totalSavingsUSD).toFixed(2)) : "$0.00"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize
                    font.bold: true
                    color: root.colors.semanticWarning
                }
            }
        }
    }
}
