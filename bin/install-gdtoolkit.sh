#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

trap cleanup SIGINT SIGTERM ERR EXIT

cleanup() {
    trap - SIGINT SIGTERM ERR EXIT
}

# ------------------------- Define: Logging functions ------------------------ #

msg() {
    echo >&2 -e "${1-}"
}

die() {
    local msg=$1
    local code=${2-1} # default exit status 1
    echo >&2 -e "$msg"
    exit "$code"
}

# ------------------------- Define: Utility functions ------------------------ #

need_cmd() {
    if ! check_cmd "$1"; then
        die "Failed to execute; need '$1' (command not found)" 1
    fi
}

check_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# ------------------------- Define: Script Arguments ------------------------- #

GDTK="gdtoolkit"

usage() {
    cat <<EOF
Installs the specified version of the '$GDTK' Python library. See
https://pypi.org/project/gdtoolkit/ for details.

Usage: $(basename "${BASH_SOURCE[0]}") [OPTIONS] [VERSION]

Available options:
    -h, --help              Print this help and exit
    -v, --verbose           Print script debug info

Supported version strings:
    latest (default)
    MAJOR.MINOR.PATCH (e.g. 4.0.0)
    MAJOR.MINOR (e.g. 4.0)
    MAJOR (e.g. 4)
EOF
    exit
}

parse_params() {
    ACCEPT=0

    while :; do
        case "${1-}" in
        -h | --help) usage ;;
        -v | --verbose) set -x ;;

        -?*) die "Unknown option: $1" ;;
        *) break ;;
        esac
        shift
    done

    args=("$@")

    # check required params and arguments
    VERSION="${args[0]:-latest}"
    if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+)?(\.[0-9]+)?$ && "$VERSION" != "latest" ]]; then
        die "Invalid version string: '$VERSION'"
    fi

    return 0
}

parse_params "$@"

need_cmd python3

msg "Installing 'gdtoolkit@$VERSION' using '$(which python3)'..."
echo ""

# ---------------------- Install the 'gdtoolkit' library --------------------- #

VERSION_STR="gdtoolkit"
if [[ "$VERSION" != "latest" ]]; then
    VERSION_STR="$VERSION_STR==$(echo $VERSION$([[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || echo '.*'))"
fi

python3 \
    -m pip install \
    --upgrade \
    $VERSION_STR
