@echo off
setlocal EnableExtensions
chcp 65001 >nul 2>&1
set "SCRIPT_DIR=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%install.ps1"
exit /b %errorlevel%
