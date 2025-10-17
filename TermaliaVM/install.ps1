<#
tweaker_update.ps1
PowerShell Tweaker � ���������� ������ ��� ������ ������������.
������: PowerShell (Admin) -> .\tweaker_update.ps1
#>

# --- �������� ���� �������������� ---
function Assert-Admin {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "������ ������ ���� ������� �� ����� ��������������. ������������� PowerShell ��� Administrator."
        exit 1
    }
}
Assert-Admin

# --- ���������� ������� ---
$UserProfile = $env:USERPROFILE
$ToolsRoot = Join-Path $UserProfile 'tools'
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$WallpaperFile = Join-Path $ScriptRoot 'wallpaper\TermaliaVM.png'
$LogFile = Join-Path $ToolsRoot 'install_log.txt'

# ������ �����
New-Item -Path $ToolsRoot -ItemType Directory -Force | Out-Null
New-Item -Path (Join-Path $ToolsRoot 'wallpaper') -ItemType Directory -Force | Out-Null

# ����������� (�������)
function Log {
    param($msg)
    $t = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "$t`t$msg"
    $line | Out-File -FilePath $LogFile -Append -Encoding UTF8
    Write-Output $msg
}
Log "������ tweaker_update.ps1"

# --- ������� ����������/���������� ---
function Get-FilenameFromUrl {
    param($url)
    $u = $url.Split('?')[0]
    return [IO.Path]::GetFileName($u)
}

function Download-File {
    param(
        [string]$Url,
        [string]$OutPath
    )
    try {
        $dir = Split-Path $OutPath -Parent
        if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
        Log "����������: $Url -> $OutPath"
        Invoke-WebRequest -Uri $Url -OutFile $OutPath -UseBasicParsing -TimeoutSec 120 -ErrorAction Stop
        return $true
    } catch {
        Log "������ ���������� $Url : $_"
        return $false
    }
}

function Extract-ZipSafe {
    param($zipPath, $dest)
    try {
        if (-not (Test-Path $zipPath)) { Log "����� �� ������: $zipPath"; return $false }
        if (-not (Test-Path $dest)) { New-Item -Path $dest -ItemType Directory -Force | Out-Null }
        Expand-Archive -LiteralPath $zipPath -DestinationPath $dest -Force
        Log "�����������: $zipPath -> $dest"
        return $true
    } catch {
        Log "������ ���������� $zipPath : $_"
        return $false
    }
}

# --- ��������� Chocolatey (���� �����������) ---
function Install-ChocolateyIfMissing {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Log "Chocolatey �� ������. ������� ����������..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        $chocoScript = 'https://chocolatey.org/install.ps1'
        try {
            iex ((New-Object System.Net.WebClient).DownloadString($chocoScript))
            Log "Chocolatey: ������� ��������� ���������. ��������� 'choco -v'."
        } catch {
            Log "�� ������� ������������� ���������� Chocolatey: $_"
        }
    } else {
        Log "Chocolatey ��� ����������."
    }
}

# --- ��������� WinGet (App Installer) ���� ����������� ---
function Install-WingetIfMissing {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Log "WinGet �� ������. ������� ���������� App Installer ����� https://aka.ms/getwinget"
        $tmp = Join-Path $env:TEMP 'winget.msixbundle'
        try {
            Invoke-WebRequest -Uri 'https://aka.ms/getwinget' -OutFile $tmp -UseBasicParsing -ErrorAction Stop
            Add-AppxPackage -Path $tmp -ErrorAction Stop
            Remove-Item $tmp -ErrorAction SilentlyContinue
            Log "WinGet: ������� ��������� ���������."
        } catch {
            Log "�� ������� ������������� ���������� WinGet: $_"
        }
    } else {
        Log "WinGet ��������."
    }
}

# --- ������� ��� ������� �������������� ����������� (�� silent) ---
function Run-Installer-Interactive {
    param($filePath, $workDir=$null)
    if (-not (Test-Path $filePath)) { Log "����������� �� ������: $filePath"; return }
    Log "������ ������������ (�������������): $filePath"
    if ($workDir) { Start-Process -FilePath $filePath -WorkingDirectory $workDir } else { Start-Process -FilePath $filePath }
}

# --- ������ ������������ � URL'��� (�� ������ ������) ---
$tools = @{}

# ������ ������, ��������������� ����
$tools['tdm64-gcc'] = @{
    url = 'https://github.com/jmeubank/tdm-gcc/releases/download/v10.3.0-tdm64-2/tdm64-gcc-10.3.0-2.exe'
    dest = Join-Path $ToolsRoot 'tdm64-gcc\tdm64-gcc-10.3.0-2.exe'
    interactive = $true
}
$tools['Bytecode-Viewer'] = @{
    url = 'https://github.com/Konloch/bytecode-viewer/releases/download/v2.13.1/Bytecode-Viewer-2.13.1.jar'
    dest = Join-Path $ToolsRoot 'Bytecode-Viewer\Bytecode-Viewer-2.13.1.jar'
    interactive = $false
}
$tools['de4dot-cex'] = @{
    url = 'https://github.com/ViRb3/de4dot-cex/releases/download/v4.0.0/de4dot-cex.zip'
    dest = Join-Path $ToolsRoot 'de4dot-cex\de4dot-cex.zip'
    extractTo = Join-Path $ToolsRoot 'de4dot-cex'
}
$tools['HxD'] = @{
    url = 'https://mh-nexus.de/downloads/HxDSetup.zip'
    dest = Join-Path $ToolsRoot 'HxD\HxDSetup.zip'
    extractTo = Join-Path $ToolsRoot 'HxD'
}
$tools['PS2EXE_repo'] = @{
    # ��������� ����� ����������� ������-�����
    url = 'https://github.com/MScholtes/PS2EXE/archive/refs/heads/master.zip'
    dest = Join-Path $ToolsRoot 'PS2EXE_repo\PS2EXE-master.zip'
    extractTo = Join-Path $ToolsRoot 'PS2EXE'
}
$tools['trid'] = @{
    url = 'https://mark0.net/download/trid_win64.zip'
    dest = Join-Path $ToolsRoot 'trid\trid_win64.zip'
    extractTo = Join-Path $ToolsRoot 'trid'
}
$tools['capcut'] = @{
    url = 'https://www.capcut.com/activity/download_pc?from_page=landing_page&enter_from=a1.b1.c2.0'
    dest = Join-Path $ToolsRoot 'capcut\capcut_installer.exe'
    interactive = $true
}
$tools['sublime'] = @{
    url = 'https://www.sublimetext.com/download_thanks?target=win-x64'
    dest = Join-Path $ToolsRoot 'sublime\sublime_setup.exe'
    interactive = $true
}
$tools['VidCutter'] = @{
    url = 'https://github.com/ozmartian/vidcutter/releases/download/6.0.5.1/VidCutter-6.0.5.1-setup-win64.exe'
    dest = Join-Path $ToolsRoot 'VidCutter\VidCutter-6.0.5.1-setup-win64.exe'
    interactive = $true
}
$tools['upx'] = @{
    url = 'https://github.com/upx/upx/releases/download/v5.0.2/upx-5.0.2-win64.zip'
    dest = Join-Path $ToolsRoot 'upx\upx-5.0.2-win64.zip'
    extractTo = Join-Path $ToolsRoot 'upx'
}
$tools['x64dbg'] = @{
    url = 'https://github.com/x64dbg/x64dbg/releases/download/2025.08.19/snapshot_2025-08-19_19-40.zip'
    dest = Join-Path $ToolsRoot 'x64dbg\snapshot_2025-08-19_19-40.zip'
    extractTo = Join-Path $ToolsRoot 'x64dbg'
}
$tools['dnSpy_netfx'] = @{
    url = 'https://github.com/dnSpyEx/dnSpy/releases/download/v6.5.1/dnSpy-netframework.zip'
    dest = Join-Path $ToolsRoot 'dnSpy\dnSpy-netframework.zip'
    extractTo = Join-Path $ToolsRoot 'dnSpy'
}
$tools['de4dot-cex'] = @{
    url = 'https://github.com/ViRb3/de4dot-cex/releases/download/v4.0.0/de4dot-cex.zip'
    dest = Join-Path $ToolsRoot 'de4dot-cex\de4dot-cex.zip'
    extractTo = Join-Path $ToolsRoot 'de4dot-cex'
}
$tools['trid'] = @{
    url = 'https://mark0.net/download/trid_win64.zip'
    dest = Join-Path $ToolsRoot 'trid\trid_win64.zip'
    extractTo = Join-Path $ToolsRoot 'trid'
}
# (������������� ����� ����� �� ������ ������ � ��� ���������������� ����; ������� �� ��� �������)
# �������������� �����������, ������� ����� ��������� ����� Chocolatey:
$chocoPackages = @(
    'googlechrome',
    'discord',
    '7zip',
    'sublimetext3',      # fallback - ���� sublime-installer ����������
    'upx',               # choco upx �����
    'trid',              # ���� ����
    'vcredist-all',      # ������� ���������� VC++ redistributables
    'visualstudio2022community', # Visual Studio 2022 Community (�������)
    'mp4joiner',         # ����� �� ������������ � choco, �� ���������
    'vidcutter',         # ���� ����� ����
    'hxd'                # ���� ����� ���� (hxD ����� ���� �� � choco)
)

# ����� ��������� ��� ������� ����� choco, ���� ��������
Install-ChocolateyIfMissing
Install-WingetIfMissing

# ������� ��������� choco-������� (�� ������) � �� ���������
foreach ($pkg in $chocoPackages) {
    try {
        Log "������� choco install $pkg ..."
        choco install $pkg -y --no-progress | Out-Null
        Log "choco install $pkg - ��������� (���� ����� ��������)."
    } catch {
        Log "choco install $pkg �� �������� ��� ����� �����������: $_"
    }
}

# --- ���������� � ���������� ��������� ������������ ---
foreach ($k in $tools.Keys) {
    $entry = $tools[$k]
    $url = $entry.url
    $dest = $entry.dest
    $extractTo = $null
    if ($entry.ContainsKey('extractTo')) { $extractTo = $entry.extractTo }
    if (-not $url) { Log "��� URL ��� $k, ���������."; continue }
    $fname = Get-FilenameFromUrl $url
    if ([string]::IsNullOrWhiteSpace($fname)) {
        # ���������� ��� �� �����
        $fname = "$k" + "_" + (Get-Date -Format "yyyyMMddHHmmss")
    }
    $finalPath = $dest
    $ok = Download-File -Url $url -OutPath $finalPath
    if ($ok -and $extractTo) {
        Extract-ZipSafe -zipPath $finalPath -dest $extractTo
    }
    # ���� �������� interactive - ��������� ����������
    if ($ok -and $entry.ContainsKey('interactive') -and $entry.interactive) {
        Run-Installer-Interactive -filePath $finalPath
    }
}

# --- �������������: ���������� de-facto ������������, ������� �� ��������� ���� (�� ������ ������) ---
# ������������ ������ dnSpy x64 � x86 � ���� � ������ ������ ���� ������, ������� ���.
# ���� ����� ������� 32-bit �������� � ����� �������� URL.

# --- DirectX � TDM-GCC: ��������� ������������ (������������ �������� ���) ---
# ���� tdm64-gcc ������:
$tdmExe = Join-Path $ToolsRoot 'tdm64-gcc\tdm64-gcc-10.3.0-2.exe'
if (-not (Test-Path $tdmExe)) {
    # � ������, ���� ���� ��� ������� � ������ ���� � ��������� �����
    $found = Get-ChildItem -Path $ToolsRoot -Filter 'tdm64-gcc*.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $tdmExe = $found.FullName }
}
if (Test-Path $tdmExe) {
    Log "������ TDM-GCC ������������ (������������): $tdmExe"
    Start-Process -FilePath $tdmExe
} else {
    Log "TDM-GCC ����������� �� ������, ���������."
}

# DirectX (���� �� ������ �������� � �������� URL � $tools � �������� interactive)
# ��������� ������, ���� ���� ������ � tools\DirectX:
$dxPath = Join-Path $ToolsRoot 'DirectX'
if (Test-Path $dxPath) {
    $dxInstaller = Get-ChildItem -Path $dxPath -Filter '*.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($dxInstaller) {
        Log "������ ���������� DirectX ������������: $($dxInstaller.FullName)"
        Start-Process -FilePath $dxInstaller.FullName
    }
}

# --- ��������� ����� TermaliaVM.png ---
function Set-Wallpaper {
    param($imgPath)
    if (-not (Test-Path $imgPath)) { Log "���� ����� �� ������: $imgPath"; return $false }
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
        Log "����������� ����: $imgPath"
        return $true
    } catch {
        Log "������ ��������� �����: $_"
        return $false
    }
}

# �������� ���� ����� (���� �� ���� ����� �� ��������) � ����� tools\wallpaper
if (Test-Path $WallpaperFile) {
    $destWall = Join-Path $ToolsRoot 'wallpaper\TermaliaVM.png'
    Copy-Item -Path $WallpaperFile -Destination $destWall -Force
    Set-Wallpaper -imgPath $destWall
} else {
    Log "��������� ���� ����� �� ������ �� ����: $WallpaperFile"
}

# --- �������� ������ Tools �� ������� ����� ---
try {
    $WshShell = New-Object -ComObject WScript.Shell
    $DesktopPath = [Environment]::GetFolderPath('Desktop')
    $ShortcutPath = Join-Path $DesktopPath 'Tools.lnk'
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $ToolsRoot
    $Shortcut.Description = "Tools folder for TermaliaVM"
    $Shortcut.WorkingDirectory = $ToolsRoot
    $Shortcut.Save()
    Log "������ ����� �� ������� �����: $ShortcutPath"
} catch {
    Log "�� ������� ������� ����� �� ������� �����: $_"
}

# --- ���������� ����� ���� Windows (HKCU) ---
try {
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
    New-ItemProperty -Path $key -Name 'AppsUseLightTheme' -Value 0 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $key -Name 'SystemUsesLightTheme' -Value 0 -PropertyType DWord -Force | Out-Null
    Log "Ҹ���� ���� (HKCU) �����������."
} catch {
    Log "������ ��� ��������� ����� ����: $_"
}

Log "Tweaker: ���������� �������� ��������. ��������� ���: $LogFile"
Write-Output "Tweaker �������� � ��������� ���� � ����� $ToolsRoot. ��������� ����������� ������� ������� ���������� (GUI)."
