# bash completion for bx-module (and its legacy alias install-bx-module)

_bx_module_installed() {
    local dir
    if [[ " ${COMP_WORDS[*]} " == *" --local "* ]]; then
        dir="$(pwd)/boxlang_modules"
    else
        dir="${BOXLANG_HOME:-$HOME/.boxlang}/modules"
    fi
    [ -d "$dir" ] || return 0
    find "$dir" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -exec basename {} \; 2>/dev/null
}

_bx_module_complete() {
    local cur cmd
    cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=()

    if [ "$COMP_CWORD" -eq 1 ]; then
        COMPREPLY=($(compgen -W "install remove list outdated update help --help" -- "$cur"))
        return 0
    fi

    cmd="${COMP_WORDS[1]}"
    if [[ "$cur" == -* ]]; then
        case "$cmd" in
            install|list|outdated) COMPREPLY=($(compgen -W "--local" -- "$cur")) ;;
            remove|update)         COMPREPLY=($(compgen -W "--local --force" -- "$cur")) ;;
        esac
        return 0
    fi

    case "$cmd" in
        remove|update)
            COMPREPLY=($(compgen -W "$(_bx_module_installed)" -- "$cur"))
            ;;
        help)
            if [ "$COMP_CWORD" -eq 2 ]; then
                COMPREPLY=($(compgen -W "install remove list outdated update" -- "$cur"))
            fi
            ;;
        install)
            # Module names come from FORGEBOX, nothing to suggest offline
            ;;
    esac
}

complete -F _bx_module_complete bx-module install-bx-module 2>/dev/null || true
