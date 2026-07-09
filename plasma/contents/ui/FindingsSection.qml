import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.kirigami 2.20 as Kirigami

ColumnLayout {
    id: root
    spacing: 6
    Layout.fillWidth: true

    property var findings: []
    property var colors: ({})

    Text {
        text: "OPTIMIZATION FINDINGS"
        font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
        font.bold: true
        color: Kirigami.Theme.textColor
        opacity: 0.6
    }

    Text {
        visible: root.findings.length === 0
        text: "No optimization findings"
        font.pointSize: Kirigami.Theme.defaultFont.pointSize
        font.italic: true
        color: Kirigami.Theme.textColor
        opacity: 0.5
        Layout.leftMargin: 4
    }

    ColumnLayout {
        spacing: 5
        Layout.fillWidth: true
        visible: root.findings.length > 0

        Repeater {
            model: root.findings ? root.findings.slice(0, 3) : []
            delegate: ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: modelData.title
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize
                        font.bold: true
                        color: Kirigami.Theme.textColor
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignBaseline
                    }

                    Text {
                        text: "Saved $" + Number(modelData.savingsUSD).toFixed(2)
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize - 0.5
                        font.bold: true
                        color: root.colors.semanticSuccess
                        Layout.alignment: Qt.AlignRight | Qt.AlignBaseline
                    }
                }

                Text {
                    text: modelData.impact
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize - 0.5
                    color: Kirigami.Theme.textColor
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }
    }
}
