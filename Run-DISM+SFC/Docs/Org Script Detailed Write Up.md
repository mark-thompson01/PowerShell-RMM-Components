# Detailed Checks, Research, and Script Modifications

Previously I started using Microsoft Copilot to review Claude generated PowerShell scripts to practice leveraging more than one AI model to check vet generated PowerShell scripts from Claude. For this script, I'm using Google AI mode to review and gain exposure with exercising this leveraging that particular AI model. 


## 1. No Log Rotation

### Original 

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
$KeepCount = 10<br>

Get-ChildItem -Path $LogFolder -Filter "Health_*.log -File |<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Sort-Object LastWriteTime -Descending |<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Select-Object -Skip $KeepCount |<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Remove-Item -Force -ErrorAction SilentlyContinue

#### Placement:
After the log folder is confirmed to exist, before the new log file is created. 

#### Design Notes:

> <strong>-Filter "Health_*.log"</strong>: Limits cleanup to the scripts own logs, so other tools writing to the same shared folder are never touched.

> <strong>-ErrorAction SilentlyContinue</strong>: Keeps a locked or in-use file from stopping the health check itself.

> <strong>$KeepCount</strong>: A variable at the top of the block, so retention can be changed without editing the logic.  

