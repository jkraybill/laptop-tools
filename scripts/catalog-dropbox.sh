#!/bin/bash
#
# Dropbox Catalog Runner (Linux/WSL)
# Created: 2025-11-15
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/catalog-dropbox.py"
REQUIREMENTS="$SCRIPT_DIR/dropbox-requirements.txt"

echo "========================================"
echo "Dropbox Catalog Generator"
echo "========================================"
echo ""

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "✗ Python 3 is not installed!"
    echo "  Please install Python 3 and try again."
    exit 1
fi

echo "Python version: $(python3 --version)"
echo ""

# Check if dropbox package is installed
if ! python3 -c "import dropbox" 2>/dev/null; then
    echo "⚠️  Dropbox Python package not found"
    echo ""
    echo "Installing dependencies..."
    pip3 install -r "$REQUIREMENTS"
    echo ""
fi

# Run the script
echo "Starting catalog script..."
echo ""
python3 "$PYTHON_SCRIPT"

echo ""
echo "========================================"
echo "Done!"
echo "========================================"
