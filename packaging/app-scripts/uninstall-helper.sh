#!/bin/zsh
set -euo pipefail

HELPER_LABEL="com.lookslikecode.ChargeLimitHelper"
MONITOR_LABEL="com.lookslikecode.ChargeLimitMonitor"
HELPER_DEST="/Library/PrivilegedHelperTools/charge-limit-helperd"
PLIST_DEST="/Library/LaunchDaemons/${HELPER_LABEL}.plist"
MONITOR_PLIST="${HOME}/Library/LaunchAgents/${MONITOR_LABEL}.plist"
SOCKET_PATH="/var/run/charge-limit-helper.sock"

if [[ -x /usr/local/bin/charge-limit ]]; then
  /usr/local/bin/charge-limit restore-default 2>/dev/null || true
elif [[ -x "${HELPER_DEST}" ]]; then
  "${HELPER_DEST}" restore-default 2>/dev/null || true
fi

if [[ -f "${MONITOR_PLIST}" ]]; then
  launchctl bootout "gui/$(id -u)" "${MONITOR_PLIST}" 2>/dev/null || true
  rm -f "${MONITOR_PLIST}"
fi

launchctl bootout system "${PLIST_DEST}" 2>/dev/null || true
rm -f "${PLIST_DEST}"
rm -f "${HELPER_DEST}"
rm -f "${SOCKET_PATH}"
rm -f /usr/local/bin/charge-limit
rm -f /usr/local/bin/charge-limit-monitor

echo "Removed ${HELPER_LABEL}"
