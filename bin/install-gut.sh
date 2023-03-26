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

usage() {
    cat <<EOF
Downloads and extracts the specified version of the 'Gut' testing addon. See
https://github.com/bitwes/Gut for details.

Usage: $(basename "${BASH_SOURCE[0]}") [OPTIONS] [VERSION]

Available options:
    -h, --help              Print this help and exit
    -v, --verbose           Print script debug info
    -o, --out <DIRECTORY>   Which directory to extract the addon into (default=./addons)
    -y, --yes               Automatically accept overwrite prompts (default=false)

Supported version strings:
    [v]MAJOR.MINOR.PATCH (e.g. 4.0.0 or v4.0.0)
EOF
    exit
}

parse_params() {
    ACCEPT=0
    OUT_DIR="$PWD/addons"

    while :; do
        case "${1-}" in
        -h | --help) usage ;;
        -v | --verbose) set -x ;;

        -y | --yes) ACCEPT=1 ;;

        -o | --out)
            OUT_DIR="${2-}"
            shift
            ;;

        -?*) die "Unknown option: $1" ;;
        *) break ;;
        esac
        shift
    done

    args=("$@")

    # check required params and arguments
    [[ -z "$OUT_DIR" ]] && die "Missing required parameter: 'out'"
    [[ -f "$OUT_DIR" || -f "${OUT_DIR%/gut}" ]] && die "Invalid parameter: 'out' (expected a directory, not a file)"
    OUT_DIR="${OUT_DIR%/gut}"

    [[ ${#args[@]} -eq 0 ]] && die "Missing argument: 'version'"
    [[ ! "${args[0]}" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]] && die "Invalid version string: '${args[0]}'"
    VERSION="${args[0]#v}"

    return 0
}

parse_params "$@"

need_cmd curl
need_cmd unzip

msg "Downloading and extracting 'Gut@$VERSION' to '$OUT_DIR/gut'..."
echo ""

# ------------------------ Check for existing download ----------------------- #

msg "   > checking for existing 'Gut' download..."

# If out file already exists, check before overwriting.
if [[ -d "$OUT_DIR/gut" ]]; then
    while true; do
        if [[ "${ACCEPT}" -eq 0 ]]; then
            read -p "   > existing directory '$OUT_DIR/gut' found; okay to overwrite?" yn
        else
            yn=Y
        fi

        case $yn in
        [Yy]*)
            break
            ;;
        [Nn]*)
            die "   > skipping 'Gut' download; ensure the correct version is used!" 0
            ;;
        *) msg "    > please answer yes or no." ;;
        esac
    done
fi

# ------------------------ Download and extract 'Gut' ------------------------ #

INSTALL_DIR=$(mktemp -d)

# download the correct version of 'Gut'
DOWNLOAD_URL="https://github.com/bitwes/Gut/archive/refs/tags/v${VERSION}.zip"
msg "   > downloading 'Gut' from '$DOWNLOAD_URL'..."
echo ""

(cd $INSTALL_DIR && curl -LO $DOWNLOAD_URL) || die "Failed to download 'Gut'!"
echo ""

# extract the source archive
DOWNLOAD_BASENAME="$(basename $DOWNLOAD_URL)"
(cd $INSTALL_DIR && unzip $DOWNLOAD_BASENAME && rm $DOWNLOAD_BASENAME) || die "Failed to extract '$DOWNLOAD_BASENAME'!"
echo ""

# move the executable to the correct location
mkdir -p "$OUT_DIR"
[[ -d "$OUT_DIR/gut" ]] && (rm -rf "$OUT_DIR/gut" || die "Failed to remove existing directory: $OUT_DIR/gut")
mv "$INSTALL_DIR/Gut-${VERSION}/addons/gut" $OUT_DIR

msg "Successfully installed 'Gut'!"
