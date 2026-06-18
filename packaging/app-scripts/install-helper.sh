#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESOURCES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TOOLS_DIR="${RESOURCES_DIR}/Tools"
LAUNCHD_DIR="${RESOURCES_DIR}/LaunchDaemons"

HELPER_LABEL="com.ljzxzxl.ChargeLimiter.Helper"
# Legacy labels are only kept so v0.1.0-v0.1.5 installs can be removed.
LEGACY_HELPER_LABEL="com.lookslikecode.ChargeLimitHelper"
LEGACY_MONITOR_LABEL="com.lookslikecode.ChargeLimitMonitor"
HELPER_DEST="/Library/PrivilegedHelperTools/charge-limit-helperd"
PLIST_DEST="/Library/LaunchDaemons/${HELPER_LABEL}.plist"
LEGACY_PLIST_DEST="/Library/LaunchDaemons/${LEGACY_HELPER_LABEL}.plist"

CONSOLE_USER="$(stat -f %Su /dev/console 2>/dev/null || true)"
CONSOLE_UID=""
CONSOLE_HOME=""
if [[ -n "${CONSOLE_USER}" && "${CONSOLE_USER}" != "root" ]]; then
  CONSOLE_UID="$(id -u "${CONSOLE_USER}" 2>/dev/null || true)"
  CONSOLE_HOME="$(dscl . -read "/Users/${CONSOLE_USER}" NFSHomeDirectory 2>/dev/null | awk '{print $2; exit}')"
fi

launchctl bootout system "${PLIST_DEST}" 2>/dev/null || true
launchctl bootout system "${LEGACY_PLIST_DEST}" 2>/dev/null || true
rm -f "${LEGACY_PLIST_DEST}"
rm -rf /Library/Logs/ChargeLimitHelper

if [[ -n "${CONSOLE_UID}" && -n "${CONSOLE_HOME}" ]]; then
  LEGACY_MONITOR_PLIST="${CONSOLE_HOME}/Library/LaunchAgents/${LEGACY_MONITOR_LABEL}.plist"
  launchctl bootout "gui/${CONSOLE_UID}" "${LEGACY_MONITOR_PLIST}" 2>/dev/null || true
  rm -f "${LEGACY_MONITOR_PLIST}"
  rm -f "${CONSOLE_HOME}/Library/Preferences/com.lookslikecode.ChargeLimiter.plist"
fi

mkdir -p /Library/PrivilegedHelperTools
mkdir -p /Library/Logs/ChargeLimiter
mkdir -p /usr/local/bin

install -o root -g wheel -m 755 "${TOOLS_DIR}/charge-limit-helperd" "${HELPER_DEST}"
install -o root -g wheel -m 755 "${TOOLS_DIR}/charge-limit" /usr/local/bin/charge-limit
install -o root -g wheel -m 755 "${TOOLS_DIR}/charge-limit-monitor" /usr/local/bin/charge-limit-monitor
install -o root -g wheel -m 644 "${LAUNCHD_DIR}/${HELPER_LABEL}.plist" "${PLIST_DEST}"

launchctl bootstrap system "${PLIST_DEST}"
launchctl kickstart -k "system/${HELPER_LABEL}"

echo "Installed ${HELPER_LABEL}"
