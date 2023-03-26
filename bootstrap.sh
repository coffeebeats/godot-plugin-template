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
Bootstraps and/or updates the repository for development.

Usage: $(basename "${BASH_SOURCE[0]}") [OPTIONS]

NOTE: The following dependencies are required:
    - python3

Available options:
    -h, --help          Print this help and exit
    -v, --verbose       Print script debug info (default=false)
    -y, --yes           Automatically accept all prompts (default=false)
    --[no]color         Whether to enable colored output for logging (default=true)
EOF
    exit
}

parse_params() {
    ACCEPT=0
    NO_COLOR=0

    while :; do
        case "${1-}" in
        -h | --help) usage ;;
        -v | --verbose) set -x ;;

        --color) NO_COLOR=0 ;;
        --no-color) NO_COLOR=1 ;;

        -y | --yes) ACCEPT=1 ;;

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

if [[ ! -d "$PWD/addons" || ! -d "$PWD/bin" ]]; then
    die "Could not find 'addons' directory; are you in the right directory?"
fi

info "Bootstrapping the repository for development..."

# ------------------------------- Check: Godot ------------------------------- #

echo ""
info "Installing 'Godot' executable..."

# determine the correct version to install
GODOT_VERSION=$(./bin/detect-godot-version.sh $PWD/project.godot)

# install the correct version
./bin/install-godot.sh \
    $([[ "$ACCEPT" -eq 1 ]] && echo "-y") \
    -o $PWD/godot \
    $GODOT_VERSION

# ------------------------------- Install: Gut ------------------------------- #

echo ""
info "Installing the 'Gut' testing addon..."

# determine the correct version to install
GUT_VERSION=$(./bin/detect-gut-version.sh)

# if the currently installed version (if any) doesn't match, update it
GUT_DIR="$PWD/addons/gut"
if [[ 
    ! -d "$GUT_DIR" ||
    ! -f "$GUT_DIR/plugin.cfg" ||
    "$(cat "$GUT_DIR/plugin.cfg" | grep "version=\"$GUT_VERSION\"" | sed 's/version=\"\([[:digit:]].[[:digit:]].[[:digit:]]\)\"/\1/')" != "$GUT_VERSION" ]] \
    ; then
    # install the correct version
    ./bin/install-gut.sh \
        $([[ "$ACCEPT" -eq 1 ]] && echo "-y") \
        -o $PWD/addons \
        $GUT_VERSION
else
    info "'Gut' addon already installed; skipping download!"
fi

# ---------------------------- Install: GDToolkit ---------------------------- #

echo ""
info "Installing the 'GDToolkit' formatting and linting library..."

./bin/install-gdtoolkit.sh "latest"

# ---------------------------------------------------------------------------- #

echo ""
info "Successfully bootstrapped repository!"
