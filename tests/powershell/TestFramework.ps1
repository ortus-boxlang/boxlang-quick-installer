Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Initialize-TestSuite {
    param([string]$Name)

    $global:TestSuiteName = $Name
    $global:TestPassed = 0
    $global:TestFailed = 0
    Write-Host "Running $Name"
}

function Invoke-Test {
    param(
        [string]$Name,
        [scriptblock]$ScriptBlock
    )

    try {
        & $ScriptBlock
        $global:TestPassed++
        Write-Host "PASS: $Name" -ForegroundColor Green
    }
    catch {
        $global:TestFailed++
        Write-Host "FAIL: $Name" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message)

    if ($Expected -ne $Actual) {
        throw "$Message. Expected: '$Expected'. Actual: '$Actual'."
    }
}

function Assert-True {
    param($Value, [string]$Message)

    if (-not $Value) {
        throw $Message
    }
}

function Assert-Match {
    param([string]$Pattern, [string]$Actual, [string]$Message)

    if ($Actual -notmatch $Pattern) {
        throw "$Message. Pattern '$Pattern' was not found."
    }
}

function Import-ScriptFunctions {
    param(
        [string]$Path,
        [string[]]$Names
    )

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        throw "Cannot import functions from ${Path}: $($parseErrors[0].Message)"
    }

    $definitions = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $Names -contains $node.Name
    }, $true) | Sort-Object { $_.Extent.StartOffset }

    foreach ($definition in $definitions) {
        $functionText = $definition.Extent.Text -replace '^function\s+([^\s{]+)', 'function global:$1'
        Invoke-Expression $functionText
    }
}

function Complete-TestSuite {
    Write-Host "Passed: $global:TestPassed"
    Write-Host "Failed: $global:TestFailed"
    if ($global:TestFailed -gt 0) {
        throw "$global:TestSuiteName failed."
    }
}
