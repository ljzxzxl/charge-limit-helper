#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESOURCES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TOOLS_DIR="${RESOURCES_DIR}/Tools"
LAUNCHD_DIR="${RESOURCES_DIR}/LaunchDaemons"

HELPER_LABEL="com.lookslikecode.ChargeLimitHelper"
HELPER_DEST="/Library/PrivilegedHelperTools/charge-limit-helperd"
PLIST_DEST="/Library/LaunchDaemons/${HELPER_LABEL}.plist"

mkdir -p /Library/PrivilegedHelperTools
mkdir -p /Library/Logs/ChargeLimitHelper
mkdir -p /usr/local/bin

install -o root -g wheel -m 755 "${TOOLS_DIR}/charge-limit-helperd" "${HELPER_DEST}"
install -o root -g wheel -m 755 "${TOOLS_DIR}/charge-limit" /usr/local/bin/charge-limit
install -o root -g wheel -m 755 "${TOOLS_DIR}/charge-limit-monitor" /usr/local/bin/charge-limit-monitor
install -o root -g wheel -m 644 "${LAUNCHD_DIR}/${HELPER_LABEL}.plist" "${PLIST_DEST}"

launchctl bootout system "${PLIST_DEST}" 2>/dev/null || true
launchctl bootstrap system "${PLIST_DEST}"
launchctl kickstart -k "system/${HELPER_LABEL}"

echo "Installed ${HELPER_LABEL}"
