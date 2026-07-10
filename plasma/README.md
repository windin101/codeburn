# CodeBurn KDE Plasma Widget

A beautifully native, highly integrated KDE Plasma 6 widget (Plasmoid) port of the CodeBurn macOS menubar app. This widget brings comprehensive AI coding spend tracking directly to your Linux desktop panel, matching the core features, interactivity, and design aesthetics of the macOS app while natively embracing the KDE Plasma environment.

## What it does

The CodeBurn Plasma widget provides a real-time, zero-friction window into your AI API costs across 31+ tools (like Claude Code, Cursor, Codex, Gemini, etc).

- **Ambient Spend Tracking:** Sits quietly in your panel or system tray, displaying your active spend for the period (e.g., Today, Month, Week). If you exceed your configured daily budget, the text turns a warning color so you know immediately.
- **Full Interactive Dashboard:** Clicking the widget opens a rich popover containing:
  - **Scope & Period Toggles:** Pivot between Local machine spend vs Combined multi-device spend, and shift periods (Today, 7 Days, 30 Days, Month, All).
  - **Agent Tab Strip:** A horizontally scrolling, stylish tab bar filtering your spend by individual AI tools.
  - **Insights Switcher:** Toggle between an interactive Trend Bar Chart, a GitHub-style Calendar Heatmap, detailed Stats, and automated Optimize findings.
  - **Granular Breakdowns:** Tables displaying your top Models and top Activities/Projects by spend.
- **Live Localized Data:** Communicates directly with the local `codeburn` CLI binary via background async tasks. It pulls real-time exchange rates (via Frankfurter API) to convert USD costs into your local currency seamlessly.

## How it's built

Built entirely with native KDE technologies to ensure a first-class Linux desktop experience:

- **QML & Kirigami:** The interface is constructed using standard Qt Quick (QML) and KDE Kirigami frameworks, ensuring smooth animations and proper layout management.
- **Native Theming:** The widget respects your system's global theme. It automatically adapts to Light/Dark modes, allows the blurred desktop panel to show through, uses the system default font scaling, and cleverly maps its highlights to your active system accent color (e.g. `Kirigami.Theme.highlightColor`).
- **Performance First:** It relies on a 30-second TTL memory cache to prevent duplicate CLI spawns. Background shell execution (`codeburn payload`) prevents the UI thread from ever blocking, keeping your Plasma shell snappy.

### Project Structure
- **`metadata.json`**: Declares the Plasma 6 applet properties and points to the main entry point.
- **`contents/config/main.xml`**: Defines the persistent settings schema (Currency, Budget, Default Period).
- **`contents/ui/main.qml`**: The core applet router handling state, background fetching, and the top-level layout.
- **`contents/ui/*.qml`**: Modular UI components (`HeroSection.qml`, `HeatmapSection.qml`, `AgentTabStrip.qml`, etc.) that cleanly separate the different dashboard panels.
- **`contents/ui/configGeneral.qml`**: The graphical settings panel accessible via right-click > Configure CodeBurn.

## How to install it

### Prerequisites
1. You must be running **KDE Plasma 6**.
2. You must have the [CodeBurn CLI](https://github.com/getagentseal/codeburn) installed and available in your `$PATH`.

### Installation

We provide a convenient one-shot bash script that automatically packages the widget, registers it with Plasma, and reloads your shell so it appears immediately:

```bash
cd codeburn/plasma
bash install.sh
```

### Usage
1. Right-click on your Plasma panel or desktop and select **Add Widgets...**
2. Search for **CodeBurn** and drag it onto your panel or desktop.
3. (Optional) Right-click the widget and select **Configure CodeBurn...** to set your preferred local currency, daily budget warning threshold, or default display period.

To upgrade the widget in the future after pulling new code, simply re-run `bash install.sh`!
