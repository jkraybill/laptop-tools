# diagnose-scroll-freeze.ps1
# Diagnostic script for mouse scroll input freezing issues
# Targets: Logitech MX Master 3S, Chrome, Rimworld, Windows 11
#
# Run as Administrator for full diagnostics

param(
    [switch]$Quick,      # Quick check only
    [switch]$Monitor,    # Start continuous monitoring
    [int]$MonitorSeconds = 60
)

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Scroll Freeze Diagnostic Tool" -ForegroundColor Cyan
Write-Host " Target: Logitech MX Master 3S" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[WARNING] Not running as Administrator. Some checks will be limited." -ForegroundColor Yellow
    Write-Host ""
}

#region System Info
Write-Host "=== SYSTEM INFO ===" -ForegroundColor Green

# Windows version - critical for 24H2 scroll bug
$os = Get-CimInstance Win32_OperatingSystem
$build = $os.BuildNumber
$version = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").DisplayVersion
Write-Host "Windows Version: $version (Build $build)" -ForegroundColor White

# Check for known problematic 24H2
if ($version -match "24H2") {
    Write-Host "[!] Windows 11 24H2 detected - KNOWN CHROME SCROLL BUG" -ForegroundColor Red
    Write-Host "    Chrome has D3D11 rendering issues causing scroll stutter" -ForegroundColor Yellow
    Write-Host "    FIX: chrome://flags -> ANGLE graphics backend -> D3D9" -ForegroundColor Yellow
}

Write-Host ""
#endregion

#region Logitech Software Check
Write-Host "=== LOGITECH SOFTWARE ===" -ForegroundColor Green

# Check for Logi Options+ processes
$logiProcesses = @(
    "LogiOptionsUI",
    "logioptionsplus_agent",
    "logioptionsplus_updater",
    "LogiOptions",
    "Logi Options",
    "LogiMgr"
)

$foundLogi = @()
foreach ($proc in $logiProcesses) {
    $running = Get-Process -Name $proc -ErrorAction SilentlyContinue
    if ($running) {
        $foundLogi += $running
        $cpu = [math]::Round(($running | Measure-Object -Property CPU -Sum).Sum, 2)
        $mem = [math]::Round(($running | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB, 2)
        Write-Host "  $($running[0].Name): Running (CPU: $cpu s, Mem: $mem MB)" -ForegroundColor White

        # Check for high CPU
        if ($cpu -gt 60) {
            Write-Host "  [!] HIGH CPU USAGE - Logi Options+ may be hanging" -ForegroundColor Red
        }
    }
}

if ($foundLogi.Count -eq 0) {
    Write-Host "  No Logitech software processes found" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "  Logitech processes found: $($foundLogi.Count)" -ForegroundColor White

    # Get Logi Options+ version if installed
    $logiApp = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*Logi Options*" }
    if ($logiApp) {
        Write-Host "  Installed version: $($logiApp.DisplayVersion)" -ForegroundColor White
        Write-Host "  [TIP] Update to latest Logi Options+ for CPU usage fixes" -ForegroundColor Yellow
    }
}

Write-Host ""
#endregion

#region USB Power Management
Write-Host "=== USB POWER MANAGEMENT ===" -ForegroundColor Green

# Check USB Selective Suspend in power plan
try {
    $currentPlan = powercfg /getactivescheme
    $planGuid = ($currentPlan -split ' ')[3]

    # USB selective suspend setting GUID
    $usbSubgroup = "2a737441-1930-4402-8d77-b2bebba308a3"
    $usbSelectiveSuspend = "48e6b7a6-50f5-4782-a5d4-53bb8f07e226"

    $usbSetting = powercfg /query $planGuid $usbSubgroup $usbSelectiveSuspend 2>$null
    if ($usbSetting -match "Current AC Power Setting Index: 0x00000001") {
        Write-Host "  USB Selective Suspend: ENABLED" -ForegroundColor Red
        Write-Host "  [!] This can cause momentary USB device disconnects" -ForegroundColor Yellow
        Write-Host "  FIX: Power Options -> USB settings -> Disable selective suspend" -ForegroundColor Yellow
    } elseif ($usbSetting -match "Current AC Power Setting Index: 0x00000000") {
        Write-Host "  USB Selective Suspend: Disabled (Good)" -ForegroundColor Green
    } else {
        Write-Host "  USB Selective Suspend: Unknown status" -ForegroundColor Gray
    }
} catch {
    Write-Host "  Could not check USB power settings" -ForegroundColor Gray
}

# Check USB Hub power management
Write-Host ""
Write-Host "  USB Hub Power Management:" -ForegroundColor White
$usbHubs = Get-PnpDevice -Class USB -Status OK | Where-Object { $_.FriendlyName -like "*Hub*" }
$hubsWithPowerMgmt = 0
foreach ($hub in $usbHubs) {
    try {
        $powerMgmt = Get-CimInstance -ClassName MSPower_DeviceEnable -Namespace root\wmi -ErrorAction SilentlyContinue |
            Where-Object { $_.InstanceName -like "*$($hub.InstanceId)*" }
        if ($powerMgmt -and $powerMgmt.Enable) {
            $hubsWithPowerMgmt++
        }
    } catch {}
}
if ($hubsWithPowerMgmt -gt 0) {
    Write-Host "  [!] $hubsWithPowerMgmt USB hub(s) have power management enabled" -ForegroundColor Yellow
    Write-Host "  FIX: Device Manager -> USB Root Hub -> Power Management -> Uncheck 'Allow computer to turn off'" -ForegroundColor Yellow
} else {
    Write-Host "  USB Hub power management: OK" -ForegroundColor Green
}

Write-Host ""
#endregion

#region Mouse Device Info
Write-Host "=== MOUSE DEVICE ===" -ForegroundColor Green

# Find Logitech mouse devices
$mice = Get-PnpDevice -Class Mouse -Status OK
$logiMice = $mice | Where-Object { $_.FriendlyName -like "*Logitech*" -or $_.FriendlyName -like "*MX*" }

if ($logiMice) {
    foreach ($mouse in $logiMice) {
        Write-Host "  Device: $($mouse.FriendlyName)" -ForegroundColor White
        Write-Host "  Status: $($mouse.Status)" -ForegroundColor White

        # Check driver
        $driver = Get-PnpDeviceProperty -InstanceId $mouse.InstanceId -KeyName "DEVPKEY_Device_DriverVersion" -ErrorAction SilentlyContinue
        if ($driver.Data) {
            Write-Host "  Driver: $($driver.Data)" -ForegroundColor White
        }
    }
} else {
    Write-Host "  No Logitech mouse found in Device Manager" -ForegroundColor Yellow
    Write-Host "  Looking for HID-compliant mice..." -ForegroundColor Gray
    $mice | Select-Object -First 3 | ForEach-Object {
        Write-Host "    - $($_.FriendlyName)" -ForegroundColor Gray
    }
}

# Check connection type
$btDevices = Get-PnpDevice -Class Bluetooth -Status OK -ErrorAction SilentlyContinue |
    Where-Object { $_.FriendlyName -like "*MX*" -or $_.FriendlyName -like "*Logitech*" }
if ($btDevices) {
    Write-Host ""
    Write-Host "  Connection: Bluetooth" -ForegroundColor Cyan
    Write-Host "  [TIP] Try using the Logi Bolt USB receiver instead for lower latency" -ForegroundColor Yellow
}

Write-Host ""
#endregion

#region High-Impact Background Processes
Write-Host "=== BACKGROUND PROCESSES (Potential Latency Sources) ===" -ForegroundColor Green

$suspectProcesses = @{
    "MsMpEng" = "Windows Defender (can cause periodic CPU spikes)"
    "SearchIndexer" = "Windows Search (can cause disk I/O spikes)"
    "OneDrive" = "OneDrive Sync (can cause CPU/network spikes)"
    "logioptionsplus_agent" = "Logi Options+ (known high CPU issue)"
    "NvContainer" = "NVIDIA Container (can cause DPC latency)"
    "nvcontainer" = "NVIDIA Container (can cause DPC latency)"
    "dwm" = "Desktop Window Manager (GPU scheduling)"
    "WmiPrvSE" = "WMI Provider (can spike periodically)"
    "TiWorker" = "Windows Update (heavy background activity)"
    "CompatTelRunner" = "Telemetry (periodic CPU spikes)"
}

foreach ($proc in $suspectProcesses.Keys) {
    $running = Get-Process -Name $proc -ErrorAction SilentlyContinue
    if ($running) {
        $cpu = [math]::Round(($running | Measure-Object -Property CPU -Sum).Sum, 2)
        $status = if ($cpu -gt 30) { "[HIGH]" } else { "[OK]" }
        $color = if ($cpu -gt 30) { "Yellow" } else { "Gray" }
        Write-Host "  $status $proc - $($suspectProcesses[$proc])" -ForegroundColor $color
        Write-Host "       CPU time: $cpu seconds" -ForegroundColor Gray
    }
}

Write-Host ""
#endregion

#region Chrome Specific
Write-Host "=== CHROME SETTINGS ===" -ForegroundColor Green

$chromeRunning = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
if ($chromeRunning) {
    Write-Host "  Chrome is running ($($chromeRunning.Count) processes)" -ForegroundColor White
    Write-Host ""
    Write-Host "  Recommended Chrome Flags to check:" -ForegroundColor Yellow
    Write-Host "    1. chrome://flags/#smooth-scrolling -> Enable" -ForegroundColor White
    Write-Host "    2. chrome://flags/#use-angle -> D3D9 (if 24H2)" -ForegroundColor White
    Write-Host ""
    Write-Host "  Also check:" -ForegroundColor Yellow
    Write-Host "    Settings -> System -> Use hardware acceleration" -ForegroundColor White
    Write-Host "    (Try toggling this to see if it helps)" -ForegroundColor White
} else {
    Write-Host "  Chrome not currently running" -ForegroundColor Gray
}

Write-Host ""
#endregion

#region Quick DPC Latency Check
if (-not $Quick) {
    Write-Host "=== DPC LATENCY CHECK ===" -ForegroundColor Green
    Write-Host "  Sampling for 5 seconds..." -ForegroundColor Gray

    # Basic latency indicator using timer resolution
    $samples = @()
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt 5000) {
        $start = [System.Diagnostics.Stopwatch]::GetTimestamp()
        Start-Sleep -Milliseconds 1
        $end = [System.Diagnostics.Stopwatch]::GetTimestamp()
        $elapsed = ($end - $start) / [System.Diagnostics.Stopwatch]::Frequency * 1000
        $samples += $elapsed
    }

    $avg = [math]::Round(($samples | Measure-Object -Average).Average, 2)
    $max = [math]::Round(($samples | Measure-Object -Maximum).Maximum, 2)

    Write-Host "  Average sleep accuracy: $avg ms (target: 1ms)" -ForegroundColor White
    Write-Host "  Maximum delay: $max ms" -ForegroundColor White

    if ($max -gt 15) {
        Write-Host "  [!] HIGH LATENCY SPIKES DETECTED" -ForegroundColor Red
        Write-Host "  This indicates something is blocking the system periodically" -ForegroundColor Yellow
        Write-Host "  RECOMMENDED: Download and run LatencyMon to identify the driver" -ForegroundColor Yellow
        Write-Host "  https://www.resplendence.com/latencymon" -ForegroundColor Cyan
    } elseif ($max -gt 5) {
        Write-Host "  [!] Moderate latency spikes detected" -ForegroundColor Yellow
    } else {
        Write-Host "  Latency looks OK" -ForegroundColor Green
    }
}

Write-Host ""
#endregion

#region Recommendations Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " RECOMMENDED ACTIONS (Priority Order)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$priority = 1

# 24H2 Chrome fix
if ($version -match "24H2") {
    Write-Host "$priority. [HIGH] Fix Chrome D3D11 scroll bug:" -ForegroundColor Red
    Write-Host "   - Open chrome://flags" -ForegroundColor White
    Write-Host "   - Search 'ANGLE'" -ForegroundColor White
    Write-Host "   - Set 'Choose ANGLE graphics backend' to D3D9" -ForegroundColor White
    Write-Host "   - Restart Chrome" -ForegroundColor White
    Write-Host ""
    $priority++
}

# Logi Options+ check
if ($foundLogi.Count -gt 0) {
    Write-Host "$priority. [HIGH] Check Logi Options+ SmartShift setting:" -ForegroundColor Red
    Write-Host "   - Open Logi Options+" -ForegroundColor White
    Write-Host "   - Select MX Master 3S -> Point & Scroll" -ForegroundColor White
    Write-Host "   - Try DISABLING SmartShift temporarily" -ForegroundColor White
    Write-Host "   - Also try disabling Smooth Scrolling" -ForegroundColor White
    Write-Host ""
    $priority++
}

# USB Selective Suspend
Write-Host "$priority. [MEDIUM] Disable USB Selective Suspend:" -ForegroundColor Yellow
Write-Host "   - Control Panel -> Power Options -> Change plan settings" -ForegroundColor White
Write-Host "   - Change advanced power settings" -ForegroundColor White
Write-Host "   - USB settings -> USB selective suspend -> Disabled" -ForegroundColor White
Write-Host ""
$priority++

# USB Hub power management
Write-Host "$priority. [MEDIUM] Disable USB Hub power management:" -ForegroundColor Yellow
Write-Host "   - Device Manager -> Universal Serial Bus controllers" -ForegroundColor White
Write-Host "   - For each USB Root Hub: Properties -> Power Management" -ForegroundColor White
Write-Host "   - Uncheck 'Allow the computer to turn off this device'" -ForegroundColor White
Write-Host ""
$priority++

# LatencyMon
Write-Host "$priority. [DIAGNOSTIC] Run LatencyMon to find driver issues:" -ForegroundColor Cyan
Write-Host "   - Download from: https://www.resplendence.com/latencymon" -ForegroundColor White
Write-Host "   - Run for 10+ minutes during normal use" -ForegroundColor White
Write-Host "   - Look for drivers with high DPC latency (red)" -ForegroundColor White
Write-Host "   - Common culprits: network drivers, NVMe drivers, GPU drivers" -ForegroundColor White
Write-Host ""
$priority++

# Connection type
if ($btDevices) {
    Write-Host "$priority. [OPTIONAL] Try Logi Bolt receiver instead of Bluetooth:" -ForegroundColor Gray
    Write-Host "   - Bluetooth can have interference and latency" -ForegroundColor White
    Write-Host "   - The USB receiver provides more reliable connection" -ForegroundColor White
    Write-Host ""
    $priority++
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " DIAGNOSTIC COMPLETE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
