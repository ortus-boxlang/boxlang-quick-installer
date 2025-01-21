

$requiredJavaVersion = 21
$installedJavaVersion = $null
$bxName = "BoxLang" + [char]0x00A9;

$TARGET_VERSION = "latest"
$DOWNLOAD_URL = ""

if ( $null -ne $env:BOXLANG_TARGET_VERSION ) {
    $TARGET_VERSION = $env:BOXLANG_TARGET_VERSION
}

$SNAPSHOT_URL = "https://downloads.ortussolutions.com/ortussolutions/boxlang/boxlang-snapshot.zip"
$SNAPSHOT_URL_MINISERVER = "https://downloads.ortussolutions.com/ortussolutions/boxlang-runtimes/boxlang-miniserver/boxlang-miniserver-snapshot.zip"
$LATEST_URL = "https://downloads.ortussolutions.com/ortussolutions/boxlang/boxlang-latest.zip"
$LATEST_URL_MINISERVER = "https://downloads.ortussolutions.com/ortussolutions/boxlang-runtimes/boxlang-miniserver/boxlang-miniserver-latest.zip"
$VERSIONED_URL = "https://downloads.ortussolutions.com/ortussolutions/boxlang/${TARGET_VERSION}/boxlang-${TARGET_VERSION}.zip"
$VERSIONED_URL_MINISERVER = "https://downloads.ortussolutions.com/ortussolutions/boxlang-runtimes/boxlang-miniserver/${TARGET_VERSION}/boxlang-miniserver-${TARGET_VERSION}.zip"
$destinationFolder = "c:\boxlang"
$DESTINATION_LIB = "$destinationFolder\lib"
$DESTINATION_BIN = "$destinationFolder\bin"

$ProgressPreference = 'SilentlyContinue'

if ($TARGET_VERSION -eq "snapshot") {
    $DOWNLOAD_URL = $SNAPSHOT_URL
    $DOWNLOAD_URL_MINISERVER = $SNAPSHOT_URL_MINISERVER
}
elseif ($TARGET_VERSION -eq "latest" ) {
    $DOWNLOAD_URL = $LATEST_URL
    $DOWNLOAD_URL_MINISERVER = $LATEST_URL_MINISERVER
}
else {
    $DOWNLOAD_URL = $VERSIONED_URL
    $DOWNLOAD_URL_MINISERVER = $VERSIONED_URL_MINISERVER
}

try {
    $javaVersion = java --version | Select-String -Pattern "\d+\.\d+\.\d+" | Select-Object -First 1

    if ( $null -eq $javaVersion ) {
        Write-Host "You must have Java $requiredJavaVersion or higher installed"
        exit
    }

    $javaVersion -match "(\d+)\.\d+\.\d+"
    $installedJavaVersion = $matches.1

    if ( [convert]::ToInt32($installedJavaVersion, 10) -lt [convert]::ToInt32($requiredJavaVersion, 10 ) ) {
        Write-Host "You must have Java $requiredJavaVersion or higher installed"
        exit
    }
}
catch {

}

# Tell them where we will install
Write-Host -ForegroundColor Green ''
Write-Host -ForegroundColor Green '*************************************************************************'
Write-Host -ForegroundColor Green "Welcome to the $bxName Quick Installer"
Write-Host -ForegroundColor Green "*************************************************************************"
Write-Host -ForegroundColor Green "This will download and install the latest version of $bxName and the"
Write-Host -ForegroundColor Green "$bxName MiniServer into your system."
Write-Host -ForegroundColor Green "*************************************************************************"
Write-Host -ForegroundColor Green "You can also download the $bxName runtimes from https://boxlang.io"
Write-Host -ForegroundColor Green "*************************************************************************"

Write-Host -ForegroundColor Green "Downloading $bxName [$TARGET_VERSION] from [$DOWNLOAD_URL]"
Write-Host -ForegroundColor Green "Please wait..."

$tmp = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "/boxlang"
$destinationFolder = "c:\boxlang"

New-Item -Type Directory -Path $tmp -Force | Out-Null
New-Item -Type Directory -Path $destinationFolder -Force | Out-Null

# download boxlang
Remove-Item -Path $tmp\boxlang.zip -ErrorAction SilentlyContinue -Force
Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $tmp\boxlang.zip

# download miniserver
Remove-Item -Path $tmp\boxlang-miniserver.zip -ErrorAction SilentlyContinue -Force
Invoke-WebRequest -Uri $DOWNLOAD_URL_MINISERVER -OutFile $tmp\boxlang-miniserver.zip

write-host $tmp

Write-Host -ForegroundColor Green "BoxLang downloaded to [$tmp\boxlang] continuing installation"

Write-Host -ForegroundColor Green "Unzipping BoxLang"
Expand-Archive -Path $tmp\boxlang.zip -DestinationPath $destinationFolder -ErrorAction SilentlyContinue

Write-Host -ForegroundColor Green "Unzipping BoxLang MiniServer"
Expand-Archive -Path $tmp\boxlang-miniserver.zip -DestinationPath $destinationFolder -ErrorAction SilentlyContinue

try {
    Remove-Item -Force -ErrorAction SilentlyContinue -Path $destinationFolder\bin\bx.bat | Out-Null
    New-Item -ItemType SymbolicLink -Target $destinationFolder\bin\boxlang.bat -Path $destinationFolder\bin\bx.bat | Out-Null
    
    Remove-Item -Force -ErrorAction SilentlyContinue -Path $destinationFolder\bin\bx-miniserver.bat | Out-Null
    New-Item -ItemType SymbolicLink -Target $destinationFolder\bin\boxlang-miniserver.bat -Path $destinationFolder\bin\bx-miniserver.bat | Out-Null
}
catch {
    Write-Host -ForegroundColor Red "Oh no! We weren't able to setup symlinks for the executables."
    Write-Host -ForegroundColor Red "BoxLang will still run but you will not have the 'bx' and 'bx-miniserver' aliases."
}

Write-Host -ForegroundColor Green "Adding BoxLang to your users' path variable"
[Environment]::SetEnvironmentVariable(
    "Path",
    [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User) + ";$destinationFolder\bin",
    [EnvironmentVariableTarget]::User) | Out-Null

Write-Host -ForegroundColor Green "Cleaning up..."
Remove-Item -Force -ErrorAction SilentlyContinue -Path $tmp\boxlang | Out-Null
Remove-Item -Force -ErrorAction SilentlyContinue -Path $destinationFolder\bin\boxlang | Out-Null
Remove-Item -Force -ErrorAction SilentlyContinue -Path $destinationFolder\bin\boxlang-miniserver | Out-Null

Write-Host -ForegroundColor Green "Testing BoxLang..."
boxlang --version

Write-Host -ForegroundColor Green ''
Write-Host -ForegroundColor Green "$bxName Binaries are now installed to [$DESTINATION_BIN]"
Write-Host -ForegroundColor Green "$bxName JARs are now installed to [$DESTINATION_LIB]"
Write-Host -ForegroundColor Green "$bxName Home is now set to [~/.boxlang]"
Write-Host -ForegroundColor Green ''
Write-Host -ForegroundColor Green 'Your [BOXLANG_HOME] is set by default to your user home directory.'
Write-Host -ForegroundColor Green 'You can change this by setting the [BOXLANG_HOME] environment variable in your shell profile'
Write-Host -ForegroundColor Green 'Just copy the following line to override the location if you want'
Write-Host -ForegroundColor Green ''
Write-Host -ForegroundColor Green "`$env:BOXLANG_HOME=/new/home"
Write-Host -ForegroundColor Green ''
Write-Host -ForegroundColor Green "You can start a MiniServer by running: boxlang-miniserver"
Write-Host -ForegroundColor Green '*************************************************************************'
Write-Host -ForegroundColor Green "$bxName - Dynamic : Modular : Productive : https://boxlang.io"
Write-Host -ForegroundColor Green '*************************************************************************'
Write-Host -ForegroundColor Green "$bxName is FREE and Open-Source Software under the Apache 2.0 License"
Write-Host -ForegroundColor Green "You can also buy support and enhanced versions at https://boxlang.io/plans"
Write-Host -ForegroundColor Green 'p.s. Follow us at https://twitter.com/ortussolutions.'
Write-Host -ForegroundColor Green 'p.p.s. Clone us and star us at https://github.com/ortus-boxlang/boxlang'
Write-Host -ForegroundColor Green 'Please support us via Patreon at https://www.patreon.com/ortussolutions'
Write-Host -ForegroundColor Green '*************************************************************************'
Write-Host -ForegroundColor Green "Copyright and Registered Trademarks of Ortus Solutions, Corp"