#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "Installing/updating CodeBurn Plasma widget..."

if kpackagetool6 -t Plasma/Applet -i . 2>/dev/null; then
    echo "Successfully installed CodeBurn widget!"
else
    echo "Widget already exists, upgrading..."
    kpackagetool6 -t Plasma/Applet -u .
    echo "Successfully upgraded CodeBurn widget!"
fi

if pgrep plasmashell > /dev/null; then
    echo "Reloading config in plasmashell..."
    qdbus org.kde.plasmashell /PlasmaShell evaluateScript "var all = panels(); for (var i in all) { all[i].reloadConfig(); }" 2>/dev/null || true
fi

echo "Done! You can add 'CodeBurn' to your panel or desktop."
