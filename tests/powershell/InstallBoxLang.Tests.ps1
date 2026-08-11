$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $PSScriptRoot 'TestFramework.ps1')

Initialize-TestSuite 'PowerShell BoxLang installer'
$installer = Join-Path $repoRoot 'src\install-boxlang.ps1'

function Invoke-InstallerHelp {
    param([string]$InstallHome)

    $previous = $env:BOXLANG_INSTALL_HOME
    try {
        if ($InstallHome) { $env:BOXLANG_INSTALL_HOME = $InstallHome } else { Remove-Item Env:BOXLANG_INSTALL_HOME -ErrorAction SilentlyContinue }
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer --help 2>&1 | Out-String
        Assert-Equal 0 $LASTEXITCODE 'Installer help should succeed'
        return $output
    }
    finally {
        if ($null -eq $previous) { Remove-Item Env:BOXLANG_INSTALL_HOME -ErrorAction SilentlyContinue } else { $env:BOXLANG_INSTALL_HOME = $previous }
    }
}

function New-TestJava {
    param([string]$Root)

    $javaDirectory = Join-Path $Root 'java'
    New-Item -ItemType Directory -Path $javaDirectory -Force | Out-Null
    $javaScript = "@echo off`r`nif `"%1`"==`"-jar`" (`r`n  echo BoxLang 1.0.0`r`n  exit /b 0`r`n)`r`necho openjdk version `"21.0.1`" 1>&2"
    Set-Content -Path (Join-Path $javaDirectory 'java.cmd') -Value $javaScript -Encoding ASCII
    return $javaDirectory
}

function New-TestRoot {
    param([string]$Prefix)

    $testRoot = Join-Path $env:USERPROFILE 'AppData\Local\Temp'
    $root = Join-Path $testRoot ("$Prefix-" + [guid]::NewGuid())
    [System.IO.Directory]::CreateDirectory($root) | Out-Null
    return $root
}

function New-TestInstallerScripts {
    param([string]$Root)

    New-Item -ItemType Directory -Path $Root -Force | Out-Null
    $versionScript = "@echo off`r`nif `"%1`"==`"--version`" echo BoxLang 1.0.0`r`nexit /b 0"
    Set-Content -Path (Join-Path $Root 'boxlang.bat') -Value $versionScript -Encoding ASCII
    Set-Content -Path (Join-Path $Root 'boxlang-miniserver.bat') -Value $versionScript -Encoding ASCII
    return $Root
}

function Invoke-LocalInstaller {
    param(
        [string]$Root,
        [string]$BoxLangPath,
        [string]$MiniServerPath,
        [string]$InstallerScriptsPath
    )

    $previousInstallHome = $env:BOXLANG_INSTALL_HOME
    $previousUserProfile = $env:USERPROFILE
    $previousPath = $env:PATH
    $previousTemp = $env:TEMP
    $previousTmp = $env:TMP
    try {
        $installHome = Join-Path $Root 'install'
        $env:BOXLANG_INSTALL_HOME = $installHome
        $env:USERPROFILE = Join-Path $Root 'user'
        $env:TEMP = Join-Path $Root 'temp'
        $env:TMP = $env:TEMP
        New-Item -ItemType Directory -Path $env:USERPROFILE, $env:TEMP -Force | Out-Null
        $env:PATH = "$(New-TestJava -Root $Root);$previousPath"
        $arguments = @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $installer,
            '--force', '--without-commandbox',
            '--boxlang-path', $BoxLangPath,
            '--miniserver-path', $MiniServerPath,
            '--installer-scripts-path', $InstallerScriptsPath
        )
        $output = & powershell.exe @arguments 2>&1 | Out-String
        Assert-Equal 0 $LASTEXITCODE 'Local artifact installation should succeed'
        return @{ Home = $installHome; Output = $output }
    }
    finally {
        if ($null -eq $previousInstallHome) { Remove-Item Env:BOXLANG_INSTALL_HOME -ErrorAction SilentlyContinue } else { $env:BOXLANG_INSTALL_HOME = $previousInstallHome }
        $env:USERPROFILE = $previousUserProfile
        $env:PATH = $previousPath
        $env:TEMP = $previousTemp
        $env:TMP = $previousTmp
    }
}

Invoke-Test 'shows default Windows installation paths' {
    $output = Invoke-InstallerHelp
    Assert-Match ([regex]::Escape('C:\boxlang\bin\')) $output 'Default bin path is missing'
    Assert-Match ([regex]::Escape('C:\boxlang\lib\')) $output 'Default lib path is missing'
    Assert-Match ([regex]::Escape('C:\boxlang\home\')) $output 'Default home path is missing'
}

Invoke-Test 'honors BOXLANG_INSTALL_HOME' {
    $output = Invoke-InstallerHelp 'C:\boxlang-test-home'
    Assert-Match ([regex]::Escape('C:\boxlang-test-home\bin\')) $output 'Custom bin path is missing'
    Assert-Match ([regex]::Escape('C:\boxlang-test-home\lib\')) $output 'Custom lib path is missing'
}

Invoke-Test 'documents local artifact flags' {
    $output = Invoke-InstallerHelp
    foreach ($flag in @('--boxlang-path', '--miniserver-path', '--installer-scripts-path')) {
        Assert-Match ([regex]::Escape($flag)) $output "Help is missing $flag"
    }
}

Invoke-Test 'runs as a standard Windows user when requested' {
    if ($env:BOXLANG_EXPECT_STANDARD_USER -eq 'true') {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        Assert-True (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) 'Container test is running with administrator privileges'
    }
}

Invoke-Test 'installs local JAR artifacts and a script directory without downloads' {
    $root = New-TestRoot 'boxlang-local-jar'
    try {
        $boxlangJar = Join-Path $root 'boxlang.jar'
        $miniServerJar = Join-Path $root 'boxlang-miniserver.jar'
        Set-Content -Path $boxlangJar -Value 'boxlang jar' -Encoding ASCII
        Set-Content -Path $miniServerJar -Value 'miniserver jar' -Encoding ASCII
        $result = Invoke-LocalInstaller -Root $root -BoxLangPath $boxlangJar -MiniServerPath $miniServerJar -InstallerScriptsPath (New-TestInstallerScripts -Root (Join-Path $root 'scripts'))

        Assert-True (Test-Path (Join-Path $result.Home 'lib\boxlang.jar')) 'Local BoxLang JAR was not copied'
        Assert-True (Test-Path (Join-Path $result.Home 'lib\boxlang-miniserver.jar')) 'Local MiniServer JAR was not copied'
        $boxlangLauncher = Join-Path $result.Home 'bin\boxlang.bat'
        $miniServerLauncher = Join-Path $result.Home 'bin\boxlang-miniserver.bat'
        Assert-True (Test-Path $boxlangLauncher) 'Local BoxLang JAR launcher was not created'
        Assert-True (Test-Path $miniServerLauncher) 'Local MiniServer JAR launcher was not created'
        Assert-Match ([regex]::Escape((Join-Path $result.Home 'lib\boxlang.jar'))) (Get-Content $boxlangLauncher -Raw) 'BoxLang JAR launcher has the wrong JAR path'
        Assert-Match ([regex]::Escape((Join-Path $result.Home 'lib\boxlang-miniserver.jar'))) (Get-Content $miniServerLauncher -Raw) 'MiniServer JAR launcher has the wrong JAR path'
        Assert-True ($result.Output -notmatch 'Checking for CommandBox') 'CommandBox should not be checked when disabled'
        Assert-True ($result.Output -notmatch 'Skipping CommandBox installation') 'CommandBox skip should not be reported when disabled'
        Assert-True ($result.Output -notmatch 'You can install CommandBox later') 'CommandBox installation advice should not be reported when disabled'
		Assert-True ($result.Output -notmatch '(?m)^False$') 'Disabled CommandBox handling should not write False'
        $previousPath = $env:PATH
        try {
            $env:PATH = "$(New-TestJava -Root $root);$previousPath"
            Assert-Match 'BoxLang 1.0.0' (& $boxlangLauncher --version | Out-String) 'Local BoxLang JAR launcher did not run'
            Assert-Match 'BoxLang 1.0.0' (& $miniServerLauncher --version | Out-String) 'Local MiniServer JAR launcher did not run'
        }
        finally {
            $env:PATH = $previousPath
        }
        Assert-Match 'Installation verified successfully' $result.Output 'Local JAR installation was not verified'
    }
    finally {
        Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Invoke-Test 'installs local ZIP artifacts and a script ZIP without downloads' {
    $root = New-TestRoot 'boxlang-local-zip'
    try {
        $runtimeDirectory = Join-Path $root 'runtime'
        $runtimeBin = Join-Path $runtimeDirectory 'bin'
        New-TestInstallerScripts -Root $runtimeBin | Out-Null
        $boxlangZip = Join-Path $root 'boxlang.zip'
        $miniServerZip = Join-Path $root 'boxlang-miniserver.zip'
        Compress-Archive -Path (Join-Path $runtimeDirectory '*') -DestinationPath $boxlangZip
        Compress-Archive -Path (Join-Path $runtimeDirectory '*') -DestinationPath $miniServerZip
        $scriptsDirectory = New-TestInstallerScripts -Root (Join-Path $root 'scripts')
        $scriptsZip = Join-Path $root 'scripts.zip'
        Compress-Archive -Path (Join-Path $scriptsDirectory '*') -DestinationPath $scriptsZip
        $result = Invoke-LocalInstaller -Root $root -BoxLangPath $boxlangZip -MiniServerPath $miniServerZip -InstallerScriptsPath $scriptsZip

        Assert-True (Test-Path (Join-Path $result.Home 'bin\boxlang.bat')) 'BoxLang ZIP was not extracted'
        Assert-True (Test-Path (Join-Path $result.Home 'bin\boxlang-miniserver.bat')) 'MiniServer ZIP was not extracted'
        Assert-Match 'Installation verified successfully' $result.Output 'Local ZIP installation was not verified'
    }
    finally {
        Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Invoke-Test 'fails gracefully when the installation directory cannot be created' {
    $root = New-TestRoot 'boxlang-unwritable-home'
    $previousInstallHome = $env:BOXLANG_INSTALL_HOME
    $previousUserProfile = $env:USERPROFILE
    $previousPath = $env:PATH
    $previousTemp = $env:TEMP
    $previousTmp = $env:TMP
    try {
        $boxlangJar = Join-Path $root 'boxlang.jar'
        $miniServerJar = Join-Path $root 'boxlang-miniserver.jar'
        Set-Content -Path $boxlangJar -Value 'boxlang jar' -Encoding ASCII
        Set-Content -Path $miniServerJar -Value 'miniserver jar' -Encoding ASCII
        $scriptsDirectory = New-TestInstallerScripts -Root (Join-Path $root 'scripts')
        $env:BOXLANG_INSTALL_HOME = 'Z:\boxlang-test'
        $env:USERPROFILE = Join-Path $root 'user'
        $env:TEMP = Join-Path $root 'temp'
        $env:TMP = $env:TEMP
        New-Item -ItemType Directory -Path $env:USERPROFILE, $env:TEMP -Force | Out-Null
        $env:PATH = "$(New-TestJava -Root $root);$previousPath"
        $arguments = @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $installer,
            '--force', '--without-commandbox',
            '--boxlang-path', $boxlangJar,
            '--miniserver-path', $miniServerJar,
            '--installer-scripts-path', $scriptsDirectory
        )
        $output = & powershell.exe @arguments 2>&1 | Out-String
        Assert-Equal 1 $LASTEXITCODE 'Unwritable installation directory should fail'
        Assert-Match 'Cannot create the BoxLang installation directory' $output 'Installer did not report the directory creation failure'
        Assert-Match 'BOXLANG_INSTALL_HOME' $output 'Installer did not provide the writable-directory remediation'
    }
    finally {
        if ($null -eq $previousInstallHome) { Remove-Item Env:BOXLANG_INSTALL_HOME -ErrorAction SilentlyContinue } else { $env:BOXLANG_INSTALL_HOME = $previousInstallHome }
        $env:USERPROFILE = $previousUserProfile
        $env:PATH = $previousPath
        $env:TEMP = $previousTemp
        $env:TMP = $previousTmp
        Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Invoke-Test 'parses without syntax errors' {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($installer, [ref]$tokens, [ref]$errors) | Out-Null
    Assert-Equal 0 $errors.Count 'Installer has parser errors'
}

Complete-TestSuite
