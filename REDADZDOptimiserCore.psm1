# REDADZDOptimiserCore.psm1
# Module PowerShell partagé pour l'optimisation Windows 10/11
# Niveau: Équilibré - Supprime le superflu, garde la stabilité

#Requires -Version 5.1

<#
.SYNOPSIS
    Module core pour REDADZDOptimiser - Fonctions d'optimisation fiables et non-bloquantes

.DESCRIPTION
    Fonctions réutilisables pour :
    - Points de restauration système
    - Gestion apps provisionnées (AppX)
    - Configuration services Windows (avec détection d'absence sans erreur rouge)
    - Télémétrie et vie privée (Registre, GPO, Hosts, Pare-feu)
    - Nettoyage disque et registre
    - Réparation système (DISM/SFC sécurisés, avec suivi de progression et timeout anti-gel)

.NOTES
    Compatible: Windows 10 19041+ / Windows 11 22000+
    Niveau: Équilibré
#>

# ─── Configuration globale ──────────────────────────────────────────────
$script:Config = @{
    LogPath          = "$env:TEMP\REDADZDOptimiser_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    RestorePointName = "REDADZDOptimiser_PreOptimization_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    DryRun           = $false
    VerboseOutput    = $true
    BackupRegistry   = $true
    OnLog            = $null
    OnProgress       = $null
    CancelRequested  = $false
}

function Set-REDADZDOptimiserConfig {
    param(
        [string]$LogPath,
        [switch]$DryRun,
        [switch]$VerboseOutput,
        [scriptblock]$OnLog,
        [scriptblock]$OnProgress,
        [bool]$CancelRequested,
        [bool]$BackupRegistry
    )
    if ($PSBoundParameters.ContainsKey('LogPath')) { $script:Config.LogPath = $LogPath }
    if ($PSBoundParameters.ContainsKey('DryRun')) { $script:Config.DryRun = $DryRun }
    if ($PSBoundParameters.ContainsKey('VerboseOutput')) { $script:Config.VerboseOutput = $VerboseOutput }
    if ($PSBoundParameters.ContainsKey('OnLog')) { $script:Config.OnLog = $OnLog }
    if ($PSBoundParameters.ContainsKey('OnProgress')) { $script:Config.OnProgress = $OnProgress }
    if ($PSBoundParameters.ContainsKey('CancelRequested')) { $script:Config.CancelRequested = $CancelRequested }
    if ($PSBoundParameters.ContainsKey('BackupRegistry')) { $script:Config.BackupRegistry = $BackupRegistry }
}

function Get-REDADZDOptimiserConfig {
    return $script:Config
}

# ─── Définition C# Native pour Métriques & Optimisations Système ───────
if (-not ([System.Management.Automation.PSTypeName]'REDADZD.SystemHelper').Type) {
    $csharp = @'
using System;
using System.Runtime.InteropServices;

namespace REDADZD {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct MEMORYSTATUSEX {
        public uint dwLength;
        public uint dwMemoryLoad;
        public ulong ullTotalPhys;
        public ulong ullAvailPhys;
        public ulong ullTotalPageFile;
        public ulong ullAvailPageFile;
        public ulong ullTotalVirtual;
        public ulong ullAvailVirtual;
        public ulong ullAvailExtendedVirtual;
    }

    public static class SystemHelper {
        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GlobalMemoryStatusEx(ref MEMORYSTATUSEX lpBuffer);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetSystemTimes(out long idleTime, out long kernelTime, out long userTime);

        [DllImport("psapi.dll", SetLastError = true)]
        public static extern int EmptyWorkingSet(IntPtr hProcess);

        private static long _lastIdle = 0;
        private static long _lastKernel = 0;
        private static long _lastUser = 0;

        public static MEMORYSTATUSEX GetMemoryStatus() {
            var mem = new MEMORYSTATUSEX();
            mem.dwLength = (uint)Marshal.SizeOf(typeof(MEMORYSTATUSEX));
            GlobalMemoryStatusEx(ref mem);
            return mem;
        }

        public static double GetCpuUsage() {
            long idle, kernel, user;
            if (!GetSystemTimes(out idle, out kernel, out user)) return 0;

            if (_lastIdle == 0) {
                _lastIdle = idle;
                _lastKernel = kernel;
                _lastUser = user;
                System.Threading.Thread.Sleep(50);
                GetSystemTimes(out idle, out kernel, out user);
            }

            long diffIdle = idle - _lastIdle;
            long diffKernel = kernel - _lastKernel;
            long diffUser = user - _lastUser;

            _lastIdle = idle;
            _lastKernel = kernel;
            _lastUser = user;

            long total = diffKernel + diffUser;
            if (total <= 0) return 0;

            double cpu = (double)(total - diffIdle) * 100.0 / total;
            if (cpu < 0) cpu = 0;
            if (cpu > 100) cpu = 100;
            return Math.Round(cpu, 1);
        }

        public static bool FlushProcessWorkingSet(IntPtr handle) {
            try {
                return EmptyWorkingSet(handle) != 0;
            } catch {
                return false;
            }
        }
    }
}
'@
    Add-Type -TypeDefinition $csharp
}


# ─── Apps provisionnées à SUPPRIMER (Niveau Équilibré) ──────────────────
$script:AppsToRemove = @(
    # Xbox / Gaming
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.XboxSpeechToTextOverlay"
    "Microsoft.GamingApp"
    "Microsoft.XboxGameCallableUI"
    "Microsoft.Xbox.TCUI"
    "Microsoft.XboxGameOverlay"

    # Apps préinstallées inutiles (Bloatware)
    "Microsoft.3DBuilder"
    "Microsoft.BingWeather"
    "Microsoft.BingNews"
    "Microsoft.BingFinance"
    "Microsoft.BingSports"
    "Microsoft.GetHelp"
    "Microsoft.Getstarted"
    "Microsoft.Microsoft3DViewer"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.MicrosoftStickyNotes"
    "Microsoft.Office.OneNote"
    "Microsoft.OneConnect"
    "Microsoft.People"
    "Microsoft.Print3D"
    "Microsoft.SkypeApp"
    "Microsoft.Wallet"
    "Microsoft.WindowsAlarms"
    "Microsoft.WindowsCamera"
    "microsoft.windowscommunicationsapps"
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.WindowsMaps"
    "Microsoft.WindowsSoundRecorder"
    "Microsoft.ZuneMusic"
    "Microsoft.ZuneVideo"

    # Windows 11 spécifique
    "Clipchamp"
    "MicrosoftTeams"
)

# Apps à CONSERVER (protection)
$script:AppsToKeep = @(
    "Microsoft.WindowsStore"
    "Microsoft.WindowsCalculator"
    "Microsoft.WindowsNotepad"
    "Microsoft.Paint"
    "Microsoft.WindowsTerminal"
    "Microsoft.MicrosoftEdge.Stable"
    "Windows.Defender"
    "Microsoft.WindowsSecurity"
)

# ─── Services à DÉSACTIVER (Niveau Équilibré) ───────────────────────────
$script:ServicesToDisable = @(
    @{ Name = "DiagTrack";        DisplayName = "Connected User Experiences and Telemetry"; StartupType = "Disabled" }
    @{ Name = "dmwappushservice"; DisplayName = "WAP Push Message Routing Service";         StartupType = "Disabled" }
    @{ Name = "WMPNetworkSvc";    DisplayName = "Windows Media Player Network Sharing";       StartupType = "Disabled" }
    @{ Name = "RemoteRegistry";   DisplayName = "Remote Registry";                            StartupType = "Disabled" }
    @{ Name = "RetailDemo";       DisplayName = "Retail Demo Service";                        StartupType = "Disabled" }
    @{ Name = "WerSvc";           DisplayName = "Windows Error Reporting Service";            StartupType = "Manual" }
    @{ Name = "wisvc";            DisplayName = "Windows Insider Service";                    StartupType = "Disabled" }
    @{ Name = "MapsBroker";       DisplayName = "Downloaded Maps Manager";                    StartupType = "Disabled" }
    @{ Name = "lfsvc";            DisplayName = "Geolocation Service";                        StartupType = "Manual" }
    @{ Name = "TrkWks";           DisplayName = "Distributed Link Tracking Client";           StartupType = "Manual" }
    @{ Name = "SessionEnv";       DisplayName = "Remote Desktop Configuration";               StartupType = "Manual" }
    @{ Name = "TermService";      DisplayName = "Remote Desktop Services";                    StartupType = "Manual" }
    @{ Name = "UmRdpService";     DisplayName = "Remote Desktop UserMode Port Redirector";    StartupType = "Manual" }
    @{ Name = "CDPUserSvc";       DisplayName = "Connected Devices Platform User Service";    StartupType = "Manual" }
    @{ Name = "PimIndexMaintenanceSvc"; DisplayName = "Contact Data Index Maintenance";       StartupType = "Manual" }
    @{ Name = "UserDataSvc";      DisplayName = "User Data Access";                           StartupType = "Manual" }
    @{ Name = "UnistoreSvc";      DisplayName = "Unistore Synchronization Service";           StartupType = "Manual" }
    @{ Name = "OneSyncSvc";       DisplayName = "OneSync Synchronization Service";            StartupType = "Manual" }
    @{ Name = "MessagingService"; DisplayName = "MessagingService";                           StartupType = "Manual" }
    @{ Name = "PrintNotify";      DisplayName = "Print Notify";                               StartupType = "Manual" }
    @{ Name = "Fax";              DisplayName = "Fax";                                        StartupType = "Disabled" }
)

# ─── Tâches planifiées de TÉLÉMÉTRIE à DÉSACTIVER ──────────────────────
$script:TasksToDisable = @(
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
    "\Microsoft\Windows\Application Experience\ProgramDataUpdater"
    "\Microsoft\Windows\Autochk\Proxy"
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
    "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask"
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
    "\Microsoft\Windows\Feedback\Siuf\DmClient"
    "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload"
    "\Microsoft\Windows\Maps\MapsToastTask"
    "\Microsoft\Windows\MemoryDiagnostic\RunFullMemoryDiagnostic"
    "\Microsoft\Windows\NetTrace\GatherNetworkInfo"
    "\Microsoft\Windows\PI\Sqm-Tasks"
    "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem"
    "\Microsoft\Windows\Ras\MobilityManager"
    "\Microsoft\Windows\Shell\FamilySafetyMonitor"
    "\Microsoft\Windows\Shell\FamilySafetyRefreshTask"
    "\Microsoft\Windows\SoftwareProtectionPlatform\SvcRestartTask"
    "\Microsoft\Windows\Systems\SilentCleanup"
    "\Microsoft\Windows\Windows Error Reporting\QueueReporting"
    "\Microsoft\Windows\WindowsUpdate\Scheduled Start"
    "\Microsoft\Windows\WindowsUpdate\USO_UxBroker"
    "\Microsoft\Windows\WlanSvc\WiFiTask"
)

# ─── Registre VIE PRIVÉE (Désactiver télémétrie, pub, tracking) ─────────
$script:PrivacyRegistrySettings = @(
    # Télémétrie Windows = Sécurité seulement (0)
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "AllowTelemetry"; Value = 0; Type = "DWord" }
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"; Name = "AllowTelemetry"; Value = 0; Type = "DWord" }
    @{ Path = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection"; Name = "AllowTelemetry"; Value = 0; Type = "DWord" }

    # Publicité et ID de pub
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"; Name = "Enabled"; Value = 0; Type = "DWord" }
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo"; Name = "DisabledByGroupPolicy"; Value = 1; Type = "DWord" }

    # Suggestions menu Démarrer et Windows Spotlight
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SystemPaneSuggestionsEnabled"; Value = 0; Type = "DWord" }
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SoftLandingEnabled"; Value = 0; Type = "DWord" }
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "RotatingLockScreenEnabled"; Value = 0; Type = "DWord" }
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "RotatingLockScreenOverlayEnabled"; Value = 0; Type = "DWord" }
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-310093Enabled"; Value = 0; Type = "DWord" }
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-338387Enabled"; Value = 0; Type = "DWord" }
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-338388Enabled"; Value = 0; Type = "DWord" }
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-338389Enabled"; Value = 0; Type = "DWord" }
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-353698Enabled"; Value = 0; Type = "DWord" }

    # Cortana & Recherche Web dans Windows Search
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "AllowCortana"; Value = 0; Type = "DWord" }
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "DisableWebSearch"; Value = 1; Type = "DWord" }
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "ConnectedSearchUseWeb"; Value = 0; Type = "DWord" }
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"; Name = "BingSearchEnabled"; Value = 0; Type = "DWord" }
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"; Name = "CortanaConsent"; Value = 0; Type = "DWord" }

    # Feedback et diagnostics
    @{ Path = "HKCU:\Software\Microsoft\Siuf\Rules"; Name = "NumberOfSIUFInPeriod"; Value = 0; Type = "DWord" }
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "DoNotShowFeedbackNotifications"; Value = 1; Type = "DWord" }

    # Expériences personnalisées et saisie
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy"; Name = "TailoredExperiencesWithDiagnosticDataEnabled"; Value = 0; Type = "DWord" }
    @{ Path = "HKCU:\Software\Microsoft\InputPersonalization"; Name = "RestrictImplicitInkCollection"; Value = 1; Type = "DWord" }
    @{ Path = "HKCU:\Software\Microsoft\InputPersonalization"; Name = "RestrictImplicitTextCollection"; Value = 1; Type = "DWord" }
    @{ Path = "HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore"; Name = "HarvestContacts"; Value = 0; Type = "DWord" }

    # Historique d'activité
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "EnableActivityFeed"; Value = 0; Type = "DWord" }
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "PublishUserActivities"; Value = 0; Type = "DWord" }
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "UploadUserActivities"; Value = 0; Type = "DWord" }

    # Localisation
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"; Name = "DisableLocation"; Value = 1; Type = "DWord" }

    # Rapport d'erreurs Windows (WER)
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting"; Name = "Disabled"; Value = 1; Type = "DWord" }
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"; Name = "Disabled"; Value = 1; Type = "DWord" }

    # OneDrive (Désactiver démarrage auto et synchro)
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"; Name = "DisableFileSyncNGSC"; Value = 1; Type = "DWord" }

    # Wi-Fi Sense
    @{ Path = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting"; Name = "value"; Value = 0; Type = "DWord" }
    @{ Path = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots"; Name = "value"; Value = 0; Type = "DWord" }
)

# ─── Dossiers à NETTOYER (Disque) ───────────────────────────────────────
$script:CleanupPaths = @(
    @{ Path = "$env:TEMP";                              Description = "Fichiers temporaires utilisateur"; Recurse = $true }
    @{ Path = "$env:WINDIR\Temp";                       Description = "Fichiers temporaires système";     Recurse = $true }
    @{ Path = "$env:WINDIR\Prefetch";                   Description = "Cache Prefetch Windows";          Recurse = $false }
    @{ Path = "$env:LOCALAPPDATA\CrashDumps";           Description = "Fichiers Crash Dump";             Recurse = $true }
    @{ Path = "$env:WINDIR\Minidump";                   Description = "Minidumps BSOD";                  Recurse = $true }
    @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"; Description = "Cache miniatures (Thumbnails)"; Recurse = $false }
    @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"; Description = "Cache Internet Explorer/Edge"; Recurse = $true }
    @{ Path = "$env:WINDIR\SoftwareDistribution\Download"; Description = "Téléchargements Windows Update"; Recurse = $true }
    @{ Path = "$env:LOCALAPPDATA\Temp";                 Description = "Temp local utilisateur";           Recurse = $true }
    @{ Path = "$env:APPDATA\Microsoft\Windows\Recent";  Description = "Historique fichiers récents";     Recurse = $false }
)

# ════════════════════════════════════════════════════════════════════════
# FONCTIONS UTILITAIRES & LOGGING
# ════════════════════════════════════════════════════════════════════════

function Write-Log {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet("INFO","WARN","ERROR","SUCCESS","DEBUG")][string]$Level = "INFO",
        [switch]$NoConsole
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    if ($script:Config.VerboseOutput -and -not $NoConsole) {
        switch ($Level) {
            "ERROR"   { Write-Host $logEntry -ForegroundColor Red }
            "WARN"    { Write-Host $logEntry -ForegroundColor Yellow }
            "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
            "DEBUG"   { Write-Host $logEntry -ForegroundColor DarkGray }
            Default   { Write-Host $logEntry -ForegroundColor White }
        }
    }

    if ($script:Config.OnLog -is [scriptblock]) {
        try { & $script:Config.OnLog $Message $Level } catch { }
    }

    try {
        Add-Content -Path $script:Config.LogPath -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch { }
}

function Write-ProgressBar {
    param(
        [Parameter(Mandatory=$true)][string]$Activity,
        [Parameter(Mandatory=$true)][int]$Current,
        [Parameter(Mandatory=$true)][int]$Total,
        [string]$Status = ""
    )
    $percent = if ($Total -gt 0) { [math]::Round($Current / $Total * 100) } else { 0 }
    try {
        Write-Progress -Activity $Activity -Status "$Status ($Current/$Total)" -PercentComplete $percent -ErrorAction SilentlyContinue
    } catch { }

    if ($script:Config.OnProgress -is [scriptblock]) {
        try { & $script:Config.OnProgress $Activity $Current $Total $Status $percent } catch { }
    }
}

function Test-IsAdmin {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ════════════════════════════════════════════════════════════════════════
# EXÉCUTION DE COMMANDES SYSTÈME AVEC TIMEOUT ET SUIVI EN DIRECT
# ════════════════════════════════════════════════════════════════════════

function Invoke-NativeCommandWithProgress {
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [Parameter(Mandatory=$true)][string]$ArgumentList,
        [string]$ActivityTitle = "Opération système",
        [int]$TimeoutSeconds = 300
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = $ArgumentList
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    try {
        $proc = [System.Diagnostics.Process]::Start($psi)
    } catch {
        Write-Log "Impossible d'exécuter ${FilePath}: $_" "WARN"
        return @{ ExitCode = -1; Output = ""; TimedOut = $false; Cancelled = $false }
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $outLines = @()
    $lastPct = -1

    while (-not $proc.HasExited -or -not $proc.StandardOutput.EndOfStream) {
        if ($script:Config -and $script:Config.CancelRequested) {
            try { $proc.Kill() } catch { }
            Write-Log "$ActivityTitle interrompu par l'utilisateur." "WARN"
            return @{ ExitCode = -2; Output = ($outLines -join "`n"); Cancelled = $true; TimedOut = $false }
        }

        $readSomething = $false

        if ($proc.StandardOutput.Peek() -ne -1) {
            $line = $proc.StandardOutput.ReadLine()
            if ($line -and $line.Trim()) {
                $trimmed = $line.Trim()
                $outLines += $trimmed
                $readSomething = $true

                # Extraire le pourcentage pour la barre de progression
                if ($trimmed -match '(\d{1,3}(?:\.\d)?)\s*%') {
                    $pct = [int][double]$matches[1]
                    if ($pct -ne $lastPct) {
                        $lastPct = $pct
                        Write-ProgressBar $ActivityTitle $pct 100 "$ActivityTitle ($pct%)"
                        Write-Log "[$ActivityTitle] $pct%" "DEBUG"
                    }
                }
            }
        }

        # Vider également le flux d'erreur standard pour éviter tout blocage du tampon système
        if ($proc.StandardError.Peek() -ne -1) {
            $null = $proc.StandardError.ReadLine()
            $readSomething = $true
        }

        if (-not $readSomething) {
            Start-Sleep -Milliseconds 60
            # Pompage des événements pour éviter que l'UI WinForms ne gèle
            try { [System.Windows.Forms.Application]::DoEvents() } catch { }
        }

        if ($sw.Elapsed.TotalSeconds -gt $TimeoutSeconds) {
            try { $proc.Kill() } catch { }
            Write-Log "Délai maximum ($($TimeoutSeconds)s) dépassé pour $ActivityTitle. Interrompu proprement pour éviter le gel." "WARN"
            return @{ ExitCode = -1; Output = ($outLines -join "`n"); TimedOut = $true; Cancelled = $false }
        }
    }

    return @{
        ExitCode  = $proc.ExitCode
        Output    = ($outLines -join "`n")
        TimedOut  = $false
        Cancelled = $false
    }
}

# ════════════════════════════════════════════════════════════════════════
# POINT DE RESTAURATION
# ════════════════════════════════════════════════════════════════════════

function New-SystemRestorePoint {
    param(
        [string]$Name = $script:Config.RestorePointName,
        [string]$Description = "Point de restauration avant optimisation REDADZDOptimiser"
    )
    Write-Log "Création du point de restauration: $Name" "INFO"

    try {
        if (-not (Get-Command 'Checkpoint-Computer' -ErrorAction SilentlyContinue)) {
            Write-Log "Fonction de restauration système non disponible sur cette édition de Windows." "WARN"
            return $false
        }
        # Débloquer la limite Windows de 24h entre points de restauration
        try {
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "SystemRestorePointCreationFrequency" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        } catch { }

        Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Log "Point de restauration créé avec succès" "SUCCESS"
        return $true
    } catch {
        Write-Log "Création du point de restauration non disponible: $_" "WARN"
        Write-Log "La protection système semble inactive sur $env:SystemDrive (les autres étapes continuent)." "INFO"
        return $false
    }
}

# ════════════════════════════════════════════════════════════════════════
# GESTION APPS PROVISIONNÉES (AppX)
# ════════════════════════════════════════════════════════════════════════

function Get-ProvisionedApps {
    param([switch]$AllUsers)
    if ($AllUsers) {
        Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.IsFramework -eq $false }
    } else {
        Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.IsFramework -eq $false }
    }
}

function Remove-ProvisionedApps {
    param(
        [string[]]$AppNames = $script:AppsToRemove,
        [switch]$AllUsers,
        [switch]$Force
    )
    $removed = 0
    $failed = 0
    $skipped = 0

    foreach ($appName in $AppNames) {
        if ($script:Config -and $script:Config.CancelRequested) { break }
        Write-ProgressBar "Suppression apps provisionnées" ($removed + $failed + $skipped + 1) $AppNames.Count "Traitement: $appName"

        try {
            $packages = if ($AllUsers -and (Test-IsAdmin)) {
                try { Get-AppxPackage -AllUsers -Name "*$appName*" -ErrorAction SilentlyContinue } catch { Get-AppxPackage -Name "*$appName*" -ErrorAction SilentlyContinue }
            } else {
                Get-AppxPackage -Name "*$appName*" -ErrorAction SilentlyContinue
            }

            if (-not $packages) {
                Write-Log "App absente ou déjà désinstallée: $appName" "DEBUG"
                $skipped++
                continue
            }

            foreach ($pkg in $packages) {
                # Protection apps essentielles
                if ($script:AppsToKeep -contains $pkg.Name) {
                    Write-Log "App protégée (conservée): $($pkg.Name)" "INFO"
                    $skipped++
                    continue
                }

                if ($script:Config.DryRun) {
                    Write-Log "[DRY-RUN] Supprimerait: $($pkg.Name)" "INFO"
                    $removed++
                    continue
                }

                Write-Log "Suppression: $($pkg.Name)" "INFO"
                try {
                    Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
                    $removed++
                    Write-Log "Supprimé: $($pkg.Name)" "SUCCESS"
                } catch {
                    Write-Log "Application non supprimable ($($pkg.Name)): protégée par le système" "WARN"
                    $failed++
                }

                # Supprimer version provisionnée
                try {
                    Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageFullName -ErrorAction SilentlyContinue
                } catch { }
            }
        } catch {
            Write-Log "App $appName ignorée: $_" "WARN"
            $failed++
        }
    }

    Write-Log "Apps supprimées: $removed, Non supprimables: $failed, Absentes/Conservées: $skipped" "INFO"
    return @{ Removed = $removed; Failed = $failed; Skipped = $skipped }
}

function Reinstall-ProvisionedApps {
    param([string[]]$AppNames)
    Write-Log "Réinstallation des apps Windows..." "INFO"

    Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | ForEach-Object {
        Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppxManifest.xml" -ErrorAction SilentlyContinue
    }

    Write-Log "Réinstallation terminée" "SUCCESS"
}

# ════════════════════════════════════════════════════════════════════════
# GESTION SERVICES
# ════════════════════════════════════════════════════════════════════════

function Set-ServicesState {
    param(
        [object[]]$Services = $script:ServicesToDisable,
        [ValidateSet("Disable","Enable","Manual","Auto")][string]$Action = "Disable",
        [switch]$Force
    )
    $changed = 0
    $failed = 0
    $skipped = 0

    foreach ($svc in $Services) {
        Write-ProgressBar "Configuration services" ($changed + $failed + $skipped + 1) $Services.Count "Traitement: $($svc.Name)"

        try {
            $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
            if (-not $service) {
                Write-Log "Service absent ou non installé: $($svc.Name)" "DEBUG"
                $skipped++
                continue
            }

            $targetStartup = if ($Action -eq "Disable") { "Disabled" } elseif ($Action -eq "Enable") { "Automatic" } else { $Action }
            $cimSvc = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($svc.Name)'" -ErrorAction SilentlyContinue
            $currentStartup = if ($cimSvc) { $cimSvc.StartMode } else { $service.StartType.ToString() }

            if ($currentStartup -eq $targetStartup) {
                Write-Log "Service déjà configuré: $($svc.Name) = $targetStartup" "DEBUG"
                $skipped++
                continue
            }

            if ($script:Config.DryRun) {
                Write-Log "[DRY-RUN] Changerait $($svc.Name) de $currentStartup vers $targetStartup" "INFO"
                $changed++
                continue
            }

            # Arrêter le service si nécessaire
            if ($Action -eq "Disable" -and $service.Status -eq "Running") {
                try {
                    Stop-Service -Name $svc.Name -Force -ErrorAction Stop
                    Start-Sleep -Milliseconds 300
                } catch {
                    Write-Log "Service $($svc.Name) en cours d'utilisation (sera arrêté au redémarrage)" "DEBUG"
                }
            }

            try {
                Set-Service -Name $svc.Name -StartupType $targetStartup -ErrorAction Stop
            } catch {
                if ($targetStartup -eq "Disabled") {
                    & sc.exe config $svc.Name start= disabled > $null 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Log "Service configuré (via SC): $($svc.Name) = $targetStartup" "SUCCESS"
                        $changed++
                        continue
                    }
                }
                Write-Log "Service $($svc.Name) protégé par le système" "DEBUG"
                $failed++
                continue
            }

            if ($Action -in @("Enable","Auto","Manual") -and $targetStartup -ne "Disabled") {
                Start-Service -Name $svc.Name -ErrorAction SilentlyContinue
            }

            Write-Log "Service configuré: $($svc.Name) = $targetStartup" "SUCCESS"
            $changed++
        } catch {
            Write-Log "Service $($svc.Name) non accessible: $_" "DEBUG"
            $failed++
        }
    }

    Write-Log "Services modifiés: $changed, Protégés: $failed, Déjà configurés/Absents: $skipped" "INFO"
    return @{ Changed = $changed; Failed = $failed; Skipped = $skipped }
}

# ════════════════════════════════════════════════════════════════════════
# TÂCHES PLANIFIÉES
# ════════════════════════════════════════════════════════════════════════

function Disable-ScheduledTasks {
    param([string[]]$TaskPaths = $script:TasksToDisable)
    $disabled = 0
    $failed = 0
    $notFound = 0

    foreach ($taskPath in $TaskPaths) {
        if ($script:Config -and $script:Config.CancelRequested) { break }
        Write-ProgressBar "Désactivation tâches planifiées" ($disabled + $failed + $notFound + 1) $TaskPaths.Count "Traitement: $taskPath"

        try {
            $taskDir = Split-Path $taskPath
            if (-not $taskDir.EndsWith('\')) { $taskDir += '\' }
            $taskName = Split-Path $taskPath -Leaf
            $task = Get-ScheduledTask -TaskPath $taskDir -TaskName $taskName -ErrorAction SilentlyContinue

            if (-not $task) {
                # Tentative directe via schtasks.exe si le wrapper CIM/WMI n'a pas accès
                if (-not $script:Config.DryRun) {
                    & schtasks.exe /Change /TN "$taskPath" /Disable > $null 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Log "Tâche désactivée: $taskPath" "SUCCESS"
                        $disabled++
                        continue
                    }
                }
                Write-Log "Tâche absente ou non installée: $taskPath" "DEBUG"
                $notFound++
                continue
            }

            if ($task.State -eq "Disabled") {
                Write-Log "Tâche déjà désactivée: $taskPath" "DEBUG"
                $disabled++
                continue
            }

            if ($script:Config.DryRun) {
                Write-Log "[DRY-RUN] Désactiverait: $taskPath" "INFO"
                $disabled++
                continue
            }

            try {
                Disable-ScheduledTask -TaskPath $taskDir -TaskName $taskName -ErrorAction Stop
                Write-Log "Tâche désactivée: $taskPath" "SUCCESS"
                $disabled++
            } catch {
                # Fallback via schtasks.exe
                & schtasks.exe /Change /TN "$taskPath" /Disable > $null 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Tâche désactivée: $taskPath" "SUCCESS"
                    $disabled++
                } else {
                    Write-Log "Tâche $taskPath protégée par le système" "DEBUG"
                    $failed++
                }
            }
        } catch {
            Write-Log "Tâche $taskPath non accessible: $_" "DEBUG"
            $failed++
        }
    }

    Write-Log "Tâches désactivées: $disabled, Protégées: $failed, Absentes: $notFound" "INFO"
    return @{ Disabled = $disabled; Failed = $failed; NotFound = $notFound }
}

function Enable-ScheduledTasks {
    param([string[]]$TaskPaths = $script:TasksToDisable)
    $enabled = 0
    foreach ($taskPath in $TaskPaths) {
        try {
            $taskDir = Split-Path $taskPath
            if (-not $taskDir.EndsWith('\')) { $taskDir += '\' }
            $taskName = Split-Path $taskPath -Leaf
            Enable-ScheduledTask -TaskPath $taskDir -TaskName $taskName -ErrorAction SilentlyContinue
            & schtasks.exe /Change /TN "$taskPath" /Enable > $null 2>&1
            $enabled++
        } catch { }
    }
    Write-Log "Tâches réactivées: $enabled" "INFO"
}

# ════════════════════════════════════════════════════════════════════════
# REGISTRE VIE PRIVÉE
# ════════════════════════════════════════════════════════════════════════

function Set-PrivacyRegistry {
    param([object[]]$Settings = $script:PrivacyRegistrySettings)
    $applied = 0
    $failed = 0

    foreach ($setting in $Settings) {
        if ($script:Config -and $script:Config.CancelRequested) { break }
        Write-ProgressBar "Configuration vie privée (Registre)" ($applied + $failed + 1) $Settings.Count "Traitement: $($setting.Name)"

        try {
            if (-not (Test-Path $setting.Path -ErrorAction SilentlyContinue)) {
                New-Item -Path $setting.Path -Force -ErrorAction SilentlyContinue | Out-Null
            }

            $current = Get-ItemProperty -Path $setting.Path -Name $setting.Name -ErrorAction SilentlyContinue
            if ($current -and $current."$($setting.Name)" -eq $setting.Value) {
                Write-Log "Valeur déjà définie: $($setting.Path)\$($setting.Name) = $($setting.Value)" "DEBUG"
                $applied++
                continue
            }

            if ($script:Config.DryRun) {
                Write-Log "[DRY-RUN] Définirait: $($setting.Path)\$($setting.Name) = $($setting.Value)" "INFO"
                $applied++
                continue
            }

            if ($script:Config.BackupRegistry) {
                Backup-RegistryKey -Path $setting.Path
            }

            Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -Type $setting.Type -Force -ErrorAction Stop
            Write-Log "Défini: $($setting.Name) = $($setting.Value)" "SUCCESS"
            $applied++
        } catch {
            Write-Log "Clé registre protégée ou inaccessible: $($setting.Path)\$($setting.Name)" "WARN"
            $failed++
        }
    }

    Write-Log "Paramètres registre appliqués: $applied, Non modifiables: $failed" "INFO"
    return @{ Applied = $applied; Failed = $failed }
}

function Backup-RegistryKey {
    param([string]$Path)
    try {
        $cleanPath = $Path -replace 'HKLM:\\', 'HKEY_LOCAL_MACHINE\' -replace 'HKCU:\\', 'HKEY_CURRENT_USER\'
        $backupFile = "$($script:Config.LogPath.Replace('.log', ''))_regbackup_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg"
        & reg.exe export "$cleanPath" "$backupFile" /y > $null 2>&1
    } catch { }
}

# ════════════════════════════════════════════════════════════════════════
# NETTOYAGE DISQUE & WINDOWS UPDATE SÉCURISÉ (ANTI-GEL)
# ════════════════════════════════════════════════════════════════════════

function Invoke-DiskCleanup {
    param(
        [object[]]$Paths = $script:CleanupPaths,
        [switch]$IncludeRecycleBin,
        [switch]$IncludeWindowsUpdate
    )
    $totalFreed = 0
    $cleaned = 0
    $failed = 0

    foreach ($item in $Paths) {
        if ($script:Config -and $script:Config.CancelRequested) { break }
        Write-ProgressBar "Nettoyage disque" ($cleaned + $failed + 1) $Paths.Count "Nettoyage: $($item.Description)"

        try {
            if (-not (Test-Path $item.Path -ErrorAction SilentlyContinue)) {
                Write-Log "Chemin non trouvé ou inaccessible: $($item.Path)" "DEBUG"
                $cleaned++
                continue
            }

            $files = Get-ChildItem -Path $item.Path -Recurse:$item.Recurse -Force -ErrorAction SilentlyContinue
            if (-not $files) {
                Write-Log "Rien à nettoyer: $($item.Description)" "DEBUG"
                $cleaned++
                continue
            }

            $sizeBefore = ($files | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            $count = $files.Count

            if ($count -eq 0 -or -not $sizeBefore) {
                Write-Log "Rien à nettoyer: $($item.Description)" "DEBUG"
                $cleaned++
                continue
            }

            if ($script:Config.DryRun) {
                Write-Log "[DRY-RUN] Nettoierait $count fichiers ($([math]::Round($sizeBefore/1MB,2)) MB) dans $($item.Description)" "INFO"
                $totalFreed += $sizeBefore
                $cleaned++
                continue
            }

            $deleted = 0
            foreach ($file in $files) {
                try {
                    Remove-Item -Path $file.FullName -Force -Recurse -ErrorAction SilentlyContinue
                    $deleted++
                } catch { }
            }

            $freed = if ($count -gt 0) { $deleted * ($sizeBefore / $count) } else { 0 }
            $totalFreed += $freed
            Write-Log "Nettoyé: $($item.Description) - $deleted fichiers (~$([math]::Round($freed/1MB,2)) MB libérés)" "SUCCESS"
            $cleaned++
        } catch {
            Write-Log "Nettoyage partiel ($($item.Description)): certains fichiers sont verrouillés" "WARN"
            $failed++
        }
    }

    # Corbeille
    if ($IncludeRecycleBin) {
        try {
            if ($script:Config.DryRun) {
                Write-Log "[DRY-RUN] Viderait la corbeille" "INFO"
            } else {
                Clear-RecycleBin -Force -ErrorAction SilentlyContinue
                Write-Log "Corbeille vidée" "SUCCESS"
            }
        } catch {
            Write-Log "Vidage corbeille ignoré: $_" "WARN"
        }
    }

    # Nettoyage composants Windows Update (DISM sécurisé, sans /ResetBase pour éviter le gel)
    if ($IncludeWindowsUpdate) {
        try {
            if ($script:Config.DryRun) {
                Write-Log "[DRY-RUN] Lancerait DISM Cleanup-Image /StartComponentCleanup" "INFO"
            } else {
                Write-Log "Nettoyage composants Windows Update (DISM)..." "INFO"

                # S'assurer que le service Windows Update n'est pas désactivé (requis par DISM)
                $wu = Get-Service -Name "wuauserv" -ErrorAction SilentlyContinue
                if ($wu -and $wu.StartType -eq "Disabled") {
                    Set-Service -Name "wuauserv" -StartupType Manual -ErrorAction SilentlyContinue
                }

                # StartComponentCleanup sans /ResetBase s'exécute rapidement et sans blocage
                $dismRes = Invoke-NativeCommandWithProgress -FilePath "dism.exe" -ArgumentList "/Online /Cleanup-Image /StartComponentCleanup /NoRestart" -ActivityTitle "Nettoyage Windows Update" -TimeoutSeconds 300

                if ($dismRes.ExitCode -eq 0) {
                    Write-Log "Nettoyage composants Windows Update terminé avec succès" "SUCCESS"
                } elseif ($dismRes.TimedOut) {
                    Write-Log "Nettoyage Windows Update ignoré (délai dépassé pour éviter le gel du système)" "WARN"
                } elseif ($dismRes.Cancelled) {
                    Write-Log "Nettoyage Windows Update annulé" "WARN"
                } else {
                    Write-Log "DISM a terminé avec le code $($dismRes.ExitCode)" "WARN"
                }
            }
        } catch {
            Write-Log "Avertissement nettoyage Windows Update: $_" "WARN"
        }
    }

    Write-Log "Nettoyage disque terminé. Total libéré: ~$([math]::Round($totalFreed/1MB,2)) MB" "INFO"
    return @{ FreedMB = [math]::Round($totalFreed/1MB,2); Cleaned = $cleaned; Failed = $failed }
}

# ════════════════════════════════════════════════════════════════════════
# NETTOYAGE REGISTRE
# ════════════════════════════════════════════════════════════════════════

function Invoke-RegistryCleanup {
    param(
        [switch]$BackupFirst = $true,
        [switch]$Aggressive = $false
    )
    Write-Log "Démarrage nettoyage registre (mode conservateur)..." "INFO"

    $cleaned = 0
    $failed = 0

    try {
        $uninstallPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
        )

        foreach ($path in $uninstallPaths) {
            if (Test-Path $path -ErrorAction SilentlyContinue) {
                $keys = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
                foreach ($key in $keys) {
                    $installLoc = Get-ItemProperty -Path $key.PSPath -Name "InstallLocation" -ErrorAction SilentlyContinue
                    $uninstallStr = Get-ItemProperty -Path $key.PSPath -Name "UninstallString" -ErrorAction SilentlyContinue

                    $orphan = $false
                    if ($installLoc -and $installLoc.InstallLocation -and -not (Test-Path $installLoc.InstallLocation -ErrorAction SilentlyContinue)) {
                        $orphan = $true
                    }
                    elseif ($uninstallStr -and $uninstallStr.UninstallString -and $uninstallStr.UninstallString -match '"(.+?)"') {
                        $exe = $matches[1]
                        if (-not (Test-Path $exe -ErrorAction SilentlyContinue)) { $orphan = $true }
                    }

                    if ($orphan -and -not $script:Config.DryRun) {
                        if ($BackupFirst) {
                            $backupPath = "$($script:Config.LogPath.Replace('.log', '_uninstall_backup.reg'))"
                            $regKeyName = $key.Name
                            & reg.exe export "$regKeyName" "$backupPath" /y > $null 2>&1
                        }
                        Remove-Item -Path $key.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                        Write-Log "Clé désinstallation orpheline supprimée: $($key.PSChildName)" "SUCCESS"
                        $cleaned++
                    } elseif ($orphan) {
                        Write-Log "[DRY-RUN] Supprimerait clé orpheline: $($key.PSChildName)" "INFO"
                        $cleaned++
                    }
                }
            }
        }
    } catch {
        Write-Log "Nettoyage Uninstall partiel: $_" "WARN"
        $failed++
    }

    if ($Aggressive) {
        try {
            $extKeys = Get-ChildItem -Path "HKCR:" -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\.' }
            foreach ($ext in $extKeys) {
                $progId = Get-ItemProperty -Path $ext.PSPath -Name "(default)" -ErrorAction SilentlyContinue
                if ($progId -and $progId."(default)") {
                    $clsIdPath = "HKCR:\$($progId.'(default)')\CLSID"
                    if (-not (Test-Path $clsIdPath -ErrorAction SilentlyContinue)) {
                        if (-not $script:Config.DryRun) {
                            Remove-Item -Path $ext.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                            Write-Log "Extension orpheline supprimée: $($ext.PSChildName)" "SUCCESS"
                            $cleaned++
                        } else {
                            Write-Log "[DRY-RUN] Supprimerait extension orpheline: $($ext.PSChildName)" "INFO"
                            $cleaned++
                        }
                    }
                }
            }
        } catch {
            Write-Log "Nettoyage extensions orphelines partiel: $_" "WARN"
            $failed++
        }
    }

    Write-Log "Nettoyage registre terminé. Clés nettoyées: $cleaned" "INFO"
    return @{ Cleaned = $cleaned; Failed = $failed }
}

# ════════════════════════════════════════════════════════════════════════
# RÉPARATION SYSTÈME (DISM / SFC) SÉCURISÉE & INTELLIGENTE
# ════════════════════════════════════════════════════════════════════════

function Invoke-SystemRepair {
    param(
        [switch]$RunDISM = $true,
        [switch]$RunSFC = $true,
        [switch]$RunChkdsk = $false
    )
    $results = @{}

    # 1. DISM CheckHealth & RestoreHealth intelligent
    if ($RunDISM) {
        Write-Log "Vérification intégrité image Windows (DISM)..." "INFO"
        try {
            if ($script:Config.DryRun) {
                Write-Log "[DRY-RUN] Lancerait DISM /Online /Cleanup-Image /CheckHealth" "INFO"
                $results.DISM = "DRY-RUN"
            } else {
                # S'assurer que le service Windows Update n'est pas désactivé
                $wu = Get-Service -Name "wuauserv" -ErrorAction SilentlyContinue
                if ($wu -and $wu.StartType -eq "Disabled") {
                    Set-Service -Name "wuauserv" -StartupType Manual -ErrorAction SilentlyContinue
                }

                # Vérification rapide (CheckHealth prend ~3-5 secondes)
                $checkRes = Invoke-NativeCommandWithProgress -FilePath "dism.exe" -ArgumentList "/Online /Cleanup-Image /CheckHealth /NoRestart" -ActivityTitle "DISM CheckHealth" -TimeoutSeconds 60

                if ($checkRes.Output -match "(No component store corruption detected|Aucun endommagement du magasin de composants)") {
                    Write-Log "Image Windows saine : aucune corruption détectée (RestoreHealth ignoré)" "SUCCESS"
                    $results.DISM = "HEALTHY"
                } else {
                    Write-Log "Réparation de l'image système requise (DISM /RestoreHealth)..." "INFO"
                    $restoreRes = Invoke-NativeCommandWithProgress -FilePath "dism.exe" -ArgumentList "/Online /Cleanup-Image /RestoreHealth /NoRestart" -ActivityTitle "DISM RestoreHealth" -TimeoutSeconds 600

                    if ($restoreRes.ExitCode -eq 0) {
                        Write-Log "DISM RestoreHealth terminé avec succès" "SUCCESS"
                        $results.DISM = "OK"
                    } elseif ($restoreRes.TimedOut) {
                        Write-Log "DISM RestoreHealth interrompu après délai limite (évite le blocage)" "WARN"
                        $results.DISM = "TIMED_OUT"
                    } else {
                        Write-Log "DISM RestoreHealth terminé avec code $($restoreRes.ExitCode)" "WARN"
                        $results.DISM = "EXIT_$($restoreRes.ExitCode)"
                    }
                }
            }
        } catch {
            Write-Log "Avertissement DISM: $_" "WARN"
            $results.DISM = "FAILED"
        }
    }

    # 2. SFC Scannow (avec timeout et progression en temps réel)
    if ($RunSFC) {
        Write-Log "Vérification fichiers système protégés (SFC /Scannow)..." "INFO"
        try {
            if ($script:Config.DryRun) {
                Write-Log "[DRY-RUN] Lancerait SFC /Scannow" "INFO"
                $results.SFC = "DRY-RUN"
            } else {
                $sfcRes = Invoke-NativeCommandWithProgress -FilePath "sfc.exe" -ArgumentList "/Scannow" -ActivityTitle "SFC Scannow" -TimeoutSeconds 600

                if ($sfcRes.ExitCode -eq 0) {
                    Write-Log "SFC terminé sans violation d'intégrité" "SUCCESS"
                    $results.SFC = "OK"
                } elseif ($sfcRes.TimedOut) {
                    Write-Log "SFC interrompu après délai limite (évite le blocage)" "WARN"
                    $results.SFC = "TIMED_OUT"
                } else {
                    Write-Log "SFC terminé avec le code $($sfcRes.ExitCode)" "INFO"
                    $results.SFC = "EXIT_$($sfcRes.ExitCode)"
                }
            }
        } catch {
            Write-Log "Avertissement SFC: $_" "WARN"
            $results.SFC = "FAILED"
        }
    }

    # 3. Chkdsk (planifié au redémarrage)
    if ($RunChkdsk) {
        Write-Log "Planification Chkdsk au prochain redémarrage..." "INFO"
        try {
            if ($script:Config.DryRun) {
                Write-Log "[DRY-RUN] Planifierait Chkdsk /f /r" "INFO"
                $results.Chkdsk = "DRY-RUN"
            } else {
                & chkdsk.exe $env:SystemDrive /f /r
                Write-Log "Chkdsk planifié (redémarrage requis)" "SUCCESS"
                $results.Chkdsk = "SCHEDULED"
            }
        } catch {
            Write-Log "Chkdsk non planifié: $_" "WARN"
            $results.Chkdsk = "FAILED"
        }
    }

    return $results
}

# ════════════════════════════════════════════════════════════════════════
# TÉLÉMÉTRIE - GPO
# ════════════════════════════════════════════════════════════════════════

function Disable-TelemetryGPO {
    Write-Log "Application politiques de groupe anti-télémétrie..." "INFO"

    $policies = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "AllowTelemetry"; Value = 0; Type = "DWord" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "DoNotShowFeedbackNotifications"; Value = 1; Type = "DWord" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat"; Name = "AITEnable"; Value = 0; Type = "DWord" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat"; Name = "DisableInventory"; Value = 1; Type = "DWord" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat"; Name = "DisablePCA"; Value = 1; Type = "DWord" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat"; Name = "DisableTelemetry"; Value = 1; Type = "DWord" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "AllowCortana"; Value = 0; Type = "DWord" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "DisableWebSearch"; Value = 1; Type = "DWord" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "ConnectedSearchUseWeb"; Value = 0; Type = "DWord" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "ConnectedSearchUseWebOverMeteredConnections"; Value = 0; Type = "DWord" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "PreventIndexingEncryptedStoresOrItems"; Value = 1; Type = "DWord" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Edge"; Name = "TelemetryEnabled"; Value = 0; Type = "DWord" }
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "MetricsReportingEnabled"; Value = 0; Type = "DWord" }
    )

    foreach ($pol in $policies) {
        try {
            if (-not (Test-Path $pol.Path -ErrorAction SilentlyContinue)) { New-Item -Path $pol.Path -Force -ErrorAction SilentlyContinue | Out-Null }
            if (-not $script:Config.DryRun) {
                Set-ItemProperty -Path $pol.Path -Name $pol.Name -Value $pol.Value -Type $pol.Type -Force -ErrorAction SilentlyContinue
            } else {
                Write-Log "[DRY-RUN] GPO: $($pol.Path)\$($pol.Name) = $($pol.Value)" "INFO"
            }
        } catch {
            Write-Log "GPO $($pol.Name) ignorée ou protégée: $_" "WARN"
        }
    }

    Write-Log "Politiques de groupe appliquées" "SUCCESS"
}

# ════════════════════════════════════════════════════════════════════════
# TÉLÉMÉTRIE - SERVICES VIA SC
# ════════════════════════════════════════════════════════════════════════

function Disable-TelemetryServices {
    Write-Log "Désactivation services télémétrie via SC..." "INFO"

    $telemetryServices = @(
        "DiagTrack",
        "dmwappushservice",
        "WerSvc",
        "wisvc",
        "TrkWks"
    )

    foreach ($svc in $telemetryServices) {
        try {
            $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if (-not $service) {
                Write-Log "Service absent: $svc" "DEBUG"
                continue
            }
            if (-not $script:Config.DryRun) {
                & sc.exe config $svc start= disabled > $null 2>&1
                & sc.exe stop $svc > $null 2>&1
            } else {
                Write-Log "[DRY-RUN] SC config $svc start= disabled" "INFO"
            }
            Write-Log "Service désactivé via SC: $svc" "SUCCESS"
        } catch {
            Write-Log "Avertissement SC ${svc}: $_" "WARN"
        }
    }
}

# ════════════════════════════════════════════════════════════════════════
# BLOCAGE DOMAINES TÉLÉMÉTRIE (Fichier HOSTS)
# ════════════════════════════════════════════════════════════════════════

function Block-TelemetryHosts {
    param([switch]$Enable = $true)
    Write-Log "Configuration fichier HOSTS pour bloquer télémétrie..." "INFO"

    $hostsPath = "$env:WINDIR\System32\drivers\etc\hosts"

    $telemetryDomains = @(
        "v10.events.data.microsoft.com"
        "v20.events.data.microsoft.com"
        "telemetry.microsoft.com"
        "watson.telemetry.microsoft.com"
        "diagnostics.support.microsoft.com"
        "feedback.windows.com"
        "telemetry.urs.microsoft.com"
        "oca.telemetry.microsoft.com"
        "sqm.telemetry.microsoft.com"
        "telecommand.telemetry.microsoft.com"
        "choice.microsoft.com"
    )

    try {
        if (-not (Test-Path $hostsPath -ErrorAction SilentlyContinue)) {
            Write-Log "Fichier hosts introuvable" "WARN"
            return
        }

        # Déverrouiller l'attribut lecture seule si présent
        try {
            $hItem = Get-Item $hostsPath -ErrorAction SilentlyContinue
            if ($hItem -and $hItem.IsReadOnly) {
                $hItem.IsReadOnly = $false
            }
        } catch { }

        $hostsContent = Get-Content -Path $hostsPath -Raw -ErrorAction SilentlyContinue
        if (-not $hostsContent) { return }

        if ($Enable) {
            $alreadyBlocked = $telemetryDomains | Where-Object { $hostsContent -match "0.0.0.0\s+$_" }
            if ($alreadyBlocked.Count -eq $telemetryDomains.Count) {
                Write-Log "Domaines télémétrie déjà bloqués dans hosts" "INFO"
                return
            }

            if ($script:Config.BackupRegistry) {
                try { Copy-Item -Path $hostsPath -Destination "$hostsPath.redadzdoptimiser_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')" -Force -ErrorAction SilentlyContinue } catch { }
            }

            if (-not $script:Config.DryRun) {
                $newEntries = $telemetryDomains | ForEach-Object { "0.0.0.0 $_" }
                $blockSection = @"

# === REDADZDOptimiser Telemetry Block Start ===
$($newEntries -join "`r`n")
# === REDADZDOptimiser Telemetry Block End ===
"@
                try {
                    Add-Content -Path $hostsPath -Value $blockSection -Encoding UTF8 -ErrorAction Stop
                    Write-Log "Domaines télémétrie bloqués dans hosts" "SUCCESS"
                } catch {
                    Write-Log "Le fichier hosts est protégé par le système ou l'antivirus (écriture ignorée sans impact)." "WARN"
                }
            } else {
                Write-Log "[DRY-RUN] Bloquerait $($telemetryDomains.Count) domaines dans hosts" "INFO"
            }
        }
    } catch {
        Write-Log "Fichier hosts protégé: $_" "WARN"
    }
}

# ════════════════════════════════════════════════════════════════════════
# PARE-FEU TÉLÉMÉTRIE
# ════════════════════════════════════════════════════════════════════════

function Set-FirewallTelemetryBlock {
    param([switch]$Enable = $true)
    Write-Log "Configuration pare-feu pour bloquer télémétrie..." "INFO"

    $rules = @(
        @{ 
            Name = "REDADZDOptimiser Block DiagTrack"
            Direction = "Outbound"
            Action = "Block"
            Service = "DiagTrack"
            Description = "Bloquer télémétrie DiagTrack sortante"
            Enabled = $true
            Profile = "Any" 
        }
    )

    foreach ($rule in $rules) {
        try {
            $existing = Get-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue
            if ($existing) {
                if (-not $Enable) {
                    if (-not $script:Config.DryRun) { Remove-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue }
                    Write-Log "Règle pare-feu supprimée: $($rule.Name)" "SUCCESS"
                } else {
                    Write-Log "Règle pare-feu existe déjà: $($rule.Name)" "INFO"
                }
            } elseif ($Enable) {
                $params = @{
                    DisplayName = $rule.Name
                    Direction = $rule.Direction
                    Action = $rule.Action
                    Description = $rule.Description
                    Enabled = $rule.Enabled
                    Profile = $rule.Profile
                }
                if ($rule.Service) { $params.Service = $rule.Service }

                if (-not $script:Config.DryRun) {
                    New-NetFirewallRule @params -ErrorAction SilentlyContinue | Out-Null
                    Write-Log "Règle pare-feu créée: $($rule.Name)" "SUCCESS"
                } else {
                    Write-Log "[DRY-RUN] Créerait règle pare-feu: $($rule.Name)" "INFO"
                }
            }
        } catch {
            Write-Log "Règle pare-feu non modifiable: $($rule.Name) ($_)" "WARN"
        }
    }
}


# ════════════════════════════════════════════════════════════════════════
# FONCTIONS DE PERFORMANCE : RAM, CPU & PROCESSUS
# ════════════════════════════════════════════════════════════════════════

function Get-SystemPerformanceMetrics {
    <#
    .SYNOPSIS
        Récupère en temps réel les métriques d'utilisation du CPU, de la RAM et le nombre de processus actifs.
    #>
    try {
        $mem = [REDADZD.SystemHelper]::GetMemoryStatus()
        $cpu = [REDADZD.SystemHelper]::GetCpuUsage()
        $totalGB = [math]::Round($mem.ullTotalPhys / 1GB, 2)
        $freeGB = [math]::Round($mem.ullAvailPhys / 1GB, 2)
        $usedGB = [math]::Round(($mem.ullTotalPhys - $mem.ullAvailPhys) / 1GB, 2)
        $loadPct = [int]$mem.dwMemoryLoad
        $procCount = @(Get-Process).Count

        return [PSCustomObject]@{
            CpuPercent   = $cpu
            TotalRamGB   = $totalGB
            FreeRamGB    = $freeGB
            UsedRamGB    = $usedGB
            RamPercent   = $loadPct
            ProcessCount = $procCount
        }
    } catch {
        return [PSCustomObject]@{
            CpuPercent   = 0.0
            TotalRamGB   = 0.0
            FreeRamGB    = 0.0
            UsedRamGB    = 0.0
            RamPercent   = 0
            ProcessCount = 0
        }
    }
}


function Get-SystemHardwareHealthAndDiagnostics {
    <#
    .SYNOPSIS
        Analyse approfondie de la santé matérielle (Processeur, RAM, Disque, Batterie)
        et recommandation intelligente du profil d'optimisation (Minimal, Standard, Max).
    #>
    [CmdletBinding()]
    param()

    # 1. Processeur (CPU)
    $cpuName = "Processeur Windows"
    $cores = [System.Environment]::ProcessorCount
    $threads = $cores
    $speed = 0
    $cpuLoad = 0.0

    try {
        $regCpu = Get-ItemProperty -Path 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0' -ErrorAction SilentlyContinue
        if ($regCpu -and $regCpu.ProcessorNameString) { $cpuName = $regCpu.ProcessorNameString.Trim() }
        if ($regCpu -and $regCpu.'~MHz') { $speed = [int]$regCpu.'~MHz' }
    } catch {}

    try {
        $wCpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($wCpu) {
            if ($wCpu.Name) { $cpuName = $wCpu.Name.Trim() }
            if ($wCpu.NumberOfCores) { $cores = $wCpu.NumberOfCores }
            if ($wCpu.NumberOfLogicalProcessors) { $threads = $wCpu.NumberOfLogicalProcessors }
            if ($wCpu.MaxClockSpeed) { $speed = $wCpu.MaxClockSpeed }
            if ($wCpu.LoadPercentage) { $cpuLoad = [double]$wCpu.LoadPercentage }
        }
    } catch {}

    if ($cpuLoad -eq 0.0) {
        try {
            $cpuLoad = [REDADZD.SystemHelper]::GetCpuUsage()
        } catch {}
    }

    $cpuHealth = if ($cpuLoad -gt 85) { "Surchargé (Charge élevée)" } elseif ($cpuLoad -gt 50) { "Sollicité (Normal)" } else { "Optimal (Sain ✓)" }

    # 2. Mémoire Vive (RAM)
    $totalRamGB = 0.0
    $usedRamGB  = 0.0
    $freeRamGB  = 0.0
    $ramPct     = 0
    $ramCount   = 1
    $ramSpeed   = 0

    try {
        $mem = [REDADZD.SystemHelper]::GetMemoryStatus()
        $totalRamGB = [math]::Round($mem.ullTotalPhys / 1GB, 1)
        $freeRamGB  = [math]::Round($mem.ullAvailPhys / 1GB, 1)
        $usedRamGB  = [math]::Round(($mem.ullTotalPhys - $mem.ullAvailPhys) / 1GB, 1)
        $ramPct     = [int]$mem.dwMemoryLoad
    } catch {
        try {
            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
            if ($os) {
                $totalRamGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
                $freeRamGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
                $usedRamGB  = [math]::Round($totalRamGB - $freeRamGB, 1)
                if ($totalRamGB -gt 0) { $ramPct = [int](($usedRamGB / $totalRamGB) * 100) }
            }
        } catch {}
    }

    try {
        $wMem = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue)
        if ($wMem -and $wMem.Count -gt 0) {
            $ramCount = $wMem.Count
            $ramSpeed = $wMem[0].Speed
        }
    } catch {}

    $ramHealth = if ($ramPct -gt 85) { "Saturation critique (>85%)" } elseif ($ramPct -gt 65) { "Utilisation élevée" } else { "Optimale (Sain ✓)" }

    # 3. Disque Dur & Stockage (C:)
    $diskName   = "Disque Système Principal"
    $diskType   = "SSD"
    $diskSmart  = "Healthy (Sain ✓)"
    $cTotalGB   = 0.0
    $cFreeGB    = 0.0
    $cUsedGB    = 0.0
    $cFreePct   = 0.0

    try {
        $c = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.Name -like 'C:*' } | Select-Object -First 1
        if ($c) {
            $cTotalGB = [math]::Round($c.TotalSize / 1GB, 1)
            $cFreeGB  = [math]::Round($c.TotalFreeSpace / 1GB, 1)
            $cUsedGB  = [math]::Round(($c.TotalSize - $c.TotalFreeSpace) / 1GB, 1)
            if ($cTotalGB -gt 0) {
                $cFreePct = [math]::Round(($c.TotalFreeSpace / $c.TotalSize) * 100, 1)
            }
        }
    } catch {}

    try {
        $pDisk = Get-PhysicalDisk -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($pDisk) {
            if ($pDisk.FriendlyName) { $diskName = $pDisk.FriendlyName }
            if ($pDisk.MediaType)    { $diskType = $pDisk.MediaType }
            if ($pDisk.HealthStatus) { $diskSmart = "$($pDisk.HealthStatus) (S.M.A.R.T. OK ✓)" }
        }
    } catch {}

    $diskHealth = if ($cFreeGB -lt 20 -or $cFreePct -lt 15) { "Espace disque critique (<15% libre)" } elseif ($cFreeGB -lt 40 -or $cFreePct -lt 25) { "Espace modéré" } else { "Excellent (Sain ✓)" }

    # 4. Batterie & Énergie
    $hasBattery    = $false
    $batteryCharge = 100
    $batteryStatus = "Alimentation Secteur (PC Fixe)"
    $batteryHealth = "Alimentation continue (Secteur)"

    try {
        $wBat = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($wBat) {
            $hasBattery = $true
            if ($wBat.EstimatedChargeRemaining) { $batteryCharge = [int]$wBat.EstimatedChargeRemaining }
            $isPlugged = ($wBat.BatteryStatus -eq 2 -or $wBat.BatteryStatus -eq 6 -or $wBat.BatteryStatus -eq 7 -or $wBat.BatteryStatus -eq 8)
            $batteryStatus = if ($isPlugged) { "Sur secteur (Branché • $($batteryCharge)%)" } else { "Sur batterie (Décharge • $($batteryCharge)%)" }
            $batteryHealth = if ($batteryCharge -gt 80) { "Excellente (Bonne autonomie)" } elseif ($batteryCharge -gt 40) { "Correcte" } else { "Faible (Recharge conseillée)" }
        }
    } catch {}

    # 5. Processus et Bloatwares
    $procCount = 0
    try { $procCount = @(Get-Process).Count } catch {}

    # 6. Algorithme de Recommandation de Tweak
    $score = 0

    if ($totalRamGB -gt 0 -and $totalRamGB -lt 8.0) { $score += 30 }
    elseif ($ramPct -gt 75) { $score += 25 }
    elseif ($ramPct -gt 55) { $score += 15 }

    if ($cFreeGB -gt 0 -and $cFreeGB -lt 25.0) { $score += 25 }
    elseif ($cFreePct -gt 0 -and $cFreePct -lt 20.0) { $score += 20 }
    elseif ($cFreeGB -gt 0 -and $cFreeGB -lt 50.0) { $score += 10 }

    if ($procCount -gt 220) { $score += 25 }
    elseif ($procCount -gt 150) { $score += 15 }
    elseif ($procCount -gt 100) { $score += 8 }

    if ($cpuLoad -gt 50.0) { $score += 15 }

    $recProfile = "Standard"
    $recTitle   = "Tweak Standard"
    $recReason  = ""

    if ($score -ge 50) {
        $recProfile = "Max"
        $recTitle   = "Tweak Max"
        $recReason  = "Ce PC présente une charge élevée ($($ramPct)% RAM, $($procCount) processus, $($cFreeGB) Go libres sur C:). Le profil Max désactivera tous les services inutiles, libèrera un maximum de mémoire et dopera les performances du processeur."
    } elseif ($score -le 20 -and $totalRamGB -ge 16.0 -and $cFreeGB -ge 60.0) {
        $recProfile = "Minimal"
        $recTitle   = "Tweak Minimal"
        $recReason  = "Ce PC dispose de ressources généreuses ($($totalRamGB) Go RAM, $($cFreeGB) Go libres, matériel sain). Le profil Minimal applique les optimisations essentielles sans modifier les réglages avancés."
    } else {
        $recProfile = "Standard"
        $recTitle   = "Tweak Standard"
        $recReason  = "Configuration idéale pour un usage polyvalent (travail, multimédia, jeux). Le profil Standard supprime les bloatwares préinstallés et la télémétrie Windows tout en garantissant une stabilité absolue du système."
    }

    $adviceRam = if ($totalRamGB -lt 8.0) {
        "Mémoire vive limitée ($($totalRamGB) Go) : La purge périodique du cache RAM est indispensable. Fermez les applications inutiles en arrière-plan et envisagez d'ajouter une barrette pour plus de confort."
    } elseif ($ramPct -gt 75) {
        "Forte occupation mémoire ($($ramPct)%) : $($usedRamGB) Go utilisés sur $($totalRamGB) Go. Utilisez le bouton 'Vider le cache & RAM' pour récupérer immédiatement jusqu'à 2 Go de mémoire tampon inactive."
    } else {
        "Mémoire vive saine ($($totalRamGB) Go, $($ramPct)% utilisée) : $($freeRamGB) Go de mémoire disponible. Vos barrettes ($($ramCount) module(s) à $($ramSpeed) MHz) fonctionnent dans d'excellentes conditions."
    }

    $adviceDisk = if ($cFreeGB -lt 25.0) {
        "Attention : Espace disque C: très restreint ($($cFreeGB) Go restants). Lancez un nettoyage immédiat des fichiers temporaires et des mises à jour obsolètes via l'onglet Nettoyage pour éviter tout ralentissement Windows."
    } elseif ($cFreePct -lt 25.0) {
        "Espace de stockage modéré ($($cFreeGB) Go libres, $($cFreePct)% disponible). Un nettoyage régulier préservera les cellules de mémoire de votre $($diskType)."
    } else {
        "Stockage $($diskType) en excellent état : $($cFreeGB) Go libres sur $($cTotalGB) Go ($($cFreePct)% d'espace libre). Statut S.M.A.R.T. : $($diskSmart)."
    }

    $adviceCpu = if ($procCount -gt 200 -or $cpuLoad -gt 50) {
        "Activité processeur dense : $($procCount) processus actifs ($($cpuLoad)% de charge). Désactivez les applications inutiles au démarrage pour réduire la charge de fond sur les $($cores) cœurs."
    } else {
        "Processeur $($cpuName) ($($cores) cœurs / $($threads) threads) fluide et réactif. Activez le plan d'alimentation 'Performances Élevées' pour débloquer la réactivité maximale en jeu ou en calcul."
    }

    $adviceBattery = if ($hasBattery) {
        "Batterie $($batteryStatus). Pour prolonger la durée de vie chimique de la batterie, évitez les décharges profondes sous 20% et privilégiez une charge modérée si votre constructeur le propose."
    } else {
        "Système alimenté sur secteur fixe (PC de bureau). Aucun bridage de consommation batterie n'est appliqué : vous pouvez activer les performances maximales sans compromis d'autonomie."
    }

    return [PSCustomObject]@{
        CPU = [PSCustomObject]@{
            Name        = $cpuName
            Cores       = $cores
            Threads     = $threads
            SpeedMHz    = $speed
            LoadPercent = $cpuLoad
            Health      = $cpuHealth
        }
        RAM = [PSCustomObject]@{
            TotalGB      = $totalRamGB
            UsedGB       = $usedRamGB
            FreeGB       = $freeRamGB
            UsagePercent = $ramPct
            ModuleCount  = $ramCount
            SpeedMHz     = $ramSpeed
            Health       = $ramHealth
        }
        Disk = [PSCustomObject]@{
            DriveLetter = "C:"
            Model       = $diskName
            Type        = $diskType
            TotalGB     = $cTotalGB
            UsedGB      = $cUsedGB
            FreeGB      = $cFreeGB
            FreePercent = $cFreePct
            SmartStatus = $diskSmart
            Health      = $diskHealth
        }
        Battery = [PSCustomObject]@{
            HasBattery     = $hasBattery
            ChargePercent  = $batteryCharge
            StatusText     = $batteryStatus
            HealthText     = $batteryHealth
        }
        System = [PSCustomObject]@{
            ProcessCount = $procCount
            Score        = $score
        }
        Recommendation = [PSCustomObject]@{
            Profile       = $recProfile
            Title         = $recTitle
            Score         = $score
            Reason        = $recReason
            AdviceRAM     = $adviceRam
            AdviceDisk    = $adviceDisk
            AdviceCPU     = $adviceCpu
            AdviceBattery = $adviceBattery
        }
    }
}

function Optimize-RAM {
    <#
    .SYNOPSIS
        Purge la mémoire inactive des processus de travail (EmptyWorkingSet) et force le ramasse-miettes système.
    #>
    [CmdletBinding()]
    param(
        [switch]$DryRun
    )

    Write-Log "Optimisation de la mémoire vive (RAM) en cours..." "INFO"

    $memBefore = [REDADZD.SystemHelper]::GetMemoryStatus()
    $beforeAvailMB = [math]::Round($memBefore.ullAvailPhys / 1MB, 2)
    $beforeUsedMB = [math]::Round(($memBefore.ullTotalPhys - $memBefore.ullAvailPhys) / 1MB, 2)

    if ($DryRun) {
        Write-Log "[SIMULATION] Libération du cache RAM simulée." "WARN"
        return [PSCustomObject]@{
            BeforeUsedMB = $beforeUsedMB
            AfterUsedMB  = $beforeUsedMB
            FreedMB      = 0
            ProcessCount = 0
            Success      = $true
        }
    }

    $protected = @(
        'System', 'Idle', 'smss', 'csrss', 'wininit', 'services', 'lsass', 'winlogon',
        'explorer', 'dwm', 'RuntimeBroker', 'svchost', 'fontdrvhost', 'spoolsv'
    )

    $flushedCount = 0
    $allProcesses = Get-Process -ErrorAction SilentlyContinue

    foreach ($proc in $allProcesses) {
        if ($script:Config.CancelRequested) { break }
        if (-not $proc -or $proc.Id -le 4) { continue }
        if ($protected -contains $proc.ProcessName) { continue }

        try {
            if ($proc.Handle -ne [IntPtr]::Zero) {
                if ([REDADZD.SystemHelper]::FlushProcessWorkingSet($proc.Handle)) {
                    $flushedCount++
                }
            }
        } catch {
            # Processus protégé ou accès refusé, ignoré
        }
    }

    # Collecte garbage collector .NET
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    Start-Sleep -Milliseconds 250

    $memAfter = [REDADZD.SystemHelper]::GetMemoryStatus()
    $afterAvailMB = [math]::Round($memAfter.ullAvailPhys / 1MB, 2)
    $afterUsedMB = [math]::Round(($memAfter.ullTotalPhys - $memAfter.ullAvailPhys) / 1MB, 2)
    $freedMB = [math]::Round($afterAvailMB - $beforeAvailMB, 2)
    if ($freedMB -lt 0) { $freedMB = 0 }

    Write-Log "Cache RAM vidé avec succès sur $flushedCount processus." "SUCCESS"
    Write-Log "Mémoire libérée : ~$freedMB Mo (RAM utilisée actuelle : $([math]::Round($afterUsedMB / 1024, 2)) Go)" "SUCCESS"

    return [PSCustomObject]@{
        BeforeUsedMB = $beforeUsedMB
        AfterUsedMB  = $afterUsedMB
        FreedMB      = $freedMB
        ProcessCount = $flushedCount
        Success      = $true
    }
}

function Stop-UnnecessaryProcesses {
    <#
    .SYNOPSIS
        Arrête de façon sécurisée les processus d'arrière-plan inutiles (bloatware, télémétrie, widgets, etc.)
    #>
    [CmdletBinding()]
    param(
        [switch]$DryRun
    )

    Write-Log "Analyse et fermeture des processus d'arrière-plan inutiles..." "INFO"

    $targetProcesses = @(
        'PhoneExperienceHost',      # Lien avec votre téléphone
        'YourPhone',
        'GameBarPresenceWriter',    # Xbox Game Bar
        'XboxGamingOverlay',
        'XboxApp',
        'Widgets',                  # Widgets Windows 11
        'WidgetService',
        'Cortana',                  # Assistant Cortana
        'SearchApp',
        'NewsAndInterests',         # Actualités Windows
        'FeedbackHub',              # Commentaires Windows
        'QuickAssist',              # Assistance rapide
        'SkypeApp',                 # Skype
        'SkypeBackgroundHost',
        'CompatTelRunner',          # Télémétrie Microsoft
        'DeviceCensus',             # Recensement télémétrie
        'wermgr',                   # Rapport d'erreurs
        'Microsoft.Photos'          # Arrière-plan Photos
    )

    $whitelist = @(
        'System', 'Idle', 'smss', 'csrss', 'wininit', 'services', 'lsass', 'winlogon',
        'explorer', 'dwm', 'RuntimeBroker', 'svchost', 'fontdrvhost', 'spoolsv',
        'taskmgr', 'powershell', 'pwsh', 'cmd', 'conhost'
    )

    $terminated = @()
    $running = Get-Process -ErrorAction SilentlyContinue

    foreach ($proc in $running) {
        if ($script:Config.CancelRequested) { break }
        if (-not $proc -or $proc.Id -le 4) { continue }

        $name = $proc.ProcessName
        if ($whitelist -contains $name) { continue }

        if ($targetProcesses -contains $name) {
            if ($DryRun) {
                Write-Log "[SIMULATION] Processus ciblé : $name (PID: $($proc.Id))" "WARN"
                $terminated += $name
            } else {
                try {
                    Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                    $terminated += "$name (PID: $($proc.Id))"
                    Write-Log "Processus arrêté : $name" "SUCCESS"
                } catch {
                    Write-Log "Impossible d'arrêter le processus $name : $_" "WARN"
                }
            }
        }
    }

    # Nettoyage des instances Edge dormantes en tâche de fond (sans fenêtre)
    try {
        $edgeProcs = Get-Process -Name "msedge" -ErrorAction SilentlyContinue
        if ($edgeProcs) {
            $hasVisibleWindow = ($edgeProcs | Where-Object { $_.MainWindowTitle -and $_.MainWindowTitle.Length -gt 0 })
            if (-not $hasVisibleWindow) {
                foreach ($ep in $edgeProcs) {
                    if ($DryRun) {
                        $terminated += "msedge (background)"
                    } else {
                        try {
                            Stop-Process -Id $ep.Id -Force -ErrorAction SilentlyContinue
                            $terminated += "msedge (PID: $($ep.Id))"
                        } catch {}
                    }
                }
                if ($edgeProcs.Count -gt 0) {
                    Write-Log "Instances Microsoft Edge en tâche de fond arrêtées ($($edgeProcs.Count) instances)." "SUCCESS"
                }
            }
        }
    } catch {}

    $uniqueCount = ($terminated | Select-Object -Unique).Count
    Write-Log "Fermeture terminée : $uniqueCount processus d'arrière-plan inutiles arrêtés." "SUCCESS"

    return [PSCustomObject]@{
        TerminatedCount = $uniqueCount
        TerminatedList  = $terminated
    }
}

function Optimize-CPU {
    <#
    .SYNOPSIS
        Optimise les réglages processeur et alimentation (Plan d'alimentation haute performance, priorité CPU applications premier plan, core parking).
    #>
    [CmdletBinding()]
    param(
        [switch]$HighPerformancePower = $true,
        [switch]$ForegroundPriority = $true,
        [switch]$DisableCoreParking = $false,
        [switch]$DryRun
    )

    Write-Log "Application des optimisations processeur & énergie..." "INFO"

    $results = @{
        PowerPlan          = "Ignoré"
        PrioritySeparation = "Ignoré"
        CoreParking        = "Ignoré"
    }

    # 1. Plan d'alimentation
    if ($HighPerformancePower) {
        if ($DryRun) {
            Write-Log "[SIMULATION] Activation du plan d'alimentation 'Performances Élevées'" "WARN"
            $results.PowerPlan = "Simulé"
        } else {
            try {
                $ultimateGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
                $highPerfGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"

                & powercfg /duplicatescheme $ultimateGuid 2>$null | Out-Null
                $powerOutput = & powercfg /setactive $ultimateGuid 2>&1
                if ($LASTEXITCODE -ne 0) {
                    & powercfg /setactive $highPerfGuid 2>$null | Out-Null
                    Write-Log "Plan d'alimentation : Performances Élevées activé." "SUCCESS"
                    $results.PowerPlan = "Performances Élevées"
                } else {
                    Write-Log "Plan d'alimentation : Performances Optimales (Ultimate) activé." "SUCCESS"
                    $results.PowerPlan = "Performances Optimales"
                }
            } catch {
                Write-Log "Erreur activation plan d'alimentation : $_" "WARN"
                $results.PowerPlan = "Échec"
            }
        }
    }

    # 2. Win32PrioritySeparation
    if ($ForegroundPriority) {
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
        if ($DryRun) {
            Write-Log "[SIMULATION] Configuration Win32PrioritySeparation = 38 (0x26: priorité premier plan)" "WARN"
            $results.PrioritySeparation = "Simulé"
        } else {
            try {
                if (-not (Test-Path $regPath)) {
                    New-Item -Path $regPath -Force | Out-Null
                }
                Set-ItemProperty -Path $regPath -Name "Win32PrioritySeparation" -Value 38 -Type DWord -Force
                Write-Log "Priorité CPU au premier plan configurée (Win32PrioritySeparation = 0x26 / 38)." "SUCCESS"
                $results.PrioritySeparation = "Appliqué (38 / 0x26)"
            } catch {
                Write-Log "Erreur configuration Win32PrioritySeparation : $_" "WARN"
                $results.PrioritySeparation = "Échec"
            }
        }
    }

    # 3. Core Parking
    if ($DisableCoreParking) {
        if ($DryRun) {
            Write-Log "[SIMULATION] Désactivation du Core Parking CPU" "WARN"
            $results.CoreParking = "Simulé"
        } else {
            try {
                & powercfg -setacvalueindex scheme_current sub_processor CPMINCORES 100 2>$null | Out-Null
                & powercfg -setdcvalueindex scheme_current sub_processor CPMINCORES 100 2>$null | Out-Null
                & powercfg -setactive scheme_current 2>$null | Out-Null
                Write-Log "Core Parking CPU désactivé (100% des cœurs toujours actifs)." "SUCCESS"
                $results.CoreParking = "Désactivé (100% cœurs)"
            } catch {
                Write-Log "Erreur configuration Core Parking : $_" "WARN"
                $results.CoreParking = "Échec"
            }
        }
    }

    return [PSCustomObject]$results
}


# ════════════════════════════════════════════════════════════════════════
# 13. INSTALLATEUR DE LOGICIELS (WINGET)
# ════════════════════════════════════════════════════════════════════════

function Resolve-WingetPath {
    $cmd = Get-Command "winget.exe" -ErrorAction SilentlyContinue
    if ($cmd -and (Test-Path $cmd.Source)) { return $cmd.Source }
    $appPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    if (Test-Path $appPath) { return $appPath }
    $progPath = "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe"
    $found = Get-ChildItem $progPath -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { return $found.FullName }
    return "winget"
}

function Test-WingetInstalled {
    try {
        $wPath = Resolve-WingetPath
        $proc = Start-Process -FilePath $wPath -ArgumentList "--version" -NoNewWindow -Wait -PassThru -ErrorAction Stop
        return ($proc.ExitCode -eq 0)
    } catch {
        return $false
    }
}

function Install-WingetApps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$AppIds,
        [scriptblock]$OnProgress
    )
    $results = @{
        Installed = @()
        Failed    = @()
    }

    $wPath = Resolve-WingetPath

    $total = $AppIds.Count
    $current = 0
    foreach ($app in $AppIds) {
        $current++
        if ($script:Config.CancelRequested) { break }
        Write-Log "Installation de l'application ($current/$total) : $app..." "INFO"
        if ($OnProgress) { & $OnProgress $app $current $total }

        try {
            $argList = "install --id `"$app`" --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity"
            $p = Start-Process -FilePath $wPath -ArgumentList $argList -NoNewWindow -Wait -PassThru -ErrorAction Stop
            if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 2316632065 -or $p.ExitCode -eq -1978335189) { # 0 = Success, already installed
                Write-Log "Application installée avec succès : $app" "SUCCESS"
                $results.Installed += $app
            } else {
                Write-Log "Échec ou avertissement installation pour $app (Code: $($p.ExitCode))" "WARN"
                $results.Failed += $app
            }
        } catch {
            Write-Log "Erreur lors de l'installation de $app : $_" "WARN"
            $results.Failed += $app
        }
    }
    return [PSCustomObject]$results
}

# ════════════════════════════════════════════════════════════════════════
# 14. OPTIMISATION RÉSEAU, PING & DNS GAMING
# ════════════════════════════════════════════════════════════════════════

function Get-ActiveNetworkAdapters {
    $adapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
    if (-not $adapters) {
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" }
    }
    return $adapters
}

function Set-SystemDns {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Cloudflare", "Google", "Quad9", "DHCP")]
        [string]$Provider
    )

    $adapters = Get-ActiveNetworkAdapters
    if (-not $adapters) {
        Write-Log "Aucune carte réseau active détectée pour la configuration DNS." "WARN"
        return $false
    }

    $dnsServers = switch ($Provider) {
        "Cloudflare" { @("1.1.1.1", "1.0.0.1") }
        "Google"     { @("8.8.8.8", "8.8.4.4") }
        "Quad9"      { @("9.9.9.9", "149.112.112.112") }
        "DHCP"       { $null }
    }

    $successCount = 0
    foreach ($adapter in $adapters) {
        try {
            if ($Provider -eq "DHCP") {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ResetServerAddresses -ErrorAction Stop
                Write-Log "DNS remis en automatique (DHCP) sur : $($adapter.Name)" "SUCCESS"
                $successCount++
            } else {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $dnsServers -ErrorAction Stop
                Write-Log "DNS $Provider ($($dnsServers -join ', ')) configuré sur : $($adapter.Name)" "SUCCESS"
                $successCount++
            }
        } catch {
            Write-Log "Erreur configuration DNS sur $($adapter.Name) : $_" "WARN"
        }
    }
    return ($successCount -gt 0)
}

function Reset-NetworkStack {
    Write-Log "Réinitialisation et vidage du cache réseau..." "INFO"
    try {
        & ipconfig /flushdns 2>$null | Out-Null
        Write-Log "Cache de résolution DNS vidé avec succès (ipconfig /flushdns)." "SUCCESS"
    } catch {}
    try {
        & netsh winsock reset 2>$null | Out-Null
        Write-Log "Catalogue Winsock réinitialisé." "SUCCESS"
    } catch {}
    try {
        & netsh int ip reset 2>$null | Out-Null
        Write-Log "Pile protocolaire TCP/IP réinitialisée." "SUCCESS"
    } catch {}
    return $true
}

function Optimize-NetworkGaming {
    [CmdletBinding()]
    param([switch]$DryRun)

    Write-Log "Application des optimisations latence réseau & gaming (TCP/IP)..." "INFO"
    $regMultimedia = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    $regTCPIP = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"

    if ($DryRun) {
        Write-Log "[SIMULATION] Optimisations latence réseau appliquées." "WARN"
        return $true
    }

    try {
        # 1. Supprimer le bridage réseau Windows Multimédia
        if (-not (Test-Path $regMultimedia)) { New-Item -Path $regMultimedia -Force | Out-Null }
        Set-ItemProperty -Path $regMultimedia -Name "NetworkThrottlingIndex" -Value 0xffffffff -Type DWord -Force
        Set-ItemProperty -Path $regMultimedia -Name "SystemResponsiveness" -Value 0 -Type DWord -Force
        Write-Log "Limitation réseau multimédia désactivée (NetworkThrottlingIndex = OFF)." "SUCCESS"

        # 2. Désactiver l'algorithme Nagle sur chaque interface
        if (Test-Path $regTCPIP) {
            Get-ChildItem -Path $regTCPIP | ForEach-Object {
                $subKey = $_.PSPath
                Set-ItemProperty -Path $subKey -Name "TcpAckFrequency" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $subKey -Name "TCPNoDelay" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            }
            Write-Log "Algorithme Nagle désactivé (TcpAckFrequency=1, TCPNoDelay=1 pour gaming)." "SUCCESS"
        }
        return $true
    } catch {
        Write-Log "Erreur optimisation réseau gaming : $_" "WARN"
        return $false
    }
}

# ════════════════════════════════════════════════════════════════════════
# 15. GESTIONNAIRE DE DÉMARRAGE WINDOWS (STARTUP MANAGER)
# ════════════════════════════════════════════════════════════════════════

function Get-StartupPrograms {
    $items = @()

    # 1. HKCU Run (Actifs)
    $runHKCU = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    if (Test-Path $runHKCU -ErrorAction SilentlyContinue) {
        try {
            $props = Get-ItemProperty -Path $runHKCU -ErrorAction SilentlyContinue
            if ($props) {
                foreach ($prop in $props.PSObject.Properties) {
                    if ($prop.Name -notin @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider')) {
                        $items += [PSCustomObject]@{
                            Name     = $prop.Name
                            Command  = [string]$prop.Value
                            Location = "HKCU:Run"
                            Status   = "Activé"
                        }
                    }
                }
            }
        } catch {}
    }

    # 1b. HKCU RunDisabled (Désactivés)
    $runDisabledHKCU = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunDisabled"
    if (Test-Path $runDisabledHKCU -ErrorAction SilentlyContinue) {
        try {
            $props = Get-ItemProperty -Path $runDisabledHKCU -ErrorAction SilentlyContinue
            if ($props) {
                foreach ($prop in $props.PSObject.Properties) {
                    if ($prop.Name -notin @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider')) {
                        $items += [PSCustomObject]@{
                            Name     = $prop.Name
                            Command  = [string]$prop.Value
                            Location = "HKCU:RunDisabled"
                            Status   = "Désactivé"
                        }
                    }
                }
            }
        } catch {}
    }

    # 2. HKLM Run (Actifs)
    $runHKLM = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
    if (Test-Path $runHKLM -ErrorAction SilentlyContinue) {
        try {
            $props = Get-ItemProperty -Path $runHKLM -ErrorAction SilentlyContinue
            if ($props) {
                foreach ($prop in $props.PSObject.Properties) {
                    if ($prop.Name -notin @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider')) {
                        $items += [PSCustomObject]@{
                            Name     = $prop.Name
                            Command  = [string]$prop.Value
                            Location = "HKLM:Run"
                            Status   = "Activé"
                        }
                    }
                }
            }
        } catch {}
    }

    # 2b. HKLM RunDisabled (Désactivés)
    $runDisabledHKLM = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunDisabled"
    if (Test-Path $runDisabledHKLM -ErrorAction SilentlyContinue) {
        try {
            $props = Get-ItemProperty -Path $runDisabledHKLM -ErrorAction SilentlyContinue
            if ($props) {
                foreach ($prop in $props.PSObject.Properties) {
                    if ($prop.Name -notin @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider')) {
                        $items += [PSCustomObject]@{
                            Name     = $prop.Name
                            Command  = [string]$prop.Value
                            Location = "HKLM:RunDisabled"
                            Status   = "Désactivé"
                        }
                    }
                }
            }
        } catch {}
    }

    # 3. Dossiers Startup Utilisateur
    $userStartup = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    if (Test-Path $userStartup -ErrorAction SilentlyContinue) {
        try {
            Get-ChildItem -Path $userStartup -Filter "*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
                $items += [PSCustomObject]@{
                    Name     = $_.BaseName
                    Command  = $_.FullName
                    Location = "Startup:User"
                    Status   = "Activé"
                }
            }
            $userDisabled = Join-Path $userStartup "Disabled"
            if (Test-Path $userDisabled -ErrorAction SilentlyContinue) {
                Get-ChildItem -Path $userDisabled -Filter "*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
                    $items += [PSCustomObject]@{
                        Name     = $_.BaseName
                        Command  = $_.FullName
                        Location = "Startup:User"
                        Status   = "Désactivé"
                    }
                }
            }
        } catch {}
    }

    # 4. Dossiers Startup Commun (Tous les utilisateurs)
    $allStartup = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
    if (Test-Path $allStartup -ErrorAction SilentlyContinue) {
        try {
            Get-ChildItem -Path $allStartup -Filter "*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
                $items += [PSCustomObject]@{
                    Name     = $_.BaseName
                    Command  = $_.FullName
                    Location = "Startup:Common"
                    Status   = "Activé"
                }
            }
            $allDisabled = Join-Path $allStartup "Disabled"
            if (Test-Path $allDisabled -ErrorAction SilentlyContinue) {
                Get-ChildItem -Path $allDisabled -Filter "*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
                    $items += [PSCustomObject]@{
                        Name     = $_.BaseName
                        Command  = $_.FullName
                        Location = "Startup:Common"
                        Status   = "Désactivé"
                    }
                }
            }
        } catch {}
    }

    return $items
}

function Disable-StartupProgram {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [string]$Location
    )
    try {
        switch -Wildcard ($Location) {
            "*HKCU*" {
                $reg = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
                $backup = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunDisabled"
                if (-not (Test-Path $backup)) { New-Item -Path $backup -Force | Out-Null }
                $val = (Get-ItemProperty -Path $reg -Name $Name -ErrorAction SilentlyContinue).$Name
                if ($val) {
                    Set-ItemProperty -Path $backup -Name $Name -Value $val -Force
                    Remove-ItemProperty -Path $reg -Name $Name -Force -ErrorAction SilentlyContinue
                    Write-Log "Programme désactivé au démarrage : $Name" "SUCCESS"
                    return $true
                }
            }
            "*HKLM*" {
                $reg = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
                $backup = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunDisabled"
                if (-not (Test-Path $backup)) { New-Item -Path $backup -Force | Out-Null }
                $val = (Get-ItemProperty -Path $reg -Name $Name -ErrorAction SilentlyContinue).$Name
                if ($val) {
                    Set-ItemProperty -Path $backup -Name $Name -Value $val -Force
                    Remove-ItemProperty -Path $reg -Name $Name -Force -ErrorAction SilentlyContinue
                    Write-Log "Programme désactivé au démarrage : $Name" "SUCCESS"
                    return $true
                }
            }
            default {
                # Dossiers Startup
                $folder = if ($Location -like "*Common*") { "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup" } else { "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" }
                $targetFile = Join-Path $folder "$Name.lnk"
                if (Test-Path $targetFile) {
                    $disabledFolder = Join-Path $folder "Disabled"
                    if (-not (Test-Path $disabledFolder)) { New-Item -Path $disabledFolder -ItemType Directory -Force | Out-Null }
                    Move-Item -Path $targetFile -Destination (Join-Path $disabledFolder "$Name.lnk") -Force
                    Write-Log "Raccourci de démarrage désactivé : $Name" "SUCCESS"
                    return $true
                }
            }
        }
    } catch {
        Write-Log "Erreur désactivation démarrage pour $Name : $_" "WARN"
        return $false
    }
    return $false
}

function Enable-StartupProgram {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [string]$Location
    )
    try {
        switch -Wildcard ($Location) {
            "*HKCU*" {
                $reg = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
                $backup = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunDisabled"
                if (Test-Path $backup) {
                    $prop = (Get-ItemProperty -Path $backup -Name $Name -ErrorAction SilentlyContinue)
                    if ($null -ne $prop -and $null -ne $prop.$Name) {
                        $val = $prop.$Name
                        if (-not (Test-Path $reg)) { New-Item -Path $reg -Force | Out-Null }
                        Set-ItemProperty -Path $reg -Name $Name -Value $val -Force
                        Remove-ItemProperty -Path $backup -Name $Name -Force -ErrorAction SilentlyContinue
                        Write-Log "Programme réactivé au démarrage : $Name" "SUCCESS"
                        return $true
                    }
                }
            }
            "*HKLM*" {
                $reg = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
                $backup = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunDisabled"
                if (Test-Path $backup) {
                    $prop = (Get-ItemProperty -Path $backup -Name $Name -ErrorAction SilentlyContinue)
                    if ($null -ne $prop -and $null -ne $prop.$Name) {
                        $val = $prop.$Name
                        if (-not (Test-Path $reg)) { New-Item -Path $reg -Force | Out-Null }
                        Set-ItemProperty -Path $reg -Name $Name -Value $val -Force
                        Remove-ItemProperty -Path $backup -Name $Name -Force -ErrorAction SilentlyContinue
                        Write-Log "Programme réactivé au démarrage : $Name" "SUCCESS"
                        return $true
                    }
                }
            }
            default {
                # Dossiers Startup
                $folder = if ($Location -like "*Common*") { "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup" } else { "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" }
                $disabledFolder = Join-Path $folder "Disabled"
                $disabledFile = Join-Path $disabledFolder "$Name.lnk"
                if (Test-Path $disabledFile) {
                    Move-Item -Path $disabledFile -Destination (Join-Path $folder "$Name.lnk") -Force
                    Write-Log "Raccourci de démarrage réactivé : $Name" "SUCCESS"
                    return $true
                }
            }
        }
    } catch {
        Write-Log "Erreur réactivation démarrage pour $Name : $_" "WARN"
        return $false
    }
    return $false
}

# ════════════════════════════════════════════════════════════════════════
# ORCHESTRATEUR PRINCIPAL
# ════════════════════════════════════════════════════════════════════════


# Aliases pour rétro-compatibilité
Set-Alias -Name Invoke-WinOptimizer -Value Invoke-REDADZDOptimiser -ErrorAction SilentlyContinue
Set-Alias -Name Set-WinOptimizerConfig -Value Set-REDADZDOptimiserConfig -ErrorAction SilentlyContinue
Set-Alias -Name Get-WinOptimizerConfig -Value Get-REDADZDOptimiserConfig -ErrorAction SilentlyContinue
$script:WinOptimizerConfig = $script:REDADZDOptimiserConfig

function Invoke-REDADZDOptimiser {
    [CmdletBinding()]
    param(
        [bool]$CreateRestorePoint       = $true,
        [bool]$RemoveApps               = $true,
        [bool]$AppsAllUsers             = $true,
        [bool]$ConfigureServices        = $true,
        [bool]$DisableTasks             = $true,
        [bool]$PrivacyRegistry          = $true,
        [bool]$DiskCleanup              = $true,
        [bool]$CleanRecycleBin          = $true,
        [bool]$CleanWinUpdate           = $true,
        [bool]$RegistryCleanup          = $false,
        [bool]$RegCleanAggressive       = $false,
        [bool]$SystemRepair             = $false,
        [bool]$RunDISM                  = $false,
        [bool]$RunSFC                   = $true,
        [bool]$RunChkdsk                = $false,
        [bool]$BlockHosts               = $true,
        [bool]$FirewallBlock            = $true,
        [bool]$DisableTelemetryGPO      = $true,
        [bool]$DisableTelemetryServices = $true,
        [bool]$OptimizeRAM              = $false,
        [bool]$StopBloatProcesses       = $false,
        [bool]$OptimizeCPU              = $false,
        [bool]$HighPerformancePower     = $true,
        [bool]$ForegroundPriority       = $true,
        [bool]$DisableCoreParking       = $false,
        [bool]$DryRun                   = $false,
        [bool]$VerboseOutput            = $false,
        [string]$Language               = "FR",

        # Paramètres de rétro-compatibilité
        [switch]$SkipRestorePoint,
        [switch]$SkipApps,
        [switch]$SkipServices,
        [switch]$SkipTasks,
        [switch]$SkipPrivacy,
        [switch]$SkipCleanup,
        [switch]$SkipRepair,
        [switch]$SkipHostsBlock,
        [switch]$SkipFirewall,
        [switch]$SkipGPO,
        [switch]$SkipSCServices,
        [switch]$SkipRegistry,
        [switch]$SkipDiskCleanup,
        [switch]$EnableRegistryCleanup
    )

    # Prise en compte de la rétro-compatibilité
    if ($PSBoundParameters.ContainsKey('SkipRestorePoint') -and $SkipRestorePoint) { $CreateRestorePoint = $false }
    if ($PSBoundParameters.ContainsKey('SkipApps') -and $SkipApps) { $RemoveApps = $false }
    if ($PSBoundParameters.ContainsKey('SkipServices') -and $SkipServices) { $ConfigureServices = $false }
    if ($PSBoundParameters.ContainsKey('SkipTasks') -and $SkipTasks) { $DisableTasks = $false }
    if ($PSBoundParameters.ContainsKey('SkipPrivacy') -and $SkipPrivacy) {
        $PrivacyRegistry = $false
        $DisableTelemetryGPO = $false
        $BlockHosts = $false
        $FirewallBlock = $false
        $DisableTelemetryServices = $false
    }
    if ($PSBoundParameters.ContainsKey('SkipCleanup') -and $SkipCleanup) {
        $DiskCleanup = $false
        $RegistryCleanup = $false
    }
    if ($PSBoundParameters.ContainsKey('SkipRepair') -and $SkipRepair) {
        $SystemRepair = $false
        $RunDISM = $false
        $RunSFC = $false
        $RunChkdsk = $false
    }
    if ($PSBoundParameters.ContainsKey('SkipHostsBlock') -and $SkipHostsBlock) { $BlockHosts = $false }
    if ($PSBoundParameters.ContainsKey('SkipFirewall') -and $SkipFirewall) { $FirewallBlock = $false }
    if ($PSBoundParameters.ContainsKey('SkipGPO') -and $SkipGPO) { $DisableTelemetryGPO = $false }
    if ($PSBoundParameters.ContainsKey('SkipSCServices') -and $SkipSCServices) { $DisableTelemetryServices = $false }
    if ($PSBoundParameters.ContainsKey('SkipRegistry') -and $SkipRegistry) { $PrivacyRegistry = $false }
    if ($PSBoundParameters.ContainsKey('SkipDiskCleanup') -and $SkipDiskCleanup) { $DiskCleanup = $false }
    if ($PSBoundParameters.ContainsKey('EnableRegistryCleanup') -and $EnableRegistryCleanup) { $RegistryCleanup = $true }

    if ($DryRun) { $script:Config.DryRun = $true }
    if ($VerbosePreference -eq 'Continue' -or $VerboseOutput) { $script:Config.VerboseOutput = $true }

    $startTime = Get-Date
    Write-Log "=== DÉBUT REDADZDOPTIMISER ===" "INFO"
    Write-Log "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"
    Write-Log "Mode: $(if ($DryRun) { 'SIMULATION (DRY-RUN)' } else { 'EXÉCUTION RÉELLE' })" "INFO"

    $results = @{}

    # 1. Point de restauration
    if ($CreateRestorePoint -and -not $DryRun) {
        if ($script:Config.CancelRequested) { Write-Log "Optimisation interrompue par l'utilisateur." "WARN"; return $results }
        Write-Log "--- Étape 1/12: Point de restauration ---" "INFO"
        $results.RestorePoint = New-SystemRestorePoint
    }

    # 2. Suppression Apps
    if ($RemoveApps) {
        if ($script:Config.CancelRequested) { Write-Log "Optimisation interrompue par l'utilisateur." "WARN"; return $results }
        Write-Log "--- Étape 2/12: Suppression apps provisionnées ---" "INFO"
        $results.Apps = Remove-ProvisionedApps -AllUsers:$AppsAllUsers
    }

    # 3. Services Windows
    if ($ConfigureServices) {
        if ($script:Config.CancelRequested) { Write-Log "Optimisation interrompue par l'utilisateur." "WARN"; return $results }
        Write-Log "--- Étape 3/12: Services Windows ---" "INFO"
        $results.Services = Set-ServicesState
    }

    # 4. Tâches planifiées
    if ($DisableTasks) {
        if ($script:Config.CancelRequested) { Write-Log "Optimisation interrompue par l'utilisateur." "WARN"; return $results }
        Write-Log "--- Étape 4/12: Tâches planifiées ---" "INFO"
        $results.Tasks = Disable-ScheduledTasks
    }

    # 5. Registre vie privée
    if ($PrivacyRegistry) {
        if ($script:Config.CancelRequested) { Write-Log "Optimisation interrompue par l'utilisateur." "WARN"; return $results }
        Write-Log "--- Étape 5/12: Registre vie privée ---" "INFO"
        $results.PrivacyRegistry = Set-PrivacyRegistry
    }

    # 6. GPO Télémétrie
    if ($DisableTelemetryGPO) {
        if ($script:Config.CancelRequested) { Write-Log "Optimisation interrompue par l'utilisateur." "WARN"; return $results }
        Write-Log "--- Étape 6/12: GPO Anti-télémétrie ---" "INFO"
        Disable-TelemetryGPO
    }

    # 7. Services Télémétrie (SC)
    if ($DisableTelemetryServices) {
        if ($script:Config.CancelRequested) { Write-Log "Optimisation interrompue par l'utilisateur." "WARN"; return $results }
        Write-Log "--- Étape 7/12: Services télémétrie (SC) ---" "INFO"
        Disable-TelemetryServices
    }

    # 8. Hosts
    if ($BlockHosts) {
        if ($script:Config.CancelRequested) { Write-Log "Optimisation interrompue par l'utilisateur." "WARN"; return $results }
        Write-Log "--- Étape 8/12: Blocage hôtes télémétrie ---" "INFO"
        Block-TelemetryHosts -Enable $true
    }

    # 9. Pare-feu
    if ($FirewallBlock) {
        if ($script:Config.CancelRequested) { Write-Log "Optimisation interrompue par l'utilisateur." "WARN"; return $results }
        Write-Log "--- Étape 9/12: Pare-feu anti-télémétrie ---" "INFO"
        Set-FirewallTelemetryBlock -Enable $true
    }

    # 10. Nettoyage disque
    if ($DiskCleanup) {
        if ($script:Config.CancelRequested) { Write-Log "Optimisation interrompue par l'utilisateur." "WARN"; return $results }
        Write-Log "--- Étape 10/12: Nettoyage disque ---" "INFO"
        $results.DiskCleanup = Invoke-DiskCleanup -IncludeRecycleBin:$CleanRecycleBin -IncludeWindowsUpdate:$CleanWinUpdate
    }

    # 11. Nettoyage registre (optionnel)
    if ($RegistryCleanup) {
        if ($script:Config.CancelRequested) { Write-Log "Optimisation interrompue par l'utilisateur." "WARN"; return $results }
        Write-Log "--- Étape 11/12: Nettoyage registre ---" "INFO"
        $results.RegistryCleanup = Invoke-RegistryCleanup -BackupFirst $true -Aggressive:$RegCleanAggressive
    }

    # 12. Réparation système
    if ($SystemRepair -and ($RunDISM -or $RunSFC -or $RunChkdsk)) {
        if ($script:Config.CancelRequested) { Write-Log "Optimisation interrompue par l'utilisateur." "WARN"; return $results }
        Write-Log "--- Étape 12/12: Réparation système ---" "INFO"
        $results.SystemRepair = Invoke-SystemRepair -RunDISM:$RunDISM -RunSFC:$RunSFC -RunChkdsk:$RunChkdsk
    }

    # Optimisation Processeur & Énergie
    if ($OptimizeCPU) {
        if ($script:Config.CancelRequested) { Write-Log "Optimisation interrompue par l'utilisateur." "WARN"; return $results }
        Write-Log "--- Optimisations Processeur & Énergie ---" "INFO"
        $results.CPU = Optimize-CPU -HighPerformancePower:$HighPerformancePower -ForegroundPriority:$ForegroundPriority -DisableCoreParking:$DisableCoreParking -DryRun:$DryRun
    }

    # Nettoyage des processus d'arrière-plan inutiles
    if ($StopBloatProcesses) {
        if ($script:Config.CancelRequested) { Write-Log "Optimisation interrompue par l'utilisateur." "WARN"; return $results }
        Write-Log "--- Nettoyage des processus d'arrière-plan ---" "INFO"
        $results.Processes = Stop-UnnecessaryProcesses -DryRun:$DryRun
    }

    # Purge et optimisation RAM
    if ($OptimizeRAM) {
        if ($script:Config.CancelRequested) { Write-Log "Optimisation interrompue par l'utilisateur." "WARN"; return $results }
        Write-Log "--- Optimisation de la mémoire vive (RAM) ---" "INFO"
        $results.RAM = Optimize-RAM -DryRun:$DryRun
    }

    $endTime = Get-Date
    $duration = $endTime - $startTime

    Write-Log "=== FIN REDADZDOPTIMISER ===" "INFO"
    Write-Log "Durée totale: $($duration.Hours)h $($duration.Minutes)min $($duration.Seconds)s" "INFO"
    Write-Log "Log complet: $($script:Config.LogPath)" "INFO"

    if ($DryRun) {
        Write-Log "MODE DRY-RUN : Aucune modification réelle effectuée" "WARN"
    }

    return $results
}

# ════════════════════════════════════════════════════════════════════════
# ROLLBACK, RAPPORT CLIENT, STATUT LICENCE & MISE À JOUR
# ════════════════════════════════════════════════════════════════════════

function Get-REDADZDBackupSummary {
    $logDir = Split-Path -Path $script:Config.LogPath -Parent
    $regFiles = @()
    if ($logDir -and (Test-Path $logDir)) {
        $regFiles = @(Get-ChildItem -Path $logDir -Filter "*_regbackup_*.reg" -ErrorAction SilentlyContinue) +
                    @(Get-ChildItem -Path $logDir -Filter "*_uninstall_backup.reg" -ErrorAction SilentlyContinue)
    }
    $hostsDir = "$env:WINDIR\System32\drivers\etc"
    $hostsBackups = @()
    if (Test-Path $hostsDir) {
        $hostsBackups = @(Get-ChildItem -Path $hostsDir -Filter "hosts.redadzdoptimiser_backup_*" -ErrorAction SilentlyContinue)
    }
    return @{
        RegBackupCount   = $regFiles.Count
        HostsBackupCount = $hostsBackups.Count
        RegFiles         = $regFiles
        HostsBackups     = $hostsBackups
    }
}

function Invoke-REDADZDRollback {
    Write-Log "=== DÉMARRAGE ROLLBACK / RESTAURATION ÉTAT PRÉCÉDENT ===" "INFO"
    $summary = Get-REDADZDBackupSummary
    $regRestored = 0
    $regFailed   = 0
    $hostsRestored = $false
    $servicesRestored = 0

    # 1. Restauration des sauvegardes registre (.reg)
    foreach ($rf in ($summary.RegFiles | Sort-Object LastWriteTime -Descending)) {
        try {
            $proc = Start-Process -FilePath "reg.exe" -ArgumentList "import `"$($rf.FullName)`"" -Wait -NoNewWindow -PassThru -ErrorAction Stop
            if ($proc.ExitCode -eq 0) {
                $regRestored++
                Write-Log "Registre restauré : $($rf.Name)" "SUCCESS"
            } else {
                $regFailed++
                Write-Log "Échec import registre ($($rf.Name)) : code $($proc.ExitCode)" "WARN"
            }
        } catch {
            $regFailed++
            Write-Log "Erreur import registre ($($rf.Name)) : $_" "WARN"
        }
    }

    # 2. Restauration du fichier hosts
    $hostsPath = "$env:WINDIR\System32\drivers\etc\hosts"
    $latestHosts = $summary.HostsBackups | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latestHosts -and (Test-Path $latestHosts.FullName)) {
        try {
            $hItem = Get-Item $hostsPath -ErrorAction SilentlyContinue
            if ($hItem -and $hItem.IsReadOnly) { Set-ItemProperty -Path $hostsPath -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue }
            Copy-Item -Path $latestHosts.FullName -Destination $hostsPath -Force -ErrorAction Stop
            $hostsRestored = $true
            Write-Log "Fichier hosts restauré depuis $($latestHosts.Name)" "SUCCESS"
        } catch {
            Write-Log "Impossible de restaurer le fichier hosts : $_" "WARN"
        }
    } elseif (Test-Path $hostsPath) {
        try {
            $raw = Get-Content -Path $hostsPath -Raw -ErrorAction SilentlyContinue
            if ($raw -and $raw -match "# === REDADZDOptimiser Telemetry Block Start ===") {
                $cleaned = [regex]::Replace($raw, "(?s)\r?\n?# === REDADZDOptimiser Telemetry Block Start ===.*?# === REDADZDOptimiser Telemetry Block End ===\r?\n?", "")
                Set-Content -Path $hostsPath -Value $cleaned -Encoding UTF8 -ErrorAction Stop
                $hostsRestored = $true
                Write-Log "Bloc télémétrie retiré du fichier hosts" "SUCCESS"
            }
        } catch {
            Write-Log "Nettoyage hosts impossible : $_" "WARN"
        }
    }

    # 3. Réactivation des services non critiques mis en manuel/auto si désactivés
    $restoreServices = @("WSearch", "SysMain", "PrintNotify", "Spooler", "MapsBroker", "WerSvc")
    foreach ($svcName in $restoreServices) {
        try {
            $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if ($svc -and $svc.StartType -eq "Disabled") {
                Set-Service -Name $svcName -StartupType Manual -ErrorAction SilentlyContinue
                $servicesRestored++
            }
        } catch { }
    }
    if ($servicesRestored -gt 0) {
        Write-Log "$servicesRestored service(s) réactivé(s) en mode Manuel" "SUCCESS"
    }

    Write-Log "=== FIN ROLLBACK : $regRestored clé(s) .reg, Hosts=$hostsRestored, $servicesRestored service(s) ===" "INFO"
    return @{
        RegRestored      = $regRestored
        RegFailed        = $regFailed
        HostsRestored    = $hostsRestored
        ServicesRestored = $servicesRestored
    }
}

function Get-SystemLicenseStatus {
    $items = @()
    try {
        $products = Get-CimInstance -ClassName SoftwareLicensingProduct -ErrorAction Stop |
            Where-Object { $_.PartialProductKey -and ($_.Name -match "Windows|Office") }

        foreach ($p in $products) {
            $statusText = switch ([int]$p.LicenseStatus) {
                0 { "Sans licence" }
                1 { "Activé ✓" }
                2 { "Période de grâce initiale" }
                3 { "Période de grâce supplémentaire" }
                4 { "Grâce non authentique" }
                5 { "Mode notification" }
                6 { "Grâce étendue" }
                default { "Inconnu ($($p.LicenseStatus))" }
            }
            $items += [PSCustomObject]@{
                Name              = $p.Name
                Description       = $p.Description
                PartialProductKey = $p.PartialProductKey
                LicenseStatus     = [int]$p.LicenseStatus
                StatusText        = $statusText
                IsActivated       = ([int]$p.LicenseStatus -eq 1)
            }
        }
    } catch {
        Write-Log "Lecture statut licence impossible : $_" "WARN"
    }
    return $items
}

function Export-REDADZDClientReport {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        [hashtable]$Results = $null,
        [object]$Diag = $null,
        [string[]]$LogLines = @()
    )

    if (-not $Diag) {
        try { $Diag = Get-SystemHardwareHealthAndDiagnostics } catch { $Diag = $null }
    }
    $licenses = Get-SystemLicenseStatus
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    $pcName = $env:COMPUTERNAME
    $dateStr = Get-Date -Format "dd/MM/yyyy HH:mm"

    $diagHtml = "<p style='color:#64748B;'>Diagnostic matériel non exécuté.</p>"
    if ($Diag) {
        $diagHtml = @"
        <div class="grid">
            <div class="card"><h3>Processeur (CPU)</h3><p><strong>$($Diag.CPU.Name)</strong><br>$($Diag.CPU.Cores) cœurs / $($Diag.CPU.Threads) threads • $($Diag.CPU.SpeedMHz) MHz<br>Santé : <span class="badge">$($Diag.CPU.Health)</span></p></div>
            <div class="card"><h3>Mémoire Vive (RAM)</h3><p><strong>$($Diag.RAM.TotalGB) Go</strong> ($($Diag.RAM.UsagePercent)% utilisée)<br>$($Diag.RAM.FreeGB) Go libres • $($Diag.RAM.SpeedMHz) MHz<br>Santé : <span class="badge">$($Diag.RAM.Health)</span></p></div>
            <div class="card"><h3>Stockage (Disque C:)</h3><p><strong>$($Diag.Disk.Model)</strong> ($($Diag.Disk.Type))<br>$($Diag.Disk.FreeGB) Go libres / $($Diag.Disk.TotalGB) Go ($($Diag.Disk.FreePercent)% libre)<br>S.M.A.R.T. : $($Diag.Disk.SmartStatus) • <span class="badge">$($Diag.Disk.Health)</span></p></div>
            <div class="card"><h3>Batterie</h3><p><strong>$($Diag.Battery.StatusText)</strong><br>Charge : $($Diag.Battery.ChargePercent)%<br>Santé : <span class="badge">$($Diag.Battery.HealthText)</span></p></div>
        </div>
        <p style="margin-top:12px;"><strong>Profil recommandé :</strong> $($Diag.Recommendation.Title) (Score système : $($Diag.Recommendation.Score)/100)</p>
"@
    }

    $resRows = ""
    if ($Results) {
        if ($Results.Apps)            { $resRows += "<tr><td>Applications Bloatware</td><td>$($Results.Apps.Removed) supprimée(s), $($Results.Apps.Skipped) ignorée(s)</td></tr>" }
        if ($Results.Services)        { $resRows += "<tr><td>Services Windows</td><td>$($Results.Services.Changed) optimisé(s), $($Results.Services.Skipped) déjà conformes</td></tr>" }
        if ($Results.Tasks)           { $resRows += "<tr><td>Tâches planifiées</td><td>$($Results.Tasks.Disabled) désactivée(s)</td></tr>" }
        if ($Results.PrivacyRegistry) { $resRows += "<tr><td>Confidentialité & Registre</td><td>$($Results.PrivacyRegistry.Applied) paramètre(s) appliqué(s)</td></tr>" }
        if ($Results.DiskCleanup)     { $resRows += "<tr><td>Nettoyage Disque</td><td>~$($Results.DiskCleanup.FreedMB) Mo libérés</td></tr>" }
        if ($Results.RegistryCleanup) { $resRows += "<tr><td>Nettoyage Registre</td><td>$($Results.RegistryCleanup.Cleaned) entrée(s) orpheline(s)</td></tr>" }
        if ($Results.SystemRepair)    { $resRows += "<tr><td>Intégrité Système</td><td>DISM: $($Results.SystemRepair.DISM) | SFC: $($Results.SystemRepair.SFC)</td></tr>" }
        if ($Results.RestorePoint)    { $resRows += "<tr><td>Point de restauration</td><td>Créé avec succès ✓</td></tr>" }
        if ($Results.CPU)             { $resRows += "<tr><td>Processeur & Énergie</td><td>Plan=$($Results.CPU.PowerPlan) | Priorité=$($Results.CPU.PrioritySeparation)</td></tr>" }
        if ($Results.RAM)             { $resRows += "<tr><td>Optimisation RAM</td><td>~$($Results.RAM.FreedMB) Mo libérés</td></tr>" }
    }
    if (-not $resRows) {
        $resRows = "<tr><td colspan='2' style='color:#64748B;'>Aucune session d'optimisation exécutée durant cette session.</td></tr>"
    }

    $licRows = ""
    foreach ($l in $licenses) {
        $licRows += "<tr><td>$($l.Name)</td><td>*****-$($l.PartialProductKey)</td><td><strong>$($l.StatusText)</strong></td></tr>"
    }
    if (-not $licRows) {
        $licRows = "<tr><td colspan='3' style='color:#64748B;'>Aucune licence détectée ou accès WMI restreint.</td></tr>"
    }

    $recentLogs = ($LogLines | Select-Object -Last 35) -join "`n"
    $recentLogsEsc = [System.Net.WebUtility]::HtmlEncode($recentLogs)

    $html = @"
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>Rapport d'Intervention REDADZDOptimiser - $pcName</title>
<style>
  body { font-family: 'Segoe UI', Arial, sans-serif; background:#F8FAFC; color:#0F172A; margin:0; padding:32px; }
  .container { max-width:960px; margin:0 auto; background:#FFFFFF; border:1px solid #E2E8F0; border-radius:12px; padding:32px; box-shadow:0 4px 20px rgba(15,23,42,0.06); }
  .header { display:flex; justify-content:space-between; align-items:center; border-bottom:2px solid #2563EB; padding-bottom:16px; margin-bottom:24px; }
  .header h1 { margin:0; font-size:22px; color:#1E293B; }
  .meta { text-align:right; font-size:13px; color:#64748B; }
  h2 { font-size:16px; color:#2563EB; margin:24px 0 12px; border-left:4px solid #2563EB; padding-left:10px; }
  .grid { display:grid; grid-template-columns:1fr 1fr; gap:14px; }
  .card { background:#F8FAFC; border:1px solid #E2E8F0; border-radius:8px; padding:14px; }
  .card h3 { margin:0 0 6px; font-size:14px; color:#334155; }
  .card p { margin:0; font-size:13px; line-height:1.5; }
  .badge { display:inline-block; background:#ECFDF5; color:#047857; border:1px solid #A7F3D0; padding:2px 8px; border-radius:999px; font-size:12px; font-weight:600; }
  table { width:100%; border-collapse:collapse; font-size:13px; }
  th, td { text-align:left; padding:10px 12px; border-bottom:1px solid #E2E8F0; }
  th { background:#F1F5F9; color:#334155; }
  pre { background:#0F172A; color:#F1F5F9; padding:14px; border-radius:8px; font-size:12px; overflow-x:auto; white-space:pre-wrap; }
  .footer { margin-top:28px; padding-top:14px; border-top:1px solid #E2E8F0; display:flex; justify-content:space-between; font-size:12px; color:#64748B; }
  .print-btn { background:#2563EB; color:#FFF; border:none; padding:8px 16px; border-radius:6px; cursor:pointer; font-weight:600; }
  @media print { .print-btn { display:none; } body { padding:0; background:#FFF; } .container { border:none; box-shadow:none; } }
</style>
</head>
<body>
<div class="container">
  <div class="header">
    <div>
      <h1>⚡ REDADZDOptimiser — Rapport d'Intervention Client</h1>
      <div style="font-size:13px;color:#64748B;margin-top:4px;">Poste : <strong>$pcName</strong> • $($osInfo.Caption) (Build $($osInfo.BuildNumber))</div>
    </div>
    <div class="meta">
      <div>Date : $dateStr</div>
      <div style="margin-top:6px;"><button class="print-btn" onclick="window.print()">🖨️ Imprimer / Sauvegarder en PDF</button></div>
    </div>
  </div>

  <h2>🩺 Diagnostic & Santé Matérielle</h2>
  $diagHtml

  <h2>⚡ Résumé des Optimisations Appliquées</h2>
  <table>
    <thead><tr><th>Catégorie</th><th>Résultat</th></tr></thead>
    <tbody>$resRows</tbody>
  </table>

  <h2>🔑 Statut Officiel des Licences Windows & Office</h2>
  <table>
    <thead><tr><th>Produit</th><th>Clé partielle</th><th>Statut</th></tr></thead>
    <tbody>$licRows</tbody>
  </table>

  <h2>📋 Extrait du Journal d'Exécution</h2>
  <pre>$recentLogsEsc</pre>

  <div class="footer">
    <span>© 2026 REDADZDOptimiser • Anagou Reda</span>
    <span>Support Technique : 0542439514</span>
  </div>
</div>
</body>
</html>
"@

    [System.IO.File]::WriteAllText($OutputPath, $html, [System.Text.Encoding]::UTF8)
    Write-Log "Rapport client HTML exporté : $OutputPath" "SUCCESS"
    return $OutputPath
}

function Test-REDADZDUpdate {
    param(
        [string]$CurrentVersion = "2.1.0",
        [string]$RepoApiUrl = "https://api.github.com/repos/AnagouReda/REDADZDOptimiser/releases/latest"
    )
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $headers = @{ "User-Agent" = "REDADZDOptimiser/$CurrentVersion" }
        $resp = Invoke-RestMethod -Uri $RepoApiUrl -Headers $headers -TimeoutSec 6 -ErrorAction Stop
        $latest = ($resp.tag_name -replace '^v', '').Trim()
        if ($latest -and ([version]$latest -gt [version]$CurrentVersion)) {
            return @{ Success = $true; UpdateAvailable = $true; Current = $CurrentVersion; Latest = $latest; Url = $resp.html_url }
        }
        return @{ Success = $true; UpdateAvailable = $false; Current = $CurrentVersion; Latest = $latest; Url = $resp.html_url }
    } catch {
        return @{ Success = $false; UpdateAvailable = $false; Current = $CurrentVersion; Error = $_.Exception.Message }
    }
}

# ─── Export des fonctions publiques ─────────────────────────────────────
Export-ModuleMember -Function @(
    'Write-Log',
    'Write-ProgressBar',
    'Test-IsAdmin',
    'Invoke-NativeCommandWithProgress',
    'New-SystemRestorePoint',
    'Get-ProvisionedApps',
    'Remove-ProvisionedApps',
    'Reinstall-ProvisionedApps',
    'Set-ServicesState',
    'Disable-ScheduledTasks',
    'Enable-ScheduledTasks',
    'Set-PrivacyRegistry',
    'Invoke-DiskCleanup',
    'Invoke-RegistryCleanup',
    'Invoke-SystemRepair',
    'Disable-TelemetryGPO',
    'Disable-TelemetryServices',
    'Block-TelemetryHosts',
    'Set-FirewallTelemetryBlock',
    'Get-SystemPerformanceMetrics',
    'Get-SystemHardwareHealthAndDiagnostics',
    'Optimize-RAM',
    'Stop-UnnecessaryProcesses',
    'Optimize-CPU',
    'Resolve-WingetPath',
    'Test-WingetInstalled',
    'Install-WingetApps',
    'Get-ActiveNetworkAdapters',
    'Set-SystemDns',
    'Reset-NetworkStack',
    'Optimize-NetworkGaming',
    'Get-StartupPrograms',
    'Disable-StartupProgram',
    'Enable-StartupProgram',
    'Invoke-REDADZDOptimiser',
    'Invoke-WinOptimizer',
    'Set-REDADZDOptimiserConfig',
    'Set-WinOptimizerConfig',
    'Get-REDADZDOptimiserConfig',
    'Get-WinOptimizerConfig',
    'Set-REDADZDOptimiserConfig',
    'Get-REDADZDOptimiserConfig',
    'Get-REDADZDBackupSummary',
    'Invoke-REDADZDRollback',
    'Get-SystemLicenseStatus',
    'Export-REDADZDClientReport',
    'Test-REDADZDUpdate'
)

# ─── Export des variables de config (lecture seule) ─────────────────────
Export-ModuleMember -Variable @(
    'Config',
    'AppsToRemove',
    'AppsToKeep',
    'ServicesToDisable',
    'TasksToDisable',
    'PrivacyRegistrySettings',
    'CleanupPaths'
)
