#!/bin/bash

# BVM (BoxLang Version Manager) Installer
# This script installs BVM and sets up the environment
# Author: BoxLang Team
# Version: @build.version@
# License: Apache License, Version 2.0

set -Eeuo pipefail

###########################################################################
# Global state
###########################################################################

REPOSITORY="ortus-boxlang/boxlang-quick-installer"
PRODUCT_URL="https://boxlang.io/"
BVM_HOME="${BVM_HOME:-$HOME/.bvm}"
BVM_VERSION="@build.version@"
INSTALLER_URL="https://downloads.ortussolutions.com/ortussolutions/boxlang-quick-installer/boxlang-installer.zip"
BVM_INIT_FILE="$BVM_HOME/scripts/bvm-init.sh"
BVM_FISH_INIT_FILE="$BVM_HOME/scripts/bvm-init.fish"
BVM_PROFILE_FILE=""
LOCAL_INSTALL=false
FORCE=false
UPGRADE=false
NON_INTERACTIVE=no
VERBOSE=no
WITH_JAVA=auto
WITH_SHELL=yes
WITH_RUNTIME=latest
PLATFORM=""
ARCH=""
OS_NAME=""
SHELL_NAME=""
BINARY="$BVM_HOME/bin/bvm"

COLOR_RESET="" COLOR_BOLD="" COLOR_DIM="" COLOR_ACCENT="" COLOR_SUCCESS="" COLOR_WARNING="" COLOR_ERROR=""
COLOR_LAYER_ONE="" COLOR_LAYER_TWO=""
RICH_TERMINAL=no
PROMPT_DEVICE=""
WARNING_COUNT=0
SETUP_NOTICES=no
CORE_INSTALLED=no
ACTIVE_PID=""
LOG_FILE=""
TEMP_DIR=""
TASK_OUTPUT_FILE=""
MENU_KEY=""
MENU_LABELS=()
MENU_HINTS=()
MENU_CHOICES=()

###########################################################################
# Helpers (loaded locally, from an installed BVM, or from the CDN)
###########################################################################

INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$INSTALLER_DIR/helpers/helpers.sh" ]]; then
    # shellcheck disable=SC1091
    source "$INSTALLER_DIR/helpers/helpers.sh"
elif [[ -f "$BVM_HOME/scripts/helpers.sh" ]]; then
    # shellcheck disable=SC1091
    source "$BVM_HOME/scripts/helpers.sh"
else
    printf 'Downloading helper functions...\n'
    helpers_url="https://downloads.ortussolutions.com/ortussolutions/boxlang-quick-installer/helpers/helpers.sh"
    helpers_file="${TMPDIR:-/tmp}/bvm-helpers.sh"
    if curl -fsSL --retry 3 --retry-delay 2 "$helpers_url" -o "$helpers_file"; then
        # shellcheck disable=SC1090
        source "$helpers_file"
    else
        printf 'Error: failed to download helper functions from %s\n' "$helpers_url" >&2
        exit 1
    fi
fi

###########################################################################
# Output and terminal helpers
###########################################################################

setup_terminal() {
    local rows columns
    if [[ -t 1 && ${TERM:-dumb} != dumb ]]; then
        if [[ -t 2 && -z ${NO_COLOR:-} ]]; then
            COLOR_RESET=$'\033[0m' COLOR_BOLD=$'\033[1m' COLOR_DIM=$'\033[2m'
            COLOR_ACCENT=$'\033[36m' COLOR_SUCCESS=$'\033[32m'
            COLOR_WARNING=$'\033[33m' COLOR_ERROR=$'\033[31m'
            COLOR_LAYER_ONE=$'\033[34m' COLOR_LAYER_TWO=$'\033[35m'
        fi
        if [[ -e /dev/tty && -r /dev/tty && -w /dev/tty ]]; then
            PROMPT_DEVICE=/dev/tty
        fi
        if [[ -n "$PROMPT_DEVICE" ]] && command -v stty >/dev/null 2>&1 \
            && read -r rows columns < <(stty size <"$PROMPT_DEVICE" 2>/dev/null) \
            && ((rows >= 24 && columns >= 64)); then
            RICH_TERMINAL=yes
        fi
    fi
}

info() {
    printf '  %s✓%s  %s\n' "$COLOR_SUCCESS" "$COLOR_RESET" "$*"
}

note() {
    printf '  %s!  %s%s\n' "$COLOR_WARNING" "$*" "$COLOR_RESET" >&2
}

warn() {
    WARNING_COUNT=$((WARNING_COUNT + 1))
    note "$@"
    [[ -z "$LOG_FILE" ]] || printf 'warning: %s\n' "$*" >>"$LOG_FILE"
}

die() {
    printf '  %s×%s  %s\n' "$COLOR_ERROR" "$COLOR_RESET" "$*" >&2
    [[ -z "$LOG_FILE" ]] || printf 'error: %s\n' "$*" >>"$LOG_FILE"
    exit 1
}

section() {
    printf '\n  %s%s%s%s\n\n' "$COLOR_ACCENT" "$COLOR_BOLD" "$*" "$COLOR_RESET"
}

divider() {
    if [[ "$RICH_TERMINAL" == yes ]]; then
        printf '  %s────────────────────────────────────────────────────────────%s\n' "$COLOR_DIM" "$COLOR_RESET"
    fi
}

installer_cleanup() {
    local status=$?
    [[ "$RICH_TERMINAL" != yes ]] || printf '\033[?25h'
    if [[ -n "$ACTIVE_PID" ]]; then
        kill "$ACTIVE_PID" 2>/dev/null || true
        wait "$ACTIVE_PID" 2>/dev/null || true
    fi
    [[ -z "$TEMP_DIR" ]] || rm -rf -- "$TEMP_DIR"
    if ((status != 0)) && [[ -n "$LOG_FILE" ]]; then
        if [[ "$CORE_INSTALLED" == yes ]]; then
            warn "BVM is installed, but setup did not finish."
        else
            warn "Installation did not finish."
        fi
        printf '  Detailed output: %s\n' "$LOG_FILE" >&2
    elif [[ -n "$LOG_FILE" && $WARNING_COUNT -eq 0 && "$SETUP_NOTICES" == no ]]; then
        rm -f -- "$LOG_FILE"
    fi
}

cancel_installation() {
    [[ "$RICH_TERMINAL" != yes ]] || printf '\0338\033[J\033[?25h'
    printf '\n  Installation cancelled. No changes made.\n\n'
    exit 0
}

show_banner() {
    local -a logo=(
        '             ⠈⠑⠲⣤⡀      '
        '        ⢀⣴⣿⣿⣷⣦⣄ ⠈⠻⣷⣄    '
        '      ⢠⣾⣿⣿⣿⣿⣿⣿⣿⣷⡄ ⠈⢿⣷⡄  '
        '        ⠈⠙⠻⣿⣿⣿⣿⣿⣿⡆ ⠘⣿⣿⡄ '
        '           ⠈⢿⣿⣿⣿⣿⣿  ⢻⣿⣿ '
        '            ⠸⣿⣿⣿⣿⣿  ⣸⣿⣿⡆'
        '            ⢠⣿⣿⣿⣿⡏  ⣿⣿⣿⠇'
        '            ⣼⣿⣿⣿⠏  ⣼⣿⣿⡿ '
        '         ⢀⣠⣾⣿⡿⠟⠁ ⢀⣾⣿⣿⣿⠃ '
        '⢠⣿⣿⠄    ⠚⠛⠛⠉⠁ ⢀⣠⣶⣿⣿⣿⡿⠁  '
        ' ⠉⠉⢾⣿⣶⣦⣤⣤⣤⣤⣤⣶⣾⣿⣿⣿⣿⠿⠋    '
        '    ⠈⠛⠻⠿⣿⣿⣿⣿⣿⣿⠿⠟⠋⠁      '
    )
    local -a colored_logo=(
        '             [38;2;0;239;177m⠈[38;2;0;241;171m⠑[38;2;0;242;165m⠲[38;2;0;244;159m⣤[38;2;0;246;153m⡀      '
        '        [38;2;0;232;207m⢀[38;2;0;233;201m⣴[38;2;0;235;195m⣿[38;2;0;236;189m⣿[38;2;0;238;183m⣷[38;2;0;239;177m⣦[38;2;0;241;171m⣄ [38;2;0;244;159m⠈[38;2;0;246;153m⠻[38;2;0;247;147m⣷[38;2;0;249;141m⣄    '
        '      [38;2;0;228;219m⢠[38;2;0;230;213m⣾[38;2;0;232;207m⣿[38;2;0;233;201m⣿[38;2;0;235;195m⣿[38;2;0;236;189m⣿[38;2;0;238;183m⣿[38;2;0;239;177m⣿[38;2;0;241;171m⣿[38;2;0;242;165m⣷[38;2;0;244;159m⡄ [38;2;0;247;147m⠈[38;2;0;249;141m⢿[38;2;0;250;135m⣷[38;2;0;252;129m⡄  '
        '        [38;2;0;232;207m⠈[38;2;0;233;201m⠙[38;2;0;235;195m⠻[38;2;0;236;189m⣿[38;2;0;238;183m⣿[38;2;0;239;177m⣿[38;2;0;241;171m⣿[38;2;0;242;165m⣿[38;2;0;244;159m⣿[38;2;0;246;153m⡆ [38;2;0;249;141m⠘[38;2;0;250;135m⣿[38;2;0;252;129m⣿[38;2;0;253;123m⡄ '
        '           [38;2;0;236;189m⠈[38;2;0;238;183m⢿[38;2;0;239;177m⣿[38;2;0;241;171m⣿[38;2;0;242;165m⣿[38;2;0;244;159m⣿[38;2;0;246;153m⣿  [38;2;0;250;135m⢻[38;2;0;252;129m⣿[38;2;0;253;123m⣿ '
        '            [38;2;0;238;183m⠸[38;2;0;239;177m⣿[38;2;0;241;171m⣿[38;2;0;242;165m⣿[38;2;0;244;159m⣿[38;2;0;246;153m⣿  [38;2;0;250;135m⣸[38;2;0;252;129m⣿[38;2;0;253;123m⣿[38;2;0;255;117m⡆'
        '            [38;2;0;238;183m⢠[38;2;0;239;177m⣿[38;2;0;241;171m⣿[38;2;0;242;165m⣿[38;2;0;244;159m⣿[38;2;0;246;153m⡏  [38;2;0;250;135m⣿[38;2;0;252;129m⣿[38;2;0;253;123m⣿[38;2;0;255;117m⠇'
        '            [38;2;0;238;183m⣼[38;2;0;239;177m⣿[38;2;0;241;171m⣿[38;2;0;242;165m⣿[38;2;0;244;159m⠏  [38;2;0;249;141m⣼[38;2;0;250;135m⣿[38;2;0;252;129m⣿[38;2;0;253;123m⡿ '
        '         [38;2;0;233;201m⢀[38;2;0;235;195m⣠[38;2;0;236;189m⣾[38;2;0;238;183m⣿[38;2;0;239;177m⡿[38;2;0;241;171m⠟[38;2;0;242;165m⠁ [38;2;0;246;153m⢀[38;2;0;247;147m⣾[38;2;0;249;141m⣿[38;2;0;250;135m⣿[38;2;0;252;129m⣿[38;2;0;253;123m⠃ '
        '[38;2;0;219;255m⢠[38;2;0;221;249m⣿[38;2;0;222;243m⣿[38;2;0;224;237m⠄    [38;2;0;232;207m⠚[38;2;0;233;201m⠛[38;2;0;235;195m⠛[38;2;0;236;189m⠉[38;2;0;238;183m⠁ [38;2;0;241;171m⢀[38;2;0;242;165m⣠[38;2;0;244;159m⣶[38;2;0;246;153m⣿[38;2;0;247;147m⣿[38;2;0;249;141m⣿[38;2;0;250;135m⡿[38;2;0;252;129m⠁  '
        ' [38;2;0;221;249m⠉[38;2;0;222;243m⠉[38;2;0;224;237m⢾[38;2;0;225;231m⣿[38;2;0;227;225m⣶[38;2;0;228;219m⣦[38;2;0;230;213m⣤[38;2;0;232;207m⣤[38;2;0;233;201m⣤[38;2;0;235;195m⣤[38;2;0;236;189m⣤[38;2;0;238;183m⣶[38;2;0;239;177m⣾[38;2;0;241;171m⣿[38;2;0;242;165m⣿[38;2;0;244;159m⣿[38;2;0;246;153m⣿[38;2;0;247;147m⠿[38;2;0;249;141m⠋    '
        '    [38;2;0;225;231m⠈[38;2;0;227;225m⠛[38;2;0;228;219m⠻[38;2;0;230;213m⠿[38;2;0;232;207m⣿[38;2;0;233;201m⣿[38;2;0;235;195m⣿[38;2;0;236;189m⣿[38;2;0;238;183m⣿[38;2;0;239;177m⣿[38;2;0;241;171m⠿[38;2;0;242;165m⠟[38;2;0;244;159m⠋[38;2;0;246;153m⠁      '
    )
    local -a text=(
        ""
        "  ${COLOR_BOLD}${COLOR_ACCENT}B O X L A N G${COLOR_RESET}"
        ""
        "  ${COLOR_SUCCESS}The software productivity platform${COLOR_RESET}"
        ""
        "  ${COLOR_SUCCESS}www.boxlang.io${COLOR_RESET}"
        ""
        ""
        "  ${COLOR_SUCCESS}BoxLang Version Manager (BVM)${COLOR_RESET}"
        ""
        ""
        ""
    )
    local -a lines=("${logo[@]}")
    if [[ -t 1 && ${TERM:-dumb} != dumb && -z ${NO_COLOR:-} ]]; then
        lines=("${colored_logo[@]}")
    fi
    local i
    printf '
'
    for ((i = 0; i < 12; i++)); do
        printf '%b%s%b
' "${lines[i]}" "${text[i]}" "$COLOR_RESET"
    done
    printf '
'
}

show_system() {
    local system_name="Unknown system"
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        system_name="${PRETTY_NAME:-${ID:-Unknown system}}"
    elif command -v sw_vers >/dev/null 2>&1; then
        system_name="macOS $(sw_vers -productVersion 2>/dev/null)"
    fi
    printf '  %s%s · %s-%s · shell: %s%s\n' "$COLOR_DIM" "$system_name" "$PLATFORM" "$ARCH" "$SHELL_NAME" "$COLOR_RESET"
}

###########################################################################
# Menus
###########################################################################

read_menu_key() {
    local continuation
    MENU_KEY=""
    IFS= read -rsn1 MENU_KEY <"$PROMPT_DEVICE" || return 1
    if [[ "$MENU_KEY" == $'\033' ]]; then
        if IFS= read -rsn1 -t 0.1 continuation <"$PROMPT_DEVICE"; then
            MENU_KEY+="$continuation"
            if [[ "$continuation" == '[' || "$continuation" == O ]]; then
                IFS= read -rsn1 -t 0.1 continuation <"$PROMPT_DEVICE" || true
                MENU_KEY+="$continuation"
            fi
        fi
    fi
}

# Reads MENU_LABELS, MENU_HINTS and MENU_CHOICES. Writes selections to MENU_CHOICES.
select_menu() {
    local title="$1" multiple="$2" active=0 i answer marker color check rows
    if [[ "$RICH_TERMINAL" == yes ]]; then
        rows=$((${#MENU_LABELS[@]} + 12))
        for ((i = 0; i < rows; i++)); do printf '\n'; done
        printf '\033[%dA\0337\033[?25l' "$rows"
    fi
    while true; do
        [[ "$RICH_TERMINAL" != yes ]] || printf '\0338\033[J'
        section "$title"
        for i in "${!MENU_LABELS[@]}"; do
            marker=' ' color="$COLOR_RESET"
            if [[ "$RICH_TERMINAL" != yes ]]; then
                marker=$((i + 1))
            elif ((i == active)); then
                marker='›' color="$COLOR_ACCENT$COLOR_BOLD"
            elif [[ "$multiple" == yes && "${MENU_CHOICES[i]}" == yes ]]; then
                color="$COLOR_SUCCESS"
            fi
            if [[ "$multiple" == yes ]]; then
                check=' '
                [[ "${MENU_CHOICES[i]}" != yes ]] || check='✓'
                printf '  %s%s  [%s] %s%s\n' "$color" "$marker" "$check" "${MENU_LABELS[i]}" "$COLOR_RESET"
            else
                printf '  %s%s  %s%s\n' "$color" "$marker" "${MENU_LABELS[i]}" "$COLOR_RESET"
            fi
        done
        if [[ "$RICH_TERMINAL" == yes ]]; then
            printf '\n  %s%s%s\n\n' "$COLOR_DIM" "${MENU_HINTS[active]}" "$COLOR_RESET"
            divider
            if [[ "$multiple" == yes ]]; then
                printf '  %s↑/↓ move · Space toggle · Enter install · Esc cancel%s\n' "$COLOR_DIM" "$COLOR_RESET"
            else
                printf '  %s↑/↓ choose · Enter continue · Esc cancel%s\n' "$COLOR_DIM" "$COLOR_RESET"
            fi
            read_menu_key || cancel_installation
            case "$MENU_KEY" in
                $'\033[A'|$'\033OA'|k) active=$(((active + ${#MENU_LABELS[@]} - 1) % ${#MENU_LABELS[@]})) ;;
                $'\033[B'|$'\033OB'|j) active=$(((active + 1) % ${#MENU_LABELS[@]})) ;;
                ' ')
                    if [[ "$multiple" == yes ]]; then
                        if [[ "${MENU_CHOICES[active]}" == yes ]]; then MENU_CHOICES[active]=no; else MENU_CHOICES[active]=yes; fi
                    fi
                    ;;
                '')
                    [[ "$multiple" == yes ]] || MENU_CHOICES[active]=yes
                    [[ "$RICH_TERMINAL" != yes ]] || printf '\0338\033[J\033[?25h'
                    return 0
                    ;;
                $'\033'|q|Q) cancel_installation ;;
            esac
        else
            printf '\n'
            for i in "${!MENU_LABELS[@]}"; do
                printf '  %s: %s\n' "${MENU_LABELS[i]}" "${MENU_HINTS[i]}"
            done
            if [[ "$multiple" == yes ]]; then
                printf '\n  Toggle an option by number; Enter to install, q to cancel: ' >"$PROMPT_DEVICE"
            else
                printf '\n  Choose [1], or q to cancel: ' >"$PROMPT_DEVICE"
            fi
            IFS= read -r answer <"$PROMPT_DEVICE" || cancel_installation
            case "$answer" in
                q|Q) cancel_installation ;;
                '')
                    [[ "$multiple" == yes ]] || MENU_CHOICES[0]=yes
                    return 0
                    ;;
                *)
                    if [[ "$answer" =~ ^[1-9][0-9]*$ ]] && ((10#$answer <= ${#MENU_LABELS[@]})); then
                        active=$((10#$answer - 1))
                        if [[ "$multiple" == yes ]]; then
                            if [[ "${MENU_CHOICES[active]}" == yes ]]; then MENU_CHOICES[active]=no; else MENU_CHOICES[active]=yes; fi
                        else
                            MENU_CHOICES[active]=yes
                            return 0
                        fi
                    else
                        note "Choose one of the listed options."
                    fi
                    ;;
            esac
        fi
    done
}

prompt() {
    local question="$1" default="${2:-yes}" suffix answer
    if [[ "$default" == yes ]]; then suffix="[Y/n]"; else suffix="[y/N]"; fi
    printf '%s %s ' "$question" "$suffix" >"$PROMPT_DEVICE"
    IFS= read -r answer <"$PROMPT_DEVICE" || die "Could not read your answer."
    answer="${answer:-$default}"
    [[ "$answer" == [Yy] || "$answer" == [Yy][Ee][Ss] ]]
}

###########################################################################
# Task runner
###########################################################################

download_percent() {
    local progress
    progress=$(tail -c 2048 "$TASK_OUTPUT_FILE" 2>/dev/null) || return 1
    progress="${progress%$'\r'}"
    progress="${progress##*$'\r'}"
    [[ "$progress" =~ ([0-9]{1,3})[.,][0-9]+% ]] || return 1
    local percent=$((10#${BASH_REMATCH[1]}))
    ((percent <= 100)) || return 1
    printf '%s' "$percent"
}

progress_bar() {
    local percent="$1" marker="$2" label="$3" ribbon="" color cell i
    local filled=$((percent * 18 / 100))
    local -a layers=("$COLOR_LAYER_ONE" "$COLOR_LAYER_TWO" "$COLOR_ACCENT")
    for ((i = 0; i < 18; i++)); do
        if ((i < filled)); then
            color="${layers[i / 6]}" cell='▓'
            [[ "$marker" != ✓ ]] || color="$COLOR_SUCCESS"
        elif ((i == filled && percent > 0)); then
            color="$COLOR_ACCENT$COLOR_BOLD" cell='▒'
        else
            color="$COLOR_DIM" cell='░'
        fi
        ribbon+="$COLOR_RESET$color$cell"
    done
    color="$COLOR_ACCENT"
    [[ "$marker" != ✓ ]] || color="$COLOR_SUCCESS"
    printf '\r  %s%s%s  %-34s [%s%s] %s%3s%%%s\033[K' "$color" "$marker" "$COLOR_RESET" "$label" "$ribbon" "$COLOR_RESET" "$color" "$percent" "$COLOR_RESET"
}

run_task() {
    local label="$1" result frame=0 percent output_mode="${TASK_OUTPUT:-quiet}"
    local -a frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    shift
    if [[ -z "$LOG_FILE" ]]; then
        "$@"
        return
    fi
    printf '\n--- %s ---\n' "$label" >>"$LOG_FILE"
    : >"$TASK_OUTPUT_FILE"
    if [[ "$VERBOSE" == yes || "$output_mode" == live ]]; then
        printf '  %s→%s  %s\n' "$COLOR_ACCENT" "$COLOR_RESET" "$label"
        if "$@" 2>&1 | tee -a "$LOG_FILE" "$TASK_OUTPUT_FILE"; then result=0; else result=${PIPESTATUS[0]}; fi
    else
        "$@" >"$TASK_OUTPUT_FILE" 2>&1 &
        ACTIVE_PID=$!
        if [[ "$RICH_TERMINAL" != yes ]]; then
            printf '  …  %s\n' "$label"
        fi
        while kill -0 "$ACTIVE_PID" 2>/dev/null; do
            if [[ "$RICH_TERMINAL" == yes ]]; then
                if [[ "${TASK_PROGRESS:-no}" == yes ]] && percent=$(download_percent); then
                    progress_bar "$percent" "${frames[frame % 10]}" "$label"
                elif [[ "${TASK_PROGRESS:-no}" == yes ]]; then
                    progress_bar 0 "${frames[frame % 10]}" "$label"
                else
                    printf '\r  %s%s%s  %s\033[K' "$COLOR_ACCENT" "${frames[frame % 10]}" "$COLOR_RESET" "$label"
                fi
                frame=$((frame + 1))
            fi
            sleep 0.1
        done
        if wait "$ACTIVE_PID"; then result=0; else result=$?; fi
        ACTIVE_PID=""
        [[ "$RICH_TERMINAL" != yes ]] || printf '\r\033[K'
        cat "$TASK_OUTPUT_FILE" >>"$LOG_FILE"
        if ((result != 0)); then
            cat "$TASK_OUTPUT_FILE" >&2
        fi
    fi
    if ((result != 0)); then
        printf '  %s×%s  Failed: %s\n' "$COLOR_ERROR" "$COLOR_RESET" "$label" >&2
        return "$result"
    fi
    if [[ "$output_mode" == notices && -s "$TASK_OUTPUT_FILE" ]]; then
        SETUP_NOTICES=yes
        [[ "$VERBOSE" == yes ]] || cat "$TASK_OUTPUT_FILE"
    fi
    if [[ "$RICH_TERMINAL" == yes && "$VERBOSE" == no && "${TASK_PROGRESS:-no}" == yes ]]; then
        progress_bar 100 '✓' "$label"
        printf '\n'
    else
        info "$label"
    fi
}

###########################################################################
# Argument parsing
###########################################################################

usage() {
    cat <<EOF
Usage: install-bvm.sh [options]

Without options, choose a recommended install or customize BVM setup.

Options:
  --non-interactive          Never prompt; install the recommended set
  --yes, -y                  Alias for --non-interactive
  --verbose                  Show detailed task output
  --bvm-home PATH            Install BVM to PATH
  --with-java                Install Java 21+ automatically when missing
  --without-java             Skip Java detection and installation
  --with-shell               Configure shell initialization and PATH
  --without-shell            Leave shell profiles and PATH unchanged
  --with-runtime VERSION     Install a BoxLang runtime (latest, snapshot, or exact)
  --without-runtime          Skip the BoxLang runtime install
  --force                    Reinstall over an existing BVM installation
  --local                    Install scripts from this checkout
  --upgrade                  Internal self-update flow; skips the runtime prompt
  -h, --help                 Show this help

Any explicit --with-* or --without-* option implies --non-interactive.
EOF
}

parse_args() {
    while (($# > 0)); do
        case "$1" in
            --non-interactive|--yes|-y) NON_INTERACTIVE=yes ;;
            --verbose) VERBOSE=yes ;;
            --force) FORCE=true ;;
            --local) LOCAL_INSTALL=true ;;
            --upgrade) UPGRADE=true; NON_INTERACTIVE=yes ;;
            --with-java|--with-jre) WITH_JAVA=auto; NON_INTERACTIVE=yes ;;
            --without-java|--without-jre) WITH_JAVA=skip; NON_INTERACTIVE=yes ;;
            --with-shell) WITH_SHELL=yes; NON_INTERACTIVE=yes ;;
            --without-shell) WITH_SHELL=no; NON_INTERACTIVE=yes ;;
            --with-runtime|--runtime)
                WITH_RUNTIME="${2:-latest}"
                NON_INTERACTIVE=yes
                shift
                ;;
            --with-runtime=*|--runtime=*)
                WITH_RUNTIME="${1#*=}"
                NON_INTERACTIVE=yes
                ;;
            --without-runtime|--no-runtime) WITH_RUNTIME=none; NON_INTERACTIVE=yes ;;
            --bvm-home)
                BVM_HOME="${2:-$BVM_HOME}"
                shift
                ;;
            --bvm-home=*) BVM_HOME="${1#*=}" ;;
            -h|--help) usage; exit 0 ;;
            *) die "Unknown option: $1 (run with --help for usage)." ;;
        esac
        shift
    done
    BVM_INIT_FILE="$BVM_HOME/scripts/bvm-init.sh"
    BVM_FISH_INIT_FILE="$BVM_HOME/scripts/bvm-init.fish"
    BINARY="$BVM_HOME/bin/bvm"
}

###########################################################################
# Installation choices and plan
###########################################################################

choose_installation() {
    if [[ "$NON_INTERACTIVE" == yes || "$UPGRADE" == true ]]; then
        return 0
    fi
    MENU_LABELS=("Install BVM (recommended)" "Customize installation")
    MENU_HINTS=(
        "Everything this system supports: launchers, shell integration, Java 21+, and the latest BoxLang runtime."
        "Choose shell integration, Java behavior, and the runtime to install."
    )
    MENU_CHOICES=(no no)
    select_menu "Choose your setup" no >"$PROMPT_DEVICE"
    [[ "${MENU_CHOICES[1]}" != yes ]] || choose_custom_options
}

choose_custom_options() {
    MENU_LABELS=(
        "Shell integration for $SHELL_NAME"
        "Add $BVM_HOME/bin to PATH"
        "Install Java 21+ if missing"
        "Install the latest stable BoxLang runtime"
    )
    MENU_HINTS=(
        "Update your shell profile so BVM is available in new terminals."
        "Add the BVM bin directory to your PATH in the current shell and profile."
        "Download a Java 21 runtime automatically when one is not installed."
        "Install and activate the latest stable BoxLang runtime after BVM is ready."
    )
    MENU_CHOICES=(yes yes yes yes)
    select_menu "Make BVM yours" yes >"$PROMPT_DEVICE"
    if [[ "${MENU_CHOICES[0]}" == yes ]]; then
        WITH_SHELL=yes
    else
        WITH_SHELL=no
        MENU_CHOICES[1]=no
    fi
    if [[ "${MENU_CHOICES[2]}" == yes ]]; then WITH_JAVA=auto; else WITH_JAVA=skip; fi

    local skip_runtime="${MENU_CHOICES[3]:-no}"
    if [[ "$skip_runtime" == yes ]]; then
        WITH_RUNTIME=none
    else
        MENU_LABELS=("Latest stable" "Snapshot" "Do not install a runtime")
        MENU_HINTS=(
            "Install and activate the latest stable BoxLang release."
            "Install and activate the rolling development snapshot."
            "Install BVM only; choose a runtime later with 'bvm install latest'."
        )
        MENU_CHOICES=(no no no)
        select_menu "Choose a BoxLang runtime" no >"$PROMPT_DEVICE"
        if [[ "${MENU_CHOICES[1]}" == yes ]]; then
            WITH_RUNTIME=snapshot
        elif [[ "${MENU_CHOICES[2]}" == yes ]]; then
            WITH_RUNTIME=none
        else
            WITH_RUNTIME=latest
        fi
    fi
}

show_installation_plan() {
    section "Installation Plan"
    printf '  Install to %s\n\n' "$BVM_HOME"
    printf '  %s+%s  BVM launchers and wrappers\n' "$COLOR_ACCENT" "$COLOR_RESET"
    if [[ "$WITH_SHELL" == yes ]]; then
        printf '  %s+%s  Shell integration for %s\n' "$COLOR_ACCENT" "$COLOR_RESET" "$SHELL_NAME"
        printf '  %s+%s  Add %s/bin to PATH\n' "$COLOR_ACCENT" "$COLOR_RESET" "$BVM_HOME"
    else
        printf '\n  %sYour shell profile and PATH will stay unchanged.%s\n' "$COLOR_DIM" "$COLOR_RESET"
    fi
    case "$WITH_JAVA" in
        auto) printf '  %s+%s  Install Java 21+ if missing\n' "$COLOR_ACCENT" "$COLOR_RESET" ;;
        skip) printf '  %s+%s  Skip Java checks\n' "$COLOR_ACCENT" "$COLOR_RESET" ;;
    esac
    if [[ "$WITH_RUNTIME" != none && "$UPGRADE" != true ]]; then
        printf '  %s+%s  Install and activate BoxLang %s\n' "$COLOR_ACCENT" "$COLOR_RESET" "$WITH_RUNTIME"
    fi
    if ((${#MISSING_DEPS[@]} > 0)); then
        printf '  %s+%s  Install dependencies: %s\n' "$COLOR_ACCENT" "$COLOR_RESET" "${MISSING_DEPS[*]}"
    else
        printf '\n  %sAll selected runtime packages are already installed.%s\n' "$COLOR_DIM" "$COLOR_RESET"
    fi
}

###########################################################################
# Installation steps
###########################################################################

missing_dependencies() {
    MISSING_DEPS=()
    local tool
    for tool in curl unzip jq; do
        command -v "$tool" >/dev/null 2>&1 || MISSING_DEPS+=("$tool")
    done
}

install_dependencies() {
    if ((${#MISSING_DEPS[@]} == 0)); then
        return 0
    fi
    preflight_check skip -- "${MISSING_DEPS[@]}"
}

verify_java() {
    check_java_version
}

download_bundle() {
    local scripts_dir="$BVM_HOME/scripts"
    mkdir -p "$scripts_dir"
    if [[ "$LOCAL_INSTALL" == true ]]; then
        cp -R "$INSTALLER_DIR"/. "$scripts_dir"/
        return 0
    fi
    curl -L --retry 3 --retry-delay 2 --progress-bar -o "${TEMP_DIR}/boxlang-installer.zip" "$INSTALLER_URL"
    unzip -q -o "${TEMP_DIR}/boxlang-installer.zip" -d "$scripts_dir"
}

install_scripts() {
    mkdir -p "$BVM_HOME/bin" "$BVM_HOME/versions" "$BVM_HOME/cache" "$BVM_HOME/scripts"

    if [[ -f "$INSTALLER_DIR/bvm-init.sh" ]]; then
        cp "$INSTALLER_DIR/bvm-init.sh" "$BVM_INIT_FILE"
    fi
    if [[ ! -f "$BVM_INIT_FILE" ]]; then
        die "BVM initialization file was not found in the installer bundle"
    fi
    if [[ -f "$INSTALLER_DIR/bvm-init.fish" ]]; then
        cp "$INSTALLER_DIR/bvm-init.fish" "$BVM_FISH_INIT_FILE"
    fi
    if [[ ! -f "$BVM_FISH_INIT_FILE" ]]; then
        die "BVM fish initialization file was not found in the installer bundle"
    fi

    chmod -R 755 "$BVM_HOME/scripts"

    local scripts_dir="$BVM_HOME/scripts"
    ln -sf "$scripts_dir/bx-module.sh" "$BVM_HOME/bin/bx-module"
    ln -sf "$scripts_dir/install-bx-module.sh" "$BVM_HOME/bin/install-bx-module"
    ln -sf "$BVM_HOME/scripts/install-bx-site.sh" "$BVM_HOME/bin/install-bx-site"
    ln -sf "$BVM_HOME/scripts/install-bvm.sh" "$BVM_HOME/bin/install-bvm"
    ln -sf "$BVM_HOME/scripts/bvm.sh" "$BVM_HOME/bin/bvm"

    cat > "$BVM_HOME/bin/boxlang" <<'EOF'
#!/bin/bash
# BoxLang wrapper script for BVM
exec "$(dirname "$0")/bvm" exec "$@"
EOF
    cat > "$BVM_HOME/bin/bx" <<'EOF'
#!/bin/bash
# BoxLang (bx) wrapper script for BVM
exec "$(dirname "$0")/bvm" exec "$@"
EOF
    cat > "$BVM_HOME/bin/boxlang-miniserver" <<'EOF'
#!/bin/bash
# BoxLang MiniServer wrapper script for BVM
exec "$(dirname "$0")/bvm" miniserver "$@"
EOF
    cat > "$BVM_HOME/bin/bx-miniserver" <<'EOF'
#!/bin/bash
# BoxLang MiniServer (bx-miniserver) wrapper script for BVM
exec "$(dirname "$0")/bvm" miniserver "$@"
EOF
    chmod -R 755 "$BVM_HOME/bin"/*
}

setup_path() {
    local shell_name="${SHELL##*/}"
    local profile_init_marker="BVM (BoxLang Version Manager) shell initialization"

    BVM_PROFILE_FILE=$(get_shell_profile_file)

    if [[ "$shell_name" == fish ]]; then
        if ! grep -Fq "$profile_init_marker" "$BVM_PROFILE_FILE" 2>/dev/null; then
            {
                printf "\n# BVM (BoxLang Version Manager) shell initialization\n"
                printf "set -q BVM_HOME; or set -gx BVM_HOME \$HOME/.bvm\n"
                printf "test -s \"\$BVM_HOME/scripts/bvm-init.fish\"; and source \"\$BVM_HOME/scripts/bvm-init.fish\"\n"
            } >> "$BVM_PROFILE_FILE"
        fi
    elif ! grep -Fq "$profile_init_marker" "$BVM_PROFILE_FILE" 2>/dev/null; then
        {
            printf "\n# BVM (BoxLang Version Manager) shell initialization\n"
            printf "export BVM_HOME=\"\${BVM_HOME:-\$HOME/.bvm}\"\n"
            printf "[ -s \"\$BVM_HOME/scripts/bvm-init.sh\" ] && . \"\$BVM_HOME/scripts/bvm-init.sh\"\n"
        } >> "$BVM_PROFILE_FILE"
    fi

    # shellcheck disable=SC1090
    . "$BVM_INIT_FILE"
}

install_runtime() {
    export PATH="$BVM_HOME/bin:$PATH"
    run_task "Downloaded and installed BoxLang $WITH_RUNTIME" "$BINARY" install "$WITH_RUNTIME"
    run_task "Activated BoxLang $WITH_RUNTIME" "$BINARY" use "$WITH_RUNTIME"
}

show_summary() {
    info "BVM $BVM_VERSION is installed."
    printf '\n  %s🚨 Before you use BVM in this terminal, you need to source its initialization script:%s\n' "$COLOR_BOLD" "$COLOR_RESET"
	printf '\n'
    case "$SHELL_NAME" in
        fish) printf '     source ~/.config/fish/config.fish\n' ;;
        zsh) printf '     source ~/.zshrc\n' ;;
        *) printf '     source ~/.bashrc\n' ;;
    esac
    printf '\n  %s⚡Quick start:%s\n' "$COLOR_BOLD" "$COLOR_RESET"
    printf '     bvm install latest\n     bvm --help\n     boxlang --version\n'
    printf '\n  %sLearn more: %s%s\n\n' "$COLOR_DIM" "$PRODUCT_URL" "$COLOR_RESET"
}

###########################################################################
# Main
###########################################################################

main() {
    parse_args "$@"
    setup_colors
    setup_terminal
    trap installer_cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM

    show_banner

    OS_NAME="$(uname -s)"
    case "$OS_NAME" in
        Linux) PLATFORM=linux ;;
        Darwin) PLATFORM=macos ;;
        *) die "Unsupported operating system: $OS_NAME" ;;
    esac
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64|amd64) ARCH=x64 ;;
        arm64|aarch64) ARCH=arm64 ;;
        *) die "Unsupported architecture: $ARCH" ;;
    esac
    SHELL_NAME="${SHELL##*/}"
    show_system

    if [[ -e "$BVM_HOME/bin/bvm" && "$UPGRADE" != true && "$FORCE" != true ]]; then
		echo ""
        warn "BVM is already installed at $BVM_HOME. Use --force to reinstall."
    fi

    choose_installation
    missing_dependencies
    show_installation_plan

    TEMP_DIR=$(mktemp -d)
    TASK_OUTPUT_FILE="$TEMP_DIR/task-output"
    LOG_FILE=$(mktemp "${TMPDIR:-/tmp}/bvm-install.XXXXXX.log")

    section "Installing BVM"

    if ((${#MISSING_DEPS[@]} > 0)); then
        TASK_OUTPUT=live run_task "Installed dependencies" install_dependencies || die "Dependency installation failed"
    fi

    case "$WITH_JAVA" in
        skip)
            note "Java checks skipped. BoxLang will not run until Java 21+ is installed."
            ;;
        *)
            if run_task "Verified Java 21+" verify_java; then
                :
            elif [[ "$WITH_JAVA" == auto ]]; then
                TASK_OUTPUT=live run_task "Installed Java 21+" install_java || die "Java installation failed"
            else
                die "Java 21+ is required. Install it and rerun the installer."
            fi
            ;;
    esac

    TASK_PROGRESS=yes run_task "Downloaded BVM installer bundle" download_bundle || die "Download failed"
    run_task "Installed BVM launchers and wrappers" install_scripts || die "BVM installation failed"
    CORE_INSTALLED=yes

    if [[ "$WITH_SHELL" == yes ]]; then
        run_task "Configured shell integration" setup_path || die "Shell integration failed"
    else
        export PATH="$BVM_HOME/bin:$PATH"
    fi

    if [[ "$WITH_RUNTIME" != none && "$UPGRADE" != true ]]; then
        java_ok=no
        if check_java_version >/dev/null 2>&1; then java_ok=yes; fi
        if [[ "$java_ok" == yes ]]; then
            install_runtime || die "BoxLang runtime installation failed"
        else
            warn "Java 21+ is unavailable; skipped the BoxLang runtime install."
            printf '  Install it later with: bvm install latest && bvm use latest\n'
        fi
    fi

    if ((WARNING_COUNT > 0)); then
        section "Installed with warnings"
    elif [[ "$SETUP_NOTICES" == yes ]]; then
        section "Installed - review setup details"
    else
        section "Ready to explore"
    fi
    show_summary
}

if [[ ${BVM_INSTALLER_TESTING:-0} != 1 ]]; then
    main "$@"
fi
