# New-RestorePoint

An on-demand PowerShell script that creates a Windows System Restore point on a workstation before a risky change. Built to run as an RMM component (built and tested for Datto RMM) against a single endpoint whenever a technician needs a fresh rollback point.

## When to Use It

Run it right before making a change that could leave a workstation in a bad state:

- Installing, updating, or rolling back a **driver** (graphics, network, audio, docking station)
- Installing or uninstalling **software**, especially older or line-of-business applications
- Editing the **registry** by hand
- Changing **system settings** or Windows features during troubleshooting
- Running **cleanup, repair, or optimization tools** that modify system files or services
- Applying a **manual Windows update** or a fix outside the normal patch cycle

### What It Doesn't Cover

System Restore rolls back system files, drivers, the registry, and installed programs. It is **not a backup**:

- User files (documents, desktop, downloads) are not saved or restored
- Restore points live on the same drive, so they don't survive drive failure, theft, or ransomware
- Use a real backup solution for disaster recovery

## Requirements

- Windows 10 or 11 workstation (exits on Windows Server and domain controllers)
- Windows PowerShell 5.1 (the restore point cmdlets don't exist in PowerShell 7)
- Runs as SYSTEM (the default for RMM components)

## Usage as an RMM Component

1. Create a new PowerShell component in the RMM and paste in `New-RestorePoint.ps1`.
2. *(Optional)* Add a **String** input variable named `RPDescription`.
3. Run the component as a quick job against the endpoint before making the change.
4. Check the job output and exit code to confirm the restore point was created.

### The `RPDescription` Variable

An optional label for the restore point, so it's easy to find later in System Restore.

- **Examples:** `Ticket 1234 - before driver update`, `Before uninstalling legacy VPN client`
- **Left blank:** defaults to `Datto RMM - Manual Restore Point`
- **Max 64 characters.** Longer text is truncated.
- Control and invisible characters (tabs, line breaks, emoji) are removed automatically.

## Exit Codes

| Code | Meaning |
|---|---|
| **0** | Restore point created and confirmed. |
| **1** | Failed: WMI error, System Restore blocked (for example by Group Policy), or creation failed. Check the output for the cause. |
| **2** | Skipped. Windows only allows one restore point per 24 hours, and one already exists within that window. The most recent point's name and time are reported so the technician can decide whether it's recent enough. |

## Key Design Decisions

- **On demand, not scheduled.** An earlier version used a monthly scheduled task running as SYSTEM. It was redesigned as an on-demand component because Windows already creates restore points before most updates and installs, and the most useful restore point is one taken right before a change. This also removed a persistent SYSTEM task (a pattern EDR tools commonly flag) and leaves nothing on the endpoint.
- **Success is verified, not assumed.** Windows reports its 24-hour limit as a warning, not an error, so a restore point can silently fail to appear. The script confirms a new point exists, matching it by sequence number and description, before reporting success.
- **The 24-hour limit is reported, not bypassed.** The limit can be removed with a registry change, but that changes behavior for the whole machine. The script reports the existing point instead and leaves the decision to the technician.
- **Separate exit codes for "skipped" and "failed."** A skip means a recent point already exists. A failure means System Restore isn't working. They need different responses, so they return different codes.
- **Accurate error messages.** WMI and restore point queries use `-ErrorAction Stop` with `try`/`catch`, so a failure reports the real cause instead of a misleading message like "Not a workstation."
- **Description input is cleaned and limited.** This prevents Windows from rejecting or silently shortening the description, which would break the success check.
- **Shadow storage is left at the Windows default.** Lowering the storage limit can immediately delete existing restore points and shadow copies. Changing machine-wide storage policy was out of scope for an on-demand tool.
- **Workstations only.** The script exits on servers and domain controllers.

## Rollback Caveat for Domain-Joined Machines

Creating restore points is safe. **Restoring** a domain-joined machine to an older point can break its domain trust, because the restore can roll back the computer's machine account password. Restore points from the last few weeks are usually fine; much older ones are more likely to cause problems. If the trust breaks after a rollback, sign in with a local admin account and run:

```powershell
Test-ComputerSecureChannel -Repair -Credential (Get-Credential)
```

## Testing

*To be completed after VM and pilot testing.*

- [ ] Normal run creates and confirms a restore point (exit 0)
- [ ] Immediate second run reports the existing point (exit 2)
- [ ] Custom `RPDescription` appears correctly on the restore point
- [ ] Description over 64 characters is truncated and still confirmed
- [ ] Blank `RPDescription` falls back to the default
- [ ] Exits cleanly on Windows Server
- [ ] RMM job output and exit codes display as expected

## Development and Review

This script was built with an AI-assisted workflow, with every change reviewed and decided by me:

1. **Generate.** Claude (Anthropic) generated the initial script from a prompt describing the environment, requirements, and security constraints.
2. **Cross-model review.** Microsoft Copilot reviewed the script using structured review prompts: a line-by-line explanation, a production safety check, and a security and logic audit.
3. **Verify and research.** Each finding was checked against PowerShell and Windows behavior before acting on it, with Claude used to research and trace edge cases. Several AI suggestions were corrected (for example, `try`/`catch` blocks that wouldn't work without `-ErrorAction Stop`), and some were rejected with documented reasoning.
4. **Redesign where warranted.** The review led to replacing a scheduled-task design with this on-demand component and removing a feature (shadow storage resizing) instead of patching it.
5. **Test.** The script was tested in an isolated VM before production use.

Full review findings, including what was changed, what was rejected, and why, are in the [`docs/`](docs/) folder. Commit history shows the script's progression from the original AI-generated draft.

