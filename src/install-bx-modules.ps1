# Check if at least one argument is passed
if ($args.Count -eq 0){
    Write-Host -ForegroundColor Red "Usage: " $MyInvocation.MyCommand.Name "module1 module2 module3 ..."
    exit 1
}

# Install modules in parallel
Write-Host -ForegroundColor Green "Install the following modules: $args"
$jobs = @()
foreach ($module in $args){
    $job = Start-Job -ScriptBlock {
        param ($module)

        & "install-bx-module" $module
        Write-Host ""
        Write-Host "*************************************************************************"
        Write-Host ""
    } -ArgumentList $module


    $jobs += $job
}

# Wait for all jobs to finish
$jobs | ForEach-Object {
    Wait-Job -Job $_ | Out-Null
    Receive-Job -Job $_ | Out-Null
    Remove-Job -Job $_ | Out-Null
}

Write-Host -ForegroundColor Green "BoxLang® Modules [$args] installed to [$Env:BOXLANG_HOME\modules]"
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
