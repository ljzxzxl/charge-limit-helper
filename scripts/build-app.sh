#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ChargeLimiter"
EXECUTABLE_NAME="ChargeLimiter"
VERSION="$("${ROOT_DIR}/scripts/read-version.sh")"
BUILD_DIR="${ROOT_DIR}/build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
LEGACY_APP_DIR="${BUILD_DIR}/Charge Limit Helper.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
TOOLS_DIR="${RESOURCES_DIR}/Tools"
SCRIPTS_DIR="${RESOURCES_DIR}/Scripts"
LAUNCHD_DIR="${RESOURCES_DIR}/LaunchDaemons"
ICON_PNG="${ROOT_DIR}/Resources/ChargeLimitHelper.png"
ICONSET_DIR="${BUILD_DIR}/ChargeLimitHelper.iconset"
ICON_ICNS="${RESOURCES_DIR}/ChargeLimitHelper.icns"

cd "${ROOT_DIR}"
swift build -c release

rm -rf "${APP_DIR}" "${LEGACY_APP_DIR}" "${ICONSET_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}" "${TOOLS_DIR}" "${SCRIPTS_DIR}" "${LAUNCHD_DIR}" "${ICONSET_DIR}"

cp "${ROOT_DIR}/packaging/app/Info.plist" "${CONTENTS_DIR}/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${CONTENTS_DIR}/Info.plist"

cp "${ROOT_DIR}/.build/release/charge-limit-menubar" "${MACOS_DIR}/${EXECUTABLE_NAME}"
chmod +x "${MACOS_DIR}/${EXECUTABLE_NAME}"

cp "${ROOT_DIR}/.build/release/charge-limit-helperd" "${TOOLS_DIR}/charge-limit-helperd"
cp "${ROOT_DIR}/.build/release/charge-limit" "${TOOLS_DIR}/charge-limit"
cp "${ROOT_DIR}/.build/release/charge-limit-monitor" "${TOOLS_DIR}/charge-limit-monitor"
chmod +x "${TOOLS_DIR}/charge-limit-helperd" "${TOOLS_DIR}/charge-limit" "${TOOLS_DIR}/charge-limit-monitor"

cp "${ROOT_DIR}/packaging/app-scripts/install-helper.sh" "${SCRIPTS_DIR}/install-helper.sh"
cp "${ROOT_DIR}/packaging/app-scripts/uninstall-helper.sh" "${SCRIPTS_DIR}/uninstall-helper.sh"
chmod +x "${SCRIPTS_DIR}/install-helper.sh" "${SCRIPTS_DIR}/uninstall-helper.sh"

cp "${ROOT_DIR}/packaging/launchd/com.lookslikecode.ChargeLimitHelper.plist" "${LAUNCHD_DIR}/com.lookslikecode.ChargeLimitHelper.plist"
cp "${ROOT_DIR}/Resources/MenuBarIcons/MenuBarIconLight.png" "${RESOURCES_DIR}/MenuBarIconLight.png"
cp "${ROOT_DIR}/Resources/MenuBarIcons/MenuBarIconLight@2x.png" "${RESOURCES_DIR}/MenuBarIconLight@2x.png"
cp "${ROOT_DIR}/Resources/MenuBarIcons/MenuBarIconDark.png" "${RESOURCES_DIR}/MenuBarIconDark.png"
cp "${ROOT_DIR}/Resources/MenuBarIcons/MenuBarIconDark@2x.png" "${RESOURCES_DIR}/MenuBarIconDark@2x.png"

if [[ ! -f "${ICON_PNG}" ]]; then
  echo "Missing icon: ${ICON_PNG}" >&2
  exit 1
fi

for size in 16 32 128 256 512; do
  /usr/bin/sips -z "${size}" "${size}" "${ICON_PNG}" --out "${ICONSET_DIR}/icon_${size}x${size}.png" >/dev/null
  double=$(( size * 2 ))
  /usr/bin/sips -z "${double}" "${double}" "${ICON_PNG}" --out "${ICONSET_DIR}/icon_${size}x${size}@2x.png" >/dev/null
done

/usr/bin/iconutil -c icns "${ICONSET_DIR}" -o "${ICON_ICNS}"
rm -rf "${ICONSET_DIR}"

/usr/bin/codesign --force --sign - "${APP_DIR}" >/dev/null

echo "Built ${APP_DIR}"
