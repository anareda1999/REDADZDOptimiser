@echo off
chcp 65001 >nul
title REDADZDOptimiser Launcher

:: Vérifier admin et auto-élever
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Demande des droits administrateur... / Requesting administrator privileges...
    powershell.exe -NoProfile -Command "Start-Process cmd -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)
cd /d "%~dp0"

:LANG_SELECT
cls
echo.
echo ================================================================
echo   REDADZDOptimiser - Language / Langue / اختيار اللغة
echo ================================================================
echo.
echo   1) Français (FR)
echo   2) English (EN)
echo   3) العربية (AR)
echo.
set "LANG_CHOICE="
set /p LANG_CHOICE="Votre choix / Your choice / اختيارك [1-3] (1): "

if "%LANG_CHOICE%"=="" set LANG_CHOICE=1
if "%LANG_CHOICE%"=="1" (
    set "OPT_LANG=FR"
    goto MENU_FR
)
if "%LANG_CHOICE%"=="2" (
    set "OPT_LANG=EN"
    goto MENU_EN
)
if "%LANG_CHOICE%"=="3" (
    set "OPT_LANG=AR"
    goto MENU_AR
)
goto LANG_SELECT

:: ══════════════════════════════════════════════════════════════════
:: MENU FRANCAIS
:: ══════════════════════════════════════════════════════════════════
:MENU_FR
cls
echo.
echo ╔══════════════════════════════════════════════════════════════╗
echo ║              REDADZDOptimiser - Lanceur Windows                  ║
echo ║                  Optimisation Windows 10/11                  ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.
echo [OK] Droits administrateur confirmés
echo.
echo Choisissez une option:
echo.
echo   1) Interface Graphique (GUI) - RECOMMANDÉ
echo   2) Ligne de commande - Exécution complète
echo   3) Ligne de commande - Simulation (Dry-Run)
echo   4) Ligne de commande - Nettoyage + Réparation seulement
echo   5) Ligne de commande - Vie privée seulement
echo   6) RESTAURATION - Annuler les changements
echo   7) Lister points de restauration
echo   8) Changer de langue (Switch Language)
echo   9) Quitter
echo.
set "CHOICE="
set /p CHOICE="Votre choix [1-9]: "

if "%CHOICE%"=="1" goto RUN_GUI
if "%CHOICE%"=="2" goto RUN_CLI_FULL
if "%CHOICE%"=="3" goto RUN_CLI_DRYRUN
if "%CHOICE%"=="4" goto RUN_CLI_CLEANUP
if "%CHOICE%"=="5" goto RUN_CLI_PRIVACY
if "%CHOICE%"=="6" goto RUN_RESTORE
if "%CHOICE%"=="7" goto RUN_LIST_RESTORE
if "%CHOICE%"=="8" goto LANG_SELECT
if "%CHOICE%"=="9" goto EXIT
goto MENU_FR

:: ══════════════════════════════════════════════════════════════════
:: MENU ENGLISH
:: ══════════════════════════════════════════════════════════════════
:MENU_EN
cls
echo.
echo ╔══════════════════════════════════════════════════════════════╗
echo ║              REDADZDOptimiser - Windows Launcher                 ║
echo ║                  Windows 10/11 Optimization                  ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.
echo [OK] Administrator privileges confirmed
echo.
echo Choose an option:
echo.
echo   1) Graphical Interface (GUI) - RECOMMENDED
echo   2) Command Line - Full Execution
echo   3) Command Line - Simulation (Dry-Run)
echo   4) Command Line - Cleanup + Repair only
echo   5) Command Line - Privacy only
echo   6) RESTORE - Undo optimizations
echo   7) List restore points
echo   8) Change language
echo   9) Exit
echo.
set "CHOICE="
set /p CHOICE="Your choice [1-9]: "

if "%CHOICE%"=="1" goto RUN_GUI
if "%CHOICE%"=="2" goto RUN_CLI_FULL
if "%CHOICE%"=="3" goto RUN_CLI_DRYRUN
if "%CHOICE%"=="4" goto RUN_CLI_CLEANUP
if "%CHOICE%"=="5" goto RUN_CLI_PRIVACY
if "%CHOICE%"=="6" goto RUN_RESTORE
if "%CHOICE%"=="7" goto RUN_LIST_RESTORE
if "%CHOICE%"=="8" goto LANG_SELECT
if "%CHOICE%"=="9" goto EXIT
goto MENU_EN

:: ══════════════════════════════════════════════════════════════════
:: MENU ARABIC (بسيط ومدعوم بالإنجليزية لتفادي الشاشات الفارغة في CMD)
:: ══════════════════════════════════════════════════════════════════
:MENU_AR
cls
echo.
echo ╔══════════════════════════════════════════════════════════════╗
echo ║       REDADZDOptimiser - أداة تحسين ويندوز 10/11 (AR)            ║
echo ║            Windows 10/11 Optimizer (Arabic)                  ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.
echo [OK] تم تأكيد صلاحيات المسؤول / Administrator privileges OK
echo.
echo اختر أحد الخيارات / Choose an option:
echo.
echo   1) الواجهة الرسومية / GUI (Graphical Interface) - [موصى به]
echo   2) سطر الأوامر / Full Optimization (CLI) - تنفيذ شامل
echo   3) محاكاة تجريبية / Simulation (Dry-Run) - بدون تغييرات
echo   4) تنظيف وإصلاح فقط / Cleanup and Repair only
echo   5) إعدادات الخصوصية فقط / Privacy Tweaks only
echo   6) استعادة النظام / System Restore (إلغاء التغييرات)
echo   7) عرض نقاط الاستعادة / List Restore Points
echo   8) تغيير اللغة / Change Language (Switch FR/EN)
echo   9) خروج / Exit
echo.
set "CHOICE="
set /p CHOICE="اختيارك / Your choice [1-9]: "

if "%CHOICE%"=="1" goto RUN_GUI
if "%CHOICE%"=="2" goto RUN_CLI_FULL
if "%CHOICE%"=="3" goto RUN_CLI_DRYRUN
if "%CHOICE%"=="4" goto RUN_CLI_CLEANUP
if "%CHOICE%"=="5" goto RUN_CLI_PRIVACY
if "%CHOICE%"=="6" goto RUN_RESTORE
if "%CHOICE%"=="7" goto RUN_LIST_RESTORE
if "%CHOICE%"=="8" goto LANG_SELECT
if "%CHOICE%"=="9" goto EXIT
goto MENU_AR

:: ══════════════════════════════════════════════════════════════════
:: ACTIONS D'EXECUTION
:: ══════════════════════════════════════════════════════════════════
:RUN_GUI
echo.
if "%OPT_LANG%"=="AR" echo جاري تشغيل الواجهة الرسومية... / Launching GUI...
if "%OPT_LANG%"=="EN" echo Launching Graphical Interface...
if "%OPT_LANG%"=="FR" echo Lancement de l'interface graphique...
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0REDADZDOptimiserGUI.ps1" -Language %OPT_LANG%
goto END

:RUN_CLI_FULL
echo.
if "%OPT_LANG%"=="AR" echo جاري التنفيذ الشامل... / Running full optimization...
if "%OPT_LANG%"=="EN" echo Running full optimization...
if "%OPT_LANG%"=="FR" echo Exécution complète...
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0REDADZDOptimiser.ps1" -Language %OPT_LANG%
goto END

:RUN_CLI_DRYRUN
echo.
if "%OPT_LANG%"=="AR" echo وضع المحاكاة... / Running simulation (Dry-Run)...
if "%OPT_LANG%"=="EN" echo Simulation mode (Dry-run, no changes made)...
if "%OPT_LANG%"=="FR" echo Mode simulation (Dry-run, aucune modification)...
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0REDADZDOptimiser.ps1" -DryRun -Language %OPT_LANG%
goto END

:RUN_CLI_CLEANUP
echo.
if "%OPT_LANG%"=="AR" echo تنظيف القرص وإصلاح النظام... / Disk cleanup and repair...
if "%OPT_LANG%"=="EN" echo Disk cleanup and system repair only...
if "%OPT_LANG%"=="FR" echo Nettoyage disque et réparation système...
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0REDADZDOptimiser.ps1" -OnlyCleanup -OnlyRepair -Language %OPT_LANG%
goto END

:RUN_CLI_PRIVACY
echo.
if "%OPT_LANG%"=="AR" echo إعدادات الخصوصية... / Privacy settings only...
if "%OPT_LANG%"=="EN" echo Privacy settings only...
if "%OPT_LANG%"=="FR" echo Configuration vie privée seulement...
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0REDADZDOptimiser.ps1" -OnlyPrivacy -Language %OPT_LANG%
goto END

:RUN_RESTORE
echo.
if "%OPT_LANG%"=="AR" echo استعادة النظام... / System restore...
if "%OPT_LANG%"=="EN" echo System restore - Rolling back optimizations...
if "%OPT_LANG%"=="FR" echo Restauration du système - Annulation des optimisations...
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0REDADZDOptimiser_Restore.ps1"
goto END

:RUN_LIST_RESTORE
echo.
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0REDADZDOptimiser_Restore.ps1" -ListRestorePoints
echo.
pause
if "%OPT_LANG%"=="AR" goto MENU_AR
if "%OPT_LANG%"=="EN" goto MENU_EN
goto MENU_FR

:EXIT
if "%OPT_LANG%"=="AR" echo مع السلامة! / Goodbye!
if "%OPT_LANG%"=="EN" echo Goodbye!
if "%OPT_LANG%"=="FR" echo Au revoir!
timeout /t 1 /nobreak >nul
exit /b 0

:END
echo.
if "%OPT_LANG%"=="AR" echo انتهى. اضغط على أي مفتاح للمتابعة... / Finished. Press any key...
if "%OPT_LANG%"=="EN" echo Finished. Press any key to continue...
if "%OPT_LANG%"=="FR" echo Terminé. Appuyez sur une touche pour continuer...
pause
if "%OPT_LANG%"=="AR" goto MENU_AR
if "%OPT_LANG%"=="EN" goto MENU_EN
goto MENU_FR
