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
Usage: $(basename "${BASH_SOURCE[0]}") [-h,--help] [-v,--verbose] [-y,--yes]
Bootstraps and/or updates the repository for development.

NOTE: The following dependencies are required:
    - python3

Available options:
-h, --help          Print this help and exit
-v, --verbose       Print script debug info
-y, --yes           Automatically accept all prompts
--no-color          Disables the use of color when logging
EOF
    exit
}

parse_params() {
    ACCEPT=0
    QUIET=0

    while :; do
        case "${1-}" in
        -h | --help) usage ;;
        -v | --verbose) set -x ;;
        -y | --yes) ACCEPT=1 ;;
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
fi

# ------------------------------- Check: Godot ------------------------------- #

echo ""
info "Checking for a 'godot' install..."

if [[ "$(
    command -v godot >/dev/null
    echo $?
)" -ne 0 ]]; then
    warn "Could not find 'godot' on \$PATH; consider creating an alias!"
fi

# ------------------------------- Install: Gut ------------------------------- #

echo ""
info "Checking for a 'gut' addon install..."

if [[ ! -f "$SCRIPT_DIR/addons/gut/plugin.cfg" ]]; then
    info "No installation of 'gut' found; installing now..."
    echo ""

    GUT_INSTALL_DIR=$(mktemp -d)

    # download the correct version of 'gut'
    GUT_VERSION="9.0.1" # TODO: Make this an option
    GUT_DOWNLOAD_URL="https://github.com/bitwes/Gut/archive/refs/tags/v${GUT_VERSION}.tar.gz"
    (cd $GUT_INSTALL_DIR && curl -LO $GUT_DOWNLOAD_URL) || die "Failed to download 'gut'!"

    # extract the source archive
    (cd $GUT_INSTALL_DIR && tar -xzf "$(basename $GUT_DOWNLOAD_URL)") || die "Failed to extract '$GUT_BASENAME.tar.gz'!"

    # move the addon into the correct location
    mv "${GUT_INSTALL_DIR}/Gut-${GUT_VERSION}/addons/gut" "${SCRIPT_DIR}/addons"

    echo ""
    info "Successfully installed the 'gut' addon!"
else
    info "Found existing installation of 'gut'; skipping install!"
fi

# ---------------------------- Install: GDToolkit ---------------------------- #

echo ""
info "Checking for *local* 'gdtoolkit' install..."

if [[ ! -d "$SCRIPT_DIR/third_party/gdtoolkit" ]]; then
    info "No installation of 'gdtoolkit' found; installing now..."
    echo ""

else
    info "Found existing installation of 'gdtoolkit'; skipping install!"
fi

# ---------------------------------------------------------------------------- #

echo ""
info "Successfully bootstrapped repository!"
