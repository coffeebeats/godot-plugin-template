#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

trap cleanup SIGINT SIGTERM ERR EXIT

cleanup() {
    trap - SIGINT SIGTERM ERR EXIT
}

# ------------------------- Define: Logging functions ------------------------ #

setup_colors() {
    if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
        NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
    else
        NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
    fi
}

msg() {
    echo >&2 -e "${1-}"
}

debug() {
    echo >&2 -e "${BLUE}DEBUG${NOFORMAT} ${1-}"
}

err() {
    echo >&2 -e "${RED}ERR${NOFORMAT} ${1-}"
}

info() {
    echo >&2 -e "${GREEN}INFO${NOFORMAT} ${1-}"
}

warn() {
    echo >&2 -e "${YELLOW}WARN${NOFORMAT} ${1-}"
}

die() {
    local msg=$1
    local code=${2-1} # default exit status 1
    err "$msg"
    exit "$code"
}

# ------------------------- Define: Script Arguments ------------------------- #

usage() {
    cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h,--help] [-v,--verbose] [--no-color] [-y,--yes] [--install-godot] 
Bootstraps and/or updates the repository for development.

NOTE: The following dependencies are required:
    - python3

Available options:
-h, --help          Print this help and exit
-v, --verbose       Print script debug info
-y, --yes           Automatically accept all prompts
--install-godot     Downloads a local copy of 'godot'
--no-color          Disables the use of color when logging
EOF
    exit
}

parse_params() {
    ACCEPT=0
    QUIET=0
    INSTALL_GODOT=0

    while :; do
        case "${1-}" in
        -h | --help) usage ;;
        -v | --verbose) set -x ;;
        -y | --yes) ACCEPT=1 ;;
        --install-godot) INSTALL_GODOT=1 ;;
        --no-color) NO_COLOR=1 ;;
        -?*) die "Unknown option: $1" ;;
        *) break ;;
        esac
        shift
    done

    args=("$@")

    return 0
}

setup_colors
parse_params "$@"

if [[ ! -d "$SCRIPT_DIR/addons" ]]; then
    die "Could not find 'addons' directory; was the repository cloned correctly?"
fi

info "Bootstrapping the repository for development..."

# ------------------------------- Check: Python ------------------------------- #

echo ""
info "Checking for a 'python3' install..."

if [[ "$(
    command -v python3 >/dev/null
    echo $?
)" -ne 0 ]]; then
    warn "Could not find 'python3' on \$PATH; please install and then re-run!"
else
    info "Ok! Using 'python3' executable: $(which python3)"
fi

# ------------------------------- Check: Godot ------------------------------- #

echo ""
info "Checking for a 'godot' install..."

GODOT_INSTALL_REQUIRED=0
if [[ "$INSTALL_GODOT" -eq 1 && -f "$SCRIPT_DIR/godot" ]]; then
    info "Ok! using 'godot' executable: $(ls $SCRIPT_DIR/godot)"
elif [[ "$INSTALL_GODOT" -eq 1 ]]; then
    GODOT_INSTALL_REQUIRED=1
elif [[ "$(
    command -v godot >/dev/null
    echo $?
)" -ne 0 ]]; then
    warn "Could not find 'godot' on \$PATH; consider creating an alias or re-running with the '--install-godot' flag!"
else
    info "Ok! Using 'godot' executable: $(which godot)"
fi

# Check with the user if it's okay to download 'godot'
if [[ "$GODOT_INSTALL_REQUIRED" -eq 1 ]]; then
    while true; do
        if [[ "${ACCEPT}" -eq 0 ]]; then
            read -p "   > downloading 'godot' to '$SCRIPT_DIR/godot'; is this okay?" yn
        else
            yn=Y
        fi

        case $yn in
        [Yy]*)
            break
            ;;
        [Nn]*)
            warn "Skipping 'godot' download; you will be unable to test code without it!"
            GODOT_INSTALL_REQUIRED=0
            break
            ;;
        *) msg "Please answer yes or no." ;;
        esac
    done
fi

# If it is then download to $SCRIPT_DIR
if [[ "$GODOT_INSTALL_REQUIRED" -eq 1 ]]; then

    case "$(uname | tr '[:upper:]' '[:lower:]')" in
    darwin*) PLATFORM="macos.universal" ;;
    linux*) PLATFORM="linux.$HOSTTYPE" ;;
    msys*) PLATFORM="win$([[ "$HOSTTYPE" == "x86" ]] && echo 32 || echo 64).exe" ;;
    *) die "Unknown platform type; please file an issue!" ;;
    esac

    INSTALL_DIR=$(mktemp -d)

    # download the correct version of 'gut'
    GODOT_VERSION="4.0.1" # TODO: Make this an option
    GODOT_DOWNLOAD_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_${PLATFORM}.zip"
    debug "Downloading 'godot' from '$GODOT_DOWNLOAD_URL'..."
    (cd $INSTALL_DIR && curl -LO $GODOT_DOWNLOAD_URL) || die "Failed to download 'godot'!"

    # extract the source archive
    GODOT_DOWNLOAD_BASENAME="$(basename $GODOT_DOWNLOAD_URL)"
    (cd $INSTALL_DIR && unzip $GODOT_DOWNLOAD_BASENAME && rm $GODOT_DOWNLOAD_BASENAME) || die "Failed to extract '$GODOT_DOWNLOAD_BASENAME'!"

    # move the addon into the correct location
    mv "$INSTALL_DIR/${GODOT_DOWNLOAD_BASENAME%.zip}" "${SCRIPT_DIR}/godot"
    chmod +x "${SCRIPT_DIR}/godot"

    echo ""
    info "Successfully downloaded 'godot' to '${SCRIPT_DIR}/godot'!"
fi

# ------------------------------- Install: Gut ------------------------------- #

echo ""
info "Checking for a 'gut' addon install..."

if [[ ! -f "$SCRIPT_DIR/addons/gut/plugin.cfg" ]]; then
    info "No installation of 'gut' found; installing now..."
    echo ""

    INSTALL_DIR=$(mktemp -d)

    # download the correct version of 'gut'
    GUT_VERSION="9.0.1" # TODO: Make this an option
    GUT_DOWNLOAD_URL="https://github.com/bitwes/Gut/archive/refs/tags/v${GUT_VERSION}.tar.gz"
    (cd $INSTALL_DIR && curl -LO $GUT_DOWNLOAD_URL) || die "Failed to download 'gut'!"

    # extract the source archive
    GUT_DOWNLOAD_BASENAME="$(basename $GUT_DOWNLOAD_URL)"
    (cd $INSTALL_DIR && tar -xzf $GUT_DOWNLOAD_BASENAME) || die "Failed to extract '$GUT_DOWNLOAD_BASENAME'!"

    # move the addon into the correct location
    mv "${INSTALL_DIR}/Gut-${GUT_VERSION}/addons/gut" "${SCRIPT_DIR}/addons"

    echo ""
    info "Successfully installed the 'gut' addon!"
else
    info "Found existing installation of 'gut'; skipping install!"
fi

# ---------------------------- Install: GDToolkit ---------------------------- #

echo ""
info "Checking for 'gdtoolkit' install..."

GDTK="gdtoolkit"

# Determine the latest version of 'gdtoolkit'
GDTK_VERSION_LATEST="$(python3 -m pip index versions gdtoolkit | grep gdtoolkit | sed 's/^gdtoolkit (\(.*\))$/\1/')"
GDTK_MAJOR_VERSION_LATEST="${GDTK_VERSION_LATEST%%.*}"
GDTK_MINOR_VERSION_LATEST="$(echo $GDTK_VERSION_LATEST | sed 's/^[[:digit:]]\+.\(.*\).[[:digit:]]\+$/\1/')"

GDTK_VERSION="$(
    TMP=$(python3 -m pip list | grep gdtoolkit)
    [[ "$?" -eq 0 ]] && echo $TMP | sed -E 's/gdtoolkit( )+//' || echo '0.0.0'
)"
GDTK_MAJOR_VERSION="${GDTK_VERSION%%.*}"
GDTK_MINOR_VERSION="$(echo $GDTK_VERSION | sed 's/^[[:digit:]]\+.\(.*\).[[:digit:]]\+$/\1/')"

GDTK_INSTALL_REQUIRED=1
GDTK_UPDATE_REQUIRED=0
if [[ "$GDTK_VERSION" == "0.0.0" ]]; then
    info "No installation  of 'gdtoolkit' found; installing now..."
    echo ""
elif [[ 
    "$GDTK_MAJOR_VERSION" -lt "$GDTK_MAJOR_VERSION_LATEST" ||
    "$GDTK_MINOR_VERSION" -lt "$GDTK_MINOR_VERSION_LATEST" ]] \
    ; then
    GDTK_UPDATE_REQUIRED=1
    debug "Found version '$GDTK_VERSION', but latest was '$GDTK_VERSION_LATEST'."
    info "Out of date installation 'gdtoolkit==${GDTK_VERSION}' found; updating now..."
    echo ""
else
    GDTK_INSTALL_REQUIRED=0
    info "Found existing installation of 'gdtoolkit'; skipping install!"
fi

if [[ "$GDTK_INSTALL_REQUIRED" -eq 1 ]]; then
    while true; do
        if [[ "${ACCEPT}" -eq 0 ]]; then
            read -p "Installing/updating 'gdtoolkit' using '$(which python3) -m pip'; is this okay?" yn
        else
            yn=Y
        fi

        case $yn in
        [Yy]*)
            python3 -m pip install $([[ "$GDTK_UPDATE_REQUIRED" -eq 1 ]] && echo '--upgrade') gdtoolkit
            break
            ;;
        [Nn]*)
            warn "Skipping 'gdtoolkit' install; code formatting and linting may not be available!"
            break
            ;;
        *) msg "Please answer yes or no." ;;
        esac
    done
fi

# ---------------------------------------------------------------------------- #

echo ""
info "Successfully bootstrapped repository!"
