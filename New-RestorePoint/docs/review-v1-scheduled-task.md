Detailed Checks, Research, and Script Modifications 

I started out with an original script leveraging generative AI via Claude to create a PowerShell script that sets up a monthly re-occurring Windows System Restore point being created. Carefully reviewing each piece of the script line per to line prior to deployment to catch any operational and security flaws, conduct research on the findings, and make necessary changes where feasible.  

The following outlines the findings and research conducted from the original generated script and recorded considerations and changes made along the way to change and build on the original drafted script.  

 

Enabling System Restore Can Consume Disk Space 

The original script doesn’t manage shadow copy storage. Once System Restore is enabled, Windows allocations shadow storage for restore points, increasing disk usage with shadow copies consuming multiple GB over time. When it comes to low-storage devices such as 64GB thin clients, embedded systems, kiosks, etc., this can add up quickly.  

Valid operational concern, though “multiple GB over time” does make it sound worse than it is.  

How shadow storage works: 

It’s a cap, not an upfront reservation: Enabling System Restore does not consume disk space right away. The disk space is used only as restore points are created.  

 

Shadow Storage is already limited by default: Windows sets a maximum, usually a few percent on the drive. When the limit is reached, Windows deletes the oldest restore points automatically, so usage never keeps growing.  

 

On a 200 GB drive with 60 GB free, even a 5% default is about 10 Gb at most. That’s noticeable but not dangerous.  

 

With that in mind, setting an explicit cap is still a good idea, because then you choose the limit instead of the Windows default. It only takes a few lines.  

Add the end of the script, I’m going to add this section that caps shadow storage of 5% of a given C: drive per endpoint.  

 

Shadow storage cap (5% OF C:) 

What it controls: Restore points are stored as Volume Shadow Copies in a reserved area of C:, called shadow storage. The script now sets the maximum size of that area to 5% of the drive.  

 

It’s a maximum, not a reservation: No space is taken up front. Space is used only as restore points are created, up to the 5% limit.  

 

What happens at the limit: Windows deletes the oldest restore points to make room for new ones. Disk usage stays bounded and can’t keep growing.  

 

Why a percentage instead of a fixed size: The limit scales with the drive. A 200GB drive allows about 10 GB, and a 1 TB drive allows about 50 GB. Smaller drives keep a small footprint, and larger drives can hold more restore points.  

 

Why it runs after the first restore point: The shadow storage link for C: may not exist until System Restore has created a point, so setting the limit earlier could fail.  

 

If setting the limit fails: The deployment still succeeds and logs a warning. Windows default limit still applies, so disk usage is still bounded.  

 

Side effect: If C: is already using more than 5% for shadow copies, Windows deletes the oldest copies right away to fit under the new limit.  

 

How to check it: Run vssadmin list shadowstorage /for=c: and confirm that “Maximum Shadow Copy Storage space” shows the size followed by “(5%)”. The script also prints this in Datto’s job output.  

 

 

 

ExecutionPolicy Bypass Running as SYSTEM 

The original script runs this to create the first restore point: 

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath 

 

The Risk: This is a common security review finding. Because the scheduled task runs as: 

SYSTEM 

RunLevel Highest 

Any modifications of  

C:\ProgramFiles\NiteIze\RestorePoints\MonthlyRestorePoint.ps1 

Would execute with full SYSTEM privileges.  

With that being said, there are some mitigating factors with the script already being stored under Program Files. Program Files is ACL protected: 

BUILTIN\Users = Read 

Administrators = Modify 

SYSTEM = Full 

With this in place, standard users generally cannot modify it.  

 

 

But there are still some concerns here, because an attacker who already obtains:  

Local Administrator 

RMM compromise 

Privileged service compromise 

Can replace the script and gain persistence through the scheduled task.  

 

Now, the –ExecutionPolicy Bypass combined with SYSTEM is one of the first things a security-minded reviewer would notice. At the same time, ExecutionPolicy Bypass is a standard for RMM-deployed scripts. Execution policy in itself isn’t a security boundary. The script is protected by Program Files permissions instead. Anyone with the ability to replace it already has admin-level access, so the task adds no new exposure because the attack scenario described already requires full control. Someone with local admin, a compromised RMM, or a compromised privileged service already can run anything as SYSTEM and can create their own scheduled tasks for persistence. In that case, swapping out the script would give an attacker nothing they didn’t already have. Code signing was considered in this scenario but not justified for a single script.  

Scheduled Task Persistence 

The script creates are persisting scheduled task under the name of Monthly Restore Point running daily as SYSTEM. 

Which brings a security review concern as many EDRs, and auditors treat this as a persistence mechanism.  

SYSTEM Scheduled Task + PowerShell + ExecutionPolicy Bypass 

 

 

 

While the script is legitimate, it could generate: 

Defender Advanced Hunting alerts 

CrowdStrike detections 

SentinelOne investigations 

SOC review findings  

 

A SYSTEM scheduled task that launches PowerShell with –ExecutionPolicy Bypass is exactly the pattern behavioral detection looks for, because real malware uses the same setup to persist. Whether an EDR flags it is dependent on given policies that are set in these platforms and worth planning for.  

Datto RMM runs PowerShell as SYSTEM all the time without triggering S1. That’s usually because the Datto agent is excluded or trusted in EDRs like S1. The scheduled task in the script wouldn’t fall under that, because it’s launched by Windows Task Scheduler, not by the Datto agent, where S1 sees a different chain of processes.  

Changes worth making: 

Use the full path to PowerShell, as suggested by MS Copilot: C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe. It removes any ambiguity about which executable runs and makes the activity cleaner in EDR logs. 

 

Put the task in a named folder and give it a description: For example, \<CompanyName>\ with the description “Creates a monthly System Restore point. Deployed via Datto RMM. When a SOC analyst or S1 shows the task, it’s obvious what it is and who owns it.  

 

Test it on a real machine with S1, not just the VM. Deploy a single pilot workstation, then check the S1 console after the first run. If it gets flagged, add an exclusion for that specific script in S1.  

A bigger option to consider on cleaning it up a little: Drop the scheduled task and use a monthly RMM component job instead. The deployment script would shrink to just the restore point logic, and Datto would run it on a schedule.  

Which looks to be the better direction in this case. There’s no persistent task, eliminating potential EDR alerts, runs under the RMM agent that the EDR already trusts, and the results show up centrally in the RMM instead of in the local logs.  

On top of that this appears to be more practical given that creating Windows System Restore points is not considered a complete modern recovery strategy on its own but still serves as a helpful quick safety net. With that being the case, the original script wouldn’t really be necessary to automate a monthly restore point. Which changes the intent of the script. Instead of writing a script to create a monthly restore point, the purpose of the script would be to have an RMM component to run as a job that just creates a restore point whenever there is an applicable scenario to do that on an endpoint.  

Overall, that’s a better design for the following reasons: 

Windows already handles the routine case: When System Restore is on, Windows creates restore points automatically before updates and many installs. A monthly point on top of that adds little.  

 

What helps is a restore point at the moment it’s needed: Right before you update a driver, install something risky, make a registry change, or start troubleshooting on a user’s machine. A month old restore point is less useful than one from five minutes ago. 

 

The potential for an EDR to flag persistence goes away: With no scheduled task, there’s no persistence for EDR to flag, no script left on the endpoint, and no question about execution policy on a file. It runs under the RMM agent, which EDR is already set to trust, and result appears in the RMM’s job output instead of a local log.  

 

It’s much simpler: Which fits a more practical workflow.  

 

What the component would do:  

Exit on Server or DC 

Enable System Restore on C: if it’s off 

Set the 5% shadow storage limit 

Create a restore point, with an optional description from an RMM input variable (a ticket number, or “Before driver update”). 

Confirm the point exists and exit 0 or 1, so Datto shows a clear success or failure.  

 

 

 

 

 

One decision I had to make:  

The scripts 24 hour limit:  

On demand, this limit matters more. If Windows made its own restore point this morning, the component would be skipped, which is exactly when a fresh one was wanted. Two choices:  

A: Report it clearly: "Skipped, a restore point already exists from [time]," and exit 1. No registry changes. The tech can see the existing recent point and decide whether it's good enough. 

 

B. Lift the limit: set the SystemRestorePointCreationFrequency registry value to 0 so a point is always created. Many RMM restore point components do this. It's a small, well-known change, but it's a registry change and it affects the whole machine. 

In my workflow, I’m personally very mindful of registry changes and like avoid them when I can. So, in this case, I’m going to go with A. 

 

With this direction, this changes the entire script and gives me new things to review: 

I’m going to type this out in PowerShell ISE as the new script replacing the original to visually go through each piece and then leverage specific prompts in Microsoft Copilot to review the script line per line and check for operational and security flaws, research, and make any necessary edits.  

 

 

 
