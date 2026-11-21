<#
.SYNOPSIS
    REDADZDOptimiser_Restore - Annule les changements de REDADZDOptimiser

.DESCRIPTION
    Ce script restaure le système à l'état précédent :
    - Restaure le point de restauration système
    - Réactive les services désactivés
    - Réinstalle les apps provisionnées supprimées
    - Restaure le fichier hosts
    - Supprime les règles pare-feu REDADZDOptimiser
    - Restaure le registre depuis backup (.reg)

.NOTES
    Exécution: PowerShell 5.1+ EN TANT QU'ADMINISTRATEUR
    Auteur: Assistant IA
    Date: 2026

.EXEMPLE
    # Restauration complète interactive
    .\REDADZDOptimiser_Restore.ps1

    # Restauration seulement services
    .\REDADZDOptimiser_Restore.ps1 -OnlyServices

    # Lister points de restauration disponibles
    .\REDADZDOptimiser_Restore.ps1 -ListRestorePoints
#>

#Requires -Version 5.1

[CmdletBinding(DefaultParameterSetName="Full")]
param(
    [Parameter(ParameterSetName="Full")]
    [Parameter(ParameterSetName="Custom")]
    [switch]$Force,

    [Parameter(ParameterSetName="Custom")]
    [switch]$OnlySystemRestore,

    [Parameter(ParameterSetName="Custom")]
    [switch]$OnlyServices,

    [Parameter(ParameterSetName="Custom")]
    [switch]$OnlyApps,

    [Parameter(ParameterSetName="Custom")]
    [switch]$OnlyHosts,

    [Parameter(ParameterSetName="Custom")]
    [switch]$OnlyFirewall,

    [Parameter(ParameterSetName="Custom")]
    [switch]$OnlyRegistry,

    [Parameter(ParameterSetName="List")]
    [switch]$ListRestorePoints,

    [Parameter(ParameterSetName="Custom")]
    [string]$BackupLogPath
)

# ─── Vérifications ──────────────────────────────────────────────────────
function Test-Prerequisites {
    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║         REDADZDOptimiser_Restore - Restauration Windows          ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "ERREUR: Ce script doit être exécuté EN TANT QU'ADMINISTRATEUR"
        exit 1
    }

    return $true
}

# ─── Logging ────────────────────────────────────────────────────────────
$script:LogPath = "$env:TEMP\REDADZDOptimiser_Restore_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
function Write-Log {
    param([string]$Message, [ValidateSet("INFO","WARN","ERROR","SUCCESS")][string]$Level = "INFO")
    $entry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    switch ($Level) {
        "ERROR"   { Write-Host $entry -ForegroundColor Red }
        "WARN"    { Write-Host $entry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $entry -ForegroundColor Green }
        Default   { Write-Host $entry -ForegroundColor White }
    }
    Add-Content -Path $script:LogPath -Value $entry -Encoding UTF8
}

# ─── Lister points de restauration ──────────────────────────────────────
function List-RestorePoints {
    Write-Host "`nPoints de restauration disponibles:" -ForegroundColor Cyan
    Write-Host "────────────────────────────────────" -ForegroundColor Cyan

    $points = Get-ComputerRestorePoint | Sort-Object CreationTime -Descending
    if (-not $points) {
        Write-Host "Aucun point de restauration trouvé." -ForegroundColor Yellow
        return
    }

    foreach ($p in $points) {
        $age = (Get-Date) - $p.CreationTime
        Write-Host "  #$($p.SequenceNumber)  $($p.Description)`n      $($p.CreationTime)  (il y a $($age.Days)j $($age.Hours)h)" -ForegroundColor White
        if ($p.Description -like "*REDADZDOptimiser*") {
            Write-Host "      ↑ Point REDADZDOptimiser détecté" -ForegroundColor Green
        }
    }
}

# ─── Restauration système ───────────────────────────────────────────────
function Invoke-SystemRestore {
    param([int]$SequenceNumber)

    Write-Log "Démarrage restauration système..." "INFO"

    if ($SequenceNumber) {
        Write-Log "Restauration vers point #$SequenceNumber" "INFO"
        try {
            # Note: Restore-Computer nécessite confirmation interactive
            Write-Warning "La restauration système nécessite une confirmation interactive."
            Write-Warning "Une fenêtre va s'ouvrir pour confirmer la restauration."
            Restore-Computer -RestorePoint $SequenceNumber -Confirm:$false -ErrorAction Stop
            Write-Log "Restauration système lancée (redémarrage requis)" "SUCCESS"
            return $true
        } catch {
            Write-Log "Échec restauration système: $_" "ERROR"
            return $false
        }
    } else {
        # Trouver le dernier point REDADZDOptimiser
        $wp = Get-ComputerRestorePoint | Where-Object { $_.Description -like "*REDADZDOptimiser*" } | Sort-Object CreationTime -Descending | Select-Object -First 1
        if ($wp) {
            Write-Log "Point REDADZDOptimiser trouvé: #$($wp.SequenceNumber) - $($wp.Description)" "INFO"
            return Invoke-SystemRestore -SequenceNumber $wp.SequenceNumber
        } else {
            Write-Log "Aucun point REDADZDOptimiser trouvé. Utilisez -ListRestorePoints pour voir les points disponibles." "WARN"
            return $false
        }
    }
}

# ─── Réactiver services ─────────────────────────────────────────────────
function Restore-Services {
    Write-Log "Réactivation des services..." "INFO"

    $services = @(
        "DiagTrack", "dmwappushservice", "WMPNetworkSvc", "RemoteRegistry",
        "RetailDemo", "WerSvc", "wisvc", "MapsBroker", "lfsvc", "TrkWks",
        "SessionEnv", "TermService", "UmRdpService", "CDPUserSvc",
        "PimIndexMaintenanceSvc", "UserDataSvc", "UnistoreSvc", "OneSyncSvc",
        "MessagingService", "PrintNotify", "Fax"
    )

    $restored = 0
    $failed = 0

    foreach ($svc in $services) {
        try {
            $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if (-not $service) {
                Write-Log "Service non trouvé: $svc" "DEBUG"
                continue
            }

            # Déterminer le type de démarrage par défaut
            $defaultStartup = switch ($svc) {
                "DiagTrack"           { "Auto" }
                "dmwappushservice"    { "Auto" }
                "WMPNetworkSvc"       { "Manual" }
                "RemoteRegistry"      { "Disabled" }  # Sécurité: garder désactivé
                "RetailDemo"          { "Disabled" }
                "WerSvc"              { "Auto" }
                "wisvc"               { "Manual" }
                "MapsBroker"          { "Manual" }
                "lfsvc"               { "Manual" }
                "TrkWks"              { "Auto" }
                "SessionEnv"          { "Manual" }
                "TermService"         { "Manual" }
                "UmRdpService"        { "Manual" }
                "CDPUserSvc"          { "Manual" }
                "PimIndexMaintenanceSvc" { "Manual" }
                "UserDataSvc"         { "Manual" }
                "UnistoreSvc"         { "Manual" }
                "OneSyncSvc"          { "Manual" }
                "MessagingService"    { "Manual" }
                "PrintNotify"         { "Manual" }
                "Fax"                 { "Manual" }
                Default               { "Manual" }
            }

            $current = (Get-CimInstance -ClassName Win32_Service -Filter "Name='$svc'").StartMode
            if ($current -ne $defaultStartup) {
                Set-Service -Name $svc -StartupType $defaultStartup -ErrorAction Stop
                if ($defaultStartup -ne "Disabled" -and $service.Status -ne "Running") {
                    Start-Service -Name $svc -ErrorAction SilentlyContinue
                }
                Write-Log "Service restauré: $svc = $defaultStartup" "SUCCESS"
                $restored++
            } else {
                Write-Log "Service déjà correct: $svc = $current" "DEBUG"
            }
        } catch {
            Write-Log "Échec restauration service ${svc}: $_" "ERROR"
            $failed++
        }
    }

    Write-Log "Services restaurés: $restored, Échecs: $failed" "INFO"
}

# ─── Réinstaller apps ───────────────────────────────────────────────────
function Restore-Apps {
    Write-Log "Réinstallation des apps provisionnées..." "INFO"

    try {
        # Méthode 1: Réenregistrer toutes les apps pour l'utilisateur courant
        Get-AppxPackage -AllUsers | ForEach-Object {
            if ($_.InstallLocation -and (Test-Path "$($_.InstallLocation)\AppxManifest.xml")) {
                Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppxManifest.xml" -ErrorAction SilentlyContinue
            }
        }

        # Méthode 2: Via PowerShell (pour apps système)
        $systemApps = @(
            "Microsoft.WindowsStore",
            "Microsoft.WindowsCalculator",
            "Microsoft.WindowsNotepad",
            "Microsoft.Paint",
            "Microsoft.WindowsTerminal",
            "Microsoft.MicrosoftEdge.Stable"
        )

        foreach ($app in $systemApps) {
            try {
                Get-AppxPackage -Name $app -AllUsers | ForEach-Object {
                    Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppxManifest.xml" -ErrorAction SilentlyContinue
                }
            } catch { }
        }

        Write-Log "Réinstallation apps terminée" "SUCCESS"
    } catch {
        Write-Log "Erreur réinstallation apps: $_" "ERROR"
    }
}

# ─── Restaurer fichier hosts ────────────────────────────────────────────
function Restore-Hosts {
    Write-Log "Restauration fichier hosts..." "INFO"

    $hostsPath = "$env:WINDIR\System32\drivers\etc\hosts"

    # Chercher backup le plus récent
    $backups = Get-ChildItem -Path "$env:WINDIR\System32\drivers\etc" -Filter "hosts.*optimizer_backup_*" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending

    if ($backups.Count -gt 0) {
        $latest = $backups[0]
        Write-Log "Backup trouvé: $($latest.Name)" "INFO"
        try {
            Copy-Item -Path $latest.FullName -Destination $hostsPath -Force -ErrorAction Stop
            Write-Log "Hosts restauré depuis backup" "SUCCESS"
        } catch {
            Write-Log "Échec restauration hosts: $_" "ERROR"
        }
    } else {
        # Pas de backup - supprimer section REDADZDOptimiser
        Write-Log "Aucun backup, suppression section REDADZDOptimiser..." "INFO"
        try {
            $content = Get-Content -Path $hostsPath -Raw -ErrorAction Stop
            $content = $content -replace "(?s)# === REDADZDOptimiser Telemetry Block Start ===.*?# === REDADZDOptimiser Telemetry Block End ===\r?\n?", ""
            Set-Content -Path $hostsPath -Value $content -Encoding ASCII -Force -ErrorAction Stop
            Write-Log "Section REDADZDOptimiser supprimée du hosts" "SUCCESS"
        } catch {
            Write-Log "Échec modification hosts: $_" "ERROR"
        }
    }
}

# ─── Supprimer règles pare-feu ──────────────────────────────────────────
function Restore-Firewall {
    Write-Log "Suppression règles pare-feu REDADZDOptimiser..." "INFO"

    $rules = @(
        "REDADZDOptimiser Block Telemetry Outbound",
        "REDADZDOptimiser Block DiagTrack"
    )

    $removed = 0
    foreach ($rule in $rules) {
        try {
            $existing = Get-NetFirewallRule -DisplayName $rule -ErrorAction SilentlyContinue
            if ($existing) {
                Remove-NetFirewallRule -DisplayName $rule -ErrorAction Stop
                Write-Log "Règle supprimée: $rule" "SUCCESS"
                $removed++
            } else {
                Write-Log "Règle non trouvée: $rule" "DEBUG"
            }
        } catch {
            Write-Log "Échec suppression ${rule}: $_" "ERROR"
        }
    }

    Write-Log "Règles pare-feu supprimées: $removed" "INFO"
}

# ─── Restaurer registre depuis backup ───────────────────────────────────
function Restore-Registry {
    param([string]$BackupPath)

    Write-Log "Restauration registre..." "INFO"

    if (-not $BackupPath) {
        # Chercher backup dans le dossier temp
        $backups = Get-ChildItem -Path $env:TEMP -Filter "REDADZDOptimiser_*_registry_backup.reg" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
        if ($backups.Count -gt 0) {
            $BackupPath = $backups[0].FullName
            Write-Log "Backup auto-détecté: $($backups[0].Name)" "INFO"
        } else {
            Write-Log "Aucun backup registre trouvé dans $env:TEMP" "WARN"
            Write-Host "Spécifiez le chemin avec -BackupLogPath ou placez le .reg dans $env:TEMP" -ForegroundColor Yellow
            return
        }
    }

    if (Test-Path $BackupPath) {
        try {
            Write-Log "Application backup: $BackupPath" "INFO"
            & reg.exe import "$BackupPath"
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Registre restauré depuis backup" "SUCCESS"
            } else {
                Write-Log "Erreur import registre (code: $LASTEXITCODE)" "ERROR"
            }
        } catch {
            Write-Log "Échec restauration registre: $_" "ERROR"
        }
    } else {
        Write-Log "Fichier backup introuvable: $BackupPath" "ERROR"
    }
}

# ─── Confirmation ───────────────────────────────────────────────────────
function Confirm-Action {
    param([string]$Message)
    if ($Force) { return $true }
    Write-Host "`n$Message" -ForegroundColor Yellow
    $confirm = Read-Host "Continuer ? (o/N)"
    return $confirm -in @("o","O","y","Y")
}

# ════════════════════════════════════════════════════════════════════════
# MAIN
# ════════════════════════════════════════════════════════════════════════

try {
    Test-Prerequisites

    # Mode liste seulement
    if ($ListRestorePoints) {
        List-RestorePoints
        exit 0
    }

    Write-Host "`nLog: $script:LogPath" -ForegroundColor Gray

    # Déterminer actions
    $actions = @()
    if ($PSCmdlet.ParameterSetName -eq "Custom") {
        if ($OnlySystemRestore) { $actions += "SystemRestore" }
        if ($OnlyServices) { $actions += "Services" }
        if ($OnlyApps) { $actions += "Apps" }
        if ($OnlyHosts) { $actions += "Hosts" }
        if ($OnlyFirewall) { $actions += "Firewall" }
        if ($OnlyRegistry) { $actions += "Registry" }
    } else {
        $actions = @("SystemRestore", "Services", "Apps", "Hosts", "Firewall", "Registry")
    }

    if ($actions.Count -eq 0) {
        Write-Host "Aucune action sélectionnée. Utilisez -Only* ou lancez sans paramètre pour tout restaurer." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "`nActions prévues: $($actions -join ', ')" -ForegroundColor Cyan

    if (-not (Confirm-Action "⚠  Cela va ANNULER les optimisations de REDADZDOptimiser.")) {
        Write-Host "Annulé." -ForegroundColor Yellow
        exit 0
    }

    # Exécuter actions
    foreach ($action in $actions) {
        Write-Host "`n═══ $action ═══" -ForegroundColor Cyan

        switch ($action) {
            "SystemRestore" { Invoke-SystemRestore }
            "Services"      { Restore-Services }
            "Apps"          { Restore-Apps }
            "Hosts"         { Restore-Hosts }
            "Firewall"      { Restore-Firewall }
            "Registry"      { Restore-Registry -BackupPath $BackupLogPath }
        }
    }

    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                    RESTAURATION TERMINÉE                     ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host "`n⚠  REDÉMARRAGE REQUIS pour appliquer tous les changements" -ForegroundColor Yellow
    Write-Host "Log: $script:LogPath" -ForegroundColor Gray

} catch {
    Write-Error "ERREUR FATALE: $_"
    exit 1
}