$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $PSScriptRoot 'TestFramework.ps1')

Initialize-TestSuite 'PowerShell module installer argument parsing'
$moduleInstaller = Join-Path $repoRoot 'src\install-bx-module.ps1'

function Invoke-ModuleInstaller {
    param([string[]]$InstallerArguments, [scriptblock]$Setup)

    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('bx-module-installer-' + [guid]::NewGuid())
    $fakeHome = Join-Path $root 'home'
    [System.IO.Directory]::CreateDirectory($fakeHome) | Out-Null
    if ($Setup) { & $Setup $fakeHome }

    $previousLocation = Get-Location
    $previousBoxlangHome = $env:BOXLANG_HOME
    try {
        Set-Location $root
        $env:BOXLANG_HOME = $fakeHome
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $moduleInstaller @InstallerArguments 2>&1 | Out-String
        return @{ Output = $output; ExitCode = $LASTEXITCODE }
    }
    finally {
        Set-Location $previousLocation
        if ($null -eq $previousBoxlangHome) { Remove-Item Env:BOXLANG_HOME -ErrorAction SilentlyContinue } else { $env:BOXLANG_HOME = $previousBoxlangHome }
        Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Invoke-Test '--remove with no module name shows a usage error instead of doing nothing' {
    $result = Invoke-ModuleInstaller -InstallerArguments @('--remove')
    Assert-Equal 1 $result.ExitCode '--remove with no module name should exit 1'
    Assert-Match 'No module\(s\) specified for removal' $result.Output '--remove with no module name did not show the usage error'
}

Invoke-Test '--remove --local with no module name shows a usage error instead of doing nothing' {
    $result = Invoke-ModuleInstaller -InstallerArguments @('--remove', '--local')
    Assert-Equal 1 $result.ExitCode '--remove --local with no module name should exit 1'
    Assert-Match 'No module\(s\) specified for removal' $result.Output '--remove --local with no module name did not show the usage error'
}

Invoke-Test '--remove with a module name still works' {
    $result = Invoke-ModuleInstaller -InstallerArguments @('--remove', 'bx-orm', '--force')
    Assert-Equal 0 $result.ExitCode '--remove with a module name should succeed'
    Assert-Match 'Starting removal of module: bx-orm' $result.Output '--remove with a module name did not attempt removal'
}

Invoke-Test '--list alone still succeeds' {
    $result = Invoke-ModuleInstaller -InstallerArguments @('--list')
    Assert-Equal 0 $result.ExitCode '--list alone should succeed'
    Assert-Match 'Installed BoxLang Modules' $result.Output '--list alone did not show the module listing header'
}

Invoke-Test '--list --local still succeeds' {
    $result = Invoke-ModuleInstaller -InstallerArguments @('--list', '--local')
    Assert-Equal 0 $result.ExitCode '--list --local should succeed'
    Assert-Match 'Local' $result.Output '--list --local did not report the local location'
}

Invoke-Test '--list shows modules nested inside their parent module' {
    $result = Invoke-ModuleInstaller -InstallerArguments @('--list') -Setup {
        param($fakeHome)
        $modules = Join-Path $fakeHome 'modules'
        $nested = Join-Path $modules 'bx-sites\modules\bx-markdown'
        [System.IO.Directory]::CreateDirectory($nested) | Out-Null
        '{"dependencies": {"bx-sites": "1.0.0"}}' | Set-Content (Join-Path $modules 'box.json')
        '{"version": "1.0.0"}' | Set-Content (Join-Path $modules 'bx-sites\box.json')
        '{"version": "2.0.0"}' | Set-Content (Join-Path $nested 'box.json')
    }
    Assert-Equal 0 $result.ExitCode '--list with nested modules should succeed'
    Assert-Match 'bx-sites \(1\.0\.0\)' $result.Output '--list did not show the top-level module'
    Assert-Match '(?m)^\s{2}\S+ bx-markdown \(2\.0\.0\)' $result.Output '--list did not show the nested module indented under its parent'
}

Complete-TestSuite
