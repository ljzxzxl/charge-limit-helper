#!/bin/zsh
set -euo pipefail

MONITOR_LABEL="com.lookslikecode.ChargeLimitMonitor"
MONITOR_PLIST="$HOME/Library/LaunchAgents/${MONITOR_LABEL}.plist"

launchctl bootout "gui/$(id -u)" "$MONITOR_PLIST" 2>/dev/null || true
rm -f "$MONITOR_PLIST"

echo "Removed ${MONITOR_LABEL}"
