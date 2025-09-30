#!/bin/bash

# Author : Adrian K. (https://github.com/adriankubinyete)
# Co-author, assistance : Rafael R. (https://github.com/rafaelRizzo) 

# === CONSTANTS ===

# General script constants
FULL_SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
CURRDIR="$(dirname "$FULL_SCRIPT_PATH")"
SCRIPT_NAME="$(basename "$FULL_SCRIPT_PATH")"

# Versioning 
REPO_OWNER="phonevox"
REPO_NAME="motd"
REPO_URL="https://github.com/$REPO_OWNER/$REPO_NAME"
ZIP_URL="$REPO_URL/archive/refs/heads/main.zip"
APP_VERSION="v$(grep '"version"' $CURRDIR/lib/version.json | sed -E 's/.*"version": *"([^"]+)".*/\1/')"

source "$CURRDIR/lib/uzful.sh"

# === FUNCS ===

function print_help() {
    echo -e "Usage: $SCRIPT_NAME [options]

Options:
    -h, --help            Show this help message
    -u, --update          Update to the latest version
    -v, --version         Show version information
    --run                 Install the script
"
    exit 0
}

function update() {
    echo "update"
}

function install() {
    echo "install"
}

# ==============================================================================================================
# VERSION CONTROL, UPDATES

function check_for_updates() {
    local FORCE_UPDATE="false"; if [[ -n "$1" ]]; then FORCE_UPDATE="true"; fi
    local CURRENT_VERSION=$APP_VERSION
    local LATEST_VERSION="$(curl -s https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/tags | grep '"name":' | head -n 1 | sed 's/.*"name": "\(.*\)",/\1/')"

    # its the same version
    if ! version_is_greater "$LATEST_VERSION" "$CURRENT_VERSION"; then
        echo "$(colorir verde "You are using the latest version. ($CURRENT_VERSION)")"
        if ! $FORCE_UPDATE; then exit 1; fi
    else
        echo "You are not using the latest version. (CURRENT: '$CURRENT_VERSION', LATEST: '$LATEST_VERSION')"
    fi

    echo "Do you want to download the latest version from source? ($(colorir azul "$CURRENT_VERSION") -> $(colorir azul "$LATEST_VERSION")) ($(colorir verde y)/$(colorir vermelho n))"
    read -r _answer 
    if ! [[ "$_answer" == "y" ]]; then
        echo "Exiting..."
        exit 1
    fi
    update_all_files
    exit 0
}

# needs curl and unzip installed
function update_all_files() {
    local INSTALL_DIR=$CURRDIR
    local REPO_NAME=$REPO_NAME
    local ZIP_URL=$ZIP_URL

    echo "- Creating temp dir"
    tmp_dir=$(mktemp -d) # NOTE(adrian): this is not dry-able. dry will actually make change in the system just as this tmp folder.
    
    echo "- Downloading repository zip to '$tmp_dir/repo.zip'"
    srun "curl -L \"$ZIP_URL\" -o \"$tmp_dir/repo.zip\""

    echo "- Unzipping '$tmp_dir/repo.zip' to '$tmp_dir'"
    srun "unzip -qo \"$tmp_dir/repo.zip\" -d \"$tmp_dir\""

    echo "- Copying files from '$tmp_dir/$REPO_NAME-main' to '$INSTALL_DIR'"
    srun "cp -r \"$tmp_dir/$REPO_NAME-main/\"* \"$INSTALL_DIR/\""
    
    echo "- Updating permissions on '$INSTALL_DIR'"
    srun "find \"$INSTALL_DIR\" -type f -name \"*.sh\" -exec chmod +x {} \;"

    # cleaning
    echo "- Cleaning up"
    srun "rm -rf \"$tmp_dir\""
    echo "--- UPDATE FINISHED ---"
}


function version_is_greater() {
    # ignore metadata
    ver1=$(echo "$1" | grep -oE '^[vV]?[0-9]+\.[0-9]+\.[0-9]+')
    ver2=$(echo "$2" | grep -oE '^[vV]?[0-9]+\.[0-9]+\.[0-9]+')
    
    # remove "v" prefix
    ver1="${ver1#v}"
    ver2="${ver2#v}"

    # gets major, minor and patch
    IFS='.' read -r major1 minor1 patch1 <<< "$ver1"
    IFS='.' read -r major2 minor2 patch2 <<< "$ver2"

    # compares major, then minor, then patch
    if (( major1 > major2 )); then
        return 0
    elif (( major1 < major2 )); then
        return 1
    elif (( minor1 > minor2 )); then
        return 0
    elif (( minor1 < minor2 )); then
        return 1
    elif (( patch1 > patch2 )); then
        return 0
    else
        return 1
    fi
}
# === RUNTIME ===

function main () {
    if [[ "$#" -eq 0 ]]; then
        print_help
    fi

    # if [[ "$EUID" -ne 0 ]]; then
    #     echo "FATAL: This script must be run as root."
    #     exit 1
    # fi

    if [[ "$#" -gt 1 ]]; then
        echo "FATAL: Only one option is allowed."
        exit 1
    fi

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -h|--help) print_help;;
            -v|--version) echo "$APP_VERSION"; exit 0;;
            --update) check_for_updates;;
            --run) install;;
            *) echo "Invalid argument: $1"; exit 1;;
        esac
        shift
    done
}

main "$@"