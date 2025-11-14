# Laptop Tools - Scripts

Utility scripts for optimizing and maintaining JK's dev laptop.

## Available Scripts

### WSL Performance Optimization

**`optimize-wsl-config.sh`**
- Generates optimized `.wslconfig` for WSL2 performance
- Auto-detects system resources and recommends settings
- Backs up existing configuration before changes
- **Usage:** `./optimize-wsl-config.sh`
- **Requires:** WSL restart after running (`wsl --shutdown` from PowerShell)

**What it optimizes:**
- Memory allocation (50% of system RAM)
- Processor allocation (75% of CPU cores)
- Swap configuration
- Kernel parameters for reduced swappiness
- Nested virtualization for Docker

---

### Windows Defender Exclusions

**`configure-defender-exclusions.ps1`**
- PowerShell script to add dev directories and processes to Defender exclusions
- Improves WSL and dev tool performance significantly
- **Run from:** Windows PowerShell as Administrator
- **Usage:** Right-click → "Run with PowerShell" (as Admin)

**`configure-defender-exclusions.sh`**
- WSL helper script that launches the PowerShell script with elevation
- **Usage:** `./configure-defender-exclusions.sh`
- **Note:** Will prompt for UAC elevation

**What it excludes:**
- WSL2 virtual disk (`ext4.vhdx`)
- Common dev directories (GitHub, Projects, repos)
- Language-specific paths (Node, Python, Go, Rust)
- Dev tool processes (node, python, git, vscode, wsl)

---

## Installation / First Run

1. **Optimize WSL:**
   ```bash
   cd ~/laptop-tools/scripts
   ./optimize-wsl-config.sh
   ```
   Then from Windows PowerShell: `wsl --shutdown` and restart WSL

2. **Configure Defender Exclusions:**
   ```bash
   cd ~/laptop-tools/scripts
   ./configure-defender-exclusions.sh
   ```
   Approve UAC prompt and review exclusions in PowerShell window

---

## Safety Notes

- All scripts create backups before modifying system files
- Defender script checks for existing exclusions (won't duplicate)
- Scripts are idempotent - safe to run multiple times
- Review generated configs before applying if uncertain

---

## Future Scripts (Planned)

- Registry tweaks for UI performance
- HDD cleanup and cataloguing tools
- Automated backup utilities
- System health checker

---

**Last Updated:** 2025-11-15
