<#
    New-RestorePoint.ps1 - Datto RMM component (run on demand)

    Creates a System Restore point on C: before a risky change (driver update,
    software install, troubleshooting). Runs once and exits: no scheduled task,
    no files left on the endpoint.

    Optional Datto input variable:
        RPDescription (String) - e.g. "Ticket 1234 - before driver update"

    Exit codes: 0 = restore point created and verified
                1 = failed (WMI error, System Restore blocked, creation failed)
                2 = skipped by Windows' 24-hour limit (most recent point is reported)
#>

# Clean up the optional description: remove control/invisible characters and emoji,
# fall back to a default if nothing is left, and keep it within the 64-character limit
# so Windows doesn't reject or silently shorten it (which would break verification below).
$Description = "$env:RPDescription" -replace '\p{C}', ''
$Description = $Description.Trim()
if (-not $Description) { $Description = "Datto RMM - Manual Restore Point" }
if ($Description.Length -gt 64) { $Description = $Description.Substring(0, 64).Trim() }

# Workstations only (ProductType 1 = workstation, 2 = DC, 3 = server).
# If WMI/CIM is broken, fail with an accurate message; restore points depend on WMI anyway.
try {
    $OS = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
}
catch {
    Write-Output "Could not query the OS through WMI/CIM (WMI may be damaged): $($_.Exception.Message)"
    exit 1
}

if ($OS.ProductType -ne 1) {
    Write-Output "Not a workstation (Server or DC detected). Exiting."
    exit 1
}

try {
    Enable-ComputerRestore -Drive "C:\" -ErrorAction Stop
}
catch {
    Write-Output "Could not enable System Restore on C: (check Group Policy): $($_.Exception.Message)"
    exit 1
}

# Note the newest existing point so we can confirm a new one was actually created.
# -ErrorAction Stop is required: without it, a failure is non-terminating and catch never runs.
try {
    $Before = @(Get-ComputerRestorePoint -ErrorAction Stop)
}
catch {
    Write-Output "Unable to list existing restore points (WMI or System Restore problem): $($_.Exception.Message)"
    exit 1
}
$LastSeq = ($Before | Measure-Object -Property SequenceNumber -Maximum).Maximum
if (-not $LastSeq) { $LastSeq = 0 }

# Windows reports its 24-hour frequency limit as a WARNING, not an error,
# so capture warnings and verify the result instead of assuming success.
$CpWarn = $null
try {
    Checkpoint-Computer -Description $Description -RestorePointType MODIFY_SETTINGS `
        -ErrorAction Stop -WarningAction SilentlyContinue -WarningVariable CpWarn
}
catch {
    Write-Output "Failed to create restore point: $($_.Exception.Message)"
    exit 1
}

$New = Get-ComputerRestorePoint |
    Where-Object { $_.SequenceNumber -gt $LastSeq -and $_.Description -eq $Description }

if ($New) {
    Write-Output "SUCCESS: Created restore point '$Description' (sequence $($New.SequenceNumber))."
    $Result = 0
}
elseif ($CpWarn) {
    $Latest = $Before | Sort-Object SequenceNumber | Select-Object -Last 1
    Write-Output "SKIPPED: Windows allows one restore point per 24 hours."
    if ($Latest) {
        $LatestTime = [Management.ManagementDateTimeConverter]::ToDateTime($Latest.CreationTime)
        Write-Output "Most recent restore point: '$($Latest.Description)' created $LatestTime."
        Write-Output "Decide whether that point is recent enough before making changes."
    }
    else {
        Write-Output "Windows reported: $($CpWarn -join ' ')"
        Write-Output "No existing restore point could be found to report. Verify manually before making changes."
    }
    $Result = 2
}
else {
    Write-Output "ERROR: No error was reported, but no new restore point was found."
    $Result = 1
}

exit $Result