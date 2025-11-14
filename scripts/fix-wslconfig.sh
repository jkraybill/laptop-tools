#!/bin/bash
# Quick fix for corrupted .wslconfig
# Fixes path escaping and removes invalid pageReporting key

set -euo pipefail

WINDOWS_USER=$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r')
WSLCONFIG_PATH="/mnt/c/Users/${WINDOWS_USER}/.wslconfig"

echo "Fixing .wslconfig..."

# Fix the swapfile path (backslashes to forward slashes)
sed -i 's|swapfile=C:\\temp\\wsl-swap.vhdx|swapfile=C:/temp/wsl-swap.vhdx|g' "$WSLCONFIG_PATH"

# Remove the invalid pageReporting line
sed -i '/pageReporting=false/d' "$WSLCONFIG_PATH"
sed -i '/# Disable page reporting/d' "$WSLCONFIG_PATH"

echo "Fixed! Changes made:"
echo "  - Changed swapfile path to use forward slashes"
echo "  - Removed invalid pageReporting setting"
echo ""
echo "Run 'wsl --shutdown' from PowerShell and restart WSL to apply."
