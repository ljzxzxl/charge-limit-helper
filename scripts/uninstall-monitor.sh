#!/bin/zsh
set -euo pipefail

MONITOR_LABEL="com.ljzxzxl.ChargeLimiter.Monitor"
# Legacy label is only kept so v0.1.0-v0.1.5 monitor installs can be removed.
LEGACY_MONITOR_LABEL="com.lookslikecode.ChargeLimitMonitor"
MONITOR_PLIST="$HOME/Library/LaunchAgents/${MONITOR_LABEL}.plist"
LEGACY_MONITOR_PLIST="$HOME/Library/LaunchAgents/${LEGACY_MONITOR_LABEL}.plist"

launchctl bootout "gui/$(id -u)" "$MONITOR_PLIST" 2>/dev/null || true
launchctl bootout "gui/$(id -u)" "$LEGACY_MONITOR_PLIST" 2>/dev/null || true
rm -f "$MONITOR_PLIST"
rm -f "$LEGACY_MONITOR_PLIST"

echo "Removed ${MONITOR_LABEL}"
