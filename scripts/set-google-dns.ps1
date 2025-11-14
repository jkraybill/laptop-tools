#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Sets DNS servers to Google Public DNS (8.8.8.8 and 8.8.4.4)

.DESCRIPTION
    Changes DNS settings for active network adapters to Google's public DNS servers.
    Backs up current settings before making changes.

.NOTES
    Author: Gordo
    Created: 2025-11-15
    Requires: Administrator privileges
#>

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Google DNS Configuration Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Create backup directory if it doesn't exist
$backupDir = Join-Path $PSScriptRoot "backups"
if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir | Out-Null
}

# Backup current DNS settings
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupFile = Join-Path $backupDir "dns-backup-$timestamp.txt"

Write-Host "[1/4] Backing up current DNS settings..." -ForegroundColor Yellow
Get-DnsClientServerAddress | Out-File $backupFile
Write-Host "      Backup saved to: $backupFile" -ForegroundColor Green
Write-Host ""

# Get active network adapters (excluding virtual adapters, loopback, etc.)
Write-Host "[2/4] Detecting active network adapters..." -ForegroundColor Yellow
$adapters = Get-NetAdapter | Where-Object {
    $_.Status -eq "Up" -and
    $_.Name -notmatch "vEthernet|Loopback|Bluetooth" -and
    $_.InterfaceDescription -notmatch "Virtual|Loopback|WAN Miniport"
}

if ($adapters.Count -eq 0) {
    Write-Host "      ERROR: No active network adapters found!" -ForegroundColor Red
    exit 1
}

Write-Host "      Found $($adapters.Count) active adapter(s):" -ForegroundColor Green
foreach ($adapter in $adapters) {
    Write-Host "      - $($adapter.Name) ($($adapter.InterfaceDescription))" -ForegroundColor Cyan
}
Write-Host ""

# Google DNS servers
$primaryDNS = "8.8.8.8"
$secondaryDNS = "8.8.4.4"

Write-Host "[3/4] Setting Google DNS servers..." -ForegroundColor Yellow
foreach ($adapter in $adapters) {
    try {
        # Set IPv4 DNS servers
        Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses ($primaryDNS, $secondaryDNS)
        Write-Host "      SUCCESS: DNS updated for $($adapter.Name)" -ForegroundColor Green
        Write-Host "               Primary: $primaryDNS" -ForegroundColor Gray
        Write-Host "               Secondary: $secondaryDNS" -ForegroundColor Gray
    }
    catch {
        Write-Host "      ERROR: Failed to update $($adapter.Name)" -ForegroundColor Red
        Write-Host "             $($_.Exception.Message)" -ForegroundColor Red
    }
}
Write-Host ""

# Verify DNS settings
Write-Host "[4/4] Verifying DNS configuration..." -ForegroundColor Yellow
foreach ($adapter in $adapters) {
    $dnsServers = Get-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4
    Write-Host "      $($adapter.Name):" -ForegroundColor Cyan
    if ($dnsServers.ServerAddresses.Count -gt 0) {
        foreach ($dns in $dnsServers.ServerAddresses) {
            Write-Host "      - $dns" -ForegroundColor Green
        }
    } else {
        Write-Host "      - (Automatic/DHCP)" -ForegroundColor Yellow
    }
}
Write-Host ""

# Flush DNS cache
Write-Host "[BONUS] Flushing DNS cache..." -ForegroundColor Yellow
try {
    Clear-DnsClientCache
    Write-Host "        DNS cache cleared successfully" -ForegroundColor Green
}
catch {
    Write-Host "        Warning: Could not clear DNS cache" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "DNS Configuration Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Google DNS servers are now active." -ForegroundColor White
Write-Host "To restore previous settings, see: $backupFile" -ForegroundColor Gray
Write-Host ""
