# Check if the last argument is --local or --list
$LocalInstall = $false
$ListModules = $false

if ($args[-1] -eq "--local") {
	$LocalInstall = $true
	$args = $args[0..($args.Length - 2)]  # Remove --local from arguments
} elseif ($args[-1] -eq "--list") {
	$ListModules = $true
	$args = $args[0..($args.Length - 2)]  # Remove --list from arguments
}

if ($ListModules -and $args.Length -eq 0) {
	if (-not $Env:BOXLANG_HOME) {
		$Env:BOXLANG_HOME = Join-Path -Path "$Env:USERPROFILE" -ChildPath ".boxlang"
	}
	$ModulesHome = Join-Path -Path "$Env:BOXLANG_HOME" -ChildPath "modules"
	Write-Host -ForegroundColor Yellow "Installed OS BoxLang Modules ($ModulesHome):"
	Get-ChildItem -Path $ModulesHome -Directory | ForEach-Object {
		Write-Host -ForegroundColor Green "- $($_.Name)"
	}
	exit 0
}

$sanitized = $args |
	ForEach-Object {
		$a = $_ -split "@"

		[PSCustomObject]@{
			Name = $a[0];
			Version = if ($a[1]) { $a[1] } else { "latest" }
		}
	}

if ($null -eq $sanitized -or $sanitized.Length -eq 0) {
	Write-Host -ForegroundColor Red "You must provide at least one module to install."
	exit 1
}

function downloadModule($moduleName, $moduleVersion) {
	if ([string]::IsNullOrEmpty($moduleVersion) -or $moduleVersion -eq "latest") {
		Write-Host -ForegroundColor Yellow "No version provided, using latest from https://forgebox.io"
		$ForgeBoxResponse = Invoke-RestMethod -Uri "https://forgebox.io/api/v1/entry/$moduleName/latest" -Method Get
		if ($ForgeBoxResponse) {
			$ModuleDownloadUrl = "$($ForgeBoxResponse.data.downloadURL)"
		}
		else {
			Write-Host -ForegroundColor Red "No data received from https://forgebox.io/api/v1/entry/$moduleName/latest"
		}
	}
	else {
		$ModuleDownloadUrl = "https://downloads.ortussolutions.com/ortussolutions/boxlang-modules/$moduleName/$moduleVersion/$moduleName-$moduleVersion.zip"
	}

	# Set installation path based on local flag
	if ($LocalInstall) {
		$ModuleHome = Join-Path -Path (Get-Location) -ChildPath "boxlang_modules"
	}
	else {
		if (-not $Env:BOXLANG_HOME) {
			$Env:BOXLANG_HOME = Join-Path -Path "$Env:USERPROFILE" -ChildPath ".boxlang"
		}
		$ModuleHome = Join-Path -Path "$Env:BOXLANG_HOME" -ChildPath "modules"
	}

	$ModuleDestination = Join-Path -Path "$ModuleHome" -ChildPath "$moduleName@$moduleVersion"

	Write-Host -ForegroundColor Yellow "Please wait..."

	New-Item -Path "$ModuleHome" -ItemType "directory" -Force | Out-Null

	$ZipFileName = "$moduleName@$moduleVersion.zip"
	$ZipFileModulePath = Join-Path -Path $ModuleHome -ChildPath $ZipFileName

	Write-Host -ForegroundColor Blue "Downloading Module [$moduleVersion] from [$ModuleDownloadUrl]"
	Invoke-WebRequest -Uri $ModuleDownloadUrl -OutFile $ZipFileModulePath

	if (Test-Path -Path $ModuleDestination) {
		Remove-Item -Path $ModuleDestination -Recurse -Force
	}

	New-Item -Path "$ModuleDestination" -ItemType "directory" -Force | Out-Null
	Expand-Archive -Path $ZipFileModulePath -DestinationPath $ModuleDestination
	Remove-Item -Path $ZipFileModulePath -Force

	Write-Host -ForegroundColor Green "Successfully downloaded $moduleName"
}

function showGreeting() {
	Write-Host -ForegroundColor Green ''
	Write-Host -ForegroundColor Green '*************************************************************************'
	Write-Host -ForegroundColor Green 'Welcome to the BoxLang® Module Quick Installer'
	Write-Host -ForegroundColor Green '*************************************************************************'
	Write-Host -ForegroundColor Green 'This will download and install the requested module into:'
	if ($LocalInstall) {
		Write-Host -ForegroundColor Green "Local directory: $(Get-Location)\boxlang_modules"
	}
	else {
		Write-Host -ForegroundColor Green "BoxLang® HOME directory: [$Env:BOXLANG_HOME\modules]"
	}
	Write-Host -ForegroundColor Green '*************************************************************************'
	Write-Host -ForegroundColor Green 'You can also download the BoxLang® modules from https://forgebox.io'
	Write-Host -ForegroundColor Green '*************************************************************************'

	Write-Host -ForegroundColor Yellow "Please wait..."
}

function showCompleteMessage($modules) {
	Write-Host -ForegroundColor Green "BoxLang® Modules [$modules] installed to:"
	if ($LocalInstall) {
		Write-Host -ForegroundColor Green "$(Get-Location)\boxlang_modules"
	}
	else {
		Write-Host -ForegroundColor Green "$Env:BOXLANG_HOME\modules"
	}
	Write-Host -ForegroundColor Green ''
	Write-Host -ForegroundColor Green '*************************************************************************'
	Write-Host -ForegroundColor Green 'BoxLang® - Dynamic : Modular : Productive : https://boxlang.io'
	Write-Host -ForegroundColor Green '*************************************************************************'
	Write-Host -ForegroundColor Green "BoxLang® is FREE and Open-Source Software under the Apache 2.0 License"
	Write-Host -ForegroundColor Green "You can also buy support and enhanced versions at https://boxlang.io/plans"
	Write-Host -ForegroundColor Green '*************************************************************************'
	Write-Host -ForegroundColor Green "Copyright and Registered Trademarks of Ortus Solutions, Corp"
}

showGreeting

$sanitized | ForEach-Object {
	downloadModule $_.Name $_.Version
}

showCompleteMessage $args
