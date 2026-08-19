#!/bin/bash

set -Eeuo pipefail

VERSION="${1:-1.0.0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
BG3SE_REPO="${BG3SE_REPO:-${PROJECT_ROOT}/../bg3se-macos}"
PACKAGE_NAME="BG3-Player-Immersive-Camera-v${VERSION}-macOS"
PACKAGE_DIR="${PROJECT_ROOT}/dist/${PACKAGE_NAME}"
PAYLOAD_DIR="${PACKAGE_DIR}/Payload"

DYLIB="${BG3SE_REPO}/build/lib/libbg3se.dylib"
PATCHER="${BG3SE_REPO}/tools/vendor/insert_dylib/insert_dylib_bin"

[[ "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]] || {
    echo "Invalid version: ${VERSION}" >&2
    exit 1
}
[[ -f "${DYLIB}" ]] || { echo "Missing extender build: ${DYLIB}" >&2; exit 1; }
[[ -x "${PATCHER}" ]] || { echo "Missing insert_dylib tool: ${PATCHER}" >&2; exit 1; }

/bin/rm -rf "${PACKAGE_DIR}"
/bin/mkdir -p "${PAYLOAD_DIR}"
/bin/cp "${PROJECT_ROOT}/Installer/Install.command" "${PACKAGE_DIR}/Install.command"
/bin/cp "${PROJECT_ROOT}/Installer/Uninstall.command" "${PACKAGE_DIR}/Uninstall.command"
/bin/cp "${PROJECT_ROOT}/Installer/merge-input.js" "${PACKAGE_DIR}/merge-input.js"
/usr/bin/printf '%s\n' "${VERSION}" > "${PACKAGE_DIR}/VERSION"
/bin/cp "${PROJECT_ROOT}/README.md" "${PACKAGE_DIR}/README.md"
/bin/cp "${PROJECT_ROOT}/LICENSE" "${PACKAGE_DIR}/LICENSE"
/bin/cp -R "${PROJECT_ROOT}/assets" "${PACKAGE_DIR}/assets"
/bin/cp "${DYLIB}" "${PAYLOAD_DIR}/libbg3se.dylib"
/bin/cp "${PATCHER}" "${PAYLOAD_DIR}/insert_dylib"
/bin/cp -R "${PROJECT_ROOT}/Mods/BG3PlayerImmersiveCamera" "${PAYLOAD_DIR}/BG3PlayerImmersiveCamera"
/bin/chmod +x "${PACKAGE_DIR}/Install.command" "${PACKAGE_DIR}/Uninstall.command" "${PAYLOAD_DIR}/insert_dylib"

/usr/bin/xattr -cr "${PACKAGE_DIR}" 2>/dev/null || true
/usr/bin/codesign --force --sign - "${PAYLOAD_DIR}/libbg3se.dylib" >/dev/null
/usr/bin/codesign --force --sign - "${PAYLOAD_DIR}/insert_dylib" >/dev/null
/usr/bin/codesign --verify --strict "${PAYLOAD_DIR}/libbg3se.dylib"
/usr/bin/codesign --verify --strict "${PAYLOAD_DIR}/insert_dylib"

echo "Built tester package: ${PACKAGE_DIR}"
/usr/bin/du -sh "${PACKAGE_DIR}"
