$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $PSScriptRoot 'TestFramework.ps1')

Initialize-TestSuite 'PowerShell module manager commands'
$moduleInstaller = Join-Path $repoRoot 'src\bx-module.ps1'
$legacyModuleInstaller = Join-Path $repoRoot 'src\install-bx-module.ps1'

function Invoke-ModuleInstaller {
    param([string[]]$InstallerArguments, [scriptblock]$Setup, [string]$Script = $moduleInstaller)

    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('bx-module-installer-' + [guid]::NewGuid())
    $fakeHome = Join-Path $root 'home'
    [System.IO.Directory]::CreateDirectory($fakeHome) | Out-Null
    if ($Setup) { & $Setup $fakeHome }

    $previousLocation = Get-Location
    $previousBoxlangHome = $env:BOXLANG_HOME
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        # Windows PowerShell turns child stderr output into terminating errors under 'Stop'
        $ErrorActionPreference = 'Continue'
        Set-Location $root
        $env:BOXLANG_HOME = $fakeHome
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script @InstallerArguments 2>&1 | Out-String
        return @{ Output = $output; ExitCode = $LASTEXITCODE }
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
        Set-Location $previousLocation
        if ($null -eq $previousBoxlangHome) { Remove-Item Env:BOXLANG_HOME -ErrorAction SilentlyContinue } else { $env:BOXLANG_HOME = $previousBoxlangHome }
        Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Invoke-Test 'remove with no module name shows a usage error instead of doing nothing' {
    $result = Invoke-ModuleInstaller -InstallerArguments @('remove')
    Assert-Equal 1 $result.ExitCode 'remove with no module name should exit 1'
    Assert-Match 'No module\(s\) specified for removal' $result.Output 'remove with no module name did not show the usage error'
}

Invoke-Test 'remove --local with no module name shows a usage error instead of doing nothing' {
    $result = Invoke-ModuleInstaller -InstallerArguments @('remove', '--local')
    Assert-Equal 1 $result.ExitCode 'remove --local with no module name should exit 1'
    Assert-Match 'No module\(s\) specified for removal' $result.Output 'remove --local with no module name did not show the usage error'
}

Invoke-Test 'remove with a module name still works' {
    $result = Invoke-ModuleInstaller -InstallerArguments @('remove', 'bx-orm', '--force')
    Assert-Equal 0 $result.ExitCode 'remove with a module name should succeed'
    Assert-Match 'Starting removal of module: bx-orm' $result.Output 'remove with a module name did not attempt removal'
}

Invoke-Test 'list alone still succeeds' {
    $result = Invoke-ModuleInstaller -InstallerArguments @('list')
    Assert-Equal 0 $result.ExitCode 'list alone should succeed'
    Assert-Match 'Installed BoxLang Modules' $result.Output 'list alone did not show the module listing header'
}

Invoke-Test 'list --local still succeeds' {
    $result = Invoke-ModuleInstaller -InstallerArguments @('list', '--local')
    Assert-Equal 0 $result.ExitCode 'list --local should succeed'
    Assert-Match 'Local' $result.Output 'list --local did not report the local location'
}

Invoke-Test 'no arguments shows the command help' {
    $result = Invoke-ModuleInstaller -InstallerArguments @()
    Assert-Equal 0 $result.ExitCode 'no arguments should show help and exit 0'
    Assert-Match 'bx-module <command>' $result.Output 'no arguments did not show the command usage'
}

Invoke-Test 'help lists the commands and help <command> shows one command' {
    $result = Invoke-ModuleInstaller -InstallerArguments @('help')
    Assert-Equal 0 $result.ExitCode 'help should exit 0'
    Assert-Match 'update \[<module> \.\.\.\]' $result.Output 'help did not list the update command'

    $result = Invoke-ModuleInstaller -InstallerArguments @('help', 'update')
    Assert-Equal 0 $result.ExitCode 'help update should exit 0'
    Assert-Match 'bx-module update \[<module> \.\.\.\]' $result.Output 'help update did not show the update usage'

    $result = Invoke-ModuleInstaller -InstallerArguments @('install', '--help')
    Assert-Equal 0 $result.ExitCode 'install --help should exit 0'
    Assert-Match 'bx-module install <module>' $result.Output 'install --help did not show the install usage'
}

Invoke-Test 'an unknown command is rejected with a hint' {
    $result = Invoke-ModuleInstaller -InstallerArguments @('bx-orm')
    Assert-Equal 1 $result.ExitCode 'a bare module name should exit 1'
    Assert-Match "Unknown command 'bx-orm'" $result.Output 'a bare module name did not report an unknown command'
    Assert-Match 'Did you mean: bx-module install bx-orm' $result.Output 'a bare module name did not suggest install'

    $result = Invoke-ModuleInstaller -InstallerArguments @('--list')
    Assert-Equal 1 $result.ExitCode 'a legacy flag should exit 1'
    Assert-Match 'Did you mean: bx-module list' $result.Output 'a legacy flag did not suggest the verb'
}

Invoke-Test 'list rejects module names and --force' {
    $result = Invoke-ModuleInstaller -InstallerArguments @('list', 'bx-orm')
    Assert-Equal 1 $result.ExitCode 'list with a module name should exit 1'
    $result = Invoke-ModuleInstaller -InstallerArguments @('list', '--force')
    Assert-Equal 1 $result.ExitCode 'list --force should exit 1'
    Assert-Match "'list' does not accept additional arguments" $result.Output 'list --force did not explain the rejection'
}

Invoke-Test 'update warns about a named module that is not installed' {
    $result = Invoke-ModuleInstaller -InstallerArguments @('update', 'bx-nope', '--force') -Setup {
        param($fakeHome)
        $modules = Join-Path $fakeHome 'modules'
        [System.IO.Directory]::CreateDirectory($modules) | Out-Null
        '{"dependencies": {}}' | Set-Content (Join-Path $modules 'box.json')
    }
    Assert-Equal 0 $result.ExitCode 'update of a missing module should exit 0'
    Assert-Match "Module 'bx-nope' was not found" $result.Output 'update did not warn about the missing module'
    Assert-Match 'None of the requested modules are installed' $result.Output 'update claimed everything was up to date when no named module matched'
}

Invoke-Test 'remove deletes the launcher scripts the module installed' {
    $result = Invoke-ModuleInstaller -InstallerArguments @('remove', 'bx-demo', '--force') -Setup {
        param($fakeHome)
        $modules = Join-Path $fakeHome 'modules'
        $module = Join-Path $modules 'bx-demo'
        $bin = Join-Path $fakeHome 'bin'
        [System.IO.Directory]::CreateDirectory($module) | Out-Null
        [System.IO.Directory]::CreateDirectory($bin) | Out-Null
        '{"dependencies": {"bx-demo": "1.0.0"}}' | Set-Content (Join-Path $modules 'box.json')
        '{"version": "1.0.0", "boxlang": {"executable": "bxdemo"}}' | Set-Content (Join-Path $module 'box.json')
        '# launcher' | Set-Content (Join-Path $bin 'bxdemo')
        '@echo off' | Set-Content (Join-Path $bin 'bxdemo.bat')
        '# unrelated' | Set-Content (Join-Path $bin 'keepme')
    }
    Assert-Equal 0 $result.ExitCode 'remove of a module with launchers should succeed'
    Assert-Match 'Removed launcher script: bxdemo' $result.Output 'remove did not report removing the launcher'
    Assert-Match 'Removed launcher script: bxdemo.bat' $result.Output 'remove did not report removing the .bat wrapper'
    Assert-True ($result.Output -notmatch 'Removed launcher script: keepme') 'remove touched an unrelated bin script'
}

Invoke-Test 'the legacy install-bx-module command forwards to bx-module with a deprecation notice' {
    $result = Invoke-ModuleInstaller -Script $legacyModuleInstaller -InstallerArguments @('--list')
    Assert-Equal 0 $result.ExitCode 'legacy --list should succeed'
    Assert-Match 'deprecated' $result.Output 'legacy --list did not print a deprecation notice'
    Assert-Match 'Installed BoxLang Modules' $result.Output 'legacy --list did not run the list command'

    $result = Invoke-ModuleInstaller -Script $legacyModuleInstaller -InstallerArguments @('--remove')
    Assert-Equal 1 $result.ExitCode 'legacy --remove with no module name should exit 1'
    Assert-Match 'No module\(s\) specified for removal' $result.Output 'legacy --remove did not run the remove command'

    $result = Invoke-ModuleInstaller -Script $legacyModuleInstaller -InstallerArguments @('--remove', 'bx-orm', '--force')
    Assert-Equal 0 $result.ExitCode 'legacy --remove with a module name should succeed'
    Assert-Match 'Starting removal of module: bx-orm' $result.Output 'legacy --remove did not attempt removal'

    $result = Invoke-ModuleInstaller -Script $legacyModuleInstaller -InstallerArguments @('--help')
    Assert-Equal 0 $result.ExitCode 'legacy --help should exit 0'
    Assert-Match 'bx-module <command>' $result.Output 'legacy --help did not show the command help'
}

Invoke-Test 'list shows modules nested inside their parent module' {
    $result = Invoke-ModuleInstaller -InstallerArguments @('list') -Setup {
        param($fakeHome)
        $modules = Join-Path $fakeHome 'modules'
        $nested = Join-Path $modules 'bx-sites\modules\bx-markdown'
        [System.IO.Directory]::CreateDirectory($nested) | Out-Null
        '{"dependencies": {"bx-sites": "1.0.0"}}' | Set-Content (Join-Path $modules 'box.json')
        '{"version": "1.0.0"}' | Set-Content (Join-Path $modules 'bx-sites\box.json')
        '{"version": "2.0.0"}' | Set-Content (Join-Path $nested 'box.json')
    }
    Assert-Equal 0 $result.ExitCode 'list with nested modules should succeed'
    Assert-Match 'bx-sites \(1\.0\.0\)' $result.Output 'list did not show the top-level module'
    Assert-Match '(?m)^\s{2}\S+ bx-markdown \(2\.0\.0\)' $result.Output 'list did not show the nested module indented under its parent'
}

Complete-TestSuite
