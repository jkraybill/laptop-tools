#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Creates comprehensive system catalog for migration planning

.DESCRIPTION
    Scans the system and creates a detailed catalog of:
    - Installed applications
    - User files and directories
    - Development environments (Git repos, projects)
    - Configuration files
    - File statistics by type/location

    Output: JSON catalog file that can be used to plan migration to new system

.NOTES
    Author: Gordo
    Created: 2025-11-15
    Purpose: Old laptop cataloging for migration to new laptop
    Safe: Read-only operations, no modifications
#>

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "System Catalog Generator" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script will catalog your system for migration planning." -ForegroundColor White
Write-Host "It performs READ-ONLY operations and makes no changes." -ForegroundColor Green
Write-Host ""

$catalog = @{
    metadata = @{
        computerName = $env:COMPUTERNAME
        userName = $env:USERNAME
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        osVersion = [System.Environment]::OSVersion.VersionString
    }
    installedPrograms = @()
    userDirectories = @{}
    developmentProjects = @{
        gitRepos = @()
        nodeProjects = @()
        pythonProjects = @()
        otherProjects = @()
    }
    configFiles = @{}
    fileStatistics = @{}
    browserData = @{}
}

# Helper function to get directory size safely
function Get-DirectorySize {
    param([string]$Path)
    try {
        if (Test-Path $Path) {
            $size = (Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
                     Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            return [math]::Round($size / 1MB, 2)
        }
    }
    catch {
        return 0
    }
    return 0
}

# Helper function to count files by extension
function Get-FileTypeStats {
    param([string]$Path)
    try {
        if (Test-Path $Path) {
            $files = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue
            $stats = $files | Group-Object Extension | Select-Object @{
                Name='Extension'; Expression={if($_.Name) {$_.Name} else {'(no extension)'}}
            }, Count, @{
                Name='TotalSizeMB'; Expression={[math]::Round(($_.Group | Measure-Object Length -Sum).Sum / 1MB, 2)}
            } | Sort-Object TotalSizeMB -Descending
            return $stats
        }
    }
    catch {
        return @()
    }
    return @()
}

# 1. Get installed programs
Write-Host "[1/7] Cataloging installed programs..." -ForegroundColor Yellow
try {
    # From registry (64-bit and 32-bit)
    $regPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $programs = foreach ($path in $regPaths) {
        Get-ItemProperty $path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName } |
            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, EstimatedSizeMB
    }

    $catalog.installedPrograms = $programs |
        Sort-Object DisplayName -Unique |
        Select-Object -Property @{Name='Name';Expression={$_.DisplayName}},
                                @{Name='Version';Expression={$_.DisplayVersion}},
                                Publisher,
                                InstallDate,
                                @{Name='SizeMB';Expression={[math]::Round($_.EstimatedSizeMB, 2)}}

    Write-Host "      Found $($catalog.installedPrograms.Count) installed programs" -ForegroundColor Green
}
catch {
    Write-Host "      Warning: Could not fully enumerate installed programs" -ForegroundColor Yellow
}
Write-Host ""

# 2. Catalog user directories
Write-Host "[2/7] Cataloging user directories..." -ForegroundColor Yellow
$userProfile = $env:USERPROFILE
$userDirs = @(
    "Desktop",
    "Documents",
    "Downloads",
    "Pictures",
    "Videos",
    "Music",
    "OneDrive",
    ".ssh",
    "AppData\Roaming",
    "AppData\Local"
)

foreach ($dir in $userDirs) {
    $fullPath = Join-Path $userProfile $dir
    if (Test-Path $fullPath) {
        $sizeMB = Get-DirectorySize -Path $fullPath
        $fileCount = (Get-ChildItem -Path $fullPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count

        $catalog.userDirectories[$dir] = @{
            path = $fullPath
            exists = $true
            sizeMB = $sizeMB
            fileCount = $fileCount
        }

        Write-Host "      $dir : $sizeMB MB ($fileCount files)" -ForegroundColor Cyan
    }
}
Write-Host ""

# 3. Find development projects
Write-Host "[3/7] Scanning for development projects..." -ForegroundColor Yellow

# Common project locations
$projectLocations = @(
    (Join-Path $userProfile "Documents"),
    (Join-Path $userProfile "Desktop"),
    (Join-Path $userProfile "Projects"),
    (Join-Path $userProfile "dev"),
    (Join-Path $userProfile "code"),
    (Join-Path $userProfile "source"),
    "C:\Projects",
    "C:\dev",
    "C:\code"
)

foreach ($location in $projectLocations) {
    if (Test-Path $location) {
        # Find Git repos
        $gitRepos = Get-ChildItem -Path $location -Recurse -Directory -Filter ".git" -ErrorAction SilentlyContinue -Depth 3
        foreach ($repo in $gitRepos) {
            $repoPath = Split-Path $repo.FullName -Parent
            $repoName = Split-Path $repoPath -Leaf
            $sizeMB = Get-DirectorySize -Path $repoPath

            # Try to get remote URL
            $remoteUrl = ""
            try {
                Push-Location $repoPath
                $remoteUrl = (git config --get remote.origin.url 2>$null) -replace "`n", ""
                Pop-Location
            }
            catch {
                Pop-Location
            }

            $catalog.developmentProjects.gitRepos += @{
                name = $repoName
                path = $repoPath
                remoteUrl = $remoteUrl
                sizeMB = $sizeMB
            }
        }

        # Find Node.js projects (package.json)
        $nodeProjects = Get-ChildItem -Path $location -Recurse -File -Filter "package.json" -ErrorAction SilentlyContinue -Depth 3
        foreach ($pkg in $nodeProjects) {
            $projectPath = Split-Path $pkg.FullName -Parent
            $projectName = Split-Path $projectPath -Leaf
            $sizeMB = Get-DirectorySize -Path $projectPath

            $catalog.developmentProjects.nodeProjects += @{
                name = $projectName
                path = $projectPath
                sizeMB = $sizeMB
            }
        }

        # Find Python projects (requirements.txt, setup.py, pyproject.toml)
        $pythonIndicators = @("requirements.txt", "setup.py", "pyproject.toml")
        foreach ($indicator in $pythonIndicators) {
            $pythonProjects = Get-ChildItem -Path $location -Recurse -File -Filter $indicator -ErrorAction SilentlyContinue -Depth 3
            foreach ($proj in $pythonProjects) {
                $projectPath = Split-Path $proj.FullName -Parent
                $projectName = Split-Path $projectPath -Leaf
                $sizeMB = Get-DirectorySize -Path $projectPath

                # Check if not already added
                if (-not ($catalog.developmentProjects.pythonProjects | Where-Object { $_.path -eq $projectPath })) {
                    $catalog.developmentProjects.pythonProjects += @{
                        name = $projectName
                        path = $projectPath
                        indicator = $indicator
                        sizeMB = $sizeMB
                    }
                }
            }
        }
    }
}

Write-Host "      Found $($catalog.developmentProjects.gitRepos.Count) Git repositories" -ForegroundColor Green
Write-Host "      Found $($catalog.developmentProjects.nodeProjects.Count) Node.js projects" -ForegroundColor Green
Write-Host "      Found $($catalog.developmentProjects.pythonProjects.Count) Python projects" -ForegroundColor Green
Write-Host ""

# 4. Find important config files
Write-Host "[4/7] Locating configuration files..." -ForegroundColor Yellow

$configLocations = @{
    ".gitconfig" = (Join-Path $userProfile ".gitconfig")
    ".ssh" = (Join-Path $userProfile ".ssh")
    ".bashrc" = (Join-Path $userProfile ".bashrc")
    ".bash_profile" = (Join-Path $userProfile ".bash_profile")
    ".zshrc" = (Join-Path $userProfile ".zshrc")
    "VSCode settings" = (Join-Path $userProfile "AppData\Roaming\Code\User\settings.json")
    "VSCode keybindings" = (Join-Path $userProfile "AppData\Roaming\Code\User\keybindings.json")
    ".aws" = (Join-Path $userProfile ".aws")
    ".docker" = (Join-Path $userProfile ".docker")
}

foreach ($configName in $configLocations.Keys) {
    $configPath = $configLocations[$configName]
    if (Test-Path $configPath) {
        $isDir = (Get-Item $configPath) -is [System.IO.DirectoryInfo]
        $catalog.configFiles[$configName] = @{
            path = $configPath
            exists = $true
            isDirectory = $isDir
            sizeMB = if ($isDir) { Get-DirectorySize -Path $configPath } else {
                [math]::Round((Get-Item $configPath).Length / 1MB, 2)
            }
        }
        Write-Host "      Found: $configName" -ForegroundColor Green
    }
}
Write-Host ""

# 5. File statistics by category
Write-Host "[5/7] Analyzing file statistics..." -ForegroundColor Yellow

$categories = @{
    "Documents" = @("*.doc", "*.docx", "*.pdf", "*.txt", "*.xlsx", "*.xls", "*.pptx", "*.ppt")
    "Images" = @("*.jpg", "*.jpeg", "*.png", "*.gif", "*.bmp", "*.svg", "*.ico")
    "Videos" = @("*.mp4", "*.avi", "*.mkv", "*.mov", "*.wmv", "*.flv")
    "Audio" = @("*.mp3", "*.wav", "*.flac", "*.m4a", "*.aac")
    "Archives" = @("*.zip", "*.rar", "*.7z", "*.tar", "*.gz")
    "Code" = @("*.js", "*.ts", "*.py", "*.java", "*.cpp", "*.c", "*.cs", "*.go", "*.rs", "*.rb", "*.php")
}

foreach ($category in $categories.Keys) {
    $extensions = $categories[$category]
    $files = @()

    # Search in user profile (faster, more relevant)
    try {
        foreach ($ext in $extensions) {
            $found = Get-ChildItem -Path $userProfile -Recurse -File -Filter $ext -ErrorAction SilentlyContinue
            $files += $found
        }

        if ($files.Count -gt 0) {
            $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
            $catalog.fileStatistics[$category] = @{
                count = $files.Count
                totalSizeMB = [math]::Round($totalSize / 1MB, 2)
                averageSizeMB = [math]::Round(($totalSize / $files.Count) / 1MB, 2)
            }
            Write-Host "      $category : $($files.Count) files, $([math]::Round($totalSize / 1MB, 2)) MB" -ForegroundColor Cyan
        }
    }
    catch {
        Write-Host "      Warning: Error scanning $category files" -ForegroundColor Yellow
    }
}
Write-Host ""

# 6. Browser data (Chrome/Edge)
Write-Host "[6/7] Checking browser data..." -ForegroundColor Yellow

$browserPaths = @{
    "Chrome" = (Join-Path $userProfile "AppData\Local\Google\Chrome\User Data\Default")
    "Edge" = (Join-Path $userProfile "AppData\Local\Microsoft\Edge\User Data\Default")
}

foreach ($browser in $browserPaths.Keys) {
    $browserPath = $browserPaths[$browser]
    if (Test-Path $browserPath) {
        $bookmarksPath = Join-Path $browserPath "Bookmarks"
        $extensionsPath = Join-Path (Split-Path $browserPath -Parent) "Extensions"

        $catalog.browserData[$browser] = @{
            hasBookmarks = Test-Path $bookmarksPath
            bookmarksPath = $bookmarksPath
            hasExtensions = Test-Path $extensionsPath
            extensionsPath = $extensionsPath
            profileSizeMB = Get-DirectorySize -Path $browserPath
        }

        Write-Host "      $browser profile found ($($catalog.browserData[$browser].profileSizeMB) MB)" -ForegroundColor Green
    }
}
Write-Host ""

# 7. Save catalog
Write-Host "[7/7] Saving catalog..." -ForegroundColor Yellow

$outputDir = Join-Path $PSScriptRoot "catalog"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$jsonFile = Join-Path $outputDir "system-catalog-$timestamp.json"
$txtFile = Join-Path $outputDir "system-catalog-$timestamp.txt"

# Save JSON
$catalog | ConvertTo-Json -Depth 10 | Out-File $jsonFile -Encoding UTF8

# Save human-readable text
$summary = @"
========================================
SYSTEM CATALOG
========================================
Computer: $($catalog.metadata.computerName)
User: $($catalog.metadata.userName)
Generated: $($catalog.metadata.timestamp)
OS: $($catalog.metadata.osVersion)

========================================
INSTALLED PROGRAMS ($($catalog.installedPrograms.Count))
========================================
$($catalog.installedPrograms | Format-Table Name, Version, Publisher, SizeMB -AutoSize | Out-String)

========================================
USER DIRECTORIES
========================================
$($catalog.userDirectories.Keys | ForEach-Object {
    "$_ : $($catalog.userDirectories[$_].sizeMB) MB ($($catalog.userDirectories[$_].fileCount) files)"
} | Out-String)

========================================
DEVELOPMENT PROJECTS
========================================
Git Repositories ($($catalog.developmentProjects.gitRepos.Count)):
$($catalog.developmentProjects.gitRepos | ForEach-Object {
    "  - $($_.name) ($($_.sizeMB) MB)`n    Path: $($_.path)`n    Remote: $($_.remoteUrl)"
} | Out-String)

Node.js Projects ($($catalog.developmentProjects.nodeProjects.Count)):
$($catalog.developmentProjects.nodeProjects | ForEach-Object {
    "  - $($_.name) ($($_.sizeMB) MB) - $($_.path)"
} | Out-String)

Python Projects ($($catalog.developmentProjects.pythonProjects.Count)):
$($catalog.developmentProjects.pythonProjects | ForEach-Object {
    "  - $($_.name) ($($_.sizeMB) MB) - $($_.path)"
} | Out-String)

========================================
CONFIGURATION FILES
========================================
$($catalog.configFiles.Keys | ForEach-Object {
    "$_ : $($catalog.configFiles[$_].path) ($($catalog.configFiles[$_].sizeMB) MB)"
} | Out-String)

========================================
FILE STATISTICS
========================================
$($catalog.fileStatistics.Keys | ForEach-Object {
    "$_ : $($catalog.fileStatistics[$_].count) files, $($catalog.fileStatistics[$_].totalSizeMB) MB"
} | Out-String)

========================================
BROWSER DATA
========================================
$($catalog.browserData.Keys | ForEach-Object {
    "$_ :`n  Profile Size: $($catalog.browserData[$_].profileSizeMB) MB`n  Has Bookmarks: $($catalog.browserData[$_].hasBookmarks)`n  Has Extensions: $($catalog.browserData[$_].hasExtensions)"
} | Out-String)

========================================
END OF CATALOG
========================================
"@

$summary | Out-File $txtFile -Encoding UTF8

Write-Host "      JSON catalog saved: $jsonFile" -ForegroundColor Green
Write-Host "      Text summary saved: $txtFile" -ForegroundColor Green
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "Catalog Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Copy these files to your new laptop:" -ForegroundColor White
Write-Host "  1. $jsonFile" -ForegroundColor Cyan
Write-Host "  2. $txtFile" -ForegroundColor Cyan
Write-Host ""
Write-Host "Then feed them to Gordo for migration planning!" -ForegroundColor White
Write-Host ""
