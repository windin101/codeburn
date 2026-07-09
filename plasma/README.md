# CodeBurn KDE Plasma Widget

This directory contains the KDE Plasma 6 widget (Plasmoid) port of the CodeBurn macOS menubar app. The widget reproduces the core features, interactivity, and design aesthetics of the native macOS app directly on your KDE desktop.

## Overview

The CodeBurn Plasma widget provides a compact and full representation of your AI spending across 31 tools and agents. 

- **Compact Representation:** A panel or system tray icon showing your active spend. The text will turn a warning color if you exceed your daily budget.
- **Full Representation:** A popover dialog that provides detailed insights and breakdowns.
- **Live Data:** It communicates directly with the local `codeburn` CLI binary (with a 30s TTL memory cache to prevent duplicate loads) and fetches live exchange rates from the Frankfurter API to localize cost metrics automatically.

## Files and Structure

The Plasmoid is built using QML and structured as follows:

### Metadata & Configuration
- **`metadata.json`**: Declares the Plasma 6 applet with package properties, target API version, and points to the main QML file.
- **`contents/config/main.xml`**: Defines the persistent configuration schema for settings like currency, display metrics, periods, daily budgets, and the `codeburn` binary path.

### Design System
- **`contents/ui/theme.js`**: Contains design tokens for the terracotta-ember color palette, including light and dark theme mappings.

### Main Applet & Layout
- **`contents/ui/main.qml`**: The main applet handling the compact/full representations and data fetching.
- **`contents/ui/HeroSection.qml`**: Displays the large hero amount, token breakdown, sessions/calls counts, daily budget warnings, local model savings, and combined device breakdown list.
- **`contents/ui/SegmentedControl.qml`**: Custom-styled segmented pill-switchers for Scope, Period, and Chart visualization modes.
- **`contents/ui/AgentTabStrip.qml`**: A horizontally scrolling tab bar showing individual AI tools and their costs.
- **`contents/ui/HeatmapSection.qml`**: Provides different insight views, including an interactive trend bar chart, a calendar contribution grid, and stats/optimization summaries.
- **`contents/ui/ModelsSection.qml`**: Displays the top models table.
- **`contents/ui/ActivitySection.qml`**: Displays the top activities table.
- **`contents/ui/ToolingSection.qml`**: Collapsible/tabbed lists of tools, skills, subagents, and MCP server calls.
- **`contents/ui/FindingsSection.qml`**: Displays optimization findings.

### Settings UI & Installer
- **`contents/ui/configGeneral.qml`**: Integrated configuration dialog for the Plasmoid settings.
- **`install.sh`**: Executable bash installer to register, build, and upgrade the widget in `~/.local/share/plasma/plasmoids/org.codeburn.plasma` and reload the Plasma configuration.

## UX and Rendering

The widget is designed to integrate seamlessly with the KDE Plasma 6 environment:
- Uses native Plasma styling, letting the blurred, themed popover frame show through.
- Dynamic sizing and layout scaling using relative point sizes based on the Plasma theme default font.
- Uses native Plasma theme text colors to blend perfectly with the active color scheme.
- Uses explicit baseline alignment constraints for perfect typography rendering.
- Features a custom QML image element loading the native CodeBurn `menu-logo.png` asset.
