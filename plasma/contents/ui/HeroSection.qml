import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.kirigami 2.20 as Kirigami

ColumnLayout {
    id: root
    spacing: 6
    Layout.fillWidth: true

    property string caption: ""
    property string heroText: ""
    property string displayMetric: "cost"
    property var totals: ({})
    property bool budgetWarning: false
    property string budgetText: ""
    property string savingsText: ""
    property var combinedUsage: null
    property var colors: ({})
    property string currencyCode: ""

    function formatNumber(num) {
        if (num === undefined) return "0";
        return Number(num).toLocaleString(Qt.locale(), 'f', 0);
    }

    function formatCompactTokens(num) {
        if (num === undefined) return "0";
        if (num >= 1e9) return (num / 1e9).toFixed(1) + "B";
        if (num >= 1e6) return (num / 1e6).toFixed(1) + "M";
        if (num >= 1e3) return (num / 1e3).toFixed(0) + "K";
        return num.toFixed(0);
    }

    function formatCurrency(num) {
        if (num === undefined) return "$0.00";
        return "$" + Number(num).toFixed(2);
    }

    Text {
        text: root.caption.toUpperCase()
        font.pointSize: Kirigami.Theme.defaultFont.pointSize - 2
        font.bold: true
        color: Kirigami.Theme.textColor
        opacity: 0.6
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        RowLayout {
            spacing: 4
            Layout.fillWidth: true

            Text {
                text: root.heroText
                font.pointSize: Kirigami.Theme.defaultFont.pointSize + 22
                font.family: Kirigami.Theme.defaultFont.family
                font.bold: true
                color: root.colors.brandAccent
            }

            Text {
                visible: root.displayMetric === "cost" && root.currencyCode !== ""
                text: root.currencyCode
                font.pointSize: Kirigami.Theme.defaultFont.pointSize
                font.bold: true
                color: root.colors.brandAccent
                opacity: 0.6
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 6
            }

            Item { Layout.fillWidth: true }
        }

        ColumnLayout {
            spacing: 1
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

            ColumnLayout {
                visible: root.displayMetric === "tokens" || root.displayMetric === "totalTokens"
                spacing: 1
                Layout.alignment: Qt.AlignRight

                RowLayout {
                    spacing: 2
                    Layout.alignment: Qt.AlignRight
                    Text { text: "↑"; font.pointSize: Kirigami.Theme.defaultFont.pointSize - 2; color: Kirigami.Theme.textColor; opacity: 0.6 }
                    Text {
                        text: root.formatCompactTokens(root.totals.outputTokens)
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize
                        font.family: "monospace"
                        color: Kirigami.Theme.textColor
                        opacity: 0.7
                    }
                }
                RowLayout {
                    spacing: 2
                    Layout.alignment: Qt.AlignRight
                    Text { text: "↓"; font.pointSize: Kirigami.Theme.defaultFont.pointSize - 2; color: Kirigami.Theme.textColor; opacity: 0.4 }
                    Text {
                        text: root.formatCompactTokens(root.totals.inputTokens)
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize - 0.5
                        font.family: "monospace"
                        color: Kirigami.Theme.textColor
                        opacity: 0.5
                    }
                }
            }

            ColumnLayout {
                visible: root.displayMetric !== "tokens" && root.displayMetric !== "totalTokens"
                spacing: 1
                Layout.alignment: Qt.AlignRight

                Text {
                    text: root.formatNumber(root.totals.calls) + " calls"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize
                    font.family: "monospace"
                    color: Kirigami.Theme.textColor
                    opacity: 0.7
                    Layout.alignment: Qt.AlignRight
                }
                Text {
                    text: root.formatNumber(root.totals.sessions) + " sessions"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize - 0.5
                    font.family: "monospace"
                    color: Kirigami.Theme.textColor
                    opacity: 0.5
                    Layout.alignment: Qt.AlignRight
                }
            }
        }
    }

    RowLayout {
        visible: root.budgetWarning
        spacing: 4
        Layout.topMargin: 2

        Text {
            text: "⚠️"
            font.pointSize: Kirigami.Theme.defaultFont.pointSize
        }
        Text {
            text: root.budgetText
            font.pointSize: Kirigami.Theme.defaultFont.pointSize
            font.bold: true
            color: root.colors.semanticWarning
        }
    }

    RowLayout {
        visible: root.savingsText !== ""
        spacing: 4

        Text {
            text: "🍃"
            font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
        }
        Text {
            text: root.savingsText
            font.pointSize: Kirigami.Theme.defaultFont.pointSize
            font.bold: true
            color: root.colors.semanticSuccess
        }
    }

    ColumnLayout {
        visible: root.combinedUsage !== null && root.combinedUsage !== undefined
        spacing: 4
        Layout.fillWidth: true
        Layout.topMargin: 4

        RowLayout {
            spacing: 4
            Text { text: "💻"; font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1 }
            Text {
                text: root.combinedUsage ? (root.combinedUsage.combined.reachableCount + " of " + root.combinedUsage.combined.deviceCount + " devices") : ""
                font.pointSize: Kirigami.Theme.defaultFont.pointSize
                font.bold: true
                color: Kirigami.Theme.textColor
                opacity: 0.7
            }
        }

        ColumnLayout {
            spacing: 3
            Layout.fillWidth: true

            Repeater {
                model: root.combinedUsage ? root.combinedUsage.perDevice : []
                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        width: 5
                        height: 5
                        radius: 2.5
                        color: modelData.error ? root.colors.semanticDanger : Kirigami.Theme.textColor
                        opacity: modelData.error ? 1.0 : 0.4
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        text: modelData.local ? (modelData.name + " · local") : modelData.name
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize - 0.5
                        font.bold: true
                        color: Kirigami.Theme.textColor
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: modelData.error ? "Unavailable" : root.formatCurrency(modelData.cost)
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize - 0.5
                        font.family: "monospace"
                        color: Kirigami.Theme.textColor
                        opacity: 0.7
                    }

                    Text {
                        text: root.formatCompactTokens(modelData.totalTokens)
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                        font.family: "monospace"
                        color: Kirigami.Theme.textColor
                        opacity: 0.5
                    }
                }
            }
        }
    }
}
