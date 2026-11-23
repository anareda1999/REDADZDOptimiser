# Launch.ps1 - REDADZDOptimiser One-Liner Launcher
# Permet de lancer REDADZDOptimiser en une seule ligne dans PowerShell :
# irm https://raw.githubusercontent.com/anareda1999/REDADZDOptimiser/main/Launch.ps1 | iex

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

# 1. Vérification des privilèges administrateur
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "`n[i] Demande des privilèges administrateur en cours..." -ForegroundColor Cyan
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm https://raw.githubusercontent.com/anareda1999/REDADZDOptimiser/main/Launch.ps1 | iex`"" -Verb RunAs
    exit 0
}

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║              REDADZDOptimiser Professional                   ║" -ForegroundColor Cyan
Write-Host "║           Centre d'Optimisation Windows 10/11                ║" -ForegroundColor Cyan
Write-Host "║       © 2026 Anagou Reda - Contact : 0542439514              ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Téléchargement des composants de REDADZDOptimiser..." -ForegroundColor Yellow

$targetDir = Join-Path $env:TEMP "REDADZDOptimiser"
if (-not (Test-Path $targetDir)) {
    New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
}

$baseUrl = "https://raw.githubusercontent.com/anareda1999/REDADZDOptimiser/main"
$files = @(
    "REDADZDOptimiserGUI.ps1",
    "REDADZDOptimiserCore.psm1",
    "REDADZDOptimiser.ps1",
    "REDADZDOptimiser_Restore.ps1"
)

foreach ($file in $files) {
    $dest = Join-Path $targetDir $file
    try {
        Invoke-WebRequest -Uri "$baseUrl/$file" -OutFile $dest -UseBasicParsing -ErrorAction Stop
        Write-Host "  [OK] $file téléchargé" -ForegroundColor Green
    } catch {
        Write-Host "  [!] Échec téléchargement $file : $_" -ForegroundColor Red
    }
}

$guiPath = Join-Path $targetDir "REDADZDOptimiserGUI.ps1"
if (Test-Path $guiPath) {
    Write-Host "`nLancement de l'interface graphique..." -ForegroundColor Green
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$guiPath`""
} else {
    Write-Error "Fichier REDADZDOptimiserGUI.ps1 introuvable dans $targetDir"
}
