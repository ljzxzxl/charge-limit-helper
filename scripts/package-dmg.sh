#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$("${ROOT_DIR}/scripts/read-version.sh")"
APP_NAME="ChargeLimiter"
DIST_DIR="${ROOT_DIR}/dist"
STAGING_DIR="${ROOT_DIR}/build/dmg-staging"
APP_PATH="${ROOT_DIR}/build/${APP_NAME}.app"
DMG_NAME="ChargeLimiter-${VERSION}.dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"

"${ROOT_DIR}/scripts/build-app.sh"

rm -rf "${DIST_DIR}" "${STAGING_DIR}"
mkdir -p "${DIST_DIR}" "${STAGING_DIR}"

COPYFILE_DISABLE=1 /usr/bin/ditto --norsrc "${APP_PATH}" "${STAGING_DIR}/${APP_NAME}.app"
/bin/ln -s /Applications "${STAGING_DIR}/Applications"

COPYFILE_DISABLE=1 /usr/bin/hdiutil create \
  -volname "ChargeLimiter" \
  -srcfolder "${STAGING_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

(
  cd "${DIST_DIR}"
  /usr/bin/shasum -a 256 "${DMG_NAME}" > "${DMG_NAME}.sha256"
)

echo "Created ${DMG_PATH}"
cat "${DMG_PATH}.sha256"
