# Detailed Checks, Research, and Script Modifications

Previously I started using Microsoft Copilot to review Claude generated PowerShell scripts to practice leveraging more than one AI model to check vet generated PowerShell scripts from Claude. For this script, I'm using Google AI mode to review and gain exposure with exercising this leveraging that particular AI model. 


## 1. Review Item: No Log Rotation

### Original 
$LogFolder = "C:\ProgramData\CompanyName\Logs"<br>
if (-not (Test-Path $LogFolder)) {<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null<br>
}

$TimeStamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss"<br>
$LogFile   = Join-Path $LogFolder "Health_$TimeStamp.log"

New-Item -Path $LogFile -ItemType File -Force | Out-Null

#### Finding:
Every run creates a new timestamped log file (Health_yyyy-MM-dd-mm-ss.log), and nothing ever removes old logs from previous runs. Over months or years across many endpoints, logs would keep piling up in C:\ProgramData\CompanyName\Logs unless something outside the script cleaned them up.

#### Assessment: 
Valid concern, but low severity. Each log is small, and a maintenance script like this runs on a weekly or monthly schedule, so disk usage on a single machine would take years to matter. I addressed it anyway because a script shouldn't leave behind files it never cleans up, and because cleanup should live in the script itself, not in a separate external process. 

#### Decision: 
Add a block that does count-based retention, keeping the 10 most recent logs. 

#### Change Implemented: 
$LogFolder = "C:\ProgramData\CompanyName\Logs"<br>
if (-not (Test-Path $LogFolder)) {<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null<br>
}<br>
############# Log retention - keep the most recent runs, remove older logs<br>
$KeepCount = 10<br>

Get-ChildItem -Path $LogFolder -Filter "Health_*.log -File |<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Sort-Object LastWriteTime -Descending |<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Select-Object -Skip $KeepCount |<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Remove-Item -Force -ErrorAction SilentlyContinue

$TimeStamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss"<br>
$LogFile   = Join-Path $LogFolder "Health_$TimeStamp.log"

New-Item -Path $LogFile -ItemType File -Force | Out-Null

#### Placement:
After the log folder is confirmed to exist, before the new log file is created. 

#### Design Notes:

> <strong>-Filter "Health_*.log"</strong>: Limits cleanup to the scripts own logs, so other tools writing to the same shared folder are never touched.

> <strong>-ErrorAction SilentlyContinue</strong>: Keeps a locked or in-use file from stopping the health check itself.

> <strong>$KeepCount</strong>: A variable at the top of the block, so retention can be changed without editing the logic.

<br>

## 2. Review Item: DISM Progress Bar Clutter

### Original

Write-Log ""
Write-Log "Starting DISM RestoreHealth..."
Write-Log "--- DISM Output Start ---"

$dismOutput = DISM.exe /Online /Cleanup-Image /RestoreHealth 2>&1

$dismOutput | ForEach-Object {
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Add-Conent -Path $LogFile -Value $_
}

Write-Log "--- DISM Output End ---"

$DismExitCode = $LASTEXITCODE

if ($DismExitCode -ne 0) {
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Write-Log "[WARNING] DISM returned exit $DismExitCode"
}

Write-Log "DISM completed with exit code $DismExitCode"


### Finding:
The DISM output was collected into a variable and written to the log after the command finished. Because DISM's progress bar <strong>( [=== 20.0% ===[ )</strong> is redrawn in place on a console, redirecting it turns every update in a separate line, which buried the useful output in noise. Output also didn't appear until DISM was done. 

### Assessment:
Valid. The log clutter makes the log harder to review when you're troubleshooting, which is the whole reason the log exits. Missing live progress matters less, because the script it meant to run unattended. 

### Change Implemented:
* Piped DISM output line by line instead of buffering it in a variable, so output streams to the console and log as it's produced.
* Added a regex filter ($ProgressPattern) that removes progress-bar lines and black lines before logging.
* Moved $DismExitCode = $LASTEXITCODE to directly after the DISM call, so no later command can change it before it's captured

### Design notes:
* The filter only removes lines made up entirely of progress-bar segments. Any line with real text is kept.
* DISM keeps its own full log at <strong>C:\Windows\Logs\DISM\dism.log, so nothing diagnostic is lost by filtering the console output.



