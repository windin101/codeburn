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

    function getTotalTokens() {
        if (!root.bucketedTrendData) return 0;
        var total = 0;
        for (var i = 0; i < root.bucketedTrendData.length; i++) {
            total += (root.bucketedTrendData[i].inputTokens || 0) + (root.bucketedTrendData[i].outputTokens || 0);
        }
        return total;
    }

    property var bucketedTrendData: getBucketedTrendData(root.historyData, trendPeriodSwitcher.currentIndex)
    
    function getBucketedTrendData(historyArray, modeIndex) {
        if (!historyArray || historyArray.length === 0) return [];
        var res = [];
        if (modeIndex === 0) { // Days
            var startIdx = Math.max(0, historyArray.length - 30);
            return historyArray.slice(startIdx);
        } else if (modeIndex === 1) { // Weeks
            var currentChunk = [];
            var chunks = [];
            for (var i = historyArray.length - 1; i >= 0; i--) {
                currentChunk.unshift(historyArray[i]);
                if (currentChunk.length === 7 || i === 0) {
                    chunks.unshift(currentChunk);
                    currentChunk = [];
                }
                if (chunks.length >= 52) break;
            }
            for (var c = 0; c < chunks.length; c++) {
                var chunk = chunks[c];
                var cost = 0, input = 0, output = 0;
                for (var j = 0; j < chunk.length; j++) {
                    cost += chunk[j].cost || 0;
                    input += chunk[j].inputTokens || 0;
                    output += chunk[j].outputTokens || 0;
                }
                res.push({ date: chunk[0].date, cost: cost, inputTokens: input, outputTokens: output });
            }
            return res;
        } else if (modeIndex === 2) { // Months
            var monthMap = {};
            var monthKeys = [];
            for (var k = 0; k < historyArray.length; k++) {
                var prefix = historyArray[k].date.substring(0, 7);
                if (!monthMap[prefix]) {
                    monthMap[prefix] = { cost: 0, inputTokens: 0, outputTokens: 0, date: prefix };
                    monthKeys.push(prefix);
                }
                monthMap[prefix].cost += historyArray[k].cost || 0;
                monthMap[prefix].inputTokens += historyArray[k].inputTokens || 0;
                monthMap[prefix].outputTokens += historyArray[k].outputTokens || 0;
            }
            var startM = Math.max(0, monthKeys.length - 24);
            for (var m = startM; m < monthKeys.length; m++) {
                res.push(monthMap[monthKeys[m]]);
            }
            return res;
        }
        return historyArray;
    }

    property real maxTrendCost: {
        var m = 0.01;
        var d = bucketedTrendData || [];
        for (var i = 0; i < d.length; i++) {
            if (d[i].cost > m) m = d[i].cost;
        }
        if (plasmoid.configuration.dailyBudget > 0 && plasmoid.configuration.dailyBudget > m && trendPeriodSwitcher.currentIndex === 0) {
            m = plasmoid.configuration.dailyBudget;
        }
        return m;
    }
    
    property real adjustedTargetSpend: {
        var b = plasmoid.configuration.dailyBudget || 0;
        if (trendPeriodSwitcher.currentIndex === 1) return b * 7;
        if (trendPeriodSwitcher.currentIndex === 2) return b * 30.4;
        return b;
    }

    function formatTokens(t) {
        if (t >= 1e6) return (t / 1e6).toFixed(1) + "M tokens";
        if (t >= 1e3) return (t / 1e3).toFixed(1) + "K tokens";
        return t.toLocaleString() + " tokens";
    }

    SegmentedControl {
        id: insightSwitcher
        model: ["Trend", "Calendar", "Stats", "Optimize"]
        colors: root.colors
        highlightColor: root.colors.brandAccent
        highlightTextColor: "#FFFFFF"
    }

    StackLayout {
        id: insightStack
        currentIndex: insightSwitcher.currentIndex
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(173, Kirigami.Theme.defaultFont.pointSize * 14.25)

        Item {
            id: trendView
            Layout.fillWidth: true
            Layout.fillHeight: true

            Row {
                visible: root.bucketedTrendData.length > 0
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 4
                anchors.topMargin: 4
                spacing: 12
                z: 10

                Column {
                    spacing: 0
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: {
                            if (trendPeriodSwitcher.currentIndex === 0) return root.bucketedTrendData.length + (root.bucketedTrendData.length === 1 ? " Day" : " Days");
                            if (trendPeriodSwitcher.currentIndex === 1) return root.bucketedTrendData.length + (root.bucketedTrendData.length === 1 ? " Week" : " Weeks");
                            return root.bucketedTrendData.length + (root.bucketedTrendData.length === 1 ? " Month" : " Months");
                        }
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize - 2
                        color: Kirigami.Theme.textColor
                        opacity: 0.6
                    }
                    Text {
                        text: root.formatTokens(root.getTotalTokens())
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1
                        font.bold: true
                        color: Kirigami.Theme.textColor
                        opacity: 0.8
                    }
                }

                SegmentedControl {
                    id: trendPeriodSwitcher
                    width: 180
                    implicitHeight: Math.max(22, Kirigami.Theme.defaultFont.pointSize * 2)
                    anchors.verticalCenter: parent.verticalCenter
                    model: ["Days", "Weeks", "Months"]
                    colors: root.colors
                    highlightColor: root.colors.brandAccent
                    highlightTextColor: "#FFFFFF"
                }
            }

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
                visible: root.bucketedTrendData.length > 0

                Repeater {
                    model: root.bucketedTrendData
                    delegate: Rectangle {
                        width: (trendView.width - (root.bucketedTrendData.length * 3)) / Math.max(1, root.bucketedTrendData.length)
                        height: Math.max(4, (modelData.cost / Math.max(0.01, root.maxTrendCost)) * (trendView.height - 16))
                        anchors.bottom: parent.bottom
                        color: (root.adjustedTargetSpend > 0 && modelData.cost > root.adjustedTargetSpend && root.displayMetric === "cost") ? root.colors.semanticWarning : root.colors.brandAccent
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
                visible: root.adjustedTargetSpend > 0 && root.bucketedTrendData.length > 0 && root.displayMetric === "cost"
                anchors.left: parent.left
                anchors.right: parent.right
                y: Math.max(0, parent.height - Math.max(4, (root.adjustedTargetSpend / Math.max(0.01, root.maxTrendCost)) * (parent.height - 16)))
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
