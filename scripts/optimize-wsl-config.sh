#!/bin/bash
# WSL Performance Configuration Generator
# Generates optimized .wslconfig for dev laptop performance

set -euo pipefail

# Detect Windows username (not WSL username) from USERPROFILE
WINDOWS_USER=$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r')
WSLCONFIG_PATH="/mnt/c/Users/${WINDOWS_USER}/.wslconfig"
BACKUP_PATH="/mnt/c/Users/${WINDOWS_USER}/.wslconfig.backup.$(date +%Y%m%d_%H%M%S)"

echo "WSL Performance Configuration Generator"
echo "======================================="
echo ""

# Detect system resources
TOTAL_RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
CPU_CORES=$(nproc)

# Calculate recommended settings (use 50% of RAM, 75% of cores for WSL)
RECOMMENDED_RAM=$((TOTAL_RAM_GB / 2))
RECOMMENDED_CORES=$((CPU_CORES * 3 / 4))

# Ensure minimum values
[ "$RECOMMENDED_RAM" -lt 4 ] && RECOMMENDED_RAM=4
[ "$RECOMMENDED_CORES" -lt 2 ] && RECOMMENDED_CORES=2

echo "System detected:"
echo "  Total RAM: ${TOTAL_RAM_GB}GB"
echo "  CPU Cores: ${CPU_CORES}"
echo ""
echo "Recommended WSL settings:"
echo "  Memory: ${RECOMMENDED_RAM}GB"
echo "  Processors: ${RECOMMENDED_CORES}"
echo ""

# Check if .wslconfig already exists
if [ -f "$WSLCONFIG_PATH" ]; then
    echo "Existing .wslconfig found - creating backup..."
    cp "$WSLCONFIG_PATH" "$BACKUP_PATH"
    echo "Backup saved to: $BACKUP_PATH"
    echo ""
fi

# Generate .wslconfig
cat > "$WSLCONFIG_PATH" << 'EOF'
# WSL2 Performance Configuration
# Generated automatically
# For best performance on dev laptop

[wsl2]
# Memory allocation (50% of system RAM)
memory=MEMORY_PLACEHOLDER

# Processor allocation (75% of system cores)
processors=PROCESSORS_PLACEHOLDER

# Swap file size (match memory allocation)
swap=SWAP_PLACEHOLDER

# Swap file location (Windows temp) - use forward slashes
swapfile=C:/temp/wsl-swap.vhdx

# Network mode (default NAT for compatibility)
# networkingMode=mirrored  # Uncomment for mirrored mode (Windows 11 22H2+)

# Kernel parameters for performance
kernelCommandLine=sysctl.vm.swappiness=10

# Localhost forwarding enabled
localhostForwarding=true

# Nested virtualization (enable if needed for Docker)
nestedVirtualization=true

# GUI support (WSLg)
guiApplications=true

# Debug console (disable for production)
debugConsole=false
EOF

# Replace placeholders with actual values
sed -i "s/MEMORY_PLACEHOLDER/${RECOMMENDED_RAM}GB/g" "$WSLCONFIG_PATH"
sed -i "s/PROCESSORS_PLACEHOLDER/${RECOMMENDED_CORES}/g" "$WSLCONFIG_PATH"
sed -i "s/SWAP_PLACEHOLDER/${RECOMMENDED_RAM}GB/g" "$WSLCONFIG_PATH"

echo "Configuration written to: $WSLCONFIG_PATH"
echo ""
echo "IMPORTANT: To apply these settings:"
echo "  1. Exit this WSL session"
echo "  2. From Windows PowerShell, run: wsl --shutdown"
echo "  3. Restart WSL"
echo ""
echo "Configuration complete!"
