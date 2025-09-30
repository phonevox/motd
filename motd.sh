#!/bin/bash

# ========================
#  Color Codes
# ========================
RESET="\033[0m"
BLACK="\033[0;30m"
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
MAGENTA="\033[0;35m"
CYAN="\033[0;36m"
WHITE="\033[0;37m"

# ========================
#  Progress Bar Colors
# ========================
BRACKET_COLOR="$CYAN"
FILL_COLOR="$GREEN"
EMPTY_COLOR="$RED"

# ========================
#  Helpers
# ========================

# thresholds format: "70:YELLOW,90:RED"
dynamic_color() {
    local value=$1
    local thresholds=$2
    local color=$GREEN  # default

    IFS=',' read -ra pairs <<< "$thresholds"
    for pair in "${pairs[@]}"; do
        th="${pair%%:*}"
        c="${pair##*:}"
        if (( value >= th )); then
            color=$(eval echo \$$c)
        fi
    done
    echo "$color"
}

progress_bar() {
    local value=${1:-0}    # valor atual
    local total=${2:-100}  # máximo
    local fill_arg=${3:-$GREEN}      # pode ser cor direta ou thresholds
    local empty_arg=${4:-$RESET}     # cor para vazio
    local bracket_arg=${5:-$RESET}   # cor do colchete
    local width=45
    local FILL_COLOR EMPTY_COLOR BRACKET_COLOR

    # garante que value não ultrapasse total
    ((value < 0)) && value=0
    ((value > total)) && value=$total

    # decide se fill_arg é thresholds ou cor literal
    if [[ "$fill_arg" == *:* ]]; then
        FILL_COLOR=$(dynamic_color $value "$fill_arg")
    else
        FILL_COLOR=$fill_arg
    fi

    # empty
    if [[ "$empty_arg" == *:* ]]; then
        EMPTY_COLOR=$(dynamic_color $value "$empty_arg")
    else
        EMPTY_COLOR=$empty_arg
    fi

    # bracket
    if [[ "$bracket_arg" == *:* ]]; then
        BRACKET_COLOR=$(dynamic_color $value "$bracket_arg")
    else
        BRACKET_COLOR=$bracket_arg
    fi

    # calcula filled e empty
    local filled=$((value * width / total))
    local empty=$((width - filled))

    # garante que sempre pelo menos imprime os colchetes
    printf "${BRACKET_COLOR}[${RESET}"
    for ((i=0; i<filled; i++)); do printf "${FILL_COLOR}#${RESET}"; done
    for ((i=0; i<empty; i++)); do printf "${EMPTY_COLOR}-${RESET}"; done
    printf "${BRACKET_COLOR}]${RESET} %d%%" $((value * 100 / total))
}

# ========================
#  Service Checks
# ========================
HAS_ASTERISK=false
HAS_MARIADB=false
HAS_PBACKUP=false
PBACKUP_TEXT="${RED}not installed${RESET}"
HAS_PFIREWALL=false
PFIREWALL_TEXT="${RED}not installed${RESET}"

if command -v asterisk &> /dev/null; then
    HAS_ASTERISK=true
fi

if command -v mysql &> /dev/null || command -v mariadb &> /dev/null; then
    HAS_MARIADB=true
fi

if which pbackup &> /dev/null; then
    HAS_PBACKUP=true
    PBACKUP_VERSION=$(pbackup --version 2>/dev/null | tail -n1 | awk '{print $2}')
    PBACKUP_TEXT="${GREEN}installed${RESET} ($PBACKUP_VERSION)"
fi

if which pfirewall &> /dev/null; then
    HAS_PFIREWALL=true
    PFIREWALL_VERSION=$(pfirewall --version 2>/dev/null | tail -n1 | awk '{print $2}')
    PFIREWALL_TEXT="${GREEN}installed${RESET} ($PFIREWALL_VERSION)"
fi

# Status services
if $HAS_ASTERISK; then
    if pgrep -x asterisk > /dev/null; then
        asterisk_status="${GREEN}online${RESET}"
    else
        asterisk_status="${RED}offline${RESET}"
    fi
else
    asterisk_status="${YELLOW}not available${RESET}"
fi

if $HAS_MARIADB; then
    if pgrep -x mysqld > /dev/null; then
        mariadb_status="${GREEN}online${RESET}"
    else
        mariadb_status="${RED}offline${RESET}"
    fi
else
    mariadb_status="${YELLOW}not available${RESET}"
fi

# ========================
#  System Info
# ========================
# Armazenamento total
disk_total=$(df -B1 --total | grep total | awk '{print $2}')
disk_used=$(df -B1 --total | grep total | awk '{print $3}')
disk_percent=$((disk_used * 100 / disk_total))

# CPU %
cpu_idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d. -f1)
cpu_used=$((100 - cpu_idle))

# RAM %
read ram_total ram_used <<< $(free -m | awk '/Mem:/ {print $2, $3}')
ram_percent=$((ram_used * 100 / ram_total))

# Último login
last_login=$(last -F -n 1 $USER | tail -n1 | awk '{$1=$1; print $4,$5,$6,$7,$8}')

# Uptime
uptime_h=$(uptime -p)
load_average=$(uptime | awk -F'load average:' '{ print $2 }' | sed 's/ //g')

# Data e timezone
server_date=$(date +"%Y-%m-%d %H:%M:%S")
server_tz=$(cat /etc/timezone 2>/dev/null || timedatectl show -p Timezone --value 2>/dev/null || date +"%Z")

# Endereços IP 
ips=$(hostname -I 2>/dev/null || echo "N/A")

# Nome do host
host_name=$(hostname)

# Machine ID
machine_id=$(cat /etc/machine-id 2>/dev/null || echo "N/A")

open_ssh_sessions=$(who | wc -l)

# Sistema operacional (nome + versão)
if [ -f /etc/os-release ]; then
    os_name=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '"')
else
    os_name=$(uname -s)  # fallback
fi

# ========================
#  Asterisk Specific
# ========================
if $HAS_ASTERISK; then
    ast_rec_directory=$(cat /etc/asterisk/asterisk.conf | grep astspooldir | awk -F"=> " '{print $2}')
    ast_log_directory=$(cat /etc/asterisk/asterisk.conf | grep astlogdir | awk -F"=> " '{print $2}')
    rec_size=$(du -sh $ast_rec_directory/monitor 2>/dev/null | awk '{print $1}')
    log_size=$(du -sh $ast_log_directory 2>/dev/null | awk '{print $1}')
    dialer_log_size=$(du -sh /opt/issabel/dialer 2>/dev/null | awk '{print $1}')
    ast_version=$(asterisk -V 2>/dev/null)
fi

# ========================
#  OUTPUT
# ========================
echo -e "
${RESET}Último login: $last_login - Bem vindo de volta!${RESET}
Servidor modificado por ${MAGENTA}PHONEVOX GROUP TECHNOLOGY${RESET} - https://phonevox.com
Para suporte, entre em contato através do e-mail ${CYAN}suporte@phonevox.com.br${RESET}

● ${YELLOW}system${RESET}
Date        : $server_date | $server_tz
CPU usage   : $(progress_bar "$cpu_used" "100" "0:GREEN,85:YELLOW,95:RED" "$BLACK") | Load(1,5,15): $load_average | $uptime_h
RAM usage   : $(progress_bar "$ram_percent" "100" "0:GREEN,85:YELLOW,95:RED" "$BLACK")
Disk usage  : $(progress_bar "$disk_percent" "100" "0:GREEN,80:YELLOW,90:RED" "$BLACK") | $(numfmt --to=iec $disk_used)/$(numfmt --to=iec $disk_total)
Hostname    : $host_name | ${GREEN}$open_ssh_sessions${RESET} open session(s)
OS          : $os_name | MachineID: ${BLUE}$machine_id${RESET}
IPs         : $ips

● ${YELLOW}services${RESET}
asterisk    : $asterisk_status
mariadb     : $mariadb_status
pbackup     : $PBACKUP_TEXT
pfirewall   : $PFIREWALL_TEXT
"

if $HAS_ASTERISK; then
echo -e "● ${YELLOW}asterisk${RESET}
Version     : $ast_version
Recordings  : ${rec_size:-N/A}
Logs        : ${log_size:-N/A}
Dialer Logs : ${dialer_log_size:-N/A}
"
fi
