#!/bin/bash

declare -A COLORS_ARRAY
COLORS_ARRAY=(
    # Cores básicas
    [preto]="0;30"
    [vermelho]="0;31"
    [verde]="0;32"
    [amarelo]="0;33"
    [azul]="0;34"
    [magenta]="0;35"
    [ciano]="0;36"
    [branco]="0;37"

    # Cores claras
    [preto_claro]="1;30"
    [vermelho_claro]="1;31"
    [verde_claro]="1;32"
    [amarelo_claro]="1;33"
    [azul_claro]="1;34"
    [magenta_claro]="1;35"
    [ciano_claro]="1;36"
    [branco_claro]="1;37"

    # Cores 256 (adicionais)
    [laranja]="38;5;208"
    [rosa]="38;5;206"
    [azul_celeste]="38;5;45"
    [verde_lima]="38;5;118"
    [lavanda]="38;5;183"
    [violeta]="38;5;135"
    [caramelo]="38;5;130"
    [dourado]="38;5;220"
    [turquesa]="38;5;51"
    [cinza]="38;5;244"
    [cinza_claro]="38;5;250"
    [marrom]="38;5;94"
)

# color your text using subshells
# this needs the COLORS_ARRAY array, declared outside this function
# Usage: echo "esse texto está sem cor, mas $(colorir "verde" "esse texto aqui está com cor") "
function colorir() {
    local cor=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    local texto=$2
    local string='${COLORS_ARRAY['"\"$cor\""']}'
    eval "local cor_ansi=$string" >/dev/null 2>&1
    local cor_reset="\e[0m"

    if [[ -z "$cor_ansi" ]]; then
        cor_ansi=${COLORS_ARRAY["branco"]}  # defaults to white if invalid
    fi

    # print with selected color
    echo -e "\e[${cor_ansi}m${texto}${cor_reset}"
}


# echo-back the first argument in every possible color
# so you can search for a cool color you want to use
# Usage: colortest "batata frita"
function colortest() {
    local ORDER=(
        # tons neutros
        "preto"
        "preto_claro"
        "cinza"
        "cinza_claro"
        "branco"
        "branco_claro"
        
        # tons de verde
        # "\n"
        "verde"
        "verde_claro"
        "verde_lima"
        
        # tons azuis
        # "\n"
        "azul"
        "azul_claro"
        "azul_celeste"
        "turquesa"

        # proibido
        "ciano"
        "ciano_claro"
        
        # tons amarelados
        # "\n"
        "amarelo"
        "amarelo_claro"
        "laranja"
        "caramelo"
        
        # tons vermelhos
        # "\n"
        "vermelho"
        "vermelho_claro"
        
        # tons rosa/roxos
        # "\n"
        "magenta"
        "magenta_claro"
        "violeta"
        "rosa"
        "lavanda"
    )
    local texto=$1
    local cor_reset="\e[0m"
    echo "inside colortest"

    # Loop para aplicar todas as cores do array "COLORS_ARRAY" ao texto
    for cor in "${ORDER[@]}"; do
        if [[ "$cor" == "\\n" ]]; then
            echo ""
            continue
        fi
        local cor_ansi="${COLORS_ARRAY[$cor]}"
        echo -e "\e[${cor_ansi}m${texto} (${cor})${cor_reset}"
    done
}