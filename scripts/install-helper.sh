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

sudo mkdir -p /Library/PrivilegedHelperTools
sudo mkdir -p /Library/Logs/ChargeLimitHelper
sudo mkdir -p /usr/local/bin
sudo install -o root -g wheel -m 755 ".build/release/charge-limit-helperd" "$HELPER_DEST"
sudo install -o root -g wheel -m 755 ".build/release/charge-limit" "$CLI_DEST"
sudo install -o root -g wheel -m 755 ".build/release/charge-limit-monitor" "$MONITOR_DEST"
sudo install -o root -g wheel -m 644 "packaging/launchd/${HELPER_LABEL}.plist" "$PLIST_DEST"

sudo launchctl bootout system "$PLIST_DEST" 2>/dev/null || true
sudo launchctl bootstrap system "$PLIST_DEST"
sudo launchctl kickstart -k "system/${HELPER_LABEL}"

if [[ "$INSTALL_MONITOR" == "1" ]]; then
  "$ROOT_DIR/scripts/install-monitor.sh" --target "$TARGET"
fi

echo "Installed ${HELPER_LABEL}"
echo "Try: /usr/local/bin/charge-limit status"
