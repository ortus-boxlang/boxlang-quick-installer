# fish completion for install-boxlang

complete -c install-boxlang -f
complete -c install-boxlang -a 'latest snapshot' -d 'Version to install'
complete -c install-boxlang -s h -l help -d 'Show help'
complete -c install-boxlang -s v -l version -d 'Show the installer version'
complete -c install-boxlang -l uninstall -d 'Remove BoxLang from the system'
complete -c install-boxlang -l check-update -d 'Check if a newer version is available'
complete -c install-boxlang -l system -d 'Force system-wide installation (requires sudo)'
complete -c install-boxlang -l force -d 'Force reinstallation'
complete -c install-boxlang -l with-commandbox -d 'Install CommandBox without prompting'
complete -c install-boxlang -l without-commandbox -d 'Skip CommandBox installation'
complete -c install-boxlang -l non-interactive -d 'Never prompt for input'
complete -c install-boxlang -l with-jre -d 'Install a Java JRE if not found'
complete -c install-boxlang -l without-jre -d 'Skip Java installation'
complete -c install-boxlang -s y -l yes -d 'Use defaults for all prompts'
complete -c install-boxlang -l boxlang-path -r -F -d 'Use a local BoxLang zip'
complete -c install-boxlang -l miniserver-path -r -F -d 'Use a local MiniServer zip'
complete -c install-boxlang -l installer-scripts-path -r -F -d 'Use a local scripts zip or folder'
