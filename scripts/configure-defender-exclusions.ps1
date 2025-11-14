# Windows Defender Exclusions for Development
# Adds common dev directories to Windows Defender exclusions for performance
# Run as Administrator in PowerShell

#Requires -RunAsAdministrator

Write-Host "Windows Defender Exclusions Configuration" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Define common dev paths to exclude
$ExclusionPaths = @(
    # WSL2 filesystem (significant performance impact)
    "$env:LOCALAPPDATA\Packages\CanonicalGroupLimited.Ubuntu*\LocalState\ext4.vhdx",
    "$env:LOCALAPPDATA\Packages\CanonicalGroupLimited.Ubuntu*",

    # Common dev directories
    "$env:USERPROFILE\Documents\GitHub",
    "$env:USERPROFILE\Documents\Projects",
    "$env:USERPROFILE\source",
    "$env:USERPROFILE\repos",

    # Node.js
    "$env:APPDATA\npm",
    "$env:APPDATA\npm-cache",

    # Python
    "$env:LOCALAPPDATA\Programs\Python",
    "$env:USERPROFILE\.virtualenvs",

    # Go
    "$env:USERPROFILE\go",

    # Rust
    "$env:USERPROFILE\.cargo",
    "$env:USERPROFILE\.rustup"
)

# Define processes to exclude (dev tools)
$ExclusionProcesses = @(
    "node.exe",
    "python.exe",
    "go.exe",
    "cargo.exe",
    "git.exe",
    "code.exe",        # VS Code
    "wsl.exe",
    "wslhost.exe"
)

Write-Host "Adding Path Exclusions:" -ForegroundColor Yellow
Write-Host "----------------------" -ForegroundColor Yellow

foreach ($path in $ExclusionPaths) {
    # Expand environment variables
    $expandedPath = [System.Environment]::ExpandEnvironmentVariables($path)

    # Check if path exists (skip wildcards)
    if ($path -notlike "*`**" -and -not (Test-Path $expandedPath)) {
        Write-Host "  SKIP: $expandedPath (does not exist)" -ForegroundColor DarkGray
        continue
    }

    try {
        Add-MpPreference -ExclusionPath $expandedPath -ErrorAction Stop
        Write-Host "  OK: $expandedPath" -ForegroundColor Green
    }
    catch {
        if ($_.Exception.Message -like "*already exists*") {
            Write-Host "  SKIP: $expandedPath (already excluded)" -ForegroundColor DarkGray
        }
        else {
            Write-Host "  FAIL: $expandedPath - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "Adding Process Exclusions:" -ForegroundColor Yellow
Write-Host "-------------------------" -ForegroundColor Yellow

foreach ($process in $ExclusionProcesses) {
    try {
        Add-MpPreference -ExclusionProcess $process -ErrorAction Stop
        Write-Host "  OK: $process" -ForegroundColor Green
    }
    catch {
        if ($_.Exception.Message -like "*already exists*") {
            Write-Host "  SKIP: $process (already excluded)" -ForegroundColor DarkGray
        }
        else {
            Write-Host "  FAIL: $process - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "Current Exclusions:" -ForegroundColor Cyan
Write-Host "------------------" -ForegroundColor Cyan

$prefs = Get-MpPreference
Write-Host ""
Write-Host "Paths ($($prefs.ExclusionPath.Count)):" -ForegroundColor Yellow
$prefs.ExclusionPath | ForEach-Object { Write-Host "  $_" }

Write-Host ""
Write-Host "Processes ($($prefs.ExclusionProcess.Count)):" -ForegroundColor Yellow
$prefs.ExclusionProcess | ForEach-Object { Write-Host "  $_" }

Write-Host ""
Write-Host "Configuration complete!" -ForegroundColor Green
Write-Host ""
Write-Host "NOTE: Add custom paths by editing this script or running:" -ForegroundColor Yellow
Write-Host '  Add-MpPreference -ExclusionPath "C:\YourPath"' -ForegroundColor Gray
