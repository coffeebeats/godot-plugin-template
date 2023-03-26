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
Downloads and extracts the specified version of 'Godot'.

Usage: $(basename "${BASH_SOURCE[0]}") [OPTIONS] [VERSION]

Available options:
    -h, --help          Print this help and exit
    -v, --verbose       Print script debug info
    -o, --out <FILE>    The filepath of the extracted executable (default=./godot)
    -y, --yes           Automatically accept overwrite prompts (default=false)

Supported version strings:
    MAJOR.MINOR.PATCH[-LABEL] (e.g. 4.0.0 or 4.0.0-stable)
    MAJOR.MINOR[-LABEL] (e.g. 4.0 or 4.0-stable)
EOF
    exit
}

parse_params() {
    ACCEPT=0
    OUT_FILE="$PWD/godot"

    while :; do
        case "${1-}" in
        -h | --help) usage ;;
        -v | --verbose) set -x ;;

        -y | --yes) ACCEPT=1 ;;

        -o | --out)
            OUT_FILE="${2-}"
            shift
            ;;

        -?*) die "Unknown option: $1" ;;
        *) break ;;
        esac
        shift
    done

    args=("$@")

    # check required params and arguments
    [[ -z "$OUT_FILE" ]] && die "Missing required parameter: 'out'"
    [[ ${#args[@]} -eq 0 ]] && die "Missing argument: 'version'"

    [[ -d "$OUT_FILE" ]] && die "Invalid parameter: 'out' (expected a filepath, not a directory)"
    [[ ! "${args[0]}" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?(-[a-z]+)?$ ]] && die "Invalid version string: '${args[0]}'"

    LABEL=$(echo ${args[0]} | sed 's/[[:digit:]]\+.[[:digit:]]\+\(.[[:digit:]]\+\)\?-\?//')
    VERSION="${args[0]%-*}-${LABEL:-stable}"

    return 0
}

parse_params "$@"

need_cmd curl
need_cmd unzip

msg "Downloading and extracting 'Godot@$VERSION' to '$OUT_FILE'..."
echo ""

# ------------------------ Check for existing download ----------------------- #

msg "   > checking for existing 'godot' executable..."

# If an existing executable is found, check before continuing.
if command -v godot >/dev/null 2>&1 && [[ "$(godot --version)" == "${VERSION%-*}"* ]]; then
    die "   > skipping 'Godot' download; existing executable is the correct version: $(which godot)" 0
elif [[ -x $OUT_FILE && "$($OUT_FILE --version || :)" == "${VERSION%-*}"* ]]; then
    die "   > skipping 'Godot' download; existing executable is the correct version: $OUT_FILE" 0
elif [[ -f $OUT_FILE ]]; then
    while true; do
        if [[ "${ACCEPT}" -eq 0 ]]; then
            read -p "   > existing file '$OUT_FILE' found; okay to overwrite?" yn
        else
            yn=Y
        fi

        case $yn in
        [Yy]*)
            break
            ;;
        [Nn]*)
            die "   > skipping 'Godot' download; ensure the correct version is used!" 0
            ;;
        *) msg "    > please answer yes or no." ;;
        esac
    done
fi

# ----------------------- Download and extract 'Godot' ----------------------- #

# Download and extract 'Godot' executable
case "$(uname | tr '[:upper:]' '[:lower:]')" in
darwin*) PLATFORM="macos.universal" ;;
linux*) PLATFORM="linux.x86_$([[ "$HOSTTYPE" == "x86" ]] && echo 32 || echo 64)" ;;
msys*) PLATFORM="win$([[ "$HOSTTYPE" == "x86" ]] && echo 32 || echo 64).exe" ;;
*) die "Unknown platform type; please file an issue!" ;;
esac

INSTALL_DIR=$(mktemp -d)

# download the correct version of 'Godot'
DOWNLOAD_URL="https://github.com/godotengine/godot/releases/download/${VERSION}/Godot_v${VERSION}_${PLATFORM}.zip"
msg "   > downloading 'godot' from '$DOWNLOAD_URL'..."
echo ""

(cd $INSTALL_DIR && curl -LO $DOWNLOAD_URL) || die "Failed to download 'godot'!"
echo ""

# extract the source archive
DOWNLOAD_BASENAME="$(basename $DOWNLOAD_URL)"
(cd $INSTALL_DIR && unzip $DOWNLOAD_BASENAME && rm $DOWNLOAD_BASENAME) || die "Failed to extract '$DOWNLOAD_BASENAME'!"
echo ""

# move the executable to the correct location
mkdir -p "$(dirname $OUT_FILE)"
mv "$INSTALL_DIR/${DOWNLOAD_BASENAME%.zip}" $OUT_FILE

chmod +x $OUT_FILE

msg "Successfully installed 'Godot'!"
