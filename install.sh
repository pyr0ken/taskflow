#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
PLASMOID_DEST="$HOME/.local/share/plasma/plasmoids/org.kde.plasma.taskflow"
APPLET_CFG="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

mkdir -p "$BIN_DIR" "$HOME/.local/share/plasma/plasmoids"

chmod +x "$REPO_DIR/bin/plasma_taskflow_daemon.py" "$REPO_DIR/bin/taskflow"

ln -sfn "$REPO_DIR/bin/plasma_taskflow_daemon.py" "$BIN_DIR/plasma_taskflow_daemon.py"
ln -sfn "$REPO_DIR/bin/taskflow" "$BIN_DIR/taskflow"

if [ -d "$PLASMOID_DEST" ] && [ ! -L "$PLASMOID_DEST" ]; then
    rm -rf "$PLASMOID_DEST"
fi
ln -sfn "$REPO_DIR/plasmoid" "$PLASMOID_DEST"

# Update Plasma cached popup geometry if applet exists
if [ -f "$APPLET_CFG" ] && command -v kwriteconfig6 >/dev/null 2>&1; then
    APPLET_GROUP=$(awk '/^\[Containments\]\[[0-9]+\]\[Applets\]\[[0-9]+\]$/{grp=$0} /^plugin=org\.kde\.plasma\.taskflow$/{print grp; exit}' "$APPLET_CFG" || true)
    if [ -n "${APPLET_GROUP:-}" ]; then
        CONT_ID=$(echo "$APPLET_GROUP" | sed -n 's/\[Containments\]\[\([0-9]*\)\]\[Applets\]\[\([0-9]*\)\]/\1/p')
        APP_ID=$(echo "$APPLET_GROUP" | sed -n 's/\[Containments\]\[\([0-9]*\)\]\[Applets\]\[\([0-9]*\)\]/\2/p')
        if [ -n "$CONT_ID" ] && [ -n "$APP_ID" ]; then
            kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc --group Containments --group "$CONT_ID" --group Applets --group "$APP_ID" --group Configuration --key popupWidth 560
            kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc --group Containments --group "$CONT_ID" --group Applets --group "$APP_ID" --group Configuration --key popupHeight 720
        fi
    fi
fi

systemctl --user restart plasma-taskflow.service
echo "Installed symlinks and restarted plasma-taskflow.service."
