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
