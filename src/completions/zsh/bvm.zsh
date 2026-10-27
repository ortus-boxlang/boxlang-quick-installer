# zsh completion for bvm (BoxLang Version Manager)

_bvm_versions() {
    local dir="${BVM_HOME:-$HOME/.bvm}/versions"
    local -a versions
    [[ -d $dir ]] && versions=(${dir}/*(N:t))
    compadd -- $versions
}

_bvm() {
    local -a commands
    commands=(
        'install:Install a BoxLang version'
        'use:Switch to a BoxLang version'
        'local:Set or show the .bvmrc version'
        'current:Show the active version'
        'list:List installed versions'
        'ls:List installed versions'
        'list-remote:List versions available for download'
        'ls-remote:List versions available for download'
        'remove:Remove an installed version'
        'rm:Remove an installed version'
        'uninstall:Uninstall BVM and all versions'
        'which:Show the path of the active BoxLang'
        'exec:Run BoxLang with the active version'
        'run:Run BoxLang with the active version'
        'miniserver:Start the BoxLang MiniServer'
        'mini-server:Start the BoxLang MiniServer'
        'ms:Start the BoxLang MiniServer'
        'clean:Clean cache and temporary files'
        'stats:Show performance and usage statistics'
        'performance:Show performance and usage statistics'
        'usage:Show performance and usage statistics'
        'doctor:Check BVM installation health'
        'health:Check BVM installation health'
        'check-update:Check for BVM updates'
        'version:Show the BVM version'
        'help:Show help'
    )

    if (( CURRENT == 2 )); then
        _describe -t commands 'bvm command' commands
        compadd -- --help --version
        return
    fi

    case $words[2] in
        install)
            _alternative \
                'special:version:(latest snapshot)' \
                'installed:installed version:_bvm_versions' \
                'flags:option:(--force)'
            ;;
        use|local)
            _alternative \
                'special:version:(latest snapshot)' \
                'installed:installed version:_bvm_versions'
            ;;
        remove|rm)
            _alternative 'installed:installed version:_bvm_versions'
            ;;
        exec|run|miniserver|mini-server|ms)
            _files
            ;;
    esac
}

(( $+functions[compdef] )) && compdef _bvm bvm
