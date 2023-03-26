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
Fetches the latest version of the 'Gut' addon from 'GitHub' that matches the
versio string provided.

NOTE: This script will only review the last 'window' (default=25) releases.

Usage: $(basename "${BASH_SOURCE[0]}") [OPTIONS] [VERSION]

Available options:
    -h, --help              Print this help and exit
    -v, --verbose           Print script debug info
    -s, --strict            Fail if no matching version can be found (default=false)
    -w, --window            The number of (most-recent) releases to consider

Supported version strings:
    latest (default)
    [v]MAJOR.MINOR (e.g. 9.0 or v9.0)
    [v]MAJOR (e.g. 9 or v9)
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
        VERSION=""
    elif [[ "$VERSION_STR" =~ ^v?[0-9]+\.[0-9]+$ || "$VERSION_STR" =~ ^v?[0-9]+$ ]]; then
        VERSION="${VERSION_STR#v}"
    else
        die "Invalid argument: 'version'; see below for accepted argument patterns:\n$(usage | tail -n 5)"
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

versions = [r["tag_name"][1:] for r in releases]
versions = filter(lambda v: not version or v.startswith(version), versions)
versions = sorted(versions, key=lambda v: tuple(int(n) for n in v.split(".")))
if versions: print(list(versions)[-1])
EOF
)

OUT=$(
    curl -sL \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        https://api.github.com/repos/bitwes/Gut/releases\?per_page=$WINDOW |
        python3 -c "$PYTHON_SCRIPT"
)

# Failed to find a matching version - fail if in "strict" mode
if [[ "$STRICT" -eq 1 && -z "$OUT" ]]; then
    exit 1
elif [[ ! -z "$OUT" ]]; then
    echo $OUT
fi
