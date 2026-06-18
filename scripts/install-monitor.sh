#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MONITOR_LABEL="com.ljzxzxl.ChargeLimiter.Monitor"
# Legacy label is only kept so v0.1.0-v0.1.5 monitor installs can be removed.
LEGACY_MONITOR_LABEL="com.lookslikecode.ChargeLimitMonitor"
TARGET=80
if [[ "${EUID}" -eq 0 ]]; then
  SUDO=()
else
  SUDO=(sudo)
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      shift
      TARGET="${1:-80}"
      ;;
    --help|-h)
      echo "Usage: ./scripts/install-monitor.sh [--target 80]"
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

if [[ ! -x /usr/local/bin/charge-limit-monitor ]]; then
  ${SUDO[@]} mkdir -p /usr/local/bin
  ${SUDO[@]} install -o root -g wheel -m 755 ".build/release/charge-limit-monitor" /usr/local/bin/charge-limit-monitor
fi

mkdir -p "$HOME/Library/LaunchAgents"
MONITOR_PLIST="$HOME/Library/LaunchAgents/${MONITOR_LABEL}.plist"
LEGACY_MONITOR_PLIST="$HOME/Library/LaunchAgents/${LEGACY_MONITOR_LABEL}.plist"
launchctl bootout "gui/$(id -u)" "$LEGACY_MONITOR_PLIST" 2>/dev/null || true
rm -f "$LEGACY_MONITOR_PLIST"
cp "packaging/launchd/${MONITOR_LABEL}.plist" "$MONITOR_PLIST"
/usr/libexec/PlistBuddy -c "Set :ProgramArguments:2 ${TARGET}" "$MONITOR_PLIST"

launchctl bootout "gui/$(id -u)" "$MONITOR_PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$MONITOR_PLIST"
launchctl kickstart -k "gui/$(id -u)/${MONITOR_LABEL}"

echo "Installed ${MONITOR_LABEL} target=${TARGET}"
