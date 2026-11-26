$LogFolder = "C:\ProgramData\CompanyName\Logs"

if (-not (Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

$TimeStamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LogFile = Join-Path $LogFolder "Health_$TimeStamp.log"

New-Item -Path $LogFile -ItemType File -Force | Out-Null

function Write-Log {
    param (
        [string]$Message
    )

    $Line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Add-Content -Path $LogFile -Value $Line
    Write-Output $Line
}

Write-Log "=================================================="
Write-Log "System Health Check Started"
Write-Log "Computer: $env:COMPUTERNAME"
Write-Log "=================================================="


# DISM
Write-Log ""
Write-Log "Starting DISM RestoreHealth..."
Write-Log "--- DISM Output Start ---"

$dismOutput = DISM.exe /Online /Cleanup-Image /RestoreHealth 2>&1

$dismOutput | ForEach-Object { 
    Add-Content -Path $LogFile -Value $_
}

Write-Log "--- DISM Output End ---"

$DismExitCode = $LASTEXITCODE

if ($DismExitCode -ne 0) {
    Write-Log "[WARNING] DISM returned exit code $DismExitCode"
}

Write-Log "DISM completed with exit code $DismExitCode"

# SFC
Write-Log ""
Write-Log "Starting SFC Scan..."
Write-Log "--- SFC Output Start ---"

$sfcOutput = SFC.exe /Scannow 2>&1

$sfcOutput | ForEach-Object {
    Add-Content -Path $LogFile -Value $_
}

Write-Log "--- SFC Output End ---"

$SfcExitCode = $LASTEXITCODE

if ($SfcExitCode -ne 0) {
    Write-Log "[WARNING] SFC returned exit code $SfcExitCode"
}

Write-Log "SFC completed with exit code $SfcExitCode"

# Final status
if (($DismExitCode -ne 0) -or ($SfcExitCode -ne 0)) {
    $Result = "FAILED"
    Write-Log "[FAILED] One or more health checks reported errors."
}
else {
    $Result = "PASSED"
    Write-Log "[PASSED] All health checks completed successfully."
}

# Summary
Write-Log ""
Write-Log "================ SUMMARY ================"
Write-Log "Overall Result: $Result"
Write-Log "DISM Exit Code: $DismExitCode"
Write-Log "SFC Exit Code: $SfcExitCode"
Write-Log "Log saved to: $LogFile"
Write-Log "========================================="

if ($Result -eq "FAILED") {
    exit 1
}

exit 0



