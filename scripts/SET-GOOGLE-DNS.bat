@echo off
REM Run Google DNS configuration script with admin privileges
REM Created: 2025-11-15

echo ========================================
echo Google DNS Configuration
echo ========================================
echo.
echo This will set your DNS to Google Public DNS:
echo   Primary:   8.8.8.8
echo   Secondary: 8.8.4.4
echo.
echo Press any key to continue or Ctrl+C to cancel...
pause >nul

PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0set-google-dns.ps1'"

echo.
echo Press any key to exit...
pause >nul
