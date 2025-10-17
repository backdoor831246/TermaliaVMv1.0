<#
Tweaker_Update.ps1
Universal PowerShell Tools Downloader and Configurator
Author: Coder + ChatGPT
#>

# --- Require Administrator ---
function Assert-Admin {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "Please run this script as Administrator." -ForegroundColor Red
        exit 1
    }
}
Assert-Admin

# --- Base paths ---
$UserProfile = $env:USERPROFILE
$ToolsRoot = Join-Path $UserProfile 'tools'
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$WallpaperFile = Join-Path $ScriptRoot 'wallpaper\TermaliaVM.png'
$LogFile = Join-Path $ToolsRoot 'install_log.txt'

# Create directories
New-Item -Path $ToolsRoot -ItemType Directory -Force | Out-Null
New-Item -Path (Join-Path $ToolsRoot 'wallpaper') -ItemType Directory -Force | Out-Null

# --- Simple logger ---
function Log {
    param($msg)
    $t = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "$t`t$msg"
    $line | Out-File -FilePath $LogFile -Append -Encoding UTF8
    Write-Host $msg
}
Log "Tweaker started."

# --- Download helpers ---
function Get-FilenameFromUrl {
    param($url)
    $u = $url.Split('?')[0]
    return [IO.Path]::GetFileName($u)
}

function Download-File {
    param([string]$Url, [string]$OutPath)
    try {
        $dir = Split-Path $OutPath -Parent
        if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
        Log "Downloading: $Url"
        Invoke-WebRequest -Uri $Url -OutFile $OutPath -UseBasicParsing -TimeoutSec 120 -ErrorAction Stop
        return $true
    } catch {
        Log "Download failed: $Url : $_"
        return $false
    }
}

function Extract-ZipSafe {
    param($zipPath, $dest)
    try {
        if (-not (Test-Path $zipPath)) { Log "Archive not found: $zipPath"; return $false }
        if (-not (Test-Path $dest)) { New-Item -Path $dest -ItemType Directory -Force | Out-Null }
        Expand-Archive -LiteralPath $zipPath -DestinationPath $dest -Force
        Log "Extracted: $zipPath -> $dest"
        return $true
    } catch {
        Log "Extraction error: $zipPath : $_"
        return $false
    }
}

# --- Install Chocolatey if missing ---
function Install-ChocoIfMissing {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Log "Chocolatey not found. Attempting installation..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        try {
            iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
            Log "Chocolatey installation completed."
        } catch {
            Log "Chocolatey installation failed: $_"
        }
    } else {
        Log "Chocolatey already installed."
    }
}

# --- Install WinGet if missing ---
function Install-WingetIfMissing {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Log "WinGet not found. Attempting installation from Microsoft..."
        $tmp = Join-Path $env:TEMP 'winget.msixbundle'
        try {
            Invoke-WebRequest -Uri 'https://aka.ms/getwinget' -OutFile $tmp -UseBasicParsing -ErrorAction Stop
            Add-AppxPackage -Path $tmp -ErrorAction Stop
            Remove-Item $tmp -ErrorAction SilentlyContinue
            Log "WinGet installed."
        } catch {
            Log "Failed to install WinGet: $_"
        }
    } else {
        Log "WinGet available."
    }
}

# --- Interactive installer run ---
function Run-InstallerInteractive {
    param($filePath, $workDir=$null)
    if (-not (Test-Path $filePath)) { Log "Installer not found: $filePath"; return }
    Log "Launching interactive installer: $filePath"
    if ($workDir) { Start-Process -FilePath $filePath -WorkingDirectory $workDir }
    else { Start-Process -FilePath $filePath }
}

# --- Tool list ---
$tools = @{
    "TDM-GCC" = @{
        url = "https://github.com/jmeubank/tdm-gcc/releases/download/v10.3.0-tdm64-2/tdm64-gcc-10.3.0-2.exe"
        dest = Join-Path $ToolsRoot "TDM-GCC\tdm64-gcc-10.3.0-2.exe"
        interactive = $true
    }
    "Bytecode-Viewer" = @{
        url = "https://github.com/Konloch/bytecode-viewer/releases/download/v2.13.1/Bytecode-Viewer-2.13.1.jar"
        dest = Join-Path $ToolsRoot "Bytecode-Viewer\Bytecode-Viewer-2.13.1.jar"
    }
    "de4dot-cex" = @{
        url = "https://github.com/ViRb3/de4dot-cex/releases/download/v4.0.0/de4dot-cex.zip"
        dest = Join-Path $ToolsRoot "de4dot-cex\de4dot-cex.zip"
        extractTo = Join-Path $ToolsRoot "de4dot-cex"
    }
    "HxD" = @{
        url = "https://mh-nexus.de/downloads/HxDSetup.zip"
        dest = Join-Path $ToolsRoot "HxD\HxDSetup.zip"
        extractTo = Join-Path $ToolsRoot "HxD"
    }
    "PS2EXE" = @{
        url = "https://github.com/MScholtes/PS2EXE/archive/refs/heads/master.zip"
        dest = Join-Path $ToolsRoot "PS2EXE_repo\PS2EXE-master.zip"
        extractTo = Join-Path $ToolsRoot "PS2EXE"
    }
    "TrID" = @{
        url = "https://mark0.net/download/trid_win64.zip"
        dest = Join-Path $ToolsRoot "TrID\trid_win64.zip"
        extractTo = Join-Path $ToolsRoot "TrID"
    }
    "CapCut" = @{
        url = "https://www.capcut.com/activity/download_pc?from_page=landing_page&enter_from=a1.b1.c2.0"
        dest = Join-Path $ToolsRoot "CapCut\CapCutInstaller.exe"
        interactive = $true
    }
    "SublimeText" = @{
        url = "https://www.sublimetext.com/download_thanks?target=win-x64"
        dest = Join-Path $ToolsRoot "SublimeText\SublimeSetup.exe"
        interactive = $true
    }
    "VidCutter" = @{
        url = "https://github.com/ozmartian/vidcutter/releases/download/6.0.5.1/VidCutter-6.0.5.1-setup-win64.exe"
        dest = Join-Path $ToolsRoot "VidCutter\VidCutter-6.0.5.1-setup-win64.exe"
        interactive = $true
    }
    "UPX" = @{
        url = "https://github.com/upx/upx/releases/download/v5.0.2/upx-5.0.2-win64.zip"
        dest = Join-Path $ToolsRoot "UPX\upx-5.0.2-win64.zip"
        extractTo = Join-Path $ToolsRoot "UPX"
    }
    "x64dbg" = @{
        url = "https://github.com/x64dbg/x64dbg/releases/download/2025.08.19/snapshot_2025-08-19_19-40.zip"
        dest = Join-Path $ToolsRoot "x64dbg\snapshot_2025-08-19_19-40.zip"
        extractTo = Join-Path $ToolsRoot "x64dbg"
    }
    "dnSpy" = @{
        url = "https://github.com/dnSpyEx/dnSpy/releases/download/v6.5.1/dnSpy-netframework.zip"
        dest = Join-Path $ToolsRoot "dnSpy\dnSpy-netframework.zip"
        extractTo = Join-Path $ToolsRoot "dnSpy"
    }
}

# --- Prepare Chocolatey ---
Install-ChocoIfMissing
Install-WingetIfMissing

# --- Install useful packages via Chocolatey (without Chrome/Discord) ---
$chocoPackages = @(
    '7zip', 'vcredist-all', 'upx', 'sublimetext3', 'hxd'
)
foreach ($pkg in $chocoPackages) {
    try {
        Log "Installing via choco: $pkg ..."
        choco install $pkg -y --no-progress | Out-Null
        Log "choco install $pkg completed."
    } catch {
        Log "choco install failed for $pkg : $_"
    }
}

# --- Download and extract all tools ---
foreach ($name in $tools.Keys) {
    $t = $tools[$name]
    $url = $t.url
    $dest = $t.dest
    $extract = if ($t.ContainsKey('extractTo')) { $t.extractTo } else { $null }
    $interactive = if ($t.ContainsKey('interactive')) { $t.interactive } else { $false }

    Log "Processing $name ..."
    if (Download-File -Url $url -OutPath $dest) {
        if ($extract) { Extract-ZipSafe -zipPath $dest -dest $extract }
        if ($interactive) { Run-InstallerInteractive -filePath $dest }
    }
}

# --- Apply Dark Theme ---
try {
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
    Set-ItemProperty -Path $key -Name 'AppsUseLightTheme' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $key -Name 'SystemUsesLightTheme' -Value 0 -Type DWord -Force
    Log "Dark theme applied."
} catch { Log "Dark theme setup failed: $_" }

# --- Set Wallpaper ---
function Set-Wallpaper {
    param($imgPath)
    if (-not (Test-Path $imgPath)) { Log "Wallpaper not found: $imgPath"; return }
    try {
        Add-Type @"
using System.Runtime.InteropServices;
namespace Win32 {
  public class NativeMethods {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
  }
}
"@
        [Win32.NativeMethods]::SystemParametersInfo(20, 0, $imgPath, 3) | Out-Null
        Log "Wallpaper applied: $imgPath"
    } catch { Log "Wallpaper failed: $_" }
}

if (Test-Path $WallpaperFile) {
    $destWall = Join-Path $ToolsRoot 'wallpaper\TermaliaVM.png'
    Copy-Item -Path $WallpaperFile -Destination $destWall -Force
    Set-Wallpaper -imgPath $destWall
} else {
    Log "Wallpaper file not found at $WallpaperFile"
}

# --- Create Desktop Shortcut ---
try {
    $WshShell = New-Object -ComObject WScript.Shell
    $DesktopPath = [Environment]::GetFolderPath('Desktop')
    $ShortcutPath = Join-Path $DesktopPath 'Tools.lnk'
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $ToolsRoot
    $Shortcut.Description = "Tools folder"
    $Shortcut.WorkingDirectory = $ToolsRoot
    $Shortcut.Save()
    Log "Desktop shortcut created."
} catch { Log "Shortcut creation failed: $_" }

Log "Tweaker finished. Check log file at $LogFile"
Write-Host "✅ Tweaker completed. Check the log at $LogFile"
