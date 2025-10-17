=============================
        TermaliaVM
=============================

TermaliaVM is a lightweight PowerShell-based toolkit designed to prepare a Windows environment for reverse engineering, software analysis, and development.

This script automatically installs a full suite of essential tools using Chocolatey and Winget, configures the system with a dark theme, and applies a custom TermaliaVM wallpaper.

------------------------------------------
Main Features
------------------------------------------
- Automatic installation of:
  • Chocolatey and Winget
  • dnSpy (x64 / x86)
  • x64dbg
  • UPX
  • de4dot-cex
  • TrID
  • VC++ Redistributables
  • Visual Studio 2022
  • Sublime Text
  • VidCutter
  • CapCut
  • 7-Zip
  • Geek Uninstaller
  • Win-PS2EXE
  • HxD
  • DirectX Installer (manual setup)
  • TDM-GCC (manual setup)
  • .NET SDK
  • Makefile tools

------------------------------------------
System Configuration
------------------------------------------
- Creates working folder:
  C:\Users\<USERNAME>\tools
- Each tool is stored in its own subfolder.
- Creates a desktop shortcut "Tools" linking to that directory.
- Applies a dark Windows theme.
- Sets the wallpaper TermaliaVM.png.

------------------------------------------
Usage
------------------------------------------
1. Run PowerShell as Administrator.
2. Execute:
   powershell -ExecutionPolicy Bypass -File install.ps1
3. Wait for the setup to complete.
4. Enjoy your new reverse-engineering environment!

------------------------------------------
Credits
------------------------------------------
Developed by dev0Rot 	
Inspired by FLAREVM (by Mandiant).

