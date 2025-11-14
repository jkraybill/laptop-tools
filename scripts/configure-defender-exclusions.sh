#!/bin/bash
# Windows Defender Exclusions Helper
# Runs the PowerShell script to configure Defender exclusions
# Must be run from WSL

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PS1_SCRIPT="$SCRIPT_DIR/configure-defender-exclusions.ps1"

# Convert to Windows path
WIN_SCRIPT=$(wslpath -w "$PS1_SCRIPT")

echo "Windows Defender Exclusions Configuration"
echo "=========================================="
echo ""
echo "This will configure Windows Defender to exclude common dev paths and processes."
echo ""
echo "IMPORTANT: This requires Administrator privileges!"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Launching PowerShell (you may see a UAC prompt)..."
echo ""

# Run PowerShell script as administrator
powershell.exe -Command "Start-Process powershell -Verb RunAs -ArgumentList '-ExecutionPolicy Bypass -File \"$WIN_SCRIPT\"'"

echo ""
echo "PowerShell window launched. Check the elevated PowerShell window for results."
