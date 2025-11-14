#!/bin/bash
# WSL Performance Configuration Generator
# Generates optimized .wslconfig for dev laptop performance

set -euo pipefail

WSLCONFIG_PATH="/mnt/c/Users/$USER/.wslconfig"
BACKUP_PATH="/mnt/c/Users/$USER/.wslconfig.backup.$(date +%Y%m%d_%H%M%S)"

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
cat > "$WSLCONFIG_PATH" << EOF
# WSL2 Performance Configuration
# Generated: $(date)
# System: ${TOTAL_RAM_GB}GB RAM, ${CPU_CORES} cores

[wsl2]
# Memory allocation (50% of system RAM)
memory=${RECOMMENDED_RAM}GB

# Processor allocation (75% of system cores)
processors=${RECOMMENDED_CORES}

# Swap file size (match memory allocation)
swap=${RECOMMENDED_RAM}GB

# Swap file location (Windows temp)
swapfile=C:\\temp\\wsl-swap.vhdx

# Disable page reporting (performance boost)
pageReporting=false

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

echo "Configuration written to: $WSLCONFIG_PATH"
echo ""
echo "IMPORTANT: To apply these settings:"
echo "  1. Exit this WSL session"
echo "  2. From Windows PowerShell, run: wsl --shutdown"
echo "  3. Restart WSL"
echo ""
echo "Configuration complete!"
