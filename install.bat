@echo off
setlocal EnableExtensions
chcp 65001 >nul 2>&1
set "SCRIPT_DIR=%~dp0"

if exist "%SCRIPT_DIR%RaindropsInstaller.exe" (
    start "" "%SCRIPT_DIR%RaindropsInstaller.exe"
    exit /b 0
)

set "VBS=%TEMP%\raindrops-install-launcher.vbs"
>"%VBS%" echo CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File ""%SCRIPT_DIR%install-gui.ps1""", 0, True
wscript.exe "%VBS%"
del "%VBS%" 2>nul
exit /b 0
