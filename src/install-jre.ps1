# Suppress progress bar for Invoke-WebRequest
$ProgressPreference = 'SilentlyContinue'

# Set the JRE version and download URL
$jreVersion = "21"
# UPDATE AS NEEDED
$jreURL = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.7%2B6/OpenJDK21U-jre_x64_windows_hotspot_21.0.7_6.zip"
$installPath = "C:\Program Files\Java\jdk$jreVersion"

# Download the JRE
Write-Host "Downloading JRE $jreVersion..."
try{
    Invoke-WebRequest -Uri $jreURL -OutFile "$env:TEMP\openjdk-$jreVersion.zip"
} catch {
    Write-Host "Failed to download JRE. Please check the URL."
    exit 1
}

# Create the installation directory if it doesn't exist
if (-Not (Test-Path -Path $installPath)) {
    New-Item -ItemType Directory -Path $installPath
}

# Check if the installation path  already exists and overwrite it
if (Test-Path -Path $installPath) {
    Write-Host "Clearing existing JRE installation..."
    Remove-Item -Path $installPath -Recurse -Force
    New-Item -ItemType Directory -Path $installPath
}

# Extract the downloaded zip file to the installation path
Write-Host "Extracting OpenJDK $jreVersion..."
Expand-Archive -Path "$env:TEMP\openjdk-$jreVersion.zip" -DestinationPath $installPath

# Set the JAVA_HOME environment variable
Write-Host "Setting JAVA_HOME..."
[System.Environment]::SetEnvironmentVariable("JAVA_HOME", $installPath, [System.EnvironmentVariableTarget]::Machine)

# Update the PATH environment variable
$path = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
if ( $path -notmatch [regex]::Escape("$installPath\bin") ) {
    Write-Host "Updating PATH..."
    $newPath = "$path;$installPath\bin"
    [System.Environment]::SetEnvironmentVariable("Path", $newPath, [System.EnvironmentVariableTarget]::Machine)
}

# Clean up the downloaded zip file
Write-Host "Cleaning up..."
Remove-Item "$env:TEMP\openjdk-$jreVersion.zip" -Force

Write-Host "OpenJDK $jreVersion installation completed."