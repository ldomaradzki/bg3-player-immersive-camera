#!/bin/bash

set -Eeuo pipefail

PRODUCT_NAME="BG3 Player Immersive Camera"
SUPPORTED_VERSION="4.1.1.7398727"
SUPPORTED_CLEAN_SHA256="48991823b89a672267431766b5691b996588b38acb950c6d5f0e22eeaf054d8f"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD_DIR="${SCRIPT_DIR}/Payload"
if [[ -f "${SCRIPT_DIR}/VERSION" ]]; then
    PACKAGE_VERSION="$(<"${SCRIPT_DIR}/VERSION")"
else
    PACKAGE_VERSION="development"
fi
DEFAULT_STATE_DIR="${HOME}/Library/Application Support/BG3PlayerImmersiveCamera/InstallerState"
DEFAULT_DATA_ROOT="${HOME}/Documents/Larian Studios/Baldur's Gate 3"
STATE_DIR="${BG3PIC_STATE_DIR:-$DEFAULT_STATE_DIR}"
DATA_ROOT="${BG3PIC_DATA_ROOT:-$DEFAULT_DATA_ROOT}"

pause_at_end() {
    if [[ "${BG3PIC_NONINTERACTIVE:-0}" != "1" ]]; then
        echo
        read -r -p "Press Return to close this window..." _
    fi
}

die() {
    echo
    echo "Installation failed: $*" >&2
    pause_at_end
    exit 1
}

find_bg3_app() {
    local override="${BG3PIC_GAME_PATH:-${BG3SE_GAME_PATH:-}}"
    local name root vdf

    if [[ -n "${override}" ]]; then
        if [[ "${override}" == *.app && -d "${override}" ]]; then
            printf '%s\n' "${override}"
            return 0
        fi
        for name in "Baldur's Gate 3.app" "Baldurs Gate 3.app"; do
            if [[ -d "${override}/${name}" ]]; then
                printf '%s\n' "${override}/${name}"
                return 0
            fi
        done
    fi

    root="${HOME}/Library/Application Support/Steam"
    for name in "Baldur's Gate 3.app" "Baldurs Gate 3.app"; do
        if [[ -d "${root}/steamapps/common/Baldurs Gate 3/${name}" ]]; then
            printf '%s\n' "${root}/steamapps/common/Baldurs Gate 3/${name}"
            return 0
        fi
    done

    vdf="${root}/steamapps/libraryfolders.vdf"
    if [[ -f "${vdf}" ]]; then
        while IFS= read -r root; do
            for name in "Baldur's Gate 3.app" "Baldurs Gate 3.app"; do
                if [[ -d "${root}/steamapps/common/Baldurs Gate 3/${name}" ]]; then
                    printf '%s\n' "${root}/steamapps/common/Baldurs Gate 3/${name}"
                    return 0
                fi
            done
        done < <(sed -n 's/.*"path"[[:space:]]*"\([^"]*\)".*/\1/p' "${vdf}")
    fi

    return 1
}

is_patched() {
    /usr/bin/grep -a -q '@loader_path/libbg3se.dylib' "$1"
}

restore_after_failure() {
    local status=$?
    trap - ERR
    set +e
    local restore_ok=1

    echo
    echo "An error occurred. Restoring the pre-installation state..." >&2

    if [[ -f "${STATE_DIR}/game-app-path" ]]; then
        local saved_app saved_macos
        saved_app="$(<"${STATE_DIR}/game-app-path")"
        saved_macos="${saved_app}/Contents/MacOS"

        if [[ -f "${STATE_DIR}/original-game-executable" ]]; then
            /bin/cp -p "${STATE_DIR}/original-game-executable" "${saved_macos}/.bg3pic-rollback.$$" &&
                /bin/mv -f "${saved_macos}/.bg3pic-rollback.$$" "${saved_macos}/Baldur's Gate 3" || restore_ok=0
        fi
        if [[ -f "${STATE_DIR}/previous-libbg3se.dylib" ]]; then
            /bin/cp -p "${STATE_DIR}/previous-libbg3se.dylib" "${saved_macos}/.bg3pic-rollback-lib.$$" &&
                /bin/mv -f "${saved_macos}/.bg3pic-rollback-lib.$$" "${saved_macos}/libbg3se.dylib" || restore_ok=0
        elif [[ -f "${STATE_DIR}/owned-patch" ]]; then
            /bin/rm -f "${saved_macos}/libbg3se.dylib" || restore_ok=0
        fi
    fi

    if [[ -f "${STATE_DIR}/input-existed" ]]; then
        /bin/mkdir -p "$(/usr/bin/dirname "${INPUT_CONFIG}")"
        /bin/cp -p "${STATE_DIR}/inputconfig-p1.json" "${INPUT_CONFIG}" || restore_ok=0
    elif [[ -f "${STATE_DIR}/input-created" ]]; then
        /bin/rm -f "${INPUT_CONFIG}" || restore_ok=0
    fi

    if [[ -f "${STATE_DIR}/mod-change-started" ]]; then
        /bin/rm -rf "${MOD_DEST}" || restore_ok=0
        if [[ -d "${STATE_DIR}/previous-mod" ]]; then
            /bin/cp -R "${STATE_DIR}/previous-mod" "${MOD_DEST}" || restore_ok=0
        fi
    fi

    [[ -n "${PATCHED_EXEC:-}" ]] && /bin/rm -f "${PATCHED_EXEC}"
    [[ -n "${STAGED_DYLIB:-}" ]] && /bin/rm -f "${STAGED_DYLIB}"
    if [[ "${restore_ok}" == "1" ]]; then
        /bin/rm -rf "${STATE_DIR}"
        echo "Previous files restored." >&2
    else
        echo "Automatic restoration was incomplete." >&2
        echo "Backups were kept at: ${STATE_DIR}" >&2
    fi
    pause_at_end
    exit "${status}"
}

echo "========================================"
echo "${PRODUCT_NAME} Installer"
echo "========================================"
echo

[[ "$(/usr/bin/uname -m)" == "arm64" ]] || die "Apple Silicon is required."
[[ -f "${PAYLOAD_DIR}/libbg3se.dylib" ]] || die "Payload/libbg3se.dylib is missing."
[[ -x "${PAYLOAD_DIR}/insert_dylib" ]] || die "Payload/insert_dylib is missing or not executable."
[[ -d "${PAYLOAD_DIR}/BG3PlayerImmersiveCamera" ]] || die "The camera mod payload is missing."
[[ -f "${SCRIPT_DIR}/merge-input.js" ]] || die "The keyboard configuration helper is missing."
/usr/bin/xattr -dr com.apple.quarantine "${SCRIPT_DIR}" 2>/dev/null || true

if /usr/bin/pgrep -x "Baldur's Gate 3" >/dev/null 2>&1; then
    die "Baldur's Gate 3 is running. Quit it completely and try again."
fi

BG3_APP="$(find_bg3_app)" || die "Could not find the Steam installation of Baldur's Gate 3."
MACOS_DIR="${BG3_APP}/Contents/MacOS"
GAME_EXEC="${MACOS_DIR}/Baldur's Gate 3"
DEPLOYED_DYLIB="${MACOS_DIR}/libbg3se.dylib"
INFO_PLIST="${BG3_APP}/Contents/Info.plist"
MOD_DEST="${DATA_ROOT}/Mods/BG3PlayerImmersiveCamera"
INPUT_CONFIG="${DATA_ROOT}/PlayerProfiles/Public/inputconfig_p1.json"

[[ -f "${GAME_EXEC}" ]] || die "The BG3 executable is missing."
GAME_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${INFO_PLIST}" 2>/dev/null || true)"
[[ "${GAME_VERSION}" == "${SUPPORTED_VERSION}" ]] || die "BG3 ${SUPPORTED_VERSION} is required; found ${GAME_VERSION:-unknown}."
[[ ! -e "${STATE_DIR}/installed" ]] || die "This package is already installed. Run Uninstall.command first."
[[ ! -e "${STATE_DIR}" ]] || die "An incomplete installer state exists at ${STATE_DIR}. Remove it only after checking your game files."

PREEXISTING_PATCH=0
if is_patched "${GAME_EXEC}"; then
    PREEXISTING_PATCH=1
else
    CLEAN_SHA256="$(/usr/bin/shasum -a 256 "${GAME_EXEC}" | /usr/bin/awk '{print $1}')"
    [[ "${CLEAN_SHA256}" == "${SUPPORTED_CLEAN_SHA256}" ]] || die "The BG3 executable does not match the supported build. Use Steam's Verify Integrity, then try again."
fi

echo "Game: ${BG3_APP}"
echo "Version: ${GAME_VERSION}"
echo

/bin/mkdir -p "${STATE_DIR}"
/bin/chmod 700 "${STATE_DIR}"
printf '%s\n' "${BG3_APP}" > "${STATE_DIR}/game-app-path"
printf '%s\n' "${DATA_ROOT}" > "${STATE_DIR}/data-root"
trap restore_after_failure ERR

if [[ "${PREEXISTING_PATCH}" == "1" ]]; then
    echo "Existing BG3SE patch detected; it will be preserved on uninstall."
    /usr/bin/touch "${STATE_DIR}/preexisting-patch"
    if [[ -f "${DEPLOYED_DYLIB}" ]]; then
        /bin/cp -p "${DEPLOYED_DYLIB}" "${STATE_DIR}/previous-libbg3se.dylib.tmp"
        /bin/mv "${STATE_DIR}/previous-libbg3se.dylib.tmp" "${STATE_DIR}/previous-libbg3se.dylib"
    fi
else
    echo "Backing up and patching the BG3 executable..."
    /bin/cp -p "${GAME_EXEC}" "${STATE_DIR}/original-game-executable.tmp"
    /bin/mv "${STATE_DIR}/original-game-executable.tmp" "${STATE_DIR}/original-game-executable"
    /usr/bin/touch "${STATE_DIR}/owned-patch"

    PATCHED_EXEC="${MACOS_DIR}/.bg3pic-patched.$$"
    /bin/cp -p "${GAME_EXEC}" "${PATCHED_EXEC}"
    "${PAYLOAD_DIR}/insert_dylib" --weak --inplace --strip-codesig --all-yes \
        "@loader_path/libbg3se.dylib" "${PATCHED_EXEC}" >/dev/null
    /usr/bin/codesign --force --sign - "${PATCHED_EXEC}" >/dev/null
    is_patched "${PATCHED_EXEC}"
    /bin/mv -f "${PATCHED_EXEC}" "${GAME_EXEC}"
fi

echo "Installing the native extender..."
STAGED_DYLIB="${MACOS_DIR}/.bg3pic-lib.$$"
/bin/cp "${PAYLOAD_DIR}/libbg3se.dylib" "${STAGED_DYLIB}"
/usr/bin/xattr -d com.apple.quarantine "${STAGED_DYLIB}" 2>/dev/null || true
/usr/bin/codesign --force --sign - "${STAGED_DYLIB}" >/dev/null
/usr/bin/codesign --verify --strict "${STAGED_DYLIB}"
/bin/mv -f "${STAGED_DYLIB}" "${DEPLOYED_DYLIB}"

echo "Installing the camera mod..."
if [[ -d "${MOD_DEST}" ]]; then
    /bin/cp -R "${MOD_DEST}" "${STATE_DIR}/previous-mod.tmp"
    /bin/mv "${STATE_DIR}/previous-mod.tmp" "${STATE_DIR}/previous-mod"
fi
/usr/bin/touch "${STATE_DIR}/mod-change-started"
/bin/rm -rf "${MOD_DEST}"
/bin/mkdir -p "$(/usr/bin/dirname "${MOD_DEST}")"
/bin/cp -R "${PAYLOAD_DIR}/BG3PlayerImmersiveCamera" "${MOD_DEST}"

echo "Installing W/A/S/D bindings..."
/bin/mkdir -p "$(/usr/bin/dirname "${INPUT_CONFIG}")"
if [[ -f "${INPUT_CONFIG}" ]]; then
    /bin/cp -p "${INPUT_CONFIG}" "${STATE_DIR}/inputconfig-p1.json"
    /usr/bin/touch "${STATE_DIR}/input-existed"
else
    /usr/bin/touch "${STATE_DIR}/input-created"
fi

/usr/bin/osascript -l JavaScript "${SCRIPT_DIR}/merge-input.js" "${INPUT_CONFIG}"

printf '%s\n' "${PACKAGE_VERSION}" > "${STATE_DIR}/installed"
trap - ERR

echo
echo "Installation complete."
echo "Launch Baldur's Gate 3 normally through Steam."
echo "Press \\ in game to open the camera settings."
pause_at_end
