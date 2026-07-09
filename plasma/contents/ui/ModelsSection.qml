import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.kirigami 2.20 as Kirigami

ColumnLayout {
    id: root
    spacing: 6
    Layout.fillWidth: true

    property var models: []
    property var colors: ({})
    property string displayMetric: "cost"

    property real maxMetric: {
        var m = 0;
        var arr = root.models || [];
        for (var i = 0; i < arr.length; i++) {
            var val = (root.displayMetric === "tokens" || root.displayMetric === "totalTokens") ? 
                      ((arr[i].inputTokens || 0) + (arr[i].outputTokens || 0)) : (arr[i].cost || 0);
            if (val > m) m = val;
        }
        return m || 0.0001;
    }
    Text {
        text: "TOP MODELS"
        font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
        font.bold: true
        color: Kirigami.Theme.textColor
        opacity: 0.6
    }

    Text {
        visible: root.models.length === 0
        text: "No model usage recorded"
        font.pointSize: Kirigami.Theme.defaultFont.pointSize
        font.italic: true
        color: Kirigami.Theme.textColor
        opacity: 0.5
        Layout.leftMargin: 4
    }

    ColumnLayout {
        spacing: 4
        Layout.fillWidth: true
        visible: root.models.length > 0

        Repeater {
            model: root.models ? root.models.slice(0, 5) : []
            delegate: RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Bar Graph
                Item {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
                    Layout.preferredHeight: 4
                    Layout.alignment: Qt.AlignVCenter
                    
                    Rectangle {
                        anchors.fill: parent
                        color: Kirigami.Theme.textColor
                        opacity: 0.1
                        radius: 2
                    }
                    Rectangle {
                        height: parent.height
                        width: {
                            if (!modelData) return 0;
                            var val = (root.displayMetric === "tokens" || root.displayMetric === "totalTokens") ? 
                                      ((modelData.inputTokens || 0) + (modelData.outputTokens || 0)) : (modelData.cost || 0);
                            return Math.min(parent.width, Math.max(0, parent.width * (val / root.maxMetric)));
                        }
                        color: root.colors.primaryBrand || Kirigami.Theme.highlightColor
                        radius: 2
                    }
                }
                Text {
                    text: modelData ? (modelData.name || "") : ""
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize
                    color: Kirigami.Theme.textColor
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignBaseline
                }

                Text {
                    text: (modelData ? (modelData.calls || 0) : 0) + "x"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize - 0.5
                    color: Kirigami.Theme.textColor
                    opacity: 0.7
                    Layout.alignment: Qt.AlignRight | Qt.AlignBaseline
                }

                Text {
                    text: {
                        if (!modelData) return "";
                        if (root.displayMetric === "tokens" || root.displayMetric === "totalTokens") {
                            var totalTok = (modelData.inputTokens || 0) + (modelData.outputTokens || 0);
                            if (totalTok >= 1e6) return (totalTok / 1e6).toFixed(1) + "M tok";
                            if (totalTok >= 1e3) return (totalTok / 1e3).toFixed(0) + "K tok";
                            return totalTok + " tok";
                        }
                        return "$" + Number(modelData.cost || 0).toFixed(2);
                    }
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize
                    font.bold: true
                    font.family: "monospace"
                    color: Kirigami.Theme.textColor
                    Layout.alignment: Qt.AlignRight | Qt.AlignBaseline
                }
            }
        }
    }
}
