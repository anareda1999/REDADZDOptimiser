@echo off
chcp 65001 >nul
title REDADZDOptimiser - Lancement GUI

:: Auto-élévation en administrateur
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Demande de droits administrateur...
    powershell.exe -NoProfile -Command "Start-Process cmd -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

:: On est admin ici
cd /d "%~dp0"
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0REDADZDOptimiserGUI.ps1"
if %errorLevel% neq 0 (
    echo.
    echo Une erreur est survenue lors de l'exécution (code: %errorLevel%).
    pause
)
