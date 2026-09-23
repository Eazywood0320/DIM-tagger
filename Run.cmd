@echo off
chcp 65001 >nul
title Starside DIM 自动标签
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0StarsideDimTagger.ps1" -ShowReadme -EnsureDimOpen -Apply
echo.
pause
