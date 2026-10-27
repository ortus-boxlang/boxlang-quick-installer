# zsh completion for install-boxlang

_install_boxlang() {
    _arguments -s \
        '(- *)'{-h,--help}'[Show help]' \
        '(- *)'{-v,--version}'[Show the installer version]' \
        '--uninstall[Remove BoxLang from the system]' \
        '--check-update[Check if a newer version is available]' \
        '--system[Force system-wide installation (requires sudo)]' \
        '--force[Force reinstallation]' \
        '--with-commandbox[Install CommandBox without prompting]' \
        '--without-commandbox[Skip CommandBox installation]' \
        '--non-interactive[Never prompt for input]' \
        '--with-jre[Install a Java JRE if not found]' \
        '--without-jre[Skip Java installation]' \
        '(-y --yes)'{-y,--yes}'[Use defaults for all prompts]' \
        '--boxlang-path[Use a local BoxLang zip]:file:_files' \
        '--miniserver-path[Use a local MiniServer zip]:file:_files' \
        '--installer-scripts-path[Use a local scripts zip or folder]:path:_files' \
        '1:version:(latest snapshot)'
}

(( $+functions[compdef] )) && compdef _install_boxlang install-boxlang
