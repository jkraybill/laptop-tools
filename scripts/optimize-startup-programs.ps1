#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Disables unnecessary startup programs to improve boot time and free RAM.

.DESCRIPTION
    Scans for common bloatware and unnecessary startup programs, then disables them.
    Creates a restore point before making changes.

    SAFE TO KEEP:
    - WSL, Docker, essential drivers
    - Security tools (Defender, antivirus)
    - Critical system services

    TARGETS FOR REMOVAL:
    - Bloatware updaters (Adobe, Oracle, etc.)
    - Vendor tools (manufacturer bloat)
    - Chat apps that can be started manually
    - Unnecessary cloud sync tools

.EXAMPLE
    .\optimize-startup-programs.ps1
#>

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Startup Programs Cleanup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script requires administrator privileges." -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

# Common bloatware patterns to target
$bloatwarePatterns = @(
    # Updaters (safe to disable - apps still work)
    "*AdobeAAMUpdater*",
    "*AdobeUpdateService*",
    "*CCXProcess*",           # Adobe Creative Cloud
    "*Adobe ARM*",            # Adobe Reader updater
    "*JavaUpdate*",
    "*OracleJavaUpdate*",
    "*iTunesHelper*",
    "*QuickTime*",

    # Vendor bloat
    "*HP*",                   # HP bloatware (adjust if HP hardware needed)
    "*Lenovo*",              # Lenovo bloatware
    "*Dell*",                # Dell bloatware
    "*Asus*",                # Asus bloatware
    "*Acer*",                # Acer bloatware
    "*MSI*",                 # MSI bloatware

    # Chat/Communication (start manually)
    "*Discord*",
    "*Slack*",
    "*Teams*",               # Unless you use it constantly
    "*Skype*",
    "*Zoom*",

    # Cloud sync (if you don't need instant sync)
    "*Dropbox*",
    "*OneDrive*",            # Can be manually started when needed
    "*GoogleDrive*",
    "*BackupAndSync*",

    # Misc bloat
    "*Spotify*",
    "*Steam*",               # Start manually for gaming
    "*EpicGamesLauncher*",
    "*Razer*",               # Unless you use Razer peripherals
    "*Logitech*",            # Unless you use Logitech peripherals with custom settings
    "*Nvidia*",              # GeForce Experience - keep if you use game optimization
    "*RealTek*"              # Audio manager - usually unnecessary
)

Write-Host "Scanning for bloatware startup programs..." -ForegroundColor Yellow
Write-Host ""

# Get startup programs from registry locations
$startupLocations = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
)

$foundBloat = @()

foreach ($location in $startupLocations) {
    if (Test-Path $location) {
        $items = Get-ItemProperty -Path $location -ErrorAction SilentlyContinue
        if ($items) {
            $items.PSObject.Properties | ForEach-Object {
                $name = $_.Name
                $value = $_.Value

                # Skip PS* properties
                if ($name -like "PS*") { return }

                # Check if matches bloatware pattern
                foreach ($pattern in $bloatwarePatterns) {
                    if ($name -like $pattern -or $value -like $pattern) {
                        $foundBloat += [PSCustomObject]@{
                            Name = $name
                            Path = $value
                            Location = $location
                        }
                        break
                    }
                }
            }
        }
    }
}

# Also check Task Scheduler for startup tasks
Write-Host "Scanning Task Scheduler for bloatware tasks..." -ForegroundColor Yellow
$scheduledBloat = @()

$tasks = Get-ScheduledTask | Where-Object { $_.State -eq "Ready" -and $_.Settings.Enabled -eq $true }

foreach ($task in $tasks) {
    $taskName = $task.TaskName
    foreach ($pattern in $bloatwarePatterns) {
        if ($taskName -like $pattern) {
            $scheduledBloat += $task
            break
        }
    }
}

# Display findings
Write-Host "========================================" -ForegroundColor Green
Write-Host "FOUND BLOATWARE TO REMOVE:" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

if ($foundBloat.Count -eq 0 -and $scheduledBloat.Count -eq 0) {
    Write-Host "No bloatware found! Your startup is already clean." -ForegroundColor Green
    exit 0
}

if ($foundBloat.Count -gt 0) {
    Write-Host "Registry Startup Items ($($foundBloat.Count) found):" -ForegroundColor Cyan
    $foundBloat | ForEach-Object {
        Write-Host "  - $($_.Name)" -ForegroundColor Yellow
        Write-Host "    Location: $($_.Location)" -ForegroundColor DarkGray
    }
    Write-Host ""
}

if ($scheduledBloat.Count -gt 0) {
    Write-Host "Scheduled Tasks ($($scheduledBloat.Count) found):" -ForegroundColor Cyan
    $scheduledBloat | ForEach-Object {
        Write-Host "  - $($_.TaskName)" -ForegroundColor Yellow
        Write-Host "    Path: $($_.TaskPath)" -ForegroundColor DarkGray
    }
    Write-Host ""
}

# Confirm action
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "WARNING: This will disable the items above." -ForegroundColor Yellow
Write-Host "You can re-enable them manually if needed." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

$confirmation = Read-Host "Proceed with cleanup? (yes/no)"

if ($confirmation -ne "yes") {
    Write-Host "Cancelled by user." -ForegroundColor Red
    exit 0
}

# Create system restore point
Write-Host ""
Write-Host "Creating system restore point..." -ForegroundColor Cyan
try {
    Checkpoint-Computer -Description "Before Startup Cleanup" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
    Write-Host "Restore point created successfully." -ForegroundColor Green
} catch {
    Write-Host "Warning: Could not create restore point: $($_.Exception.Message)" -ForegroundColor Yellow
    $continueAnyway = Read-Host "Continue without restore point? (yes/no)"
    if ($continueAnyway -ne "yes") {
        Write-Host "Cancelled." -ForegroundColor Red
        exit 0
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CLEANING UP STARTUP ITEMS..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Create backup directory
$backupDir = "$PSScriptRoot\backups"
$backupFile = "$backupDir\startup-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"

if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

# Backup configuration
$foundBloat | ForEach-Object {
    "$($_.Location)|$($_.Name)|$($_.Path)" | Out-File -Append -FilePath $backupFile
}

Write-Host "Backup saved to: $backupFile" -ForegroundColor Green
Write-Host ""

# Remove registry startup items
$removedCount = 0
foreach ($item in $foundBloat) {
    try {
        Remove-ItemProperty -Path $item.Location -Name $item.Name -ErrorAction Stop
        Write-Host "[OK] Removed: $($item.Name)" -ForegroundColor Green
        $removedCount++
    } catch {
        Write-Host "[FAIL] Could not remove: $($item.Name)" -ForegroundColor Red
        Write-Host "       Error: $($_.Exception.Message)" -ForegroundColor DarkRed
    }
}

# Disable scheduled tasks
$disabledCount = 0
foreach ($task in $scheduledBloat) {
    try {
        Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction Stop | Out-Null
        Write-Host "[OK] Disabled task: $($task.TaskName)" -ForegroundColor Green
        $disabledCount++
    } catch {
        Write-Host "[FAIL] Could not disable task: $($task.TaskName)" -ForegroundColor Red
        Write-Host "       Error: $($_.Exception.Message)" -ForegroundColor DarkRed
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "CLEANUP COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Removed startup items: $removedCount" -ForegroundColor Cyan
Write-Host "Disabled scheduled tasks: $disabledCount" -ForegroundColor Cyan
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  1. Restart your computer to see boot time improvements" -ForegroundColor White
Write-Host "  2. If you need any disabled program, start it manually" -ForegroundColor White
Write-Host "  3. Backup saved to: $backupFile" -ForegroundColor White
Write-Host ""
