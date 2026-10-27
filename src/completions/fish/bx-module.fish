# fish completion for bx-module (and its legacy alias install-bx-module)

function __bx_module_installed
    set -l dir (set -q BOXLANG_HOME; and echo $BOXLANG_HOME; or echo $HOME/.boxlang)/modules
    if contains -- --local (commandline -opc)
        set dir $PWD/boxlang_modules
    end
    test -d $dir; and for m in $dir/*/
        basename $m
    end
end

set -l __bx_cmds install remove list outdated update help

for cmd in bx-module install-bx-module
    complete -c $cmd -f
    complete -c $cmd -n "not __fish_seen_subcommand_from $__bx_cmds" -a install -d 'Install modules from FORGEBOX'
    complete -c $cmd -n "not __fish_seen_subcommand_from $__bx_cmds" -a remove -d 'Remove modules'
    complete -c $cmd -n "not __fish_seen_subcommand_from $__bx_cmds" -a list -d 'List installed modules'
    complete -c $cmd -n "not __fish_seen_subcommand_from $__bx_cmds" -a outdated -d 'Check installed modules against FORGEBOX'
    complete -c $cmd -n "not __fish_seen_subcommand_from $__bx_cmds" -a update -d 'Update outdated modules'
    complete -c $cmd -n "not __fish_seen_subcommand_from $__bx_cmds" -a help -d 'Show help'
    complete -c $cmd -n "not __fish_seen_subcommand_from $__bx_cmds" -s h -l help -d 'Show help'
    complete -c $cmd -n '__fish_seen_subcommand_from install list outdated remove update' -l local -d 'Use the local boxlang_modules folder'
    complete -c $cmd -n '__fish_seen_subcommand_from remove update' -l force -d 'Skip the confirmation prompt'
    complete -c $cmd -n '__fish_seen_subcommand_from remove update' -a '(__bx_module_installed)' -d 'Installed module'
    complete -c $cmd -n '__fish_seen_subcommand_from help' -a 'install remove list outdated update'
end
