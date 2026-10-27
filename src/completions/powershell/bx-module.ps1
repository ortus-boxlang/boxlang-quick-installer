# PowerShell completion for bx-module (and its legacy alias install-bx-module)

Register-ArgumentCompleter -Native -CommandName bx-module, install-bx-module -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $verbs = @('install', 'remove', 'list', 'outdated', 'update', 'help', '--help')
    $words = @($commandAst.CommandElements | ForEach-Object { $_.ToString() })
    $position = if ($wordToComplete -eq '') { $words.Count } else { $words.Count - 1 }

    $candidates = @()
    if ($position -le 1) {
        $candidates = $verbs
    } else {
        $verb = $words[1]
        if ($wordToComplete -like '-*') {
            $candidates = switch ($verb) {
                { $_ -in 'install', 'list', 'outdated' } { @('--local') }
                { $_ -in 'remove', 'update' } { @('--local', '--force') }
                default { @() }
            }
        } elseif ($verb -in 'remove', 'update') {
            $modulesDir = if ($words -contains '--local') {
                Join-Path (Get-Location).Path 'boxlang_modules'
            } else {
                $bxHome = if ($env:BOXLANG_HOME) { $env:BOXLANG_HOME } else { Join-Path $env:USERPROFILE '.boxlang' }
                Join-Path $bxHome 'modules'
            }
            if (Test-Path $modulesDir) {
                $candidates = @(Get-ChildItem -Path $modulesDir -Directory | Where-Object { $_.Name -notlike '.*' } | ForEach-Object { $_.Name })
            }
        } elseif ($verb -eq 'help' -and $position -eq 2) {
            $candidates = @('install', 'remove', 'list', 'outdated', 'update')
        }
    }

    $candidates | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
