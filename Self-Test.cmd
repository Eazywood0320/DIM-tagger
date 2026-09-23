@echo off
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0StarsideDimTagger.ps1" -SelfTest
echo.
pause
