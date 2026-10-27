# PowerShell completion for install-boxlang

Register-ArgumentCompleter -Native -CommandName install-boxlang -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $options = @(
        '--help', '-h', '--version', '-v', '--uninstall', '--check-update', '--system', '--force',
        '--with-commandbox', '--without-commandbox', '--non-interactive', '--with-jre', '--without-jre',
        '--yes', '-y', '--boxlang-path', '--miniserver-path', '--installer-scripts-path'
    )
    $candidates = if ($wordToComplete -like '-*') { $options } else { @('latest', 'snapshot') + $options }

    $candidates | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
