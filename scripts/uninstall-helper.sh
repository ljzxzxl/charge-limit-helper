#!/bin/zsh
set -euo pipefail

HELPER_LABEL="com.lookslikecode.ChargeLimitHelper"
HELPER_DEST="/Library/PrivilegedHelperTools/charge-limit-helperd"
PLIST_DEST="/Library/LaunchDaemons/${HELPER_LABEL}.plist"
SOCKET_PATH="/var/run/charge-limit-helper.sock"

sudo launchctl bootout system "$PLIST_DEST" 2>/dev/null || true
sudo rm -f "$PLIST_DEST"
sudo rm -f "$HELPER_DEST"
sudo rm -f "$SOCKET_PATH"

echo "Removed ${HELPER_LABEL}"
