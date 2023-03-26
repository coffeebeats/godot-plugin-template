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
Determines the latest version of 'Gut' from GitHub releases.

Usage: $(basename "${BASH_SOURCE[0]}") [OPTIONS]

Available options:
    -h, --help              Print this help and exit
    -v, --verbose           Print script debug info
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

versions = [r["tag_name"][1:] for r in releases]
versions = filter(lambda v: len(v.split(".")) == 3, versions)
versions = sorted(versions, key=lambda v: tuple(int(n) for n in v.split(".")))
print(versions[-1])
EOF
)

curl -sL \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/repos/bitwes/Gut/releases\?per_page=25 |
    python3 -c "$PYTHON_SCRIPT"
