# PowerShell RMM Components

A collection of PowerShell scripts built to run as RMM components (built and tested for Datto RMM) on Windows endpoints. Each component solves a specific support or maintenance task and includes its own README and review documentation.

## Components

| Component | Description |
|---|---|
| [New-RestorePoint](New-RestorePoint/) | Creates and verifies a System Restore point on demand before a risky change (driver updates, software installs, registry edits). |

## Shared Conventions

Unless a component's README says otherwise, every script in this repo follows these rules:

- **Target:** Windows 10/11 workstations; scripts exit cleanly on servers and domain controllers unless stated
- **Runtime:** Windows PowerShell 5.1, running as SYSTEM through the RMM agent
- **No persistence:** no scheduled tasks, services, or files left on the endpoint unless the component's purpose requires it
- **Clear results:** meaningful exit codes (`0` = success, non-zero = documented failure or skip) and plain-language output readable in the RMM job log
- **Verified outcomes:** results are confirmed after the action, not assumed because no error was thrown
- **Minimal footprint:** no machine-wide setting changes beyond what the task requires

## Development Workflow

Each component goes through the same AI-assisted process, with every change reviewed and decided by me:

1. **Generate** the initial script with Claude from a prompt describing the environment, requirements, and security constraints.
2. **Review** it with Microsoft Copilot using structured review prompts: a line-by-line explanation, a production safety check, and a security and logic audit.
3. **Verify** each finding against PowerShell and Windows behavior before acting on it. Suggestions are accepted, corrected, or rejected with documented reasoning.
4. **Test** in an isolated VM before production use.

Each component's `docs/` folder holds its review findings, and the commit history shows how it evolved from the first AI-generated draft.

## Repository Structure

```
PowerShell-RMM-Components/
├── README.md
└── <Component-Name>/
    ├── README.md       ← what it does, usage, exit codes, design decisions
    ├── <Script>.ps1
    └── docs/           ← review findings and decisions
```

## Disclaimer

These scripts are provided as examples of my work. Review and test any script in your own environment before deploying it to production endpoints.
