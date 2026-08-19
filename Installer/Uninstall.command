#!/bin/bash

set -Eeuo pipefail

PRODUCT_NAME="BG3 Player Immersive Camera"
DEFAULT_STATE_DIR="${HOME}/Library/Application Support/BG3PlayerImmersiveCamera/InstallerState"
STATE_DIR="${BG3PIC_STATE_DIR:-$DEFAULT_STATE_DIR}"

pause_at_end() {
    if [[ "${BG3PIC_NONINTERACTIVE:-0}" != "1" ]]; then
        echo
        read -r -p "Press Return to close this window..." _
    fi
}

die() {
    echo
    echo "Uninstall failed: $*" >&2
    pause_at_end
    exit 1
}

echo "========================================"
echo "${PRODUCT_NAME} Uninstaller"
echo "========================================"
echo

[[ -f "${STATE_DIR}/installed" ]] || die "No installation created by this package was found."
[[ -f "${STATE_DIR}/game-app-path" ]] || die "The installer state is missing the BG3 location."
[[ -f "${STATE_DIR}/data-root" ]] || die "The installer state is missing the BG3 user-data location."

if /usr/bin/pgrep -x "Baldur's Gate 3" >/dev/null 2>&1; then
    die "Baldur's Gate 3 is running. Quit it completely and try again."
fi

BG3_APP="$(<"${STATE_DIR}/game-app-path")"
DATA_ROOT="$(<"${STATE_DIR}/data-root")"
MACOS_DIR="${BG3_APP}/Contents/MacOS"
GAME_EXEC="${MACOS_DIR}/Baldur's Gate 3"
DEPLOYED_DYLIB="${MACOS_DIR}/libbg3se.dylib"
MOD_DEST="${DATA_ROOT}/Mods/BG3PlayerImmersiveCamera"
INPUT_CONFIG="${DATA_ROOT}/PlayerProfiles/Public/inputconfig_p1.json"
[[ -d "${BG3_APP}" ]] || die "The previously installed BG3 application could not be found at ${BG3_APP}."
[[ -f "${STATE_DIR}/input-existed" && ! -f "${STATE_DIR}/inputconfig-p1.json" ]] && die "The keyboard configuration backup is missing."
[[ -f "${STATE_DIR}/owned-patch" && ! -f "${STATE_DIR}/original-game-executable" ]] && die "The original BG3 executable backup is missing."

echo "Removing the camera mod..."
/bin/rm -rf "${MOD_DEST}"
if [[ -d "${STATE_DIR}/previous-mod" ]]; then
    /bin/cp -R "${STATE_DIR}/previous-mod" "${MOD_DEST}"
fi

echo "Restoring keyboard bindings..."
if [[ -f "${STATE_DIR}/input-existed" ]]; then
    /bin/mkdir -p "$(/usr/bin/dirname "${INPUT_CONFIG}")"
    /bin/cp -p "${STATE_DIR}/inputconfig-p1.json" "${INPUT_CONFIG}"
elif [[ -f "${STATE_DIR}/input-created" ]]; then
    /bin/rm -f "${INPUT_CONFIG}"
fi

if [[ -f "${STATE_DIR}/owned-patch" ]]; then
    echo "Restoring the original BG3 executable..."
    RESTORED_EXEC="${MACOS_DIR}/.bg3pic-restored.$$"
    /bin/cp -p "${STATE_DIR}/original-game-executable" "${RESTORED_EXEC}"
    /bin/mv -f "${RESTORED_EXEC}" "${GAME_EXEC}"
    /bin/rm -f "${DEPLOYED_DYLIB}"
else
    echo "Restoring the BG3SE installation that existed before this package..."
    if [[ -f "${STATE_DIR}/previous-libbg3se.dylib" ]]; then
        RESTORED_DYLIB="${MACOS_DIR}/.bg3pic-restored-lib.$$"
        /bin/cp -p "${STATE_DIR}/previous-libbg3se.dylib" "${RESTORED_DYLIB}"
        /bin/mv -f "${RESTORED_DYLIB}" "${DEPLOYED_DYLIB}"
    else
        /bin/rm -f "${DEPLOYED_DYLIB}"
    fi
fi

/bin/rm -rf "${STATE_DIR}"

echo
echo "Uninstall complete. Saved camera profiles were kept."
pause_at_end
