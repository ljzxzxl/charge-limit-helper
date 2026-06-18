#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HELPER_LABEL="com.lookslikecode.ChargeLimitHelper"
HELPER_DEST="/Library/PrivilegedHelperTools/charge-limit-helperd"
PLIST_DEST="/Library/LaunchDaemons/${HELPER_LABEL}.plist"

cd "$ROOT_DIR"
swift build -c release

sudo mkdir -p /Library/PrivilegedHelperTools
sudo mkdir -p /Library/Logs/ChargeLimitHelper
sudo install -o root -g wheel -m 755 ".build/release/charge-limit-helperd" "$HELPER_DEST"
sudo install -o root -g wheel -m 644 "packaging/launchd/${HELPER_LABEL}.plist" "$PLIST_DEST"

sudo launchctl bootout system "$PLIST_DEST" 2>/dev/null || true
sudo launchctl bootstrap system "$PLIST_DEST"
sudo launchctl kickstart -k "system/${HELPER_LABEL}"

echo "Installed ${HELPER_LABEL}"
echo "Try: .build/release/charge-limit status"
