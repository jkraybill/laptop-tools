@echo off
REM Dropbox Catalog Runner (Windows)
REM Created: 2025-11-15

echo ========================================
echo Dropbox Catalog Generator
echo ========================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed!
    echo Please install Python 3 and try again.
    echo.
    pause
    exit /b 1
)

echo Python version:
python --version
echo.

REM Check if dropbox package is installed
python -c "import dropbox" >nul 2>&1
if errorlevel 1 (
    echo Warning: Dropbox Python package not found
    echo.
    echo Installing dependencies...
    pip install -r "%~dp0dropbox-requirements.txt"
    echo.
)

REM Run the script
echo Starting catalog script...
echo.
python "%~dp0catalog-dropbox.py"

echo.
echo ========================================
echo Done!
echo ========================================
echo.
pause
