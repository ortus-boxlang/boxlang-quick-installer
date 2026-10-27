# bash completion for install-boxlang

_install_boxlang_complete() {
    local cur prev opts
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD - 1]}"
    opts="--help -h --version -v --uninstall --check-update --system --force --with-commandbox --without-commandbox --non-interactive --with-jre --without-jre --yes -y --boxlang-path --miniserver-path --installer-scripts-path"
    COMPREPLY=()

    case "$prev" in
        --boxlang-path|--miniserver-path|--installer-scripts-path)
            # Path values, fall back to file names
            return 1
            ;;
    esac

    if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "$opts" -- "$cur"))
    else
        COMPREPLY=($(compgen -W "latest snapshot $opts" -- "$cur"))
    fi
}

complete -o default -F _install_boxlang_complete install-boxlang 2>/dev/null || true
