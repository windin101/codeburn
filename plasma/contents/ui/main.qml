import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.plasma5support 2.0 as Plasma5Support
import "theme.js" as Theme

PlasmoidItem {
    id: root
    width: Kirigami.Units.gridUnit * 25
    height: Kirigami.Units.gridUnit * 35

    // Measure panel text size to dynamically size root implicitWidth
    Text {
        id: compactTextMeasurer
        visible: false
        text: root.panelText
        font.pointSize: Kirigami.Theme.defaultFont.pointSize
        font.bold: true
    }

    property real compactWidth: {
        var iconSize = 16;
        var spacing = 6;
        var hasText = (plasmoid && plasmoid.configuration && plasmoid.configuration.displayMetric !== "iconOnly" && root.panelText !== "");
        var textWidth = hasText ? compactTextMeasurer.implicitWidth : 0;
        var padding = 16; // 8px on left, 8px on right
        return iconSize + (textWidth > 0 ? (spacing + textWidth) : 0) + padding;
    }

    implicitWidth: root.compactWidth
    implicitHeight: parent ? parent.height : 24

    // Design Tokens & Colors
    property var colors: {
        var base = Theme.getColors(Kirigami.Theme.isDarkMode);
        base.textColor = Kirigami.Theme.textColor;
        base.textSecondaryColor = Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.7);
        base.textTertiaryColor = Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.55);
        base.brandAccent = Kirigami.Theme.highlightColor;
        base.brandMuted = Qt.rgba(base.brandAccent.r, base.brandAccent.g, base.brandAccent.b, 0.2);
        
        base.semanticWarning = "#F5A623";
        base.semanticDanger = Kirigami.Theme.negativeTextColor;
        base.semanticSuccess = Kirigami.Theme.positiveTextColor;
        base.borderColor = Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15);
        
        return base;
    }

    
    // Core data cache
    property var payloadCache: ({})
    property var currentPayload: null
    property bool isFetching: false
    property string lastError: ""
    
    // FX Rates
    property double exchangeRate: 1.0
    property string currencySymbol: "$"

    // State selections (mirrored from configuration)
    property string activePeriod: plasmoid.configuration.period || "today"
    property string activeProvider: "all"
    property string activeScope: plasmoid.configuration.scope || "local"
    
    // Derived UI properties
    property double activeCost: 0.0
    property int activeCalls: 0
    property int activeSessions: 0
    property int inputTokens: 0
    property int outputTokens: 0
    property int totalTokens: 0
    
    property var topModels: []
    property var topProjects: []
    property var topActivities: []
    property var topFindings: []
    
    property var tools: []
    property var skills: []
    property var subagents: []
    property var mcpServers: []
    
    property var historyData: []
    property double maxHistoryCost: 0.1
    
    // Budget warnings
    property double activeDailyBudget: {
        var metric = plasmoid.configuration.displayMetric || "cost";
        if (metric === "tokens" || metric === "totalTokens") {
            return plasmoid.configuration.dailyTokenBudget || 0.0;
        }
        return plasmoid.configuration.dailyBudget || 0.0;
    }
    
    property bool isOverDailyBudget: {
        if (root.activeDailyBudget <= 0) return false;
        if (root.activeScope !== "local") return false;
        
        var todayVal = 0.0;
        var todayPayload = root.payloadCache[root.getCacheKey("today", "all", "local")];
        if (todayPayload && todayPayload.payload && todayPayload.payload.current) {
            var metric = plasmoid.configuration.displayMetric || "cost";
            if (metric === "tokens" || metric === "totalTokens") {
                todayVal = todayPayload.payload.current.inputTokens + todayPayload.payload.current.outputTokens;
            } else {
                todayVal = todayPayload.payload.current.cost;
            }
        }
        return todayVal >= root.activeDailyBudget;
    }

    property string panelText: {
        var metric = plasmoid.configuration.displayMetric || "cost";
        if (metric === "iconOnly") return "";
        
        if (metric === "tokens" || metric === "totalTokens") {
            return root.formatCompactTokens(root.totalTokens) + " tok";
        }
        if (metric === "credits" && root.currentPayload && root.currentPayload.current.codexCredits !== null) {
            return Number(root.currentPayload.current.codexCredits).toFixed(0) + " cr";
        }
        return root.formatCurrency(root.activeCost);
    }

    // Cache management
    function getCacheKey(period, provider, scope) {
        return period + ":" + provider + ":" + scope;
    }

    function getCachedData(period, provider, scope) {
        var key = root.getCacheKey(period, provider, scope);
        var entry = root.payloadCache[key];
        if (entry && (Date.now() - entry.fetchedAt < 30000)) {
            return entry.payload;
        }
        return null;
    }

    function checkCacheAndFetch(forceRefresh, forceOptimize) {
        var cached = root.getCachedData(root.activePeriod, root.activeProvider, root.activeScope);
        if (cached && !forceRefresh) {
            root.currentPayload = cached;
            root.updateUI();
        } else {
            root.fetchCLI(root.activePeriod, root.activeProvider, root.activeScope, forceOptimize);
        }
    }

    // Formatters
    function formatCurrency(usdAmount) {
        var amt = usdAmount * root.exchangeRate;
        return root.currencySymbol + Number(amt).toLocaleString(Qt.locale(), 'f', 2);
    }

    function formatNumber(num) {
        return Number(num).toLocaleString(Qt.locale(), 'f', 0);
    }

    function formatCompactTokens(num) {
        if (num >= 1e9) return (num / 1e9).toFixed(1) + "B";
        if (num >= 1e6) return (num / 1e6).toFixed(1) + "M";
        if (num >= 1e3) return (num / 1e3).toFixed(0) + "K";
        return Number(num).toFixed(0);
    }

    // Process executor
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
            root.isFetching = false;
            
            var stdout = data["stdout"] || "";
            var stderr = data["stderr"] || "";
            
            if (stdout.trim().length === 0) {
                root.lastError = "CLI returned empty output. Stderr: " + stderr;
                return;
            }
            
            try {
                var payload = JSON.parse(stdout);
                if (payload.error) {
                    root.lastError = payload.error;
                } else {
                    root.lastError = "";
                    var cacheKey = root.getCacheKey(root.activePeriod, root.activeProvider, root.activeScope);
                    root.payloadCache[cacheKey] = {
                        payload: payload,
                        fetchedAt: Date.now()
                    };
                    root.currentPayload = payload;
                    root.updateUI();
                }
            } catch (e) {
                root.lastError = "JSON Parse Error: " + e.message + "\nStdout snippet: " + stdout.substring(0, 150);
            }
        }
    }

    // Fire-and-forget process executor
    Plasma5Support.DataSource {
        id: launcher
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
        }
    }
    function fetchCLI(period, provider, scope, forceOptimize) {
        if (root.isFetching) return;
        root.isFetching = true;
        
        var bin = plasmoid.configuration.codeburnBin || "codeburn";
        var cmd = bin + " status --format menubar-json --period " + period + " --provider " + provider;
        if (scope === "combined") {
            cmd += " --scope combined";
        }
        if (!forceOptimize) {
            cmd += " --no-optimize";
        }
        
        executable.connectSource(cmd);
    }

    function fetchExchangeRate() {
        var curr = plasmoid.configuration.currency || "USD";
        if (curr === "USD") {
            root.exchangeRate = 1.0;
            root.currencySymbol = "$";
            return;
        }
        
        var symbols = {
            "USD": "$", "CAD": "$", "AUD": "$", "NZD": "$", "HKD": "$", "SGD": "$", "MXN": "$",
            "EUR": "€", "GBP": "£", "JPY": "¥", "CNY": "¥", "KRW": "₩", "INR": "₹", "BRL": "R$",
            "CHF": "CHF", "SEK": "kr", "DKK": "kr", "ZAR": "R"
        };
        root.currencySymbol = symbols[curr] || curr;
        
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "https://api.frankfurter.app/latest?from=USD&to=" + curr);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText);
                        if (res.rates && res.rates[curr]) {
                            root.exchangeRate = res.rates[curr];
                            root.updateUI();
                        }
                    } catch(e) {
                        console.error("CodeBurn: FX Parse Error", e);
                    }
                }
            }
        };
        xhr.send();
    }

    function updateUI() {
        if (!root.currentPayload) return;
        
        var c = root.currentPayload.current;
        root.activeCost = c.cost || 0.0;
        root.activeCalls = c.calls || 0;
        root.activeSessions = c.sessions || 0;
        root.inputTokens = c.inputTokens || 0;
        root.outputTokens = c.outputTokens || 0;
        root.totalTokens = root.inputTokens + root.outputTokens;
        
        root.topModels = c.topModels || [];
        root.topProjects = c.topProjects || [];
        root.topActivities = c.topActivities || [];
        root.topFindings = (root.currentPayload.optimize && root.currentPayload.optimize.topFindings) || [];
        
        root.tools = c.tools || [];
        root.skills = c.skills || [];
        root.subagents = c.subagents || [];
        root.mcpServers = c.mcpServers || [];
        
        if (root.currentPayload.history && root.currentPayload.history.daily) {
            root.historyData = root.currentPayload.history.daily;
            var maxC = 0.1;
            for (var i = 0; i < root.historyData.length; i++) {
                if (root.historyData[i].cost > maxC) {
                    maxC = root.historyData[i].cost;
                }
            }
            root.maxHistoryCost = maxC;
        } else {
            root.historyData = [];
            root.maxHistoryCost = 0.1;
        }
    }

    // Refresh timers
    Timer {
        id: refreshTimer
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.checkCacheAndFetch(true, false);
            // Also fetch FX rate periodically
            root.fetchExchangeRate();
        }
    }

    // Handle configuration changes
    Connections {
        target: plasmoid.configuration
        function onCurrencyChanged() { root.fetchExchangeRate(); }
        function onDisplayMetricChanged() { root.updateUI(); }
        function onPeriodChanged() { 
            root.activePeriod = plasmoid.configuration.period; 
            root.checkCacheAndFetch(false, false); 
        }
        function onScopeChanged() { 
            root.activeScope = plasmoid.configuration.scope; 
            root.checkCacheAndFetch(false, false); 
        }
    }

    compactRepresentation: MouseArea {
        id: compactRoot
        implicitWidth: root.compactWidth
        implicitHeight: parent ? parent.height : 24
        width: implicitWidth
        height: implicitHeight
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        Layout.fillHeight: true
        hoverEnabled: true

        RowLayout {
            id: layoutRow
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6

            Image {
                source: "file:///home/leeo/Code/codeburn/assets/menu-logo.png"
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                Layout.alignment: Qt.AlignVCenter
                fillMode: Image.PreserveAspectFit
            }

            Text {
                visible: plasmoid.configuration.displayMetric !== "iconOnly"
                text: root.panelText
                font.pointSize: Kirigami.Theme.defaultFont.pointSize
                font.bold: true
                Layout.alignment: Qt.AlignVCenter
                Layout.topMargin: 3
                color: root.isOverDailyBudget ? root.colors.semanticWarning : root.colors.textColor
            }
        }

        onClicked: {
            root.expanded = !root.expanded;
            if (root.expanded) {
                root.checkCacheAndFetch(true, true);
            }
        }
    }

    // 2. Full Popover Representation
    fullRepresentation: Item {
        id: fullRoot
        implicitWidth: Kirigami.Units.gridUnit * 25
        implicitHeight: Kirigami.Units.gridUnit * 35
        width: implicitWidth
        height: implicitHeight

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 0

            // Header Section
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 10

                Image {
                    source: "file:///home/leeo/Code/codeburn/assets/menu-logo.png"
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    Layout.alignment: Qt.AlignVCenter
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    text: "CodeBurn"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize + 3
                    font.bold: true
                    color: root.colors.textColor
                }

                Item { Layout.fillWidth: true }

                Text {
                    visible: root.isFetching
                    text: "Fetching..."
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize
                    color: root.colors.textColor
                    opacity: 0.6
                }
            }

            Kirigami.Separator { Layout.fillWidth: true; Layout.bottomMargin: 8 }

            // Scope Selector
            SegmentedControl {
                id: scopeSelector
                model: ["Local", "Combined"]
                currentIndex: root.activeScope === "combined" ? 1 : 0
                colors: root.colors
                Layout.bottomMargin: 8
                onIndexSelected: (index) => {
                    root.activeScope = index === 1 ? "combined" : "local";
                    root.checkCacheAndFetch(false, false);
                }
            }

            // Period Selector
            SegmentedControl {
                id: periodSelector
                model: ["Today", "7 Days", "30 Days", "Month", "All Time"]
                currentIndex: {
                    if (root.activePeriod === "today") return 0;
                    if (root.activePeriod === "week") return 1;
                    if (root.activePeriod === "30days") return 2;
                    if (root.activePeriod === "month") return 3;
                    return 4;
                }
                colors: root.colors
                Layout.bottomMargin: 10
                onIndexSelected: (index) => {
                    var mapping = ["today", "week", "30days", "month", "all"];
                    root.activePeriod = mapping[index];
                    root.checkCacheAndFetch(false, false);
                }
            }

            // Scrollable Content
            ScrollView {
                id: contentScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ColumnLayout {
                    width: contentScroll.availableWidth
                    spacing: 12

                    // Hero Breakdown
                    HeroSection {
                        caption: root.activeScope === "combined" ? "Combined" : "Local Spend"
                        heroText: root.panelText
                        displayMetric: plasmoid.configuration.displayMetric || "cost"
                        totals: ({
                            cost: root.activeCost,
                            calls: root.activeCalls,
                            sessions: root.activeSessions,
                            inputTokens: root.inputTokens,
                            outputTokens: root.outputTokens,
                            totalTokens: root.totalTokens
                        })
                        budgetWarning: root.isOverDailyBudget
                        budgetText: "Daily budget of " + (plasmoid.configuration.displayMetric === "tokens" ? root.formatCompactTokens(root.activeDailyBudget) + " tok" : root.formatCurrency(root.activeDailyBudget)) + " exceeded"
                        savingsText: (root.currentPayload && root.currentPayload.current.localModelSavings.totalUSD > 0) 
                            ? "Saved " + root.formatCurrency(root.currentPayload.current.localModelSavings.totalUSD) + " with local models"
                            : ""
                        combinedUsage: (root.activeScope === "combined" && root.currentPayload) ? root.currentPayload.combined : null
                        colors: root.colors
                    }

                    Kirigami.Separator { Layout.fillWidth: true; opacity: 0.5 }

                    // Agent Tab Strip (Provider filters)
                    AgentTabStrip {
                        providers: {
                            if (!root.currentPayload) return ["all"];
                            var keys = ["all"];
                            var map = root.currentPayload.current.providers || {};
                            for (var k in map) {
                                if (map.hasOwnProperty(k)) keys.push(k);
                            }
                            return keys;
                        }
                        providerCosts: {
                            if (!root.currentPayload) return ({ "all": 0 });
                            var map = ({ "all": root.activeCost });
                            var currentProviders = root.currentPayload.current.providers || {};
                            for (var k in currentProviders) {
                                if (currentProviders.hasOwnProperty(k)) {
                                    map[k] = currentProviders[k];
                                }
                            }
                            return map;
                        }
                        activeProvider: root.activeProvider
                        colors: root.colors
                        onProviderSelected: (provider) => {
                            root.activeProvider = provider;
                            root.checkCacheAndFetch(false, false);
                        }
                    }

                    Kirigami.Separator { Layout.fillWidth: true; opacity: 0.5 }

                    // Visual Chart / Insights
                    HeatmapSection {
                        historyData: root.historyData
                        maxHistoryCost: root.maxHistoryCost
                        payload: root.currentPayload
                        colors: root.colors
                        displayMetric: plasmoid.configuration.displayMetric || "cost"
                    }

                    Kirigami.Separator { Layout.fillWidth: true; opacity: 0.5 }

                    // Models table
                    ModelsSection {
                        models: root.topModels
                        colors: root.colors
                        displayMetric: plasmoid.configuration.displayMetric || "cost"
                    }

                    Kirigami.Separator { Layout.fillWidth: true; opacity: 0.5 }

                    // Activity table
                    ActivitySection {
                        activities: root.topActivities
                        colors: root.colors
                        displayMetric: plasmoid.configuration.displayMetric || "cost"
                    }

                    Kirigami.Separator { Layout.fillWidth: true; opacity: 0.5 }

                    // Tooling list
                    ToolingSection {
                        tools: root.tools
                        skills: root.skills
                        subagents: root.subagents
                        mcpServers: root.mcpServers
                        colors: root.colors
                    }

                    Kirigami.Separator { Layout.fillWidth: true; opacity: 0.5 }

                    // Findings list
                    FindingsSection {
                        findings: root.topFindings
                        colors: root.colors
                    }
                }
            }

            Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: 8; Layout.bottomMargin: 8 }

            // Footer Bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Manual refresh button
                Button {
                    text: "Refresh"
                    enabled: !root.isFetching
                    onClicked: {
                        root.checkCacheAndFetch(true, true);
                    }
                }

                // Launch CLI button
                Button {
                    text: "Full Report"
                    onClicked: {
                        var bin = plasmoid.configuration.codeburnBin || "codeburn";
                        launcher.connectSource("konsole -e " + bin + " &");
                        root.checkCacheAndFetch(true, true);
                    }
                }

                // Error text
                Text {
                    id: errorLabel
                    text: root.lastError
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
                    color: root.colors.semanticDanger
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    
                    MouseArea {
                        anchors.fill: parent
                        ToolTip.visible: containsMouse
                        ToolTip.text: parent.text
                        hoverEnabled: true
                    }
                }

                // Settings button
                Button {
                    text: "⚙️"
                    onClicked: {
                        plasmoid.internalAction("configure").trigger();
                        root.checkCacheAndFetch(true, true);
                    }
                }
            }
        }
    }
    
    Component.onCompleted: {
        root.fetchExchangeRate();
        root.checkCacheAndFetch(true, false);
    }
}
