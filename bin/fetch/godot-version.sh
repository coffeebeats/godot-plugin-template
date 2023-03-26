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
Fetches the latest version of 'Godot' from 'GitHub' that matches the version
string provided. If a label is provided in the version string, any releases
with labels that *start with* the label string will be matched (e.g. "canary"
would match release "4.0-canary10").

NOTE: This script will only review the last 'window' (default=25) releases.

Usage: $(basename "${BASH_SOURCE[0]}") [OPTIONS] [VERSION]

Available options:
    -h, --help              Print this help and exit
    -v, --verbose           Print script debug info
    -s, --strict            Fail if no matching version can be found (default=false)
    -w, --window            The number of (most-recent) releases to consider

Supported version strings:
    latest (default)
    LABEL (e.g. stable)
    MAJOR.MINOR[-LABEL] (e.g. 4.0 or 4.0-stable)
    MAJOR[-LABEL] (e.g. 4 or 4-stable)
EOF
    exit
}

parse_params() {
    STRICT=0
    WINDOW=25

    while :; do
        case "${1-}" in
        -h | --help) usage ;;
        -v | --verbose) set -x ;;

        -s | --strict) STRICT=1 ;;

        -w | --window)
            WINDOW="${2-}"
            shift
            ;;

        -?*) die "Unknown option: $1" ;;
        *) break ;;
        esac
        shift
    done

    args=("$@")

    # check required params and arguments
    [[ -z "$WINDOW" ]] && die "Missing required parameter: 'window'"

    VERSION_STR="${args[0]:-latest}"
    if [[ "$VERSION_STR" == "latest" ]]; then
        LABEL="stable"
        VERSION=""
    elif [[ "$VERSION_STR" =~ ^[0-9]+\.[0-9]+(-.+)?$ ]]; then
        LABEL=$(echo $VERSION_STR | sed 's/[[:digit:]]\+.[[:digit:]]\+-\?//')
        VERSION="${VERSION_STR%-*}"
    elif [[ "$VERSION_STR" =~ ^[0-9]+(-.+)?$ ]]; then
        LABEL=$(echo $VERSION_STR | sed 's/[[:digit:]]\+-\?//')
        VERSION="${VERSION_STR%-*}"
    elif [[ "$VERSION_STR" =~ ^[a-zA-Z][^-]+$ ]]; then
        LABEL="$VERSION_STR"
        VERSION=""
    else
        die "Invalid argument: 'version'; see below for accepted argument patterns:\n$(usage | tail -n 6)"
    fi

    return 0
}

parse_params "$@"

need_cmd curl
need_cmd python3

PYTHON_SCRIPT=$(
    cat <<EOF
import sys, json

releases = json.load(sys.stdin)
if not releases:
    raise Exception("Failed to fetch releases from GitHub!")

version = "${VERSION}"
label = "${LABEL:-stable}"

versions = [r["tag_name"].split("-") for r in releases]
versions = filter(lambda v: v[1].startswith(label) and (not version or v[0].startswith(version)), versions)
versions = sorted(versions, key=lambda v: tuple(int(n) for n in v[0].split(".")))
if versions: print("-".join(list(versions)[-1]))
EOF
)

OUT=$(
    curl -sL \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        https://api.github.com/repos/godotengine/godot/releases\?per_page=$WINDOW |
        python3 -c "$PYTHON_SCRIPT"
)

# Failed to find a matching version - fail if in "strict" mode
if [[ "$STRICT" -eq 1 && -z "$OUT" ]]; then
    exit 1
elif [[ ! -z "$OUT" ]]; then
    echo $OUT
fi
