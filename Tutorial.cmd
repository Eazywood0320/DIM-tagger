@echo off
chcp 65001 >nul
title Starside DIM 配置说明与密钥获取教程
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0StarsideDimTagger.ps1" -TutorialOnly
