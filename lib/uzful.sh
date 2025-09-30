#!/bin/bash

# safeguard: check if important constants are set
if [[ -z "$CURRDIR" ]]; then
    echo -e "ERROR: uzful.sh: Please set CURRDIR in your main script.\n" >&2
    echo 'CURRDIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"' >&2
    exit 1
fi

# to check for extra modules like colors and logging: where is uzful.sh?
_UZFUL_DIRNAME="$(dirname $(readlink -f "${BASH_SOURCE[0]}"))"

# import coloring, else do colorless
if [[ -f "$_UZFUL_DIRNAME/colors.sh" ]]; then
    source "$_UZFUL_DIRNAME/colors.sh"
else
    function colorir() {
        local COLOR="$1"
        local TEXT="$2"
        echo "$2"
    }
fi

# import log
if [[ -f "$_UZFUL_DIRNAME/logging.sh" && ! -z "$_LOG_FILE" ]]; then
    source "$_UZFUL_DIRNAME/logging.sh"
else
    echo "--- $(colorir "vermelho" "CRITICAL WARNING: YOU DO NOT HAVE THE LOGGING MODULE ENABLED. FAKE LOGGING WILL BE USED INSTEAD") ---"
    echo -e "$(colorir "amarelo" "Make sure you have the logging module in the same folder as uzful.sh, and that you have set up _LOG_FILE in your main script.\n_LOG_FILE should represent the complete path to log file, example: /var/log/myscript.log\nBecause the fallback is in place, the log level won't be respected!")"
    echo "--- $(colorir "vermelho" "CRITICAL WARNING: YOU DO NOT HAVE THE LOGGING MODULE ENABLED. FAKE LOGGING WILL BE USED INSTEAD") ---"
    function log() {
        # if argument 2 is not present, then echo the message ($1)
        if [[ -z "$2" ]]; then
            echo "$1"
        fi
    }
    # im so sorry for what you're about to see
    function log.test () { 
        log "$1" "$2"
    }
    function log.trace () { 
        log "$1" "$2"
    }
    function log.debug() { 
        log "$1" "$2"
    }
    function log.info() { 
        log "$1" "$2"
    }
    function log.warn() { 
        log "$1" "$2"
    }
    function log.error() { 
        log "$1" "$2"
    }
    function log.fatal() { 
        log "$1" "$2"
    }
fi

# --- useful constants

# --- useful functions

# returns the current operational system
# call in subshell and store the echo'ed value in a variable
# returns "ID"+"VERSION_ID" from /etc/os-release
# Usage: OS=$(get_os)
function get_os() {

    local INFO=$(echo $(get_os_info "ID") $(get_os_info "VERSION_ID") | tr -d '"' | tr '[:upper:]' '[:lower:]')
    echo $INFO

    # echo "$(echo $(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"') $(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"') | tr '[:upper:]' '[:lower:]')"
}

# returns information from /etc/os-release
# call in subshell and store the echo'ed value in a variable
# Usage: OS_ID=$(get_os_info "ID")
function get_os_info() {
    FIELD=$1
    if [[ -z "$FIELD" ]]; then return 1; fi
    echo "$(echo $(grep -oP "(?<=^$FIELD=).+" /etc/os-release | tr -d '"'))"
}

# this is mostly related to phonevox
# manual mapping of cloud providers
# call in subshell and store the echo'ed value in a variable
# usage: CLOUD_PROVIDER=$(determine_cloud_provider)
function determine_cloud_provider() {
    local PROBABLE_PROVIDER="local"

    # checking ovh provider
    # hostname | grep -qi "vps\.ovh" && local PROBABLE_PROVIDER="ovh" # lets not trust the hostname, shall we
    curl -s https://ipinfo.io/json | grep -i org | grep -qi OVH && local PROBABLE_PROVIDER="ovh" # via ipinfo

    # checking for qnax provider
    # hostname | grep -qE "SRV-[0-9]+" && local PROBABLE_PROVIDER="qnax" # lets not trust the hostname, shall we
    curl -s https://ipinfo.io/json | grep -i org | grep -qi QNAX && local PROBABLE_PROVIDER="qnax" # via ipinfo

    # checking for aws
    # idk what to grep for hostname search on aws. they have a lot of servers iirc
    curl -s https://ipinfo.io/json | grep -i org | grep -qi Amazon && local PROBABLE_PROVIDER="aws" # via ipinfo

    echo $PROBABLE_PROVIDER
}

# Executes commands on system, in a secure way.
# This demands "colorir" function for aesthetics.
#
# Default allowed exit codes: "0,1"
# Default dry mode: "false"
#
# Usage: run "<full command escaped>" "<acceptable exit codes separated by comma>" "<dry:true/false>"
# run "asterisk -rx \"sip show peers\"" "0,1,2" "false"
function run() {
    local CODE_FAILED_COLOR="vermelho" # exit code diferente de 0 e não está nos aceitaveis
    local CODE_ACCEPTABLE_COLOR="amarelo" # exit code diferente de 0 mas está nos aceitáveis
    local CODE_SCUCESS_COLOR="verde" # exit code === 0
    local DRY_COLOR="azul"

    local COMMAND=$1
    local USER_ACCEPTABLE_EXIT_CODES=$2
    local RUN_DRY=false # default false
    if [[ "$3" == "true" ]]; then local RUN_DRY=true; fi
    local RUN_SILENT=false
    if [[ "$4" == "true" ]]; then local RUN_SILENT=true; fi

    # transforming exit codes into array
    local ACCEPTABLE_EXIT_CODES=1
    if [ $USER_ACCEPTABLE_EXIT_CODES ]; then ACCEPTABLE_EXIT_CODES=$ACCEPTABLE_EXIT_CODES,$USER_ACCEPTABLE_EXIT_CODES; fi
    {
        local IFS=',' # split with comma
        read -r -a acceptable_codes_array <<< "$ACCEPTABLE_EXIT_CODES" # add to array
    }

    # echo ""
    # echo -e "TEST: acceptable_codes_array : ${acceptable_codes_array[@]}"
    # echo -e "TEST: ACCEPTABLE EXIT CODES: $ACCEPTABLE_EXIT_CODES"
    # echo -e "TEST: USER EXIT CODES: $USER_ACCEPTABLE_EXIT_CODES"

    # if its dry, just exit with a "fake" command message
    # CHORE(adrian): could move this up maybe?
    if [[ "$RUN_DRY" == "true" ]]; then
        if ! $RUN_SILENT; then
            echo -e ">> DRY: $(colorir "$DRY_COLOR" "[$(echo -n $COMMAND)]")"
        fi
        return
    fi

    # actually run the command
    eval "$COMMAND"
    local EXIT_CODE=$?

    # Exit code SUCCESS
    if [ $EXIT_CODE -eq 0 ]; then
        if ! $RUN_SILENT; then
            echo -e "> command:[$(colorir "$CODE_SCUCESS_COLOR" "$COMMAND")], exit_code:$(colorir "$CODE_SCUCESS_COLOR" "$EXIT_CODE")"
        fi
        return 0
    fi

    # Exit code ACCEPTABLE
    for code in "${acceptable_codes_array[@]}"; do
        if [ $EXIT_CODE -eq $code ]; then
            if ! $RUN_SILENT; then
                echo -e "> command:[$(colorir "$CODE_ACCEPTABLE_COLOR" "$COMMAND")], exit_code:$(colorir "$CODE_ACCEPTABLE_COLOR" "$EXIT_CODE")"
            fi
            return
        fi
    done

    # Exit code FAIL
    echo -e "> command:[$(colorir "$CODE_FAILED_COLOR" "$COMMAND")], exit_code:$(colorir "$CODE_FAILED_COLOR+" "$EXIT_CODE")"
    echo -e "O exit-code do comando [$COMMAND] foi diferente de 0. Encerrando o SCRIPT por segurança!"
    exit 1
}


# this is dark magic, i wont even try to explain
# in short it will make the script gets values from redirects
# Usage: STDIN=$(read_stdin)
# STDIN=$(read_stdin) 
# FILE=$(read_stdin "file.txt")
# on script call: ./script.sh < some_file.txt
# then, you can iterate over the STDIN variable to get every line of your input file
function read_stdin () {
    # 0: ignores last line (default bash behaviour)
    # 1: forces a trailing newline so that the last line is not ignored
    local FORCE_NEWLINE=1
    local IGNORE_EMPTY_INPUT=1

    # determine what we will read from: stdin or file
    local input_file="$1"
    local input_cmd="cat" # default cmd

    if [[ -n "$input_file" ]]; then
        if [[ -f "$input_file" ]]; then
            input_cmd="cat \"$input_file\""
        elif [[ "$IGNORE_EMPTY_INPUT" -eq 1 ]]; then
            return 0 # the file doesnt exist
        else
            echo -e "ERROR: read_stdin: File '$input_file' does not exist." >&2
            return 1
        fi
    elif [[ -t 0 ]]; then
        if [[ "$IGNORE_EMPTY_INPUT" -eq 1 ]]; then
            return 0 # no input to read
        else
            echo "ERROR: read_stdin: No input to read." >&2
            return 1
        fi
    fi

    # append newline if needed
    if [[ "$FORCE_NEWLINE" -eq 1 ]]; then
        input_cmd="($input_cmd; printf '\n')"
    fi

    # reads the eval result, that, in turn, cats the stdin
    # (check end of while loop)
    while read -r line; do
        i=$(($i+1))

        # remove comments
        if [[ -n "$line" && ${line:0:1} == "#" ]]; then continue; fi

        # remove inline comments (ignore if escaped)
        line=$(echo "$line" | sed -E 's/([^\\])#.*$/\1/' | sed 's/[[:space:]]*$//')

        # preserves escaped comments ("\#" to "#")
        line=$(echo "$line" | sed 's/\\#/#/g')

        echo $line
    done < <(eval $input_cmd)

    return 0
}


# validates if a string is a valid ipv4 address
# Usage: valid_ip "<ip_address>"
# CONFIG_ALLOW_CIDR to allow IPV4 with CIDR notations (consider them valid IPs)
function valid_ip() {
    CONFIG_ALLOW_CIDR=1
    local value=$1

    # defining the regex rule
    if [[ $CONFIG_ALLOW_CIDR -eq 1 ]]; then 
        # NOTE: this cidr allows from 0 to 32 (because you might want to use 0.0.0.0/0)
        local REGEX="^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])(\/([0-9]|[1-2][0-9]|3[0-2]))?$"
    else
        local REGEX="^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"
    fi

    if [[ $value =~ $REGEX ]]; then
        return 0
    else
        return 1
    fi
}


# this is meant to be used as subshell command
# Usage: IP=$(get_session_ip)
function get_session_ip() {
    local DEBUG_MODE=0; if [[ -n "$1" ]]; then DEBUG_MODE=1; fi 
    local DEBUG_TEXT=""    
    local SESSION_IP=""
    local RETURN=""

    # from ssh client
    local FROM_SSHCLIENT=$(echo $SSH_CLIENT | awk '{print $1}')
    if [[ -n "$FROM_SSHCLIENT" ]]; then SESSION_IP=$FROM_SSHCLIENT; fi

    # from "who" cmd
    local FROM_WHO=$(who -m | awk '{print $NF}' | tr -d '()')
    if [[ -n "$FROM_WHO" ]]; then SESSION_IP=$FROM_WHO; fi

    # validating
    if valid_ip "$SESSION_IP"; then RETURN=$SESSION_IP; fi

    # debug information if needed
    local DEBUG_TEXT=" (DEBUG INFO // FROM_SSHCLIENT=$FROM_SSHCLIENT, FROM_WHO=$FROM_WHO, SESSION_IP=$SESSION_IP)"

    if [[ "$DEBUG_MODE" -eq 1 ]]; then RETURN="$RETURN$DEBUG_TEXT"; fi
    echo $RETURN
}