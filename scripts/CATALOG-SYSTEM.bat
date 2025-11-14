@echo off
REM Run system catalog script with admin privileges
REM Created: 2025-11-15

echo ========================================
echo System Catalog Generator
echo ========================================
echo.
echo This will scan your system and create a catalog of:
echo   - Installed programs
echo   - User files and directories
echo   - Development projects (Git, Node, Python)
echo   - Configuration files
echo   - File statistics
echo   - Browser data
echo.
echo This is READ-ONLY and makes no changes to your system.
echo.
echo Press any key to continue or Ctrl+C to cancel...
pause >nul

PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0catalog-system.ps1'"

echo.
echo Press any key to exit...
pause >nul
