# zsh completion for bx-module (and its legacy alias install-bx-module)

_bx_module_installed() {
    local dir
    if (( ${words[(Ie)--local]} )); then
        dir="$PWD/boxlang_modules"
    else
        dir="${BOXLANG_HOME:-$HOME/.boxlang}/modules"
    fi
    local -a mods
    [[ -d $dir ]] && mods=(${dir}/*(N/:t))
    compadd -- $mods
}

_bx_module() {
    local -a commands
    commands=(
        'install:Install modules from FORGEBOX'
        'remove:Remove modules'
        'list:List installed modules'
        'outdated:Check installed modules against FORGEBOX'
        'update:Update outdated modules'
        'help:Show help'
    )

    if (( CURRENT == 2 )); then
        _describe -t commands 'bx-module command' commands
        compadd -- --help
        return
    fi

    case $words[2] in
        install|list|outdated)
            _arguments '--local[Use the local boxlang_modules folder]'
            ;;
        remove|update)
            _arguments \
                '--local[Use the local boxlang_modules folder]' \
                '--force[Skip the confirmation prompt]' \
                '*:installed module:_bx_module_installed'
            ;;
        help)
            (( CURRENT == 3 )) && compadd -- install remove list outdated update
            ;;
    esac
}

(( $+functions[compdef] )) && compdef _bx_module bx-module install-bx-module
