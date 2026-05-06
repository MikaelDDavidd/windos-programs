<div align="center">

# Windows Auto Install

**One-line PowerShell script to set up a fresh Windows install in minutes.**

Removes OneDrive bloat, installs essential programs via winget/Chocolatey with automatic fallback, and prepares your driver folder — all from a single elevated terminal command.

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![winget](https://img.shields.io/badge/winget-supported-success?logo=windows)](https://learn.microsoft.com/windows/package-manager/winget/)
[![Chocolatey](https://img.shields.io/badge/Chocolatey-fallback-80B5E3?logo=chocolatey&logoColor=white)](https://chocolatey.org/)

</div>

---

## Overview

After a Windows reinstall, you usually spend an hour clicking through installers, hunting for download links, and uninstalling junk. This script does it for you — bootstrap a usable workstation with **a single command** in an elevated PowerShell, even on a fresh Windows install where nothing is configured yet.

It auto-installs the package managers if missing, tries `winget` first, falls back to `Chocolatey` if a package fails, removes OneDrive cleanly, and writes a timestamped log to `%TEMP%` so you can audit what happened.

### Key Features

- **One-liner from a fresh install** — no git, no manual download, no setup
- **Self-bootstrapping** — installs `winget` and `Chocolatey` automatically if missing
- **Dual-source install with fallback** — tries winget first, falls back to Chocolatey on failure
- **OneDrive removal** — clears the AppX package and runs the official uninstaller
- **Phase skipping** — flags to skip bloatware removal, programs, or drivers independently
- **Timestamped log file** — every action saved to `%TEMP%\InstallLog_<datetime>.txt`
- **Prerequisite checks** — verifies Administrator rights and internet connectivity before running
- **Silent installs** — uses `--silent` / `-y` / `/SILENT` flags so nothing blocks on UI prompts

## Quick Start

Open **PowerShell as Administrator** and run:

```powershell
iex (irm "https://raw.githubusercontent.com/MikaelDDavidd/windos-programs/main/script.ps1")
```

That's it. The script handles everything else.

### Skipping Phases

You can skip any phase with switches. Download the script first, then run with the flags you want:

```powershell
# Download
irm "https://raw.githubusercontent.com/MikaelDDavidd/windos-programs/main/script.ps1" -OutFile script.ps1

# Run skipping bloatware removal
.\script.ps1 -SkipBloatware

# Run skipping driver phase
.\script.ps1 -SkipDrivers

# Combine flags
.\script.ps1 -SkipBloatware -SkipPrograms
```

| Switch | Effect |
|--------|--------|
| `-SkipBloatware` | Skip OneDrive removal |
| `-SkipPrograms` | Skip the program installation phase |
| `-SkipDrivers` | Skip the driver folder setup phase |

## What Gets Installed

The script installs the following programs (via winget, falling back to Chocolatey):

| Program | winget ID | Chocolatey ID |
|---------|-----------|---------------|
| Driver Booster | `IObit.DriverBooster` | `driverbooster` |
| Google Chrome | `Google.Chrome` | `googlechrome` |
| Discord | `Discord.Discord` | `discord` |
| Steam | `Valve.Steam` | `steam` |
| EA Desktop | `ElectronicArts.EADesktop` | `ea-desktop` |
| Epic Games Launcher | `EpicGames.EpicGamesLauncher` | `epicgameslauncher` |
| MSI Afterburner | `Guru3D.Afterburner` | `msiafterburner` |
| Blitz | `Blitz.Blitz` | `blitz` |
| WinRAR | `RARLab.WinRAR` | `winrar` |

To customize the list, edit the `$programs` array inside `Install-Programs` in `script.ps1`.

## Requirements

- **Windows 10 or 11**
- **PowerShell 5.1+** (built into Windows)
- **Administrator privileges** — the script enforces `#Requires -RunAsAdministrator`
- **Active internet connection** — verified by pinging `8.8.8.8` before running

## How It Works

The script runs three phases in sequence, each gated by its corresponding skip flag:

1. **Prerequisites & Package Managers** — verifies admin/internet, then installs `winget` and `Chocolatey` if missing.
2. **Phase 1 — Bloatware Removal** — uninstalls `Microsoft.OneDrive` AppX packages and runs the official OneDrive uninstaller.
3. **Phase 2 — Programs** — iterates the program list, attempting winget first and Chocolatey as fallback.
4. **Phase 3 — Drivers** — creates `%USERPROFILE%\Downloads\Drivers` and prepares the folder for manual driver placement (the user is expected to populate this folder; Driver Booster can then auto-detect).

A progress bar is shown for each phase, and every line is mirrored to the log file.

## Logs

Every run writes a timestamped log to:

```
%TEMP%\InstallLog_yyyyMMdd_HHmmss.txt
```

Each entry includes the time and the message, so you can review what installed (and what failed) after the script finishes.

## Project Structure

```
windos-programs/
├── README.md       # This file
└── script.ps1      # The full installer script
```

The entire installer is a single self-contained PowerShell script — no modules, no external files.

## Notes & Caveats

- The driver phase currently prepares the folder structure only; populate it manually with your motherboard/GPU drivers. Driver Booster (installed in phase 2) can scan and update from there.
- Some publishers ship installers that ignore silent flags. If a program prompts for input, the script will wait — pay attention near the end of phase 2.
- After completion, **reboot** to finalize OneDrive removal and any drivers that registered services.

## License

Personal project — no license. Use at your own risk; review `script.ps1` before running it on machines that aren't yours.

---

<div align="center">
Built by <a href="https://github.com/MikaelDDavidd">Mikael David</a>
</div>
