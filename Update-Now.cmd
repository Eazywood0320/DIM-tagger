@echo off
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0StarsideUpdater.ps1" -DestinationPath "%~dp0data\starside-shopping.json"
echo.
pause
