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
REPO_NAME="pmotd"
REPO_URL="https://github.com/$REPO_OWNER/$REPO_NAME"
ZIP_URL="$REPO_URL/archive/refs/heads/main.zip"
APP_VERSION="v$(grep '"version"' $CURRDIR/lib/version.json | sed -E 's/.*"version": *"([^"]+)".*/\1/')"

source "$CURRDIR/lib/uzful.sh"

# ==============================================================================================================
# VERSION CONTROL, UPDATES

# "safe-run", abstraction to "run" function, so it can work with our dry mode
# Usage: same as run
function srun() {
    local CMD=$1
    local ACCEPTABLE_EXIT_CODES=$2

    run "$CMD >/dev/null" "$ACCEPTABLE_EXIT_CODES" "$_DRY" "$_SILENT"
}

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

    # install the new motd
    install

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

# === FUNCS ===

function print_help() {
    echo -e "Usage: $SCRIPT_NAME [options]

Options:
    -h, --help            Show this help message
    -v, --version         Show version information
    --forceupdate         Force update to the latest version
    --update              Update to the latest version
    --run                 Install the script
"
    exit 0
}

function install() {
    local TIMESTAMP=$(date +%s)
    local BACKUP_FOLDER="motd-bkp-$TIMESTAMP"

    # fazer uma pasta de bkp
    mkdir -p motd-bkp-$TIMESTAMP

    # remover o motd.sh do issabel
    if [[ -f /usr/local/sbin/motd.sh ]]; then
        echo "Salvando backup de /usr/local/sbin/motd.sh em $BACKUP_FOLDER/"
        cp /usr/local/sbin/motd.sh "$BACKUP_FOLDER/"
        rm -f /usr/local/sbin/motd.sh
    fi

    # remover o profile login-info.sh do issabel
    if [[ -f /etc/profile.d/login-info.sh ]]; then
        echo "Salvando backup de /etc/profile.d/login-info.sh em $BACKUP_FOLDER/"
        cp /etc/profile.d/login-info.sh "$BACKUP_FOLDER/"
        rm -f /etc/profile.d/login-info.sh
    fi

    # versão antiga
    if [[ -f /etc/profile.d/motd.sh ]]; then
        echo "Parece que já tem um motd.sh instalado. Salvando e substituindo."
        echo "Salvando backup de /etc/profile.d/motd.sh em $BACKUP_FOLDER/"
        cp /etc/profile.d/motd.sh "$BACKUP_FOLDER/"
        rm -f /etc/profile.d/motd.sh
    fi

    # versão nova
    if [[ -f /etc/profile.d/pmotd.sh ]]; then
        echo "Parece que já tem um pmotd.sh instalado. Salvando e substituindo."
        echo "Salvando backup de /etc/profile.d/pmotd.sh em $BACKUP_FOLDER/"
        cp /etc/profile.d/pmotd.sh "$BACKUP_FOLDER/"
        rm -f /etc/profile.d/pmotd.sh
    fi

    # copiar o motd.sh para /etc/profile.d/pmotd.sh
    echo "Instalando pmotd.sh em /etc/profile.d/pmotd.sh"
    cp "$CURRDIR/pmotd.sh" /etc/profile.d/pmotd.sh
    chmod +x /etc/profile.d/pmotd.sh

    # sanity check:
    # - /etc/profile.d/motd.sh exists
    # - /usr/local/sbin/motd.sh does not exist
    # - /etc/profile.d/login-info.sh does not exist
    if [[ -f /etc/profile.d/pmotd.sh ]] \
    && [[ ! -f /usr/local/sbin/motd.sh ]] \
    && [[ ! -f /etc/profile.d/login-info.sh ]]; then
        echo "$(colorir "verde" "Instalação concluída com sucesso!")"
    else
        echo "$(colorir "vermelho" "Sanity check falhou. Verifique os arquivos!")"
        exit 1
    fi
}

# === RUNTIME ===

function main () {
    if [[ "$#" -eq 0 ]]; then
        print_help
    fi

    if [[ "$EUID" -ne 0 ]]; then
        echo "FATAL: This script must be run as root."
        exit 1
    fi

    if [[ "$#" -gt 1 ]]; then
        echo "FATAL: Only one option is allowed."
        exit 1
    fi

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS="$PRETTY_NAME"
        ID="$ID"
    else
        echo "FATAL: Não foi possível identificar o sistema (sem /etc/os-release)"
        exit 1
    fi

    if [[ "$ID" != "centos" && "$ID" != "rocky" ]]; then
        echo "FATAL: This script is only compatible with CentOS and Rocky Linux. (Detected: $OS)"
        exit 1
    fi


    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -h|--help) print_help;;
            -v|--version) echo "$APP_VERSION"; exit 0;;
            --update) check_for_updates;;
            --forceupdate) check_for_updates "true";;
            --run) install;;
            *) echo "Invalid argument: $1"; exit 1;;
        esac
        shift
    done
}

main "$@"