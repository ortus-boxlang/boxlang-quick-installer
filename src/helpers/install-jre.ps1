# PowerShell 5 has performance issues with progress bars, so suppress them
# PowerShell 7+ handles progress efficiently
if ($PSVersionTable.PSVersion.Major -le 5) {
    $ProgressPreference = 'SilentlyContinue'
} else {
    $ProgressPreference = 'Continue'
}

# Set the JRE version and download URL
$jreVersion = "21"
$jreURL = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.7%2B6/OpenJDK21U-jre_x64_windows_hotspot_21.0.7_6.zip"
$installPath = "C:\Program Files\Java\jre$jreVersion"

# Echo a nice announcement of what we're doing
Write-Host "🚀 Starting OpenJDK $jreVersion installation..." -ForegroundColor Green

# Clean up any existing installation first
if (Test-Path $installPath) {
    Write-Host "🗑️  Removing existing JRE installation at $installPath..." -ForegroundColor Yellow
    Remove-Item -Path $installPath -Recurse -Force -ErrorAction SilentlyContinue
}

# Download the JRE ZIP with progress tracking
$zipPath = "$env:TEMP\openjdk-$jreVersion.zip"

# Remove old download if it exists
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
}

Write-Host "⬇️  Downloading JRE $jreVersion..." -ForegroundColor Cyan

try {
    Invoke-WebRequest -Uri $jreURL -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
    Write-Host "✅ Download completed: $zipPath" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: Failed to download JRE. $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Prepare temp extract folder
$tempExtract = "$env:TEMP\jreExtract"
if (Test-Path $tempExtract) {
    Remove-Item $tempExtract -Recurse -Force
}
New-Item -ItemType Directory -Path $tempExtract | Out-Null

# Extract the ZIP
Write-Host "📦 Extracting OpenJDK $jreVersion..." -ForegroundColor Cyan
Expand-Archive -Path $zipPath -DestinationPath $tempExtract -Force

# Find the actual JRE folder inside the archive
$extractedDir = Get-ChildItem -Path $tempExtract | Where-Object { $_.PSIsContainer } | Select-Object -First 1

# Ensure parent directory exists
$parentPath = Split-Path -Path $installPath -Parent
if (-not (Test-Path $parentPath)) {
    Write-Host "📁 Creating directory: $parentPath" -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $parentPath -Force | Out-Null
}

# Clean old installation if it exists
if (Test-Path $installPath) {
    Write-Host "🧹 Clearing existing JRE installation..." -ForegroundColor Yellow
    Remove-Item -Path $installPath -Recurse -Force
}
Move-Item -Path $extractedDir.FullName -Destination $installPath

# Clean temporary files
Remove-Item $zipPath -Force
Remove-Item $tempExtract -Recurse -Force

# Set JAVA_HOME system environment variable
Write-Host "🔧 Setting JAVA_HOME to $installPath" -ForegroundColor Cyan
[System.Environment]::SetEnvironmentVariable("JAVA_HOME", $installPath, [System.EnvironmentVariableTarget]::Machine)

# Update system PATH
Write-Host "🛤️  Updating system PATH..." -ForegroundColor Cyan
$existingPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
$cleanPath = $existingPath -split ";" | Where-Object { $_ -notmatch "\\Java\\.*?\\bin" } | ForEach-Object { $_.Trim() }
$newPath = ($cleanPath + "$installPath\bin") -join ";"
[System.Environment]::SetEnvironmentVariable("Path", $newPath, [System.EnvironmentVariableTarget]::Machine)

# Verification
Write-Host "🔍 Verifying Java installation..." -ForegroundColor Cyan
try {
    & "$installPath\bin\java.exe" -version
} catch {
    Write-Host "❌ ERROR: Java did not install correctly." -ForegroundColor Red
    exit 1
}

Write-Host "✅ OpenJDK $jreVersion installation completed successfully!" -ForegroundColor Green