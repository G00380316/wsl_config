#!/usr/bin/env bash
#set -e

# Base directories — always relative to this script
scrDir="$(dirname "$(realpath "$0")")"
cloneDir="$(dirname "${scrDir}")"
cloneDir="${CLONE_DIR:-${cloneDir}}"

# Use current script folder for config + logs
confDir="${scrDir}"
cacheDir="${scrDir}/cache"

aurList=("yay" "paru")
shlList=("zsh" "fish")

# Ensure local cache folder exists
mkdir -p "$cacheDir/logs"

export scrDir cloneDir confDir cacheDir aurList shlList

# --- Package utils --- #
pkg_installed() {
    local PkgIn=$1
    pacman -Qi "${PkgIn}" &>/dev/null
}

chk_list() {
    local vrType="$1"
    local inList=("${@:2}")
    for pkg in "${inList[@]}"; do
        if pkg_installed "${pkg}"; then
            printf -v "${vrType}" "%s" "${pkg}"
            export "${vrType}"
            return 0
        fi
    done
    return 1
}

pkg_available() {
    local PkgIn=$1
    pacman -Si "${PkgIn}" &>/dev/null
}

aur_available() {
    local PkgIn=$1
    if command -v "${aurhlpr:-paru}" &>/dev/null; then
        ${aurhlpr:-paru} -Si "${PkgIn}" &>/dev/null
    else
        return 1
    fi
}

# --- GPU Detection --- #
nvidia_detect() {
    readarray -t dGPU < <(lspci -k | grep -E "(VGA|3D)" | awk -F ': ' '{print $NF}')
    case "$1" in
        --verbose)
            for indx in "${!dGPU[@]}"; do
                echo -e "\033[0;32m[gpu$indx]\033[0m detected :: ${dGPU[indx]}"
            done
            ;;
        --drivers)
            while read -r -d ' ' nvcode; do
                awk -F '|' -v nvc="${nvcode}" \
                    'substr(nvc,1,length($3)) == $3 {split(FILENAME,driver,"/"); print driver[length(driver)],"\nnvidia-utils"}' \
                    "${scrDir}"/nvidia-db/nvidia*dkms
            done <<<"${dGPU[@]}"
            ;;
        *)
            grep -iq nvidia <<<"${dGPU[@]}"
            ;;
    esac
}

# --- Timer --- #
prompt_timer() {
    set +e
    unset PROMPT_INPUT
    local timsec=$1
    local msg=$2
    while [[ ${timsec} -ge 0 ]]; do
        echo -ne "\r :: ${msg} (${timsec}s) : "
        read -rt 1 -n 1 PROMPT_INPUT && break
        ((timsec--))
    done
    export PROMPT_INPUT
    echo ""
    #set -e
}

# --- Logging --- #
print_log() {
    local executable="${0##*/}"
    local logFile="${cacheDir}/logs/${HYDE_LOG:-global}/${executable}"
    mkdir -p "$(dirname "${logFile}")"

    local section=${log_section:-}
    {
        [ -n "${section}" ] && echo -ne "\e[32m[$section] \e[0m"
        while (($#)); do
            case "$1" in
                -r|+r) echo -ne "\e[31m$2\e[0m"; shift 2;;
                -g|+g) echo -ne "\e[32m$2\e[0m"; shift 2;;
                -y|+y) echo -ne "\e[33m$2\e[0m"; shift 2;;
                -b|+b) echo -ne "\e[34m$2\e[0m"; shift 2;;
                -m|+m) echo -ne "\e[35m$2\e[0m"; shift 2;;
                -c|+c) echo -ne "\e[36m$2\e[0m"; shift 2;;
                -wt|+w) echo -ne "\e[37m$2\e[0m"; shift 2;;
                -n|+n) echo -ne "\e[96m$2\e[0m"; shift 2;;
                -stat) echo -ne "\e[30;46m $2 \e[0m :: "; shift 2;;
                -crit) echo -ne "\e[97;41m $2 \e[0m :: "; shift 2;;
                -warn) echo -ne "WARNING :: \e[97;43m $2 \e[0m :: "; shift 2;;
                +) echo -ne "\e[38;5;$2m$3\e[0m"; shift 3;;
                -sec) echo -ne "\e[32m[$2] \e[0m"; shift 2;;
                -err) echo -ne "ERROR :: \e[4;31m$2 \e[0m"; shift 2;;
                *) echo -ne "$1"; shift;;
            esac
        done
        echo ""
    } | tee >(sed 's/\x1b\[[0-9;]*m//g' >>"${logFile}")
}
