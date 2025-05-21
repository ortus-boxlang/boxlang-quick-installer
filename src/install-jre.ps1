# Suppress progress bar for Invoke-WebRequest
$ProgressPreference = 'SilentlyContinue'

# Set the JRE version and download URL
$jreVersion = "21"
$jreURL = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.7%2B6/OpenJDK21U-jre_x64_windows_hotspot_21.0.7_6.zip"
$installPath = "C:\Program Files\Java\jre$jreVersion"

# Download the JRE ZIP
$zipPath = "$env:TEMP\openjdk-$jreVersion.zip"
Write-Host "Downloading JRE $jreVersion..."
try {
    Invoke-WebRequest -Uri $jreURL -OutFile $zipPath
} catch {
    Write-Host "ERROR: Failed to download JRE. $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Prepare temp extract folder
$tempExtract = "$env:TEMP\jreExtract"
if (Test-Path $tempExtract) {
    Remove-Item $tempExtract -Recurse -Force
}
New-Item -ItemType Directory -Path $tempExtract | Out-Null

# Extract the ZIP
Write-Host "Extracting OpenJDK $jreVersion..."
Expand-Archive -Path $zipPath -DestinationPath $tempExtract -Force

# Find the actual JRE folder inside the archive
$extractedDir = Get-ChildItem -Path $tempExtract | Where-Object { $_.PSIsContainer } | Select-Object -First 1

# Clean old installation if it exists
if (Test-Path $installPath) {
    Write-Host "Clearing existing JRE installation..."
    Remove-Item -Path $installPath -Recurse -Force
}
Move-Item -Path $extractedDir.FullName -Destination $installPath

# Clean temporary files
Remove-Item $zipPath -Force
Remove-Item $tempExtract -Recurse -Force

# Set JAVA_HOME system environment variable
Write-Host "Setting JAVA_HOME to $installPath"
[System.Environment]::SetEnvironmentVariable("JAVA_HOME", $installPath, [System.EnvironmentVariableTarget]::Machine)

# Update system PATH
Write-Host "Updating system PATH..."
$existingPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
$cleanPath = $existingPath -split ";" | Where-Object { $_ -notmatch "\\Java\\.*?\\bin" } | ForEach-Object { $_.Trim() }
$newPath = ($cleanPath + "$installPath\bin") -join ";"
[System.Environment]::SetEnvironmentVariable("Path", $newPath, [System.EnvironmentVariableTarget]::Machine)

# Verification
Write-Host "Verifying Java installation..."
try {
    & "$installPath\bin\java.exe" -version
} catch {
    Write-Host "ERROR: Java did not install correctly." -ForegroundColor Red
    exit 1
}

Write-Host "✅ OpenJDK $jreVersion installation completed successfully." -ForegroundColor Green