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

extract_version_from_config_with_executable() {
    local godot_config="${1}"
    local godot_cmd="${2}"

    local filepath_check_version=$(mktemp -d)/check_version.gd

    cat <<EOM >>$filepath_check_version
extends SceneTree

func _init():
    var features = ProjectSettings.get_setting("application/config/features")
    print(features[0] if features else 0)
    quit()
EOM

    VERSION=$($godot_cmd --path $(dirname $godot_config) --headless -s $filepath_check_version | tail -n 1)
}

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
Detects the major and minor version of 'Godot', given a 'project.godot' file.

NOTE: This behavior is best-effort. There is no reliable and canonical way to
extract a version from all 'Godot' project files. If there is no version
specified in the config, or parsing fails, then the latest release will be
determined from GitHub.

Usage: $(basename "${BASH_SOURCE[0]}") [OPTIONS] [PROJECT FILE]

Available options:
    -h, --help              Print this help and exit
    -v, --verbose           Print script debug info
    --godot <FILE>          A filepath or command name for 'Godot' (used to parse the config file).

Project file:
    path/to/project.godot
EOF
    exit
}

parse_params() {
    ACCEPT=0
    GODOT_BIN=""

    while :; do
        case "${1-}" in
        -h | --help) usage ;;
        -v | --verbose) set -x ;;

        --godot)
            GODOT_BIN="${2-}"
            shift
            ;;

        -?*) die "Unknown option: $1" ;;
        *) break ;;
        esac
        shift
    done

    args=("$@")

    # check required params and arguments
    [[ ${#args[@]} -eq 0 ]] && die "Missing argument: 'path/to/project.godot'"
    [[ ! -z "$GODOT_BIN" && ! -x "$GODOT_BIN" ]] && die "Invalid parameter: 'godot' (expected executable)"

    PROJECT_FILE="$(cd $(dirname "${args[0]}") && pwd)/$(basename "${args[0]}")"
    if [[ ! -f "$PROJECT_FILE" || "$PROJECT_FILE" != *"/project.godot" ]]; then
        die "Invalid argument; expected a path to a 'project.godot' file, but was: ${args[0]}"
    fi

    return 0
}

parse_params "$@"

VERSION=0
if [[ ! -z "$GODOT_BIN" ]]; then
    extract_version_from_config_with_executable $PROJECT_FILE "$GODOT_BIN"
elif command -v godot >/dev/null 2>&1; then
    extract_version_from_config_with_executable $PROJECT_FILE godot
elif [[ -x "$PWD/godot" ]]; then
    extract_version_from_config_with_executable $PROJECT_FILE "$PWD/godot"
else
    VERSION=$(grep '^config/features' $PROJECT_FILE | sed 's/.*"\(.*\)".*/\1/') || :
    [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?(-[a-z]+)?$ ]] && VERSION=0 || :
fi

if [[ ! -z "$VERSION" && "$VERSION" != "0" ]]; then
    echo "$VERSION"
    exit 0
fi

need_cmd curl
need_cmd python3

PYTHON_SCRIPT=$(
    cat <<EOF
import sys, json

releases = json.load(sys.stdin)
if not releases:
    raise Exception("Failed to fetch releases from GitHub!")

versions = [r["tag_name"].split("-") for r in releases]
versions = filter(lambda v: v[1] == "stable" and len(v[0].split(".")) == 3, versions)
versions = sorted(versions, key=lambda v: tuple(int(n) for n in v[0].split(".")))
print("-".join(versions[-1]))
EOF
)

curl -sL \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/repos/godotengine/godot/releases\?per_page=25 |
    python3 -c "$PYTHON_SCRIPT"
