#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

trap cleanup SIGINT SIGTERM ERR EXIT

cleanup() {
    trap - SIGINT SIGTERM ERR EXIT
}

# ------------------------- Define: Script Arguments ------------------------- #

usage() {
    cat <<EOF
Tries to find an existing 'Godot' executable. This is not an exhaustive search -
only a 'godot' command on '\$PATH' or a local download will be found.

Usage: $(basename "${BASH_SOURCE[0]}") [OPTIONS]

Available options:
    -h, --help              Print this help and exit
    -v, --verbose           Print script debug info
    -f, --fail-on-missing   Return a non-zero exit code if not found (default=false)        
EOF
    exit
}

parse_params() {
    FAIL_ON_MISSING=0

    while :; do
        case "${1-}" in
        -h | --help) usage ;;
        -v | --verbose) set -x ;;
        -f | --fail-on-missing) FAIL_ON_MISSING=1 ;;
        -?*) die "Unknown option: $1" ;;
        *) break ;;
        esac
        shift
    done

    args=("$@")

    return 0
}

parse_params "$@"

if [[ -x "$PWD/godot" ]]; then
    echo "$PWD/godot"
    exit 0
fi

if command -v godot >/dev/null 2>&1; then
    echo "godot"
    exit 0
fi

[[ "$FAIL_ON_MISSING" -eq 1 ]] && exit 1 || :
