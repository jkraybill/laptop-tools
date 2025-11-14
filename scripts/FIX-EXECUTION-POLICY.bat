@echo off
REM ========================================
REM  Fix PowerShell Execution Policy
REM ========================================
REM
REM This script sets your PowerShell execution policy to RemoteSigned
REM so you can run local scripts without the -ExecutionPolicy flag.
REM
REM This is a one-time fix. After running this, you can execute
REM PowerShell scripts normally with .\scriptname.ps1

echo ========================================
echo   PowerShell Execution Policy Fix
echo ========================================
echo.
echo This will set your PowerShell execution policy to "RemoteSigned"
echo.
echo What this means:
echo   - You can run locally-created scripts (like ours)
echo   - Downloaded scripts still require unblocking
echo   - Only affects your user account (not system-wide)
echo.
echo This is the recommended setting for development work.
echo.
pause

echo.
echo Setting execution policy...
powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force"

if %errorLevel% equ 0 (
    echo.
    echo ========================================
    echo SUCCESS! Execution policy updated.
    echo ========================================
    echo.
    echo You can now run PowerShell scripts with:
    echo   .\scriptname.ps1
    echo.
    echo No need to use -ExecutionPolicy Bypass anymore.
    echo.
) else (
    echo.
    echo ========================================
    echo ERROR: Could not update execution policy
    echo ========================================
    echo.
    echo Try running this batch file as Administrator.
    echo.
)

pause
