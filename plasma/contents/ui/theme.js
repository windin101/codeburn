.pragma library

// Terracotta-ember Design System tokens
function getColors(isDark) {
    return {
        brandEmber: "#C9521D",
        brandAccent: isDark ? "#E8774A" : "#C9521D",
        brandAccentLight: isDark ? "#F0A070" : "#E8774A",
        brandAccentDeep: "#8B3E13",
        brandAccentGlow: "#F0A070",
        
        warmSurface: isDark ? "#1C1816" : "#FAF7F3",
        warmSurfaceDark: "#1C1816",
        warmSurfaceLight: "#FAF7F3",
        
        categoricalClaude: "#C9521D",
        categoricalCursor: "#3F6B8C",
        categoricalCodex: "#4A7D5C",
        
        oneShotGood: "#30D158",
        oneShotMid: "#FF9F0A",
        oneShotLow: "#FF453A",
        
        semanticDanger: "#C83F2C",
        semanticWarning: "#D98F29",
        semanticSuccess: "#4EA865",
        
        // Neutral colors
        textColor: isDark ? "#F5F2F0" : "#2C2523",
        textSecondaryColor: isDark ? "#A89F9B" : "#7A6E6A",
        textTertiaryColor: isDark ? "#7E7470" : "#A29692",
        borderColor: isDark ? "#3A3330" : "#E6E0DD",
        separatorColor: isDark ? "#2A2422" : "#F0EAE6"
    };
}
