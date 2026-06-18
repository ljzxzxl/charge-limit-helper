#!/bin/zsh
set -euo pipefail

HELPER_LABEL="com.ljzxzxl.ChargeLimiter.Helper"
MONITOR_LABEL="com.ljzxzxl.ChargeLimiter.Monitor"
# Legacy labels are only kept so v0.1.0-v0.1.5 installs can be removed.
LEGACY_HELPER_LABEL="com.lookslikecode.ChargeLimitHelper"
LEGACY_MONITOR_LABEL="com.lookslikecode.ChargeLimitMonitor"
HELPER_DEST="/Library/PrivilegedHelperTools/charge-limit-helperd"
PLIST_DEST="/Library/LaunchDaemons/${HELPER_LABEL}.plist"
LEGACY_PLIST_DEST="/Library/LaunchDaemons/${LEGACY_HELPER_LABEL}.plist"
SOCKET_PATH="/var/run/charge-limit-helper.sock"

CONSOLE_USER="$(stat -f %Su /dev/console 2>/dev/null || true)"
CONSOLE_UID=""
CONSOLE_HOME=""
if [[ -n "${CONSOLE_USER}" && "${CONSOLE_USER}" != "root" ]]; then
  CONSOLE_UID="$(id -u "${CONSOLE_USER}" 2>/dev/null || true)"
  CONSOLE_HOME="$(dscl . -read "/Users/${CONSOLE_USER}" NFSHomeDirectory 2>/dev/null | awk '{print $2; exit}')"
fi

if [[ -x /usr/local/bin/charge-limit ]]; then
  /usr/local/bin/charge-limit restore-default 2>/dev/null || true
elif [[ -x "${HELPER_DEST}" ]]; then
  "${HELPER_DEST}" restore-default 2>/dev/null || true
fi

if [[ -n "${CONSOLE_UID}" && -n "${CONSOLE_HOME}" ]]; then
  MONITOR_PLIST="${CONSOLE_HOME}/Library/LaunchAgents/${MONITOR_LABEL}.plist"
  LEGACY_MONITOR_PLIST="${CONSOLE_HOME}/Library/LaunchAgents/${LEGACY_MONITOR_LABEL}.plist"
  launchctl bootout "gui/${CONSOLE_UID}" "${MONITOR_PLIST}" 2>/dev/null || true
  launchctl bootout "gui/${CONSOLE_UID}" "${LEGACY_MONITOR_PLIST}" 2>/dev/null || true
  rm -f "${MONITOR_PLIST}"
  rm -f "${LEGACY_MONITOR_PLIST}"
  rm -f "${CONSOLE_HOME}/Library/Preferences/com.ljzxzxl.ChargeLimiter.plist"
  rm -f "${CONSOLE_HOME}/Library/Preferences/com.lookslikecode.ChargeLimiter.plist"
fi

launchctl bootout system "${PLIST_DEST}" 2>/dev/null || true
launchctl bootout system "${LEGACY_PLIST_DEST}" 2>/dev/null || true
rm -f "${PLIST_DEST}"
rm -f "${LEGACY_PLIST_DEST}"
rm -f "${HELPER_DEST}"
rm -f "${SOCKET_PATH}"
rm -f /usr/local/bin/charge-limit
rm -f /usr/local/bin/charge-limit-monitor
rm -rf /Library/Logs/ChargeLimiter
rm -rf /Library/Logs/ChargeLimitHelper

echo "Removed ${HELPER_LABEL}"
