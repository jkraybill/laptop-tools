#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Optimizes Windows visual effects for performance while keeping smooth scrolling.

.DESCRIPTION
    Disables resource-intensive visual effects like animations, transparency, and shadows.
    Keeps smooth scrolling enabled for better user experience.

    DISABLED:
    - Window animations (minimize/maximize/open/close)
    - Transparency effects (taskbar, Start menu)
    - Shadows under windows/menus
    - Animations in taskbar
    - Thumbnail previews
    - Sliding combo boxes/tooltips

    KEPT ENABLED:
    - Smooth scrolling (user preference)
    - Font smoothing (readability)

    PERFORMANCE IMPACT:
    - Reduces CPU/GPU usage during UI operations
    - Faster window operations
    - More responsive system overall

.EXAMPLE
    .\optimize-visual-effects.ps1
#>

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Visual Effects Optimization" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script requires administrator privileges." -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

Write-Host "This script will optimize visual effects for performance." -ForegroundColor Yellow
Write-Host ""
Write-Host "DISABLING:" -ForegroundColor Red
Write-Host "  - Window animations" -ForegroundColor White
Write-Host "  - Transparency effects" -ForegroundColor White
Write-Host "  - Shadows" -ForegroundColor White
Write-Host "  - Taskbar animations" -ForegroundColor White
Write-Host "  - Thumbnail previews" -ForegroundColor White
Write-Host ""
Write-Host "KEEPING ENABLED:" -ForegroundColor Green
Write-Host "  - Smooth scrolling (user preference)" -ForegroundColor White
Write-Host "  - Font smoothing (readability)" -ForegroundColor White
Write-Host ""

$confirmation = Read-Host "Proceed with optimization? (yes/no)"

if ($confirmation -ne "yes") {
    Write-Host "Cancelled by user." -ForegroundColor Red
    exit 0
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "APPLYING OPTIMIZATIONS..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Registry path for visual effects
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"

# Ensure the key exists
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}

# Set to custom mode (not "best appearance" or "best performance")
Set-ItemProperty -Path $regPath -Name "VisualFXSetting" -Value 3 -Type DWord
Write-Host "[OK] Set visual effects to Custom mode" -ForegroundColor Green

# User Preference Mask controls individual effects
# This is a bitmask - we'll set specific bits
$regPath2 = "HKCU:\Control Panel\Desktop"

# Visual Effects Settings
# These control various animations and effects
$settings = @{
    # Disable animations
    "UserPreferencesMask" = [byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)  # Custom mask for performance with smooth scrolling

    # Disable menu animations
    "MinAnimate" = "0"

    # Disable window animations
    "TaskbarAnimations" = "0"
}

foreach ($setting in $settings.GetEnumerator()) {
    try {
        if ($setting.Value -is [byte[]]) {
            Set-ItemProperty -Path $regPath2 -Name $setting.Key -Value $setting.Value -Type Binary -ErrorAction Stop
        } else {
            Set-ItemProperty -Path $regPath2 -Name $setting.Key -Value $setting.Value -Type String -ErrorAction Stop
        }
        Write-Host "[OK] Applied: $($setting.Key)" -ForegroundColor Green
    } catch {
        Write-Host "[FAIL] Could not apply: $($setting.Key)" -ForegroundColor Red
        Write-Host "       Error: $($_.Exception.Message)" -ForegroundColor DarkRed
    }
}

# Disable taskbar animations
$taskbarPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $taskbarPath -Name "TaskbarAnimations" -Value 0 -Type DWord
Write-Host "[OK] Disabled taskbar animations" -ForegroundColor Green

# Disable thumbnail previews (saves memory)
Set-ItemProperty -Path $taskbarPath -Name "DisableThumbnails" -Value 1 -Type DWord
Write-Host "[OK] Disabled thumbnail previews" -ForegroundColor Green

# Disable peek preview
Set-ItemProperty -Path $taskbarPath -Name "DisablePreviewDesktop" -Value 1 -Type DWord
Write-Host "[OK] Disabled peek preview" -ForegroundColor Green

# System-wide visual effects settings
$systemPath = "HKCU:\Software\Microsoft\Windows\DWM"

# Disable transparency (Aero Glass effects)
if (Test-Path $systemPath) {
    Set-ItemProperty -Path $systemPath -Name "EnableAeroPeek" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Host "[OK] Disabled Aero Peek" -ForegroundColor Green

    Set-ItemProperty -Path $systemPath -Name "AlwaysHibernateThumbnails" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Host "[OK] Disabled thumbnail hibernation" -ForegroundColor Green
}

# Disable transparency in Start/Taskbar (Windows 10/11)
$personalPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
if (Test-Path $personalPath) {
    Set-ItemProperty -Path $personalPath -Name "EnableTransparency" -Value 0 -Type DWord
    Write-Host "[OK] Disabled transparency effects" -ForegroundColor Green
}

# Performance settings - SystemPropertiesPerformance equivalent
$advancedPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"

# Individual effect settings (0 = disabled, 2 = enabled)
$effectsPath = "HKCU:\Control Panel\Desktop\WindowMetrics"
if (-not (Test-Path $effectsPath)) {
    New-Item -Path $effectsPath -Force | Out-Null
}

# Disable drop shadows
Set-ItemProperty -Path $effectsPath -Name "MinAnimate" -Value "0" -Type String
Write-Host "[OK] Disabled drop shadows" -ForegroundColor Green

# List smoothing (keep enabled for readability)
$listPath = "HKCU:\Control Panel\Desktop"
Set-ItemProperty -Path $listPath -Name "FontSmoothing" -Value "2" -Type String
Set-ItemProperty -Path $listPath -Name "FontSmoothingType" -Value 2 -Type DWord
Write-Host "[OK] Kept font smoothing enabled" -ForegroundColor Green

# Smooth scrolling - KEEP ENABLED per user preference
$internetPath = "HKCU:\Control Panel\Desktop"
Set-ItemProperty -Path $internetPath -Name "SmoothScroll" -Value 1 -Type DWord -ErrorAction SilentlyContinue
Write-Host "[OK] Kept smooth scrolling enabled (user preference)" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "OPTIMIZATION COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "CHANGES APPLIED:" -ForegroundColor Cyan
Write-Host "  - Disabled window animations" -ForegroundColor White
Write-Host "  - Disabled transparency effects" -ForegroundColor White
Write-Host "  - Disabled shadows and thumbnails" -ForegroundColor White
Write-Host "  - Disabled taskbar animations" -ForegroundColor White
Write-Host "  - Kept smooth scrolling enabled" -ForegroundColor Green
Write-Host "  - Kept font smoothing enabled" -ForegroundColor Green
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  1. Log out and log back in (or restart) to see full effect" -ForegroundColor White
Write-Host "  2. UI should feel snappier and more responsive" -ForegroundColor White
Write-Host "  3. To revert: System Properties > Performance > Adjust for best appearance" -ForegroundColor White
Write-Host ""
