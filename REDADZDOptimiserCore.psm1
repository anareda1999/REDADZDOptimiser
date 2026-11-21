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

        if ($proc.StandardOutput.Peek() -ne -1) {
            $line = $proc.StandardOutput.ReadLine()
            if ($line -and $line.Trim()) {
                $trimmed = $line.Trim()
                $outLines += $trimmed

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
        } else {
            Start-Sleep -Milliseconds 80
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

            Set-Service -Name $svc.Name -StartupType $targetStartup -ErrorAction Stop

            if ($Action -in @("Enable","Auto","Manual") -and $targetStartup -ne "Disabled") {
                Start-Service -Name $svc.Name -ErrorAction SilentlyContinue
            }

            Write-Log "Service configuré: $($svc.Name) = $targetStartup" "SUCCESS"
            $changed++
        } catch {
            Write-Log "Service $($svc.Name) protégé ou non modifiable: $_" "WARN"
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
        Write-ProgressBar "Désactivation tâches planifiées" ($disabled + $failed + $notFound + 1) $TaskPaths.Count "Traitement: $taskPath"

        try {
            $taskDir = Split-Path $taskPath
            $taskName = Split-Path $taskPath -Leaf
            $task = Get-ScheduledTask -TaskPath $taskDir -TaskName $taskName -ErrorAction SilentlyContinue

            if (-not $task) {
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

            Disable-ScheduledTask -TaskPath $taskDir -TaskName $taskName -ErrorAction Stop
            Write-Log "Tâche désactivée: $taskPath" "SUCCESS"
            $disabled++
        } catch {
            Write-Log "Tâche $taskPath protégée ou non modifiable: $_" "WARN"
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
            Enable-ScheduledTask -TaskPath (Split-Path $taskPath) -TaskName (Split-Path $taskPath -Leaf) -ErrorAction SilentlyContinue
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
                Add-Content -Path $hostsPath -Value $blockSection -Encoding UTF8 -ErrorAction SilentlyContinue
                Write-Log "Domaines télémétrie bloqués dans hosts" "SUCCESS"
            } else {
                Write-Log "[DRY-RUN] Bloquerait $($telemetryDomains.Count) domaines dans hosts" "INFO"
            }
        }
    } catch {
        Write-Log "Fichier hosts inaccessible: $_" "WARN"
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
# ORCHESTRATEUR PRINCIPAL
# ════════════════════════════════════════════════════════════════════════


# Aliases pour rétro-compatibilité
Set-Alias -Name Invoke-WinOptimizer -Value Invoke-REDADZDOptimiser -ErrorAction SilentlyContinue
Set-Alias -Name Set-WinOptimizerConfig -Value Set-REDADZDOptimiserConfig -ErrorAction SilentlyContinue
Set-Alias -Name Get-WinOptimizerConfig -Value Get-REDADZDOptimiserConfig -ErrorAction SilentlyContinue
$script:WinOptimizerConfig = $script:REDADZDOptimiserConfig

function Invoke-REDADZDOptimiser {
    param(
        [switch]$CreateRestorePoint = $true,
        [switch]$RemoveApps = $true,
        [switch]$ConfigureServices = $true,
        [switch]$DisableTasks = $true,
        [switch]$PrivacyRegistry = $true,
        [switch]$DiskCleanup = $true,
        [switch]$RegistryCleanup = $false,
        [switch]$SystemRepair = $true,
        [switch]$BlockHosts = $true,
        [switch]$FirewallBlock = $true,
        [switch]$DisableTelemetryGPO = $true,
        [switch]$DisableTelemetryServices = $true,
        [switch]$OptimizeRAM = $false,
        [switch]$StopBloatProcesses = $false,
        [switch]$OptimizeCPU = $false,
        [switch]$DryRun,
        [switch]$Verbose
    )

    if ($DryRun) { $script:Config.DryRun = $true }
    if ($Verbose) { $script:Config.VerboseOutput = $true }

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
        $results.Apps = Remove-ProvisionedApps -AllUsers:$true
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
        $results.DiskCleanup = Invoke-DiskCleanup -IncludeRecycleBin -IncludeWindowsUpdate
    }

    # 11. Nettoyage registre (optionnel)
    if ($RegistryCleanup) {
        if ($script:Config.CancelRequested) { Write-Log "Optimisation interrompue par l'utilisateur." "WARN"; return $results }
        Write-Log "--- Étape 11/12: Nettoyage registre ---" "INFO"
        $results.RegistryCleanup = Invoke-RegistryCleanup -BackupFirst $true -Aggressive $false
    }

    # 12. Réparation système
    if ($SystemRepair) {
        if ($script:Config.CancelRequested) { Write-Log "Optimisation interrompue par l'utilisateur." "WARN"; return $results }
        Write-Log "--- Étape 12/12: Réparation système ---" "INFO"
        $results.SystemRepair = Invoke-SystemRepair -RunDISM -RunSFC -RunChkdsk:$false
    }

    # Optimisation Processeur & Énergie
    if ($OptimizeCPU) {
        if ($script:Config.CancelRequested) { Write-Log "Optimisation interrompue par l'utilisateur." "WARN"; return $results }
        Write-Log "--- Optimisations Processeur & Énergie ---" "INFO"
        $results.CPU = Optimize-CPU -DryRun:$DryRun
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
    'Optimize-RAM',
    'Stop-UnnecessaryProcesses',
    'Optimize-CPU',
    'Invoke-REDADZDOptimiser',
    'Invoke-WinOptimizer',
    'Set-REDADZDOptimiserConfig',
    'Set-WinOptimizerConfig',
    'Get-REDADZDOptimiserConfig',
    'Get-WinOptimizerConfig',
    'Set-REDADZDOptimiserConfig',
    'Get-REDADZDOptimiserConfig'
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
