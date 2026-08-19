$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $PSScriptRoot 'TestFramework.ps1')

Initialize-TestSuite 'PowerShell prerequisites and module parsing'
$boxlangInstaller = Join-Path $repoRoot 'src\install-boxlang.ps1'
$bvmInstaller = Join-Path $repoRoot 'src\install-bvm.ps1'
$moduleInstaller = Join-Path $repoRoot 'src\install-bx-module.ps1'
Import-ScriptFunctions -Path $moduleInstaller -Names @('Parse-ModuleList')

Invoke-Test 'provides native download, JSON, and archive commands' {
    foreach ($command in @('Invoke-WebRequest', 'Invoke-RestMethod', 'Expand-Archive')) {
        Assert-True (Get-Command $command -ErrorAction SilentlyContinue) "Missing required PowerShell command $command"
    }
}

Invoke-Test 'parses module lists like the module installer' {
    $modules = @(Parse-ModuleList @('foo@1.0.0,bar@2.0.0', '--force', 'baz'))
    Assert-Equal 3 $modules.Count 'Module list count is incorrect'
    Assert-Equal 'foo@1.0.0' $modules[0] 'First module is incorrect'
    Assert-Equal 'bar@2.0.0' $modules[1] 'Second module is incorrect'
    Assert-Equal 'baz' $modules[2] 'Third module is incorrect'
}

Invoke-Test 'documents BVM Java modes' {
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $bvmInstaller --help 2>&1 | Out-String
    Assert-Equal 0 $LASTEXITCODE 'BVM installer help should succeed'
    Assert-Match '--with-jre' $output 'BVM help is missing --with-jre'
    Assert-Match '--without-jre' $output 'BVM help is missing --without-jre'
}

Invoke-Test 'parses every Windows installer script' {
    foreach ($script in @($boxlangInstaller, $bvmInstaller, $moduleInstaller, (Join-Path $repoRoot 'src\bvm.ps1'), (Join-Path $repoRoot 'src\helpers\install-jre.ps1'))) {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$tokens, [ref]$errors) | Out-Null
        Assert-Equal 0 $errors.Count "Parser errors in $script"
    }
}

Complete-TestSuite
