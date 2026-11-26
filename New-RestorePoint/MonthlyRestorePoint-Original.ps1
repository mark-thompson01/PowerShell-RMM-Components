$TaskName = "NiteIze - Monthly Restore Point"
$ScriptFolder = "C:\ProgramData\NiteIze\RestorePoints"
$LogFolder = "$ScriptFolder\Logs"
$ScriptPath = "$ScriptFolder\MonthlyRestorePoint.ps1"

Write-Output "Starting Monthly Restore Point task deployment..."

# Check Operating System
$OS = Get-CimInstance Win32_OperatingSystem

if ($OS.ProductType -ne 1) {
    Write-Output "Windows Server detected. Exiting."
    exit 1
}

# Verify Required Cmdlets
if (-not (Get-Command Checkpoint-Computer -ErrorAction SilentlyContinue)) {
    Write-Output "Checkpoint-Computer cmdlet not available."
    exit 1
}

if (-not (Get-Command Enable-ComputerRestore -ErrorAction SilentlyContinue)) {
    Write-Output "Enable-ComputerRestore cmdlet not available."
    exit 1
}

# Verify C: Exists
if (-not (Test-Path "C:\")) {
    Write-Output "System drive C: not found."
    exit 1
}

# Enable System Restore
try {
    Enable-ComputerRestore -Drive "C:\" -ErrorAction Stop
    Write-Output "System Restore enabled."
}
catch {
    Write-Output "Enable-ComputerRestore returned:"
    Write-Output $_.Exception.Message
}

# Verify System Restore Status
try {
    $RestoreSettings = Get-CimInstance -Namespace root/default -ClassName SystemRestoreConfig -ErrorAction Stop


    Write-Output "System restore maximum storage:
$($RestoreSettings.DiskPercent)%"
}
catch {
    Write-Output "Unable to verify System Restore configuration."
    exit 1
}

# Create Working Directories
New-Item -Path $ScriptFolder -ItemType Directory -Force | Out-Null
New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null


# Create initial restore point to validate functionality
Write-Output "Creating initial restore point..."

try {
    
    $Description = "Initial Restore Point - Datto Deployment"

    Checkpoint-Computer -Description $Description -RestorePointType MODIFY_SETTINGS -ErrorAction Stop

    Write-Output "Initial restore point created successfully."
}
catch {
    
    Write-Output "Failed to create initial restore point."
    Write-Output $_.Exception.Message
    Write-Output "Continuing with scheduled task deployment."

   
}

# Create Monthly Restore Point Script
$RestorePointScript = @'
$LogFile = "C:\ProgramData\NiteIze\RestorePoints\Logs\MonthlyRestorePoint.log"

if ((Get-Date).Day -ne 1) {
    exit 0
}

try {

    $Description = "Monthly Restore Point - $(Get-Date -Format ''yyyy-MM-dd'')"

    Add-Content -Path $LogFile -Value "$(Get-Date) Starting restore point creation."

    Checkpoint-Computer -Description $Description -RestorePointType MODIFY_SETTINGS -ErrorAction Stop

    Add-Content -Path $LogFile -Value "$(Get-Date) Successfully created restore point."
}
catch {
    Add-Content -Path $LogFile -Value "$(Get-Date) ERROR: $($_.Exception.Message)"

    exit 1
}
'@

$RestorePointScript | Set-Content -Path $ScriptPath -Force

# Create Scheduled Task 

Write-Output "Creating scheduled task..."

$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""

$Trigger = New-ScheduledTaskTrigger -Daily -At 12:00PM

$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null

Write-Output "Scheduled task registered."



# Verify Registration
$Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if (-not $Task) {
    Write-Output "Failed to create scheduled task."
    exit 1
}

Write-Output "Task Next Run Time: $((Get-ScheduledTaskInfo -TaskName $TaskName).NextRunTime)"


# Success
Write-Output "Monthly Restore Point task successfully configured."
exit 0

