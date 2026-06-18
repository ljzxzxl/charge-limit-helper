#!/bin/zsh
set -euo pipefail

HELPER_LABEL="com.lookslikecode.ChargeLimitHelper"
MONITOR_LABEL="com.lookslikecode.ChargeLimitMonitor"
HELPER_DEST="/Library/PrivilegedHelperTools/charge-limit-helperd"
PLIST_DEST="/Library/LaunchDaemons/${HELPER_LABEL}.plist"
SOCKET_PATH="/var/run/charge-limit-helper.sock"
CLI_DEST="/usr/local/bin/charge-limit"
MONITOR_DEST="/usr/local/bin/charge-limit-monitor"
MONITOR_PLIST="$HOME/Library/LaunchAgents/${MONITOR_LABEL}.plist"
RESTORE=1
if [[ "${EUID}" -eq 0 ]]; then
  SUDO=()
else
  SUDO=(sudo)
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-restore)
      RESTORE=0
      ;;
    --help|-h)
      echo "Usage: ./scripts/uninstall-helper.sh [--skip-restore]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
  shift
done

if [[ -f "$MONITOR_PLIST" ]]; then
  launchctl bootout "gui/$(id -u)" "$MONITOR_PLIST" 2>/dev/null || true
  rm -f "$MONITOR_PLIST"
fi

if [[ "$RESTORE" == "1" ]]; then
  "$CLI_DEST" restore-default 2>/dev/null || ${SUDO[@]} "$HELPER_DEST" restore-default 2>/dev/null || true
fi

${SUDO[@]} launchctl bootout system "$PLIST_DEST" 2>/dev/null || true
${SUDO[@]} rm -f "$PLIST_DEST"
${SUDO[@]} rm -f "$HELPER_DEST"
${SUDO[@]} rm -f "$SOCKET_PATH"
${SUDO[@]} rm -f "$CLI_DEST"
${SUDO[@]} rm -f "$MONITOR_DEST"

echo "Removed ${HELPER_LABEL}"
