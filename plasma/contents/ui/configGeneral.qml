import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

Kirigami.FormLayout {
    id: form

    property alias cfg_currency: currencyCombo.currentText
    property alias cfg_displayMetric: metricCombo.currentValue
    property alias cfg_period: periodCombo.currentValue
    property alias cfg_scope: scopeCombo.currentValue
    property alias cfg_dailyBudget: dailyBudgetField.text
    property alias cfg_dailyTokenBudget: dailyTokenBudgetField.text
    property alias cfg_codeburnBin: binField.text

    ComboBox {
        id: currencyCombo
        Kirigami.FormData.label: "Display Currency"
        model: ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "NZD", "HKD", "SGD", "MXN", "CNY", "KRW", "INR", "BRL", "CHF", "SEK", "DKK", "ZAR"]
    }

    ComboBox {
        id: metricCombo
        Kirigami.FormData.label: "Display Metric"
        textRole: "text"
        valueRole: "value"
        model: [
            { text: "Cost ($)", value: "cost" },
            { text: "Tokens (↑↓)", value: "tokens" },
            { text: "Total Tokens", value: "totalTokens" },
            { text: "Credits (Codex)", value: "credits" },
            { text: "Icon Only", value: "iconOnly" }
        ]
        
        Component.onCompleted: {
            currentIndex = indexOfValue(plasmoid.configuration.displayMetric);
        }
    }

    ComboBox {
        id: periodCombo
        Kirigami.FormData.label: "Default Period"
        textRole: "text"
        valueRole: "value"
        model: [
            { text: "Today", value: "today" },
            { text: "7 Days", value: "week" },
            { text: "30 Days", value: "30days" },
            { text: "Month", value: "month" },
            { text: "All Time", value: "all" }
        ]
        Component.onCompleted: {
            currentIndex = indexOfValue(plasmoid.configuration.period);
        }
    }

    ComboBox {
        id: scopeCombo
        Kirigami.FormData.label: "Default Scope"
        textRole: "text"
        valueRole: "value"
        model: [
            { text: "Local", value: "local" },
            { text: "Combined", value: "combined" }
        ]
        Component.onCompleted: {
            currentIndex = indexOfValue(plasmoid.configuration.scope);
        }
    }

    TextField {
        id: dailyBudgetField
        Kirigami.FormData.label: "Target Spend / Budget ($)"
        placeholderText: "0.00"
        validator: DoubleValidator { bottom: 0.0 }
    }

    TextField {
        id: dailyTokenBudgetField
        Kirigami.FormData.label: "Daily Token Budget"
        placeholderText: "0"
        validator: DoubleValidator { bottom: 0.0 }
    }

    TextField {
        id: binField
        Kirigami.FormData.label: "CodeBurn CLI Binary Path"
        placeholderText: "codeburn"
    }
}
