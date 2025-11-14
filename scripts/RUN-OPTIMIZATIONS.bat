@echo off
REM ========================================
REM  Laptop Optimization Suite Launcher
REM ========================================
REM
REM This batch file runs all PowerShell optimization scripts
REM with execution policy bypass (no policy changes needed).
REM
REM Run this as Administrator!

echo ========================================
echo   Laptop Optimization Suite
echo ========================================
echo.

REM Check for admin privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script requires Administrator privileges.
    echo Please right-click and select "Run as Administrator"
    echo.
    pause
    exit /b 1
)

echo Running as Administrator - Good!
echo.
echo This will run optimization scripts in order:
echo   1. Startup Programs Cleanup
echo   2. Visual Effects Optimization
echo   3. Power Plan Optimization
echo   4. Services Optimization
echo.
echo Each script will prompt for confirmation.
echo You can review and approve/cancel each step.
echo.
pause

echo.
echo ========================================
echo  Step 1: Startup Programs Cleanup
echo ========================================
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0optimize-startup-programs.ps1"
if %errorLevel% neq 0 (
    echo.
    echo Script encountered an error or was cancelled.
    echo.
)

echo.
echo ========================================
echo  Step 2: Visual Effects Optimization
echo ========================================
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0optimize-visual-effects.ps1"
if %errorLevel% neq 0 (
    echo.
    echo Script encountered an error or was cancelled.
    echo.
)

echo.
echo ========================================
echo  Step 3: Power Plan Optimization
echo ========================================
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0optimize-power-plan.ps1"
if %errorLevel% neq 0 (
    echo.
    echo Script encountered an error or was cancelled.
    echo.
)

echo.
echo ========================================
echo  Step 4: Services Optimization
echo ========================================
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0optimize-services.ps1"
if %errorLevel% neq 0 (
    echo.
    echo Script encountered an error or was cancelled.
    echo.
)

echo.
echo ========================================
echo  ALL OPTIMIZATIONS COMPLETE!
echo ========================================
echo.
echo RECOMMENDED: Restart your computer for all changes to take effect.
echo.
pause
