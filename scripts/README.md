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

### Windows Performance Optimization

**`optimize-startup-programs.ps1`**
- Disables unnecessary startup programs and scheduled tasks
- Targets bloatware updaters, vendor tools, and manually-started apps
- Creates system restore point and backup before changes
- **Run from:** Windows PowerShell as Administrator
- **Usage:** `.\optimize-startup-programs.ps1`
- **Impact:** Faster boot time, 200-500MB+ RAM saved

**What it removes:**
- Updaters: Adobe, Java, Oracle, iTunes
- Vendor bloat: HP, Dell, Lenovo, Asus, etc.
- Chat apps: Discord, Slack, Teams, Zoom (start manually)
- Cloud sync: Dropbox, OneDrive (if not needed at startup)
- Misc: Spotify, Steam, peripheral software

---

**`optimize-visual-effects.ps1`**
- Optimizes Windows visual effects for performance
- Disables animations, transparency, shadows
- Keeps smooth scrolling and font smoothing enabled
- **Run from:** Windows PowerShell as Administrator
- **Usage:** `.\optimize-visual-effects.ps1`
- **Impact:** Snappier UI, lower CPU/GPU usage

**What it disables:**
- Window animations (minimize/maximize)
- Transparency effects (taskbar, Start menu)
- Shadows under windows/menus
- Taskbar animations
- Thumbnail previews

**What it keeps:**
- Smooth scrolling (user preference)
- Font smoothing (readability)

---

**`optimize-power-plan.ps1`**
- Creates high-performance power plan for dev work
- Prevents CPU throttling and random slowdowns
- Balanced battery settings to avoid excessive drain
- **Run from:** Windows PowerShell as Administrator
- **Usage:** `.\optimize-power-plan.ps1`
- **Impact:** Consistent performance, no surprise slowdowns

**Optimizations:**
- CPU: 100% min/max when plugged in (5% min on battery)
- USB selective suspend: Disabled
- Disk sleep: Never
- System sleep: Never (manual only)
- Screen timeout: 15 min (AC) / 5 min (DC)

---

**`optimize-services.ps1`**
- Disables unnecessary Windows services
- Customized for your hardware (keeps printer & Bluetooth)
- Disables Xbox, fax, telemetry, and other bloat services
- Creates system restore point before changes
- **Run from:** Windows PowerShell as Administrator
- **Usage:** `.\optimize-services.ps1`
- **Impact:** ~100-300MB RAM saved, fewer background processes

**What it disables:**
- Xbox services (all - not used)
- Fax services
- Remote Registry (security improvement)
- Telemetry/diagnostic services
- Retail Demo, Parental Controls
- Optional: Phone service, geolocation, sensors

**What it keeps:**
- Print Spooler (you use printers)
- Bluetooth Support (you use Bluetooth)
- Windows Search, essential system services

---

**`fix-wslconfig.sh`**
- Emergency utility to fix corrupted `.wslconfig` files
- Run this if WSL fails to start after config changes
- **Usage:** `./fix-wslconfig.sh`

---

## Installation / First Run

### Phase 1: WSL Optimization
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

### Phase 2: Windows Optimization

#### Quick Start (Easiest Method)
**Using the helper batch file (bypasses execution policy):**
1. Right-click `RUN-OPTIMIZATIONS.bat` → "Run as Administrator"
2. Follow prompts to run all optimizations in order
3. Each script will ask for confirmation before making changes

#### Manual Method (Individual Scripts)

**First-time setup - Fix execution policy (one-time):**
- **Option A:** Right-click `FIX-EXECUTION-POLICY.bat` → "Run as Administrator"
- **Option B:** In PowerShell (Admin):
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

**Then run scripts individually:**
```powershell
cd C:\path\to\laptop-tools\scripts

# 3. Startup Programs Cleanup (restart after for full effect)
.\optimize-startup-programs.ps1

# 4. Visual Effects Optimization (logout/login or restart)
.\optimize-visual-effects.ps1

# 5. Power Plan Optimization (instant effect)
.\optimize-power-plan.ps1

# 6. Services Optimization (restart recommended)
.\optimize-services.ps1
```

#### Alternative: Bypass Policy Per Script
If you don't want to change execution policy:
```powershell
powershell -ExecutionPolicy Bypass -File .\optimize-startup-programs.ps1
```

---

## Troubleshooting

### "cannot be loaded. The file is not digitally signed"

This is PowerShell's execution policy blocking unsigned scripts. **Solutions:**

1. **Easiest:** Use `RUN-OPTIMIZATIONS.bat` (right-click → Run as Admin)
2. **Recommended:** Run `FIX-EXECUTION-POLICY.bat` once, then use scripts normally
3. **Manual fix:**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
4. **Per-script bypass:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scriptname.ps1
   ```

### Scripts won't run / "Access Denied"
- Ensure you're running PowerShell **as Administrator**
- Right-click PowerShell icon → "Run as Administrator"

### Services script fails on some services
- Some services may not exist on all Windows versions
- Script will skip non-existent services (this is normal)
- Check output for actual errors vs. "not found" messages

---

## Safety Notes

- All scripts create backups/restore points before modifying system
- Defender script checks for existing exclusions (won't duplicate)
- Scripts are idempotent - safe to run multiple times
- Services can be re-enabled via `services.msc` if needed
- Visual effects can be reverted via System Properties > Performance

---

## Future Scripts (Planned)

- O&O ShutUp10++ automation (privacy hardening)
- Disk cleanup deep dive script
- HDD cleanup and cataloguing tools
- Automated backup utilities
- System health checker

---

**Last Updated:** 2025-11-14
