
Detailed Checks, Research, and Script Modifications 

From the research gathered from the original PowerShell script, this document reviews the changes with specific prompts using a separate AI model to review the script line-per-line and to check for an operational or security risks prior to deployment.  

The original script was designed to create a monthly restore point which entailed using Windows Task Scheduler to run a daily job to check for restore points to keep a fresh one automatically created per month. Research pointed out that a daily scheduled task running as SYSTEM could potentially cause false positive alerts in EDRs. To avoid that from happening along with the feasibility or creating monthly system restore points in modern times, changes were made to design a script that just creates a restore point to run as a job in an RMM when an applicable scenario applies.  

 

Restore Point Description 

The original description is: 

$Description = if ($env:RPDescription) { $env:RPDescription } else { "Datto RMM - Manual Restore Point" } 

 

This is an extremely long description. Windows may reject overly long descriptions depending on API limits. With special characters, that is generally safe. However, unusual Unicode or control characters could potentially cause restore point creation issues.  

 

 

 

 

 

With that being the case, I’m going to change it up a little bit with this:  

Description input: The optional RPDescription variable is cleaned (control and invisible characters removed; blank input falls back to a default) and limited to 64 characters, so Windows doesn’t reject or silently shorten it and break the success check. 

 

 

This reads the Datto variable and removes control and visible characters. The quotes around $env:RPDescription turn it into a string even if the variable doesn’t exist, so an unset variable becomes empty instead of causing an error.  

$Description = "$env:RPDescription" -replace '\p{C}', '' 

 

This removes leading and trailing spaces. 
$Description = $Description.Trim() 

 

If nothing is left, because the variable was blank or contained only junk characters, the default description is used. 
if (-not $Description) { $Description = "Datto RMM - Manual Restore Point" } 

 

If the description is longer than 64 characters, it keeps the first 64. The .Trim() at the end removes a trailing space if the cut lands right after a word.  
if ($Description.Length -gt 64) { $Description = $Description.Substring(0, 64).Trim() } 

 

Workstation Check: WMI failure handling 

 

 

 

 

This queries Windows Management Instrumentation (WMI/CIM) for operating system information. In a case where a given workstation has damaged WMI, the component would exit with “Not a Workstation (Server or DC detected.) That message would be an incorrect representation of the issue and would send a technician looking for an OS or device-classification problem instead of a WMI problem.  

To change that up, I’m going to go with the recommendation of protecting the command try/catch for better error logging. In this corrected block, the OS query is moved into a try/catch statement, stored in the $OS variable.  

-ErrorAction Stop is added so a WMI failure becomes a terminating error that try/catch can catch. The catch block outputs a specific message saying WMI may be damaged, includes Windows’ error text, and exits 1.  

The workstation check now runs only after the OS information was read successfully.  

 

 

 

Resize Shadow Storage 

In the original script there’s shadow copy I added shadow copy storage managing to address workstations that might be more limited on disk space. For drives that have anywhere from 60GB to 200GB of storage space, this shadow copy management solution only uses 5% of the disk space when a restore point is created.  

Upon further inspection this shadow storage resize command could delete existing restore points. If usage already exceeds 5%, Windows may immediately delete older restore points. Along with that 5% would be pretty insufficient and cause this quickly. That might not be enough space for the restore point.  

 

 

When the shadow storage limit is set below what C: is already using, Windows deletes the oldest shadow copies right away to fit under the new limit. Shadow storage holds all shadow copies on the volume, not just restore points, so the deletion could also remove Previous Versions data or snapshots kept by backup software.  

I did draft a safeguard to skip the resize when the usage was over 5%, but that meant the limit was skipped on exactly the machines using the most space. So, I decided to go with removing the shadow storage limit from the component directly.  

 

 

Reasoning:  

Windows already applies a default limit and deletes the oldest restore points automatically, so the disk usage bounded with the component.  

 

The limit couldn’t be applied safely to the machines where it would matter most.  

 

Changing a machine-wide storage setting falls outside the components single purpose, which is creating a restore point on demand. Storage policy, if ever needed, should be a separate and deliberate configuration.  

 

Removing it reduces complexity and drops extra WMI calls.  

 

Outcome:  

Finding accepted, and the feature was removed instead of patched. The component relies on Windows’ default shadow storage limit.  

Shadow storage: Not modified. The component relies on Windows default limit, which removes the oldest restore points automatically. Changing storage policy was out of scope for an on-demand component and risked deleting existing recovery data.  

 

Exit code 

The ending of the script uses  

exit $Result 

This returns the final status to the caller 

 

Likely values  

0 = Restore Point Created 

1 = Skipped 

1 = Error 

 

This helps automation systems to determine success or failure.  

So, here we have the same exit code for “skipped” and “failed” 

 

Findings: The component returned exit code 1 both when Windows skipped the restore point because of its 24-hour limit and when something actually failed. A RMM platform couldn’t tell those apart without reading the output text.  

Confirmed: A skip means a recent restore point already exists and nothing is broken. A failure means System Restore isn’t working. Those need different responses from a technician, but they produced the same exit code.  

Correction:  

Exit 0: restore point created and confirmed 

 

Exit 1: real failure (WMI error, System Restore blocked, creation failed). 

 

Exit 2: Skipped because of the 24-hour limit; the component reports the existing point’s name and time.  

 

The exit codes are documented in the scripts header comment.  

As a result, the exit code now tells a technician what the situation is.  

 

 

Listing existing restore points had no error handling 

Findings: $Before = @(Get-ComputerRestorePoint) had no explicit error handling. If WMI failed after the earlier OS check, the script could stop unexpectedly. Rated extremely unlikely, but it is suggested wrapping it in a try/catch for maximum robustness.  

 

 

 

 

 

 
