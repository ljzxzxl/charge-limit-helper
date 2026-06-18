#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HELPER_LABEL="com.lookslikecode.ChargeLimitHelper"
MONITOR_LABEL="com.lookslikecode.ChargeLimitMonitor"
HELPER_DEST="/Library/PrivilegedHelperTools/charge-limit-helperd"
PLIST_DEST="/Library/LaunchDaemons/${HELPER_LABEL}.plist"
CLI_DEST="/usr/local/bin/charge-limit"
MONITOR_DEST="/usr/local/bin/charge-limit-monitor"
INSTALL_MONITOR=0
TARGET=80
if [[ "${EUID}" -eq 0 ]]; then
  SUDO=()
else
  SUDO=(sudo)
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-monitor)
      INSTALL_MONITOR=1
      ;;
    --target)
      shift
      TARGET="${1:-80}"
      ;;
    --help|-h)
      echo "Usage: ./scripts/install-helper.sh [--with-monitor] [--target 80]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
  shift
done

cd "$ROOT_DIR"
swift build -c release

${SUDO[@]} mkdir -p /Library/PrivilegedHelperTools
${SUDO[@]} mkdir -p /Library/Logs/ChargeLimitHelper
${SUDO[@]} mkdir -p /usr/local/bin
${SUDO[@]} install -o root -g wheel -m 755 ".build/release/charge-limit-helperd" "$HELPER_DEST"
${SUDO[@]} install -o root -g wheel -m 755 ".build/release/charge-limit" "$CLI_DEST"
${SUDO[@]} install -o root -g wheel -m 755 ".build/release/charge-limit-monitor" "$MONITOR_DEST"
${SUDO[@]} install -o root -g wheel -m 644 "packaging/launchd/${HELPER_LABEL}.plist" "$PLIST_DEST"

${SUDO[@]} launchctl bootout system "$PLIST_DEST" 2>/dev/null || true
${SUDO[@]} launchctl bootstrap system "$PLIST_DEST"
${SUDO[@]} launchctl kickstart -k "system/${HELPER_LABEL}"

if [[ "$INSTALL_MONITOR" == "1" ]]; then
  if [[ "${EUID}" -eq 0 ]]; then
    echo "Skipping monitor LaunchAgent install because this script is running as root."
    echo "Run scripts/install-monitor.sh --target ${TARGET} as the logged-in user."
  else
    "$ROOT_DIR/scripts/install-monitor.sh" --target "$TARGET"
  fi
fi

echo "Installed ${HELPER_LABEL}"
echo "Try: /usr/local/bin/charge-limit status"
