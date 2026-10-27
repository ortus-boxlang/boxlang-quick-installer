# bash completion for bvm (BoxLang Version Manager)

_bvm_versions() {
    local dir="${BVM_HOME:-$HOME/.bvm}/versions"
    [ -d "$dir" ] || return 0
    find "$dir" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) -exec basename {} \; 2>/dev/null
}

_bvm_complete() {
    local cur cmd commands
    cur="${COMP_WORDS[COMP_CWORD]}"
    commands="install use local current list ls list-remote ls-remote remove rm uninstall which exec run miniserver mini-server ms clean stats performance usage doctor health check-update version help"
    COMPREPLY=()

    if [ "$COMP_CWORD" -eq 1 ]; then
        COMPREPLY=($(compgen -W "$commands --help --version" -- "$cur"))
        return 0
    fi

    cmd="${COMP_WORDS[1]}"
    case "$cmd" in
        install)
            COMPREPLY=($(compgen -W "latest snapshot $(_bvm_versions) --force" -- "$cur"))
            ;;
        use|local)
            COMPREPLY=($(compgen -W "latest snapshot $(_bvm_versions)" -- "$cur"))
            ;;
        remove|rm)
            COMPREPLY=($(compgen -W "$(_bvm_versions)" -- "$cur"))
            ;;
        exec|run|miniserver|mini-server|ms)
            # Arguments are passed through to BoxLang, fall back to file names
            return 1
            ;;
    esac
}

complete -o default -F _bvm_complete bvm 2>/dev/null || true
