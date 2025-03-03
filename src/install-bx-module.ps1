
$sanitized = $args |
    ForEach-Object {
        $a = $_ -split "@"

        [PSCustomObject]@{
            Name = $a[ 0 ];
            Version = if( $a[1] ){ $a[1] } else { "latest" }
        }
    }

if( $null -eq $sanitized -or $sanitized.length -eq 0 ){
    Write-Host -ForegroundColor Red "You must provide at least one module to install."
    exit 1
}

function downloadModule( $moduleName, $moduleVersion ) {

    if ([string]::IsNullOrEmpty($moduleVersion) -or $moduleVersion -eq "latest" ){
        Write-Host -ForegroundColor Yellow "No version provided, using latest from https://forgebox.io"
        $ForgeBoxResponse = Invoke-RestMethod -Uri "https://forgebox.io/api/v1/entry/$moduleName/latest" -Method Get
        if ($ForgeBoxResponse){
            $ModuleDownloadUrl = "$($ForgeBoxResponse.data.downloadURL)"
        } else {
            Write-Host -ForegroundColor Red "No data received from https://forgebox.io/api/v1/entry/$moduleName/latest"
        }
    } else {
        $ModuleDownloadUrl = "https://downloads.ortussolutions.com/ortussolutions/boxlang-modules/$moduleName/$Version/$moduleName-$moduleVersion.zip"
    }

    if (!$Env:BOXLANG_HOME){
        $Env:BOXLANG_HOME = Join-Path -Path "$Env:USERPROFILE" -ChildPath ".boxlang"
    }

    $ModuleHome = Join-Path -Path "$Env:BOXLANG_HOME" -ChildPath "modules"
    $ModuleDestination = Join-Path -Path "$ModuleHome" -ChildPath "$moduleName@$moduleVersion"

    Write-Host -ForegroundColor Yellow "Please wait..."

    New-Item -Path "$ModuleHome" -ItemType "directory" -Force | Out-Null

    $ZipFileName = "$moduleName@$moduleVersion.zip"
    $ZipFileModulePath = Join-Path -Path $ModuleHome -ChildPath $ZipFileName

    Write-Host -ForegroundColor Blue "Downloading Module [$moduleVersion] from [$ModuleDownloadUrl]"
    Invoke-WebRequest -Uri $ModuleDownloadUrl -OutFile $ZipFileModulePath

    if (Test-Path -Path $ModuleDestination){
        Remove-Item -Path $ModuleDestination -Recurse -Force
    }

    New-Item -Path "$ModuleDestination" -ItemType "directory" -Force | Out-Null
    Expand-Archive -Path $ZipFileModulePath -DestinationPath $ModuleDestination
    Remove-Item -Path $ZipFileModulePath -Force

    Write-Host -ForegroundColor Green "Successfully downloaded $moduleName"
}

function showGreeting(){
    Write-Host -ForegroundColor Gree ''
    Write-Host -ForegroundColor Gree '*************************************************************************'
    Write-Host -ForegroundColor Gree 'Welcome to the BoxLang® Module Quick Installer'
    Write-Host -ForegroundColor Gree '*************************************************************************'
    Write-Host -ForegroundColor Gree 'This will download and install the requested module into you'
    Write-Host -ForegroundColor Gree "BoxLang® HOME directory at [$ModuleDestination]"
    Write-Host -ForegroundColor Gree '*************************************************************************'
    Write-Host -ForegroundColor Gree 'You can also download the BoxLang® modules from https://forgebox.io'
    Write-Host -ForegroundColor Gree '*************************************************************************'

    Write-Host -ForegroundColor Yellow "Please wait..."
}

function showCompleteMessage( $modules ){
    Write-Host -ForegroundColor Green "BoxLang® Modules [$modules] installed to [$Env:BOXLANG_HOME\modules]"
    Write-Host -ForegroundColor Green ''
    Write-Host -ForegroundColor Green '*************************************************************************'
    Write-Host -ForegroundColor Green 'BoxLang® - Dynamic : Modular : Productive : https://boxlang.io'
    Write-Host -ForegroundColor Green '*************************************************************************'
    Write-Host -ForegroundColor Green "BoxLang® is FREE and Open-Source Software under the Apache 2.0 License"
    Write-Host -ForegroundColor Green "You can also buy support and enhanced versions at https://boxlang.io/plans"
    Write-Host -ForegroundColor Green 'p.s. Follow us at https://twitter.com/ortussolutions.'
    Write-Host -ForegroundColor Green 'p.p.s. Clone us and star us at https://github.com/ortus-boxlang/boxlang'
    Write-Host -ForegroundColor Green 'Please support us via Patreon at https://www.patreon.com/ortussolutions'
    Write-Host -ForegroundColor Green '*************************************************************************'
    Write-Host -ForegroundColor Green "Copyright and Registered Trademarks of Ortus Solutions, Corp"
}

showGreeting

$sanitized | ForEach-Object {
    downloadModule $_.name $_.version
}

showCompleteMessage $args