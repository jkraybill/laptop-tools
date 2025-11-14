#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Disables unnecessary Windows services to reduce RAM usage and background processes.

.DESCRIPTION
    Safely disables Windows services that are not needed for typical development work.
    Creates restore point before making changes.

    CUSTOMIZED FOR YOUR LAPTOP:
    - Print Spooler: KEPT (you use printers)
    - Bluetooth: KEPT (you use Bluetooth devices)
    - Xbox services: DISABLED (you don't use Xbox features)

    OTHER SERVICES DISABLED:
    - Fax services (rarely needed)
    - Phone services (unless you use Your Phone app)
    - Retail Demo Service
    - Parental Controls
    - Offline Files (if you don't use it)
    - Remote Registry (security risk)
    - Secondary Logon (security risk unless needed)

    SAFETY:
    - Services set to "Manual" or "Disabled" (not deleted)
    - Can be re-enabled if needed
    - Creates system restore point first

.EXAMPLE
    .\optimize-services.ps1
#>

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Windows Services Optimization" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script requires administrator privileges." -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

Write-Host "This script will disable unnecessary services based on your preferences." -ForegroundColor Yellow
Write-Host ""
Write-Host "YOUR CONFIGURATION:" -ForegroundColor Cyan
Write-Host "  Printers: USING - Print Spooler will be KEPT" -ForegroundColor Green
Write-Host "  Bluetooth: USING - Bluetooth services will be KEPT" -ForegroundColor Green
Write-Host "  Xbox: NOT USING - Xbox services will be DISABLED" -ForegroundColor Red
Write-Host ""

# Define services to disable
# Format: ServiceName, DisplayName, Reason
$servicesToDisable = @(
    # Xbox services (user doesn't use)
    @{Name="XblAuthManager"; Display="Xbox Live Auth Manager"; Reason="Xbox gaming not used"},
    @{Name="XblGameSave"; Display="Xbox Live Game Save"; Reason="Xbox gaming not used"},
    @{Name="XboxGipSvc"; Display="Xbox Accessory Management Service"; Reason="Xbox gaming not used"},
    @{Name="XboxNetApiSvc"; Display="Xbox Live Networking Service"; Reason="Xbox gaming not used"},

    # Fax services
    @{Name="Fax"; Display="Fax"; Reason="Fax rarely used"},

    # Phone services (disable if you don't use "Your Phone" app)
    @{Name="PhoneSvc"; Display="Phone Service"; Reason="Your Phone app - disable if not used"},

    # Remote services (security improvement)
    @{Name="RemoteRegistry"; Display="Remote Registry"; Reason="Security risk, rarely needed"},
    @{Name="RemoteAccess"; Display="Routing and Remote Access"; Reason="Not needed for typical use"},

    # Retail Demo
    @{Name="RetailDemo"; Display="Retail Demo Service"; Reason="Only for store display PCs"},

    # Parental Controls
    @{Name="WpcMonSvc"; Display="Parental Controls"; Reason="Not needed without parental controls"},

    # Offline Files (disable if you don't use network folder sync)
    @{Name="CscService"; Display="Offline Files"; Reason="Disable if not using offline file sync"},

    # Secondary Logon (security risk unless you specifically use RunAs)
    @{Name="seclogon"; Display="Secondary Logon"; Reason="Security risk, disable unless using RunAs"},

    # Diagnostic services (reduce telemetry)
    @{Name="DiagTrack"; Display="Connected User Experiences and Telemetry"; Reason="Telemetry/data collection"},
    @{Name="dmwappushservice"; Display="WAP Push Message Routing Service"; Reason="Telemetry-related"},

    # Windows Search (optional - disable if you use alternative like Everything)
    # @{Name="WSearch"; Display="Windows Search"; Reason="High disk/CPU usage - use Everything instead"},

    # Windows Error Reporting (optional)
    @{Name="WerSvc"; Display="Windows Error Reporting"; Reason="Sends crash reports to Microsoft"},

    # Maps services
    @{Name="MapsBroker"; Display="Downloaded Maps Manager"; Reason="Disable if not using offline maps"},

    # Geolocation
    @{Name="lfsvc"; Display="Geolocation Service"; Reason="Disable if not using location services"},

    # Windows Biometric Service (disable if no fingerprint reader)
    @{Name="WbioSrvc"; Display="Windows Biometric Service"; Reason="Disable if no fingerprint/face recognition"},

    # Touch Keyboard (disable on non-touch screen)
    @{Name="TabletInputService"; Display="Touch Keyboard and Handwriting Panel Service"; Reason="Disable if no touch screen"},

    # Sensor services (disable if no special sensors)
    @{Name="SensrSvc"; Display="Sensor Monitoring Service"; Reason="Disable if no ambient light sensor, etc."},
    @{Name="SensorDataService"; Display="Sensor Data Service"; Reason="Disable if no sensors"},
    @{Name="SensorService"; Display="Sensor Service"; Reason="Disable if no sensors"}
)

Write-Host "SERVICES TO BE DISABLED:" -ForegroundColor Yellow
Write-Host ""
foreach ($svc in $servicesToDisable) {
    Write-Host "  - $($svc.Display)" -ForegroundColor Cyan
    Write-Host "    Reason: $($svc.Reason)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "NOTE: Services will be set to 'Disabled' startup type." -ForegroundColor Yellow
Write-Host "You can re-enable any service manually if needed." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

$confirmation = Read-Host "Proceed with service optimization? (yes/no)"

if ($confirmation -ne "yes") {
    Write-Host "Cancelled by user." -ForegroundColor Red
    exit 0
}

# Create system restore point
Write-Host ""
Write-Host "Creating system restore point..." -ForegroundColor Cyan
try {
    Checkpoint-Computer -Description "Before Services Optimization" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
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
Write-Host "DISABLING SERVICES..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$disabledCount = 0
$notFoundCount = 0
$failedCount = 0

foreach ($svc in $servicesToDisable) {
    $serviceName = $svc.Name
    $displayName = $svc.Display

    # Check if service exists
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

    if (-not $service) {
        Write-Host "[SKIP] $displayName - Service not found" -ForegroundColor Yellow
        $notFoundCount++
        continue
    }

    try {
        # Stop service if running
        if ($service.Status -eq "Running") {
            Stop-Service -Name $serviceName -Force -ErrorAction Stop
            Write-Host "  Stopped: $displayName" -ForegroundColor Cyan
        }

        # Disable service
        Set-Service -Name $serviceName -StartupType Disabled -ErrorAction Stop
        Write-Host "[OK] Disabled: $displayName" -ForegroundColor Green
        $disabledCount++

    } catch {
        Write-Host "[FAIL] $displayName" -ForegroundColor Red
        Write-Host "       Error: $($_.Exception.Message)" -ForegroundColor DarkRed
        $failedCount++
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "OPTIMIZATION COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "SUMMARY:" -ForegroundColor Cyan
Write-Host "  Services disabled: $disabledCount" -ForegroundColor Green
Write-Host "  Services not found: $notFoundCount" -ForegroundColor Yellow
Write-Host "  Services failed: $failedCount" -ForegroundColor Red
Write-Host ""

if ($disabledCount -gt 0) {
    $ramSaved = $disabledCount * 10  # Rough estimate
    Write-Host "ESTIMATED IMPACT:" -ForegroundColor Cyan
    Write-Host "  - RAM saved: ~$ramSaved MB" -ForegroundColor White
    Write-Host "  - Background processes reduced: $disabledCount" -ForegroundColor White
    Write-Host "  - Boot time improvement: Minor to moderate" -ForegroundColor White
}

Write-Host ""
Write-Host "SERVICES KEPT ENABLED (per your preferences):" -ForegroundColor Green
Write-Host "  - Print Spooler (you use printers)" -ForegroundColor White
Write-Host "  - Bluetooth Support Service (you use Bluetooth)" -ForegroundColor White
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  1. Restart your computer for changes to take full effect" -ForegroundColor White
Write-Host "  2. If any feature stops working, re-enable its service via services.msc" -ForegroundColor White
Write-Host "  3. Monitor system stability for a few days" -ForegroundColor White
Write-Host ""
Write-Host "TO RE-ENABLE A SERVICE:" -ForegroundColor DarkGray
Write-Host "  Set-Service -Name <ServiceName> -StartupType Automatic" -ForegroundColor DarkGray
Write-Host "  Start-Service -Name <ServiceName>" -ForegroundColor DarkGray
Write-Host ""
