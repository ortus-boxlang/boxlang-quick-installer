#!/usr/bin/env bash

# BVM (BoxLang Version Manager) bash completion

if [ -z "${BASH_VERSION:-}" ] && [ -z "${ZSH_VERSION:-}" ]; then
    return 0 2>/dev/null || true
fi

_bvm_versions() {
    local versions="latest snapshot"
    if [ -d "${BVM_HOME:-$HOME/.bvm}/versions" ]; then
        versions="$versions $(find "${BVM_HOME:-$HOME/.bvm}/versions" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) -exec basename {} \; 2>/dev/null)"
    fi
    printf '%s\n' "$versions"
}

_bvm_complete() {
    local current_word previous_word commands
    current_word="${COMP_WORDS[COMP_CWORD]}"
    previous_word="${COMP_WORDS[COMP_CWORD - 1]}"
    commands="install use local current list ls list-remote ls-remote remove rm uninstall which exec run miniserver mini-server ms clean stats performance usage doctor health check-update version help"

    case "$previous_word" in
        install)
            COMPREPLY=($(compgen -W "latest snapshot $(_bvm_versions) --force" -- "$current_word"))
            ;;
        use|local|remove|rm)
            COMPREPLY=($(compgen -W "$(_bvm_versions)" -- "$current_word"))
            ;;
        exec|run|miniserver|mini-server|ms)
            COMPREPLY=()
            ;;
        *)
            COMPREPLY=($(compgen -W "$commands" -- "$current_word"))
            ;;
    esac
}

if [[ -n "${ZSH_VERSION:-}" ]]; then
    if ! command -v compinit >/dev/null 2>&1; then
        autoload -U +X compinit && compinit
    fi
    autoload -U +X bashcompinit && bashcompinit
fi

complete -o default -F _bvm_complete bvm 2>/dev/null || true
