#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Creates and activates a high-performance power plan optimized for development work.

.DESCRIPTION
    Creates a custom "Dev Laptop - High Performance" power plan based on the
    High Performance template, then optimizes settings to prevent random slowdowns
    and ensure consistent CPU/disk performance.

    OPTIMIZATIONS:
    - No CPU throttling (100% min and max)
    - Disable USB selective suspend (prevents peripheral issues)
    - Disable disk sleep (SSD-friendly, prevents slowdowns)
    - Disable hibernation after timeout (faster resume)
    - Screen off after 15 min (save power when idle)
    - Never sleep automatically (manual sleep only)

    WHEN TO USE:
    - Plugged in: Always use this plan for max performance
    - Battery: Consider switching to "Balanced" to save power

.EXAMPLE
    .\optimize-power-plan.ps1
#>

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Power Plan Optimization" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script requires administrator privileges." -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

Write-Host "This script will create a high-performance power plan optimized for dev work." -ForegroundColor Yellow
Write-Host ""
Write-Host "OPTIMIZATIONS:" -ForegroundColor Cyan
Write-Host "  - CPU: 100% min/max (no throttling)" -ForegroundColor White
Write-Host "  - USB selective suspend: Disabled" -ForegroundColor White
Write-Host "  - Disk sleep: Disabled" -ForegroundColor White
Write-Host "  - Hibernation timeout: Never" -ForegroundColor White
Write-Host "  - Screen timeout: 15 minutes" -ForegroundColor White
Write-Host "  - Sleep timeout: Never (manual only)" -ForegroundColor White
Write-Host ""
Write-Host "NOTE: This prioritizes performance over power saving." -ForegroundColor Yellow
Write-Host "      Consider switching to 'Balanced' when on battery." -ForegroundColor Yellow
Write-Host ""

$confirmation = Read-Host "Proceed with power plan creation? (yes/no)"

if ($confirmation -ne "yes") {
    Write-Host "Cancelled by user." -ForegroundColor Red
    exit 0
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CREATING POWER PLAN..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$planName = "Dev Laptop - High Performance"

# Check if plan already exists
$existingPlan = powercfg /list | Select-String -Pattern $planName

if ($existingPlan) {
    Write-Host "Power plan '$planName' already exists." -ForegroundColor Yellow
    $overwrite = Read-Host "Delete and recreate? (yes/no)"

    if ($overwrite -eq "yes") {
        # Extract GUID from existing plan
        $guid = ($existingPlan -split '\s+')[3]
        Write-Host "Deleting existing plan..." -ForegroundColor Yellow
        powercfg /delete $guid
        Write-Host "[OK] Deleted existing plan" -ForegroundColor Green
    } else {
        Write-Host "Keeping existing plan. Exiting." -ForegroundColor Yellow
        exit 0
    }
}

# Duplicate High Performance plan (GUID: 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c)
Write-Host "Creating new power plan from High Performance template..." -ForegroundColor Cyan
$duplicateOutput = powercfg /duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

# Extract new GUID
$newGuid = ($duplicateOutput | Select-String -Pattern '([0-9a-f-]{36})').Matches.Groups[1].Value

if (-not $newGuid) {
    Write-Host "ERROR: Failed to create power plan." -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Created power plan with GUID: $newGuid" -ForegroundColor Green

# Rename the plan
powercfg /changename $newGuid "$planName" "High-performance plan optimized for development work. No CPU throttling, no disk sleep, no USB suspend."
Write-Host "[OK] Renamed power plan to: $planName" -ForegroundColor Green

Write-Host ""
Write-Host "Applying optimizations..." -ForegroundColor Cyan
Write-Host ""

# Function to set power setting
function Set-PowerSetting {
    param(
        [string]$Guid,
        [string]$SubGroup,
        [string]$Setting,
        [string]$ValueAC,
        [string]$ValueDC,
        [string]$Description
    )

    try {
        # Set AC (plugged in) value
        powercfg /setacvalueindex $Guid $SubGroup $Setting $ValueAC | Out-Null

        # Set DC (battery) value
        powercfg /setdcvalueindex $Guid $SubGroup $Setting $ValueDC | Out-Null

        Write-Host "[OK] $Description" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "[FAIL] $Description" -ForegroundColor Red
        Write-Host "       Error: $($_.Exception.Message)" -ForegroundColor DarkRed
        return $false
    }
}

# Apply settings
# Format: SubGroup GUID, Setting GUID, AC Value, DC Value, Description

# Processor power management - Minimum processor state
Set-PowerSetting $newGuid "54533251-82be-4824-96c1-47b60b740d00" "893dee8e-2bef-41e0-89c6-b55d0929964c" "100" "5" "CPU Min: 100% (AC) / 5% (DC)"

# Processor power management - Maximum processor state
Set-PowerSetting $newGuid "54533251-82be-4824-96c1-47b60b740d00" "bc5038f7-23e0-4960-96da-33abaf5935ec" "100" "100" "CPU Max: 100% (AC/DC)"

# USB selective suspend
Set-PowerSetting $newGuid "2a737441-1930-4402-8d77-b2bebba308a3" "48e6b7a6-50f5-4782-a5d4-53bb8f07e226" "0" "0" "USB Selective Suspend: Disabled"

# Hard disk - Turn off after
Set-PowerSetting $newGuid "0012ee47-9041-4b5d-9b77-535fba8b1442" "6738e2c4-e8a5-4a42-b16a-e040e769756e" "0" "0" "Disk Sleep: Never"

# Sleep - Sleep after
Set-PowerSetting $newGuid "238c9fa8-0aad-41ed-83f4-97be242c8f20" "29f6c1db-86da-48c5-9fdb-f2b67b1f44da" "0" "0" "Sleep After: Never"

# Sleep - Hibernate after
Set-PowerSetting $newGuid "238c9fa8-0aad-41ed-83f4-97be242c8f20" "9d7815a6-7ee4-497e-8888-515a05f02364" "0" "0" "Hibernate After: Never"

# Display - Turn off after (15 min AC, 5 min DC)
Set-PowerSetting $newGuid "7516b95f-f776-4464-8c53-06167f40cc99" "3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e" "900" "300" "Screen Off: 15 min (AC) / 5 min (DC)"

# PCI Express - Link State Power Management (disable for max performance)
Set-PowerSetting $newGuid "501a4d13-42af-4429-9fd1-a8218c268e20" "ee12f906-d277-404b-b6da-e5fa1a576df5" "0" "0" "PCIe Link Power Management: Off"

# Processor power management - System cooling policy (Active = more aggressive fan)
Set-PowerSetting $newGuid "54533251-82be-4824-96c1-47b60b740d00" "94d3a615-a899-4ac5-ae2b-e4d8f634367f" "1" "1" "Cooling Policy: Active (better cooling)"

Write-Host ""
Write-Host "Activating power plan..." -ForegroundColor Cyan
powercfg /setactive $newGuid
Write-Host "[OK] Power plan activated" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "OPTIMIZATION COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "POWER PLAN CREATED: $planName" -ForegroundColor Cyan
Write-Host "GUID: $newGuid" -ForegroundColor DarkGray
Write-Host ""
Write-Host "SETTINGS APPLIED:" -ForegroundColor Cyan
Write-Host "  When Plugged In (AC):" -ForegroundColor Yellow
Write-Host "    - CPU: 100% min/max (no throttling)" -ForegroundColor White
Write-Host "    - USB suspend: Disabled" -ForegroundColor White
Write-Host "    - Disk sleep: Never" -ForegroundColor White
Write-Host "    - System sleep: Never" -ForegroundColor White
Write-Host "    - Screen off: 15 minutes" -ForegroundColor White
Write-Host ""
Write-Host "  On Battery (DC):" -ForegroundColor Yellow
Write-Host "    - CPU: 5% min, 100% max (balanced)" -ForegroundColor White
Write-Host "    - USB suspend: Disabled" -ForegroundColor White
Write-Host "    - Disk sleep: Never" -ForegroundColor White
Write-Host "    - System sleep: Never" -ForegroundColor White
Write-Host "    - Screen off: 5 minutes" -ForegroundColor White
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  1. Power plan is now active" -ForegroundColor White
Write-Host "  2. No restart required - changes take effect immediately" -ForegroundColor White
Write-Host "  3. Check: Control Panel > Power Options to verify" -ForegroundColor White
Write-Host "  4. On battery: Consider switching to 'Balanced' for longer runtime" -ForegroundColor White
Write-Host ""
Write-Host "To switch back: powercfg /setactive [GUID]" -ForegroundColor DarkGray
Write-Host "To list plans: powercfg /list" -ForegroundColor DarkGray
Write-Host ""
