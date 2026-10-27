# fish completion for bvm (BoxLang Version Manager)

function __bvm_versions
    set -l dir (set -q BVM_HOME; and echo $BVM_HOME; or echo $HOME/.bvm)/versions
    test -d $dir; and for v in $dir/*
        basename $v
    end
end

set -l __bvm_cmds install use local current list ls list-remote ls-remote remove rm uninstall which exec run miniserver mini-server ms clean stats performance usage doctor health check-update version help

complete -c bvm -f
complete -c bvm -n "not __fish_seen_subcommand_from $__bvm_cmds" -a install -d 'Install a BoxLang version'
complete -c bvm -n "not __fish_seen_subcommand_from $__bvm_cmds" -a use -d 'Switch to a BoxLang version'
complete -c bvm -n "not __fish_seen_subcommand_from $__bvm_cmds" -a local -d 'Set or show the .bvmrc version'
complete -c bvm -n "not __fish_seen_subcommand_from $__bvm_cmds" -a current -d 'Show the active version'
complete -c bvm -n "not __fish_seen_subcommand_from $__bvm_cmds" -a 'list ls' -d 'List installed versions'
complete -c bvm -n "not __fish_seen_subcommand_from $__bvm_cmds" -a 'list-remote ls-remote' -d 'List versions available for download'
complete -c bvm -n "not __fish_seen_subcommand_from $__bvm_cmds" -a 'remove rm' -d 'Remove an installed version'
complete -c bvm -n "not __fish_seen_subcommand_from $__bvm_cmds" -a uninstall -d 'Uninstall BVM and all versions'
complete -c bvm -n "not __fish_seen_subcommand_from $__bvm_cmds" -a which -d 'Show the path of the active BoxLang'
complete -c bvm -n "not __fish_seen_subcommand_from $__bvm_cmds" -a 'exec run' -d 'Run BoxLang with the active version'
complete -c bvm -n "not __fish_seen_subcommand_from $__bvm_cmds" -a 'miniserver mini-server ms' -d 'Start the BoxLang MiniServer'
complete -c bvm -n "not __fish_seen_subcommand_from $__bvm_cmds" -a clean -d 'Clean cache and temporary files'
complete -c bvm -n "not __fish_seen_subcommand_from $__bvm_cmds" -a 'stats performance usage' -d 'Show performance and usage statistics'
complete -c bvm -n "not __fish_seen_subcommand_from $__bvm_cmds" -a 'doctor health' -d 'Check BVM installation health'
complete -c bvm -n "not __fish_seen_subcommand_from $__bvm_cmds" -a check-update -d 'Check for BVM updates'
complete -c bvm -n "not __fish_seen_subcommand_from $__bvm_cmds" -a version -d 'Show the BVM version'
complete -c bvm -n "not __fish_seen_subcommand_from $__bvm_cmds" -a help -d 'Show help'
complete -c bvm -n "not __fish_seen_subcommand_from $__bvm_cmds" -s h -l help -d 'Show help'
complete -c bvm -n "not __fish_seen_subcommand_from $__bvm_cmds" -s v -l version -d 'Show the BVM version'

complete -c bvm -n '__fish_seen_subcommand_from install' -a 'latest snapshot' -d 'Release channel'
complete -c bvm -n '__fish_seen_subcommand_from install' -l force -d 'Reinstall an existing version'
complete -c bvm -n '__fish_seen_subcommand_from use local' -a 'latest snapshot'
complete -c bvm -n '__fish_seen_subcommand_from use local remove rm' -a '(__bvm_versions)' -d 'Installed version'
complete -c bvm -n '__fish_seen_subcommand_from exec run miniserver mini-server ms' -F
