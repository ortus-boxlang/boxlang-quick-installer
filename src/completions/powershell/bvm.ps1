# PowerShell completion for bvm (BoxLang Version Manager)

Register-ArgumentCompleter -Native -CommandName bvm -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $commands = @(
        'install', 'use', 'local', 'current', 'list', 'ls', 'list-remote', 'ls-remote',
        'remove', 'rm', 'uninstall', 'which', 'exec', 'run', 'miniserver', 'mini-server', 'ms',
        'clean', 'stats', 'performance', 'usage', 'doctor', 'health', 'check-update',
        'version', 'help', '--help', '--version'
    )
    $bvmHome = if ($env:BVM_HOME) { $env:BVM_HOME } else { Join-Path $env:USERPROFILE '.bvm' }
    $installed = @()
    $versionsDir = Join-Path $bvmHome 'versions'
    if (Test-Path $versionsDir) {
        $installed = @(Get-ChildItem -Path $versionsDir -Directory | ForEach-Object { $_.Name })
    }

    $words = @($commandAst.CommandElements | ForEach-Object { $_.ToString() })
    # Completing the first argument when the cursor sits right after "bvm "
    $atNewWord = $wordToComplete -eq ''
    $position = if ($atNewWord) { $words.Count } else { $words.Count - 1 }

    $candidates = if ($position -le 1) {
        $commands
    } else {
        switch ($words[1]) {
            'install' { @('latest', 'snapshot') + $installed + '--force' }
            { $_ -in 'use', 'local' } { @('latest', 'snapshot') + $installed }
            { $_ -in 'remove', 'rm' } { $installed }
            default { @() }
        }
    }

    $candidates | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
