<#
.SYNOPSIS
    REDADZDOptimiser GUI - Interface graphique professionnelle Windows (FR / EN / AR)
    Thème moderne épuré & professionnel (Windows 11 Fluent / Slate & Pure White)

.DESCRIPTION
    Application WinForms moderne et claire avec onglets :
    - Débloat : Apps provisionnées, Services de télémétrie, Tâches planifiées
    - Vie Privée : Registre, Stratégies de groupe (GPO), Fichier HOSTS, Pare-feu
    - Nettoyage : Fichiers temporaires, Corbeille, Windows Update (DISM), Registre orphelin
    - Réparation : DISM RestoreHealth, SFC Scannow, Chkdsk, Point de restauration
    - Logs : Journalisation en temps réel avec coloration syntaxique et export
    - Support multilingue complet : Français, English, العربية (avec affichage stable)

.NOTES
    Auteur: REDADZDOptimiser Team
    Version: 2.2 - Professional Edition
    Compatibilité: Windows 10 & Windows 11 (x64)
#>

#Requires -Version 5.1
#Requires -Assembly System.Windows.Forms
#Requires -Assembly System.Drawing

param(
    [ValidateSet("FR", "EN", "AR", "fr", "en", "ar", "")]
    [string]$Language = ""
)

[System.Windows.Forms.Application]::EnableVisualStyles()
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ─── Chargement du module core ─────────────────────────────────────────
if (-not $PSScriptRoot) {
    $PSScriptRoot = if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
}
$script:ModulePath = Join-Path $PSScriptRoot "REDADZDOptimiserCore.psm1"

if (-not (Test-Path $script:ModulePath)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Fichier REDADZDOptimiserCore.psm1 introuvable dans:`n$PSScriptRoot",
        "Erreur fatale",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}

Import-Module $script:ModulePath -Force

# Relier les logs et la progression du module vers la GUI
Set-REDADZDOptimiserConfig -OnLog {
    param($msg, $lvl)
    Append-Log $msg $lvl
} -OnProgress {
    param($act, $cur, $tot, $stat, $pct)
    Update-UIProgress $act $cur $tot $stat $pct
}

# ─── Variables globales GUI ────────────────────────────────────────────
$script:IsRunning = $false
$script:CancelToken = $false
$script:CurrentLang = "FR"
$script:LogLines = @()
$script:SuppressLangEvent = $false
$script:CurrentPreset = "Standard"

# ─── Dictionnaire de traduction (FR / EN / AR) ─────────────────────────
$script:I18N = @{
    "FR" = @{
        AppTitle            = "REDADZDOptimiser Professional"
        SubTitle            = "Centre d'Optimisation Windows 10/11  •  Débloat, Confidentialité, Nettoyage & Intégrité"
        LangLabel           = "Langue :"
        AdminOk             = "✓ ADMINISTRATEUR (Élevé)"
        AdminErr            = "⚠ NON-ADMIN (Droits limités)"
        AdminMsgBox         = "Ce programme requiert les privilèges Administrateur pour appliquer les optimisations !"

        TabDebloat          = "🗑️ Débloat"
        TabPerf             = "⚡ Performance"
        TabSoftware         = "📦 Logiciels"
        TabNetwork          = "🌐 Réseau & DNS"
        TabStartup          = "🚀 Démarrage"
        TabPrivacy          = "🔒 Vie Privée"
        TabCleanup          = "🧹 Nettoyage"
        TabRepair           = "🔧 Maintenance"
        TabLogs             = "📋 Journal"

        # Préréglages d'optimisation & Copyright
        PresetLabel         = "⚡ Préréglages :"
        BtnPresetMin        = "🌱 Tweak Minimal"
        BtnPresetStd        = "⚡ Tweak Standard"
        BtnPresetMax        = "🚀 Tweak Max"
        PresetDescMin       = "(Sécurisé : Cache & Temp, préserve apps et services)"
        PresetDescStd       = "(Recommandé : Débloat, télémétrie, nettoyage & CPU)"
        PresetDescMax       = "(Extrême & Gaming : Débloat total, registre, réparation & puissance max)"
        PresetAppliedLog    = "Préréglage '{0}' appliqué avec succès."
        CopyrightText       = "© 2026 REDADZDOptimiser • Anagou Reda  |  Tél : 0542439514"


        # Onglet Logiciels (Winget)
        GbBrowsers          = "Navigateurs Web"
        GbUtilities         = "Utilitaires & Fichiers"
        GbGamingApps        = "Jeux & Streaming"
        GbDevOffice         = "Bureautique & Développement"
        BtnSelectAllApps    = "✓ Tout cocher"
        BtnDeselectAllApps  = "✕ Tout décocher"
        BtnInstallApps      = "🚀 Installer les applications cochées (Winget)"
        BtnInstallingApps   = "⏳ Installation en cours..."
        InstallAppsDone     = "✓ Installation terminée : {0} installées, {1} échecs."

        # Onglet Réseau & DNS
        GbDnsSelector       = "Sélecteur DNS Rapide & Sécurisé"
        OptDnsCloudflare    = "⚡ Cloudflare (1.1.1.1 / 1.0.0.1 - Vitesse max & Jeux en ligne)"
        OptDnsGoogle        = "🔒 Google DNS (8.8.8.8 / 8.8.4.4 - Haute compatibilité)"
        OptDnsQuad9         = "🛡️ Quad9 (9.9.9.9 - Sécurité anti-malware renforcée)"
        OptDnsDhcp          = "🔄 Automatique / FAI (DHCP standard par défaut)"
        BtnApplyDns         = "⚡ Appliquer le serveur DNS sélectionné"
        BtnApplyDnsDone     = "✓ DNS appliqué avec succès !"

        GbGamingNetwork     = "Optimisations Latence Réseau & Gaming (Ping TCP/IP)"
        CbNetThrottling     = "Désactiver la limitation de bande passante multimédia (NetworkThrottlingIndex)"
        CbNagleAlgo         = "Désactiver l'algorithme Nagle (TcpAckFrequency & TCPNoDelay = 1)"
        BtnApplyGamingNet   = "🚀 Appliquer les optimisations réseau gaming"
        BtnApplyGamingDone  = "✓ Tweaks TCP/IP gaming appliqués !"

        GbResetNetwork      = "Dépannage & Réinitialisation Réseau"
        LblResetNetworkDesc = "Vide le cache DNS et réinitialise Winsock et la pile TCP/IP pour réparer les erreurs de connexion."
        BtnResetNetStack    = "🧹 Vider le cache DNS & Réinitialiser Winsock / IP"
        BtnResetNetDone     = "✓ Réseau et cache DNS réinitialisés !"

        # Onglet Démarrage (Startup Manager)
        GbStartupManager    = "Gestionnaire des Applications au Démarrage de Windows"
        LblStartupDesc      = "Désactivez les logiciels superflus au démarrage pour faire démarrer votre PC en quelques secondes."
        BtnRefreshStartup   = "🔄 Actualiser la liste"
        BtnDisableStartup   = "🛑 Désactiver l'application sélectionnée"
        ColStartupName      = "Nom"
        ColStartupLocation  = "Emplacement"
        ColStartupStatus    = "Statut"
        ColStartupCommand   = "Commande / Chemin"
        StartupDisabledDone = "✓ Application '{0}' désactivée au démarrage."

        # Onglet Performances
        GbPerfMonitor       = "Surveillance des Ressources en temps réel"
        PerfRamFormat       = "Mémoire Vive (RAM) : {0} Go / {1} Go ({2} %)"
        BtnFlushRam         = "🚀 Vider le cache & RAM"
        BtnFlushRamDone     = "✓ Cache RAM vidé : ~{0} Mo libérés !"
        PerfCpuFormat       = "Processeur (CPU) : {0} %  •  {1} processus actifs"
        PerfLiveNotice      = "● Surveillance continue en direct • 1.5s"
        PerfRamTip          = "Astuce : La purge de la mémoire vide en toute sécurité le cache inactif des processus en arrière-plan sans fermer vos applications."
        GbPerfKill          = "Nettoyeur de Processus d'Arrière-Plan Inutiles"
        PerfKillInfo        = "Ferme immédiatement les processus d'arrière-plan gourmands ou dormants (Phone Link, Game Bar, Widgets, Télémétrie Microsoft, Edge idle) tout en protégeant les processus système vitaux."
        PerfKillTargets     = "Processus ciblés : PhoneExperienceHost, GameBarPresenceWriter, Widgets, Cortana, NewsAndInterests, FeedbackHub, Edge (idle)"
        BtnKillProcesses    = "🛑 Fermer les processus inutiles"
        BtnKillProcessesDone= "✓ {0} processus d'arrière-plan arrêtés !"
        CbAutoKillOnOptimize= "Inclure la fermeture des processus inutiles lors de l'Optimisation Globale"
        GbPerfCpu           = "Optimisations Processeur (CPU) & Alimentation"
        CbPowerPlan         = "Activer le plan d'alimentation 'Performances Élevées' / 'Performances Optimales'"
        SubPowerPlan        = "Débloque la fréquence maximale du CPU et supprime les bridages d'économie d'énergie."
        CbForegroundPriority= "Priorité CPU maximale aux applications au premier plan (Win32PrioritySeparation = 0x26)"
        SubForegroundPriority="Alloue 3x plus de temps processeur à la fenêtre active (Jeux, logiciels) pour une réactivité instantanée."
        CbDisableCoreParking= "Désactiver la mise en veille forcée des cœurs du processeur (Core Parking OFF)"
        BtnApplyCpu         = "⚡ Appliquer les réglages CPU"
        BtnApplyCpuDone     = "✓ Réglages CPU & Énergie appliqués avec succès !"

        GbApps              = "Applications provisionnées à supprimer"
        CbApps              = "Supprimer les bloatwares préinstallés (Xbox, Bing, Solitaire, Feedback, Cartes, etc.)"
        CbAppsAllUsers      = "Appliquer à tous les profils d'utilisateurs de cette machine (Recommandé)"
        LblAppsList         = "Applications ciblées : "

        GbServices          = "Services système de télémétrie à désactiver"
        CbServices          = "Désactiver les services de tracking et collecte en arrière-plan (DiagTrack, dmwappushservice, WER)"
        CbServicesSC        = "Forcer la désactivation via Service Controller (SC config = disabled)"
        LblServicesList     = "Services ciblés : "

        GbTasks             = "Tâches planifiées de collecte à désactiver"
        CbTasks             = "Désactiver les tâches de collecte de données (CEIP, Customer Experience, Error Reporting)"
        LblTasksSuffix      = "tâches planifiées ciblées"

        GbPrivacyReg        = "Registre Windows - Confidentialité & Données personnelles"
        CbPrivacyReg        = "Appliquer les restrictions de confidentialité (Télémétrie=0, Publicités=OFF, Cortana=OFF)"
        CbPrivacyBackup     = "Sauvegarder les clés avant toute modification (fichier .reg dans les sauvegardes)"
        LblPrivacyRegSuffix = "paramètres de registre configurés"

        GbGPO               = "Stratégies de groupe locales (GPO)"
        CbGPO               = "Renforcer les stratégies GPO anti-tracking (DataCollection, AppCompat, Search, Edge)"
        LblGPOCount         = "13 stratégies de groupe renforcées"

        GbHosts             = "Fichier HOSTS - Filtrage des serveurs Microsoft"
        CbHosts             = "Bloquer les serveurs de tracking Microsoft via le fichier hosts (0.0.0.0)"
        CbHostsBackup       = "Sauvegarder le fichier hosts original avant modification"

        GbFirewall          = "Pare-feu Windows - Règles de filtrage sortant"
        CbFirewall          = "Créer des règles pare-feu sortantes pour isoler les services espions (DiagTrack)"

        GbDisk              = "Optimisation et Nettoyage de l'espace disque"
        CbDisk              = "Nettoyer les fichiers temporaires, caches système, journaux d'erreurs et prefetch"
        CbDiskRecycle       = "Vider la corbeille de tous les disques locaux"
        CbDiskWinUpdate     = "Nettoyer les anciens composants obsolètes Windows Update (DISM /StartComponentCleanup)"
        LblDiskPaths        = "Emplacements nettoyés : "

        GbRegClean          = "Nettoyage du Registre (Mode Sécurisé)"
        CbRegClean          = "Activer la suppression des clés d'installation orphelines (Uninstall obsolètes)"
        CbRegBackup         = "Sauvegarder les clés du registre avant suppression (.reg)"
        CbRegAggressive     = "Mode approfondi (extensions orphelines, CLSID invalides) - Recommandé aux utilisateurs avertis"
        WarnReg             = "ℹ Nettoyage sécurisé : seules les clés orphelines orphelines vérifiées sans dépendances sont purgées."

        GbRepair            = "Vérification et Restauration de l'intégrité système"
        CbDISM              = "DISM /RestoreHealth (Vérifie et répare l'image Windows via le magasin de composants)"
        CbSFC               = "SFC /Scannow (Analyse et répare automatiquement les fichiers système protégés)"
        CbChkdsk            = "Chkdsk /f /r (Planifie une vérification minutieuse des disques au prochain redémarrage)"
        InfoRepair          = "Ordre recommandé : DISM (3-8 min) → SFC (2-5 min) → Redémarrage système."

        GbRestore           = "Point de Restauration Système"
        CbRestorePoint      = "Créer un point de restauration système AVANT toute action (FORTEMENT RECOMMANDÉ)"
        InfoRestore         = "Permet d'annuler tous les changements en un clic via 'REDADZDOptimiser_Restore.ps1' ou la Restauration Windows."

        BtnClearLog         = "🗑 Effacer le journal"
        BtnSaveLog          = "💾 Exporter le journal"
        BtnCancel           = "✕ Annuler"
        BtnDryRun           = "🔍 Simulation (Dry-Run)"
        BtnRun              = "▶ OPTIMISER MAINTENANT"
        BtnRunning          = "⏳ Optimisation en cours..."
        CancelPrompt        = "Demande d'annulation transmise..."
        ClosingConfirm      = "Une optimisation est en cours d'exécution. Voulez-vous vraiment quitter ?"
        ReadyLog            = "Prêt. Sélectionnez vos options puis cliquez sur 'OPTIMISER MAINTENANT' ou 'Simulation'."
    }
    "EN" = @{
        AppTitle            = "REDADZDOptimiser Professional"
        SubTitle            = "Windows 10/11 Optimization Center  •  Debloat, Privacy, Cleanup & Integrity"
        LangLabel           = "Language:"
        AdminOk             = "✓ ADMINISTRATOR (Elevated)"
        AdminErr            = "⚠ NON-ADMIN (Limited Rights)"
        AdminMsgBox         = "This utility requires Administrator privileges to apply system optimizations!"

        TabDebloat          = "🗑️ Debloat"
        TabPerf             = "⚡ Performance"
        TabSoftware         = "📦 Software"
        TabNetwork          = "🌐 Network & DNS"
        TabStartup          = "🚀 Startup"
        TabPrivacy          = "🔒 Privacy"
        TabCleanup          = "🧹 Cleanup"
        TabRepair           = "🔧 Maintenance"
        TabLogs             = "📋 Logs"

        # Optimization Presets & Copyright
        PresetLabel         = "⚡ Presets:"
        BtnPresetMin        = "🌱 Minimal Tweak"
        BtnPresetStd        = "⚡ Standard Tweak"
        BtnPresetMax        = "🚀 Maximum Tweak"
        PresetDescMin       = "(Safe: Cache & Temp, preserves all apps & services)"
        PresetDescStd       = "(Recommended: Debloat, privacy, cleanup & CPU)"
        PresetDescMax       = "(Extreme & Gaming: Full debloat, registry, repair & max power)"
        PresetAppliedLog    = "Preset '{0}' successfully applied."
        CopyrightText       = "© 2026 REDADZDOptimiser • Anagou Reda  |  Phone: 0542439514"


        # Software Tab (Winget)
        GbBrowsers          = "Web Browsers"
        GbUtilities         = "Utilities & File Tools"
        GbGamingApps        = "Gaming & Streaming"
        GbDevOffice         = "Office & Development"
        BtnSelectAllApps    = "✓ Select All"
        BtnDeselectAllApps  = "✕ Deselect All"
        BtnInstallApps      = "🚀 Install Selected Applications (Winget)"
        BtnInstallingApps   = "⏳ Installing..."
        InstallAppsDone     = "✓ Installation finished: {0} installed, {1} failed."

        # Network & DNS Tab
        GbDnsSelector       = "Fast & Secure DNS Selector"
        OptDnsCloudflare    = "⚡ Cloudflare (1.1.1.1 / 1.0.0.1 - Lowest ping & gaming)"
        OptDnsGoogle        = "🔒 Google DNS (8.8.8.8 / 8.8.4.4 - High reliability)"
        OptDnsQuad9         = "🛡️ Quad9 (9.9.9.9 - Enhanced anti-malware security)"
        OptDnsDhcp          = "🔄 Automatic / ISP (Default DHCP)"
        BtnApplyDns         = "⚡ Apply Selected DNS Server"
        BtnApplyDnsDone     = "✓ DNS successfully applied!"

        GbGamingNetwork     = "Network Latency & Gaming Optimizations (TCP/IP)"
        CbNetThrottling     = "Disable multimedia network throttling (NetworkThrottlingIndex)"
        CbNagleAlgo         = "Disable Nagle algorithm (TcpAckFrequency & TCPNoDelay = 1)"
        BtnApplyGamingNet   = "🚀 Apply Gaming Network Optimizations"
        BtnApplyGamingDone  = "✓ Gaming TCP/IP tweaks applied!"

        GbResetNetwork      = "Network Reset & Troubleshooting"
        LblResetNetworkDesc = "Flushes DNS cache and resets Winsock / TCP/IP stack to repair connectivity issues."
        BtnResetNetStack    = "🧹 Flush DNS Cache & Reset Winsock / IP"
        BtnResetNetDone     = "✓ Network stack & DNS cache flushed!"

        # Startup Manager Tab
        GbStartupManager    = "Windows Startup Applications Manager"
        LblStartupDesc      = "Disable non-essential startup apps to make Windows boot up in under 10 seconds."
        BtnRefreshStartup   = "🔄 Refresh List"
        BtnDisableStartup   = "🛑 Disable Selected Application"
        ColStartupName      = "Name"
        ColStartupLocation  = "Location"
        ColStartupStatus    = "Status"
        ColStartupCommand   = "Command / Path"
        StartupDisabledDone = "✓ Application '{0}' disabled from startup."

        # Performance Tab
        GbPerfMonitor       = "Real-Time Resource Monitor"
        PerfRamFormat       = "RAM Usage: {0} GB / {1} GB ({2} %)"
        BtnFlushRam         = "🚀 Flush RAM & Cache"
        BtnFlushRamDone     = "✓ RAM cache cleared: ~{0} MB freed!"
        PerfCpuFormat       = "Processor (CPU): {0} %  •  {1} active processes"
        PerfLiveNotice      = "● Live continuous monitoring • 1.5s"
        PerfRamTip          = "Tip: Memory purging safely flushes inactive background cache without closing your open applications."
        GbPerfKill          = "Unnecessary Background Process Cleaner"
        PerfKillInfo        = "Instantly terminates dormant or unnecessary background processes (Phone Link, Game Bar, Widgets, Telemetry, idle Edge) while protecting vital system processes."
        PerfKillTargets     = "Targeted processes: PhoneExperienceHost, GameBarPresenceWriter, Widgets, Cortana, NewsAndInterests, FeedbackHub, Edge (idle)"
        BtnKillProcesses    = "🛑 Stop Unnecessary Processes"
        BtnKillProcessesDone= "✓ {0} background processes stopped!"
        CbAutoKillOnOptimize= "Automatically stop unnecessary processes during Global Optimization"
        GbPerfCpu           = "Processor (CPU) & Power Optimizations"
        CbPowerPlan         = "Enable 'High Performance' / 'Ultimate Performance' power plan"
        SubPowerPlan        = "Unlocks maximum CPU clock speed and prevents aggressive frequency downscaling."
        CbForegroundPriority= "Maximum CPU priority for foreground apps & games (Win32PrioritySeparation = 0x26)"
        SubForegroundPriority="Allocates 3x more CPU quantum time to the active window for instant responsiveness."
        CbDisableCoreParking= "Disable CPU core parking (keeps all CPU cores unparked)"
        BtnApplyCpu         = "⚡ Apply CPU Settings"
        BtnApplyCpuDone     = "✓ CPU & Power settings successfully applied!"

        GbApps              = "Provisioned Apps to Remove"
        CbApps              = "Remove preinstalled bloatware (Xbox, Bing, Solitaire, Feedback, Maps, etc.)"
        CbAppsAllUsers      = "Apply to all user accounts on this machine (Recommended)"
        LblAppsList         = "Targeted applications: "

        GbServices          = "Telemetry System Services to Disable"
        CbServices          = "Disable background telemetry and tracking services (DiagTrack, dmwappushservice, WER)"
        CbServicesSC        = "Force disable via Service Controller (SC config = disabled)"
        LblServicesList     = "Targeted services: "

        GbTasks             = "Scheduled Tasks to Disable"
        CbTasks             = "Disable data collection scheduled tasks (CEIP, Customer Experience, Error Reporting)"
        LblTasksSuffix      = "targeted scheduled tasks"

        GbPrivacyReg        = "Windows Registry - Privacy & Data Protection"
        CbPrivacyReg        = "Apply anti-telemetry registry restrictions (Telemetry=0, Ads=OFF, Cortana=OFF)"
        CbPrivacyBackup     = "Backup registry values before modification (.reg backup file)"
        LblPrivacyRegSuffix = "registry settings configured"

        GbGPO               = "Local Group Policies (GPO)"
        CbGPO               = "Enforce anti-tracking group policies (DataCollection, AppCompat, Search, Edge)"
        LblGPOCount         = "13 hardened group policies"

        GbHosts             = "HOSTS File - Microsoft Tracking Server Filtering"
        CbHosts             = "Block known Microsoft telemetry servers in hosts file (0.0.0.0)"
        CbHostsBackup       = "Backup original hosts file before changes"

        GbFirewall          = "Windows Firewall - Outbound Filtering Rules"
        CbFirewall          = "Create outbound firewall rules to isolate telemetry traffic (DiagTrack)"

        GbDisk              = "Disk Space Optimization & Cleanup"
        CbDisk              = "Clean temporary files, system caches, crash logs and prefetch data"
        CbDiskRecycle       = "Empty Recycle Bin on all local drives"
        CbDiskWinUpdate     = "Clean outdated Windows Update components (DISM /StartComponentCleanup)"
        LblDiskPaths        = "Cleaned locations: "

        GbRegClean          = "Registry Cleaner (Safe Mode)"
        CbRegClean          = "Enable cleanup of orphan uninstall keys from removed software"
        CbRegBackup         = "Backup registry keys before removal (.reg)"
        CbRegAggressive     = "Deep mode (orphan file extensions, invalid CLSIDs) - Advanced users only"
        WarnReg             = "ℹ Safe Registry Cleaner: only verified orphan software keys without dependencies are purged."

        GbRepair            = "System Health & Integrity Repair"
        CbDISM              = "DISM /RestoreHealth (Scans and repairs Windows Component Store image)"
        CbSFC               = "SFC /Scannow (Scans and fixes corrupted protected system files)"
        CbChkdsk            = "Chkdsk /f /r (Schedule thorough disk check on next reboot)"
        InfoRepair          = "Recommended sequence: DISM (3-8 min) → SFC (2-5 min) → System reboot."

        GbRestore           = "System Restore Point"
        CbRestorePoint      = "Create a System Restore Point BEFORE any modification (STRONGLY RECOMMENDED)"
        InfoRestore         = "Allows rolling back all changes anytime with one click via 'REDADZDOptimiser_Restore.ps1'."

        BtnClearLog         = "🗑 Clear Log"
        BtnSaveLog          = "💾 Export Log"
        BtnCancel           = "✕ Cancel"
        BtnDryRun           = "🔍 Simulation (Dry-Run)"
        BtnRun              = "▶ OPTIMIZE NOW"
        BtnRunning          = "⏳ Optimization in progress..."
        CancelPrompt        = "Cancellation requested..."
        ClosingConfirm      = "Optimization is currently running. Are you sure you want to exit?"
        ReadyLog            = "Ready. Select options and click 'OPTIMIZE NOW' or 'Simulation'."
    }
    "AR" = @{
        AppTitle            = "REDADZDOptimiser Professional"
        SubTitle            = "مركز تحسين ويندوز 10/11  •  إزالة الزوائد، حماية الخصوصية، التنظيف وصيانة النظام"
        LangLabel           = "اللغة:"
        AdminOk             = "✓ مسؤول (صلاحيات كاملة)"
        AdminErr            = "⚠ غير مسؤول (صلاحيات محدودة)"
        AdminMsgBox         = "يتطلب هذا البرنامج تشغيله كمسؤول (Run as Administrator) لتطبيق التحسينات!"

        TabDebloat          = "🗑️ الزوائد"
        TabPerf             = "⚡ الأداء"
        TabSoftware         = "📦 البرامج"
        TabNetwork          = "🌐 الشبكة"
        TabStartup          = "🚀 الإقلاع"
        TabPrivacy          = "🔒 الخصوصية"
        TabCleanup          = "🧹 التنظيف"
        TabRepair           = "🔧 الصيانة"
        TabLogs             = "📋 السجل"

        # أوضاع التحسين وحقوق المطور
        PresetLabel         = "⚡ أوضاع التحسين :"
        BtnPresetMin        = "🌱 تحسين خفيف"
        BtnPresetStd        = "⚡ تحسين قياسي"
        BtnPresetMax        = "🚀 تحسين أقصى"
        PresetDescMin       = "(آمن: تنظيف خفيف، يحافظ على كل البرامج والخدمات)"
        PresetDescStd       = "(موصى به: إزالة الزوائد، حماية الخصوصية وتسريع المعالج)"
        PresetDescMax       = "(أقصى أداء للألعاب: إزالة شاملة، تنظيف السجل وأعلى قوة)"
        PresetAppliedLog    = "تم تطبيق الوضع '{0}' بنجاح."
        CopyrightText       = "© 2026 REDADZDOptimiser • Anagou Reda  |  هاتف : 0542439514"

        GbApps              = "تطبيقات النظام غير الضرورية للإزالة"
        CbApps              = "إزالة التطبيقات المثبتة مسبقاً (Xbox, Bing, Solitaire, Feedback, الخرائط، إلخ)"
        CbAppsAllUsers      = "تطبيق على جميع حسابات المستخدمين في هذا الجهاز (موصى به)"
        LblAppsList         = "التطبيقات المستهدفة: "

        GbServices          = "خدمات النظام المراد تعطيلها"
        CbServices          = "تعطيل خدمات التتبع والقياس عن بعد (DiagTrack, dmwappushservice, WER)"
        CbServicesSC        = "تعطيل أيضاً عبر Service Controller (أكثر ثباتاً واستقراراً)"
        LblServicesList     = "الخدمات المستهدفة: "

        GbTasks             = "المهام المجدولة المراد تعطيلها"
        CbTasks             = "تعطيل مهام جمع البيانات والقياس (CEIP, Customer Experience, Error Reporting)"
        LblTasksSuffix      = "مهمة مجدولة مستهدفة"

        GbPrivacyReg        = "سجل النظام (Registry) - حماية الخصوصية ومنع التتبع"
        CbPrivacyReg        = "تطبيق قيود الخصوصية (القياس=0, الإعلانات=معطل, Cortana=معطل)"
        CbPrivacyBackup     = "نسخ احتياطي لقيم السجل قبل التعديل (.reg)"
        LblPrivacyRegSuffix = "إعداد في السجل سيتم ضبطه"

        GbGPO               = "نهج المجموعة المحلي (GPO)"
        CbGPO               = "تطبيق سياسات منع التتبع الصارمة (DataCollection, AppCompat, بحث ويندوز, Edge)"
        LblGPOCount         = "13 سياسة نهج مجموعة سيتم تطبيقها"

        GbHosts             = "ملف HOSTS - حظر خوادم التتبع"
        CbHosts             = "حظر خوادم القياس والتتبع لـ Microsoft في ملف hosts (0.0.0.0)"
        CbHostsBackup       = "نسخ احتياطي لملف hosts قبل التعديل"

        GbFirewall          = "جدار حماية ويندوز - قواعد حظر الاتصال الخارجي"
        CbFirewall          = "إنشاء قواعد جدار حماية لمنع خروج بيانات التتبع (DiagTrack)"

        GbDisk              = "تحسين وتنظيف مساحة القرص"
        CbDisk              = "تنظيف الملفات المؤقتة، الذاكرة المؤقتة، السجلات، وتحديثات النظام القديمة"
        CbDiskRecycle       = "إفراغ سلة المحذوفات لجميع الأقراص المحلية"
        CbDiskWinUpdate     = "تنظيف بقايا مكونات تحديثات ويندوز (DISM /StartComponentCleanup)"
        LblDiskPaths        = "المسارات المستهدفة: "

        GbRegClean          = "تنظيف سجل النظام (الوضع الآمن)"
        CbRegClean          = "تفعيل تنظيف مفاتيح البرامج المحذوفة المعزولة (Uninstall)"
        CbRegBackup         = "نسخ احتياطي للمفاتيح قبل الحذف (.reg)"
        CbRegAggressive     = "الوضع المتقدم (ملحقات الملفات, معرفات CLSID المعزولة) - للمستخدمين المتقدمين"
        WarnReg             = "ℹ تنظيف السجل آمن ومتحفظ : يتم فقط مسح المفاتيح المعزولة المتأكد منها."

        GbRepair            = "فحص واستعادة سلامة النظام"
        CbDISM              = "DISM /RestoreHealth (إصلاح صورة ويندوز ومخزن المكونات)"
        CbSFC               = "SFC /Scannow (فحص وإصلاح ملفات النظام المحمية تلقائياً)"
        CbChkdsk            = "Chkdsk /f /r (جدولة فحص أخطاء القرص عند إعادة التشغيل القادمة)"
        InfoRepair          = "الترتيب الموصى به: DISM (3-8 دقائق) ← SFC (2-5 دقائق) ← إعادة تشغيل الجهاز."

        GbRestore           = "نقطة استعادة النظام"
        CbRestorePoint      = "إنشاء نقطة استعادة للنظام قبل أي تعديل (موصى به بشدة)"
        InfoRestore         = "تتيح استرجاع جميع الإعدادات السابقة في أي وقت بضغطة واحدة عبر 'REDADZDOptimiser_Restore.ps1'."

        BtnClearLog         = "🗑 مسح السجل"
        BtnSaveLog          = "💾 تصدير السجل"
        BtnCancel           = "✕ إلغاء"
        BtnDryRun           = "🔍 محاكاة تجريبية"
        BtnRun              = "▶ بدء التحسين الآن"
        BtnRunning          = "⏳ جاري التنفيذ..."
        CancelPrompt        = "جاري طلب الإلغاء..."
        ClosingConfirm      = "عملية التحسين قيد التنفيذ حالياً. هل تريد حقاً الخروج؟"
        ReadyLog            = "جاهز. حدد الخيارات المطلوبة ثم اضغط على 'بدء التحسين الآن' أو 'محاكاة تجريبية'."
    }
}

# ─── Palette Professionnelle & Claire (Style Windows 11 Fluent Pro) ────
$script:colors = @{
    # Arrière-plans clairs, lumineux et modernes
    BackColor       = [System.Drawing.Color]::FromArgb(241, 245, 249)    # #F1F5F9 (Fond canvas moderne Slate 100)
    CardBack        = [System.Drawing.Color]::FromArgb(255, 255, 255)    # #FFFFFF (Cartes blanches épurées)
    HeaderBack      = [System.Drawing.Color]::FromArgb(255, 255, 255)    # #FFFFFF (Bandeau supérieur)
    BottomBack      = [System.Drawing.Color]::FromArgb(255, 255, 255)    # #FFFFFF (Barre inférieure d'action)
    BorderColor     = [System.Drawing.Color]::FromArgb(226, 232, 240)    # #E2E8F0 (Bordures discrètes et soignées)
    TabInactiveBack = [System.Drawing.Color]::FromArgb(241, 245, 249)    # #F1F5F9 (Onglets inactifs)

    # Accent Professionnel Principal (Bleu Royal / Indigo Pro)
    AccentColor     = [System.Drawing.Color]::FromArgb(37, 99, 235)      # #2563EB (Bleu royal éclatant)
    AccentHover     = [System.Drawing.Color]::FromArgb(29, 78, 216)      # #1D4ED8
    AccentPress     = [System.Drawing.Color]::FromArgb(30, 64, 175)      # #1E40AF
    CyanAccent      = [System.Drawing.Color]::FromArgb(2, 132, 199)      # #0284C7 (Bleu azur / Océan)
    IndigoAccent    = [System.Drawing.Color]::FromArgb(79, 70, 229)      # #4F46E5 (Indigo violet élégant)
    PurpleAccent    = [System.Drawing.Color]::FromArgb(124, 58, 237)     # #7C3AED (Violet discret)

    # Boutons d'Action Professionnels
    SuccessColor    = [System.Drawing.Color]::FromArgb(16, 185, 129)     # #10B981 (Vert Émeraude Pro)
    SuccessHover    = [System.Drawing.Color]::FromArgb(5, 150, 105)      # #059669
    SuccessPress    = [System.Drawing.Color]::FromArgb(4, 120, 87)       # #047857

    WarningColor    = [System.Drawing.Color]::FromArgb(217, 119, 6)      # #D97706 (Ambre chaleureux)
    WarningHover    = [System.Drawing.Color]::FromArgb(180, 83, 9)       # #B45309
    WarningPress    = [System.Drawing.Color]::FromArgb(146, 64, 14)      # #92400E

    ErrorColor      = [System.Drawing.Color]::FromArgb(220, 38, 38)      # #DC2626 (Rouge Corail)
    ErrorHover      = [System.Drawing.Color]::FromArgb(185, 28, 28)      # #B91C1C
    ErrorPress      = [System.Drawing.Color]::FromArgb(153, 27, 27)      # #991B1B

    # Typographie à fort contraste et excellente lisibilité
    ForeColor       = [System.Drawing.Color]::FromArgb(15, 23, 42)       # #0F172A (Texte foncé Slate 900)
    MutedColor      = [System.Drawing.Color]::FromArgb(100, 116, 139)    # #64748B (Texte secondaire Slate 500)
    DisabledColor   = [System.Drawing.Color]::FromArgb(148, 163, 184)    # #94A3B8 (Gris désactivé)

    # Badges d'état (Pills modernes doux)
    AdminOkBack     = [System.Drawing.Color]::FromArgb(236, 253, 245)    # #ECFDF5 (Vert menthe doux)
    AdminOkFore     = [System.Drawing.Color]::FromArgb(4, 120, 87)       # #047857 (Texte vert émeraude)
    AdminOkBorder   = [System.Drawing.Color]::FromArgb(167, 243, 208)    # #A7F3D0
    AdminErrBack    = [System.Drawing.Color]::FromArgb(254, 242, 242)    # #FEF2F2 (Rouge pâle)
    AdminErrFore    = [System.Drawing.Color]::FromArgb(185, 28, 28)      # #B91C1C (Texte rouge foncé)
    AdminErrBorder  = [System.Drawing.Color]::FromArgb(254, 202, 202)    # #FECACA

    # Terminal de logs développeur (Bleu nuit profond pour un contraste lisible)
    LogBackColor    = [System.Drawing.Color]::FromArgb(15, 23, 42)       # #0F172A (Bleu nuit profond)
    LogForeColor    = [System.Drawing.Color]::FromArgb(241, 245, 249)    # #F1F5F9 (Blanc crème)
    LogSuccessColor = [System.Drawing.Color]::FromArgb(52, 211, 153)     # Vert menthe
    LogWarnColor    = [System.Drawing.Color]::FromArgb(251, 191, 36)     # Ambre vif
    LogErrorColor   = [System.Drawing.Color]::FromArgb(248, 113, 113)    # Rouge corail
    LogBorder       = [System.Drawing.Color]::FromArgb(51, 65, 85)

    Transparent     = [System.Drawing.Color]::Transparent
}
$colors = $script:colors

# ─── Typographie Professionnelle ───────────────────────────────────────
$script:fonts = @{
    Title    = New-Object System.Drawing.Font("Segoe UI", 13.5, [System.Drawing.FontStyle]::Bold)
    SubTitle = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    Badge    = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Bold)
    Normal   = New-Object System.Drawing.Font("Segoe UI", 9.25, [System.Drawing.FontStyle]::Regular)
    Small    = New-Object System.Drawing.Font("Segoe UI", 8.25, [System.Drawing.FontStyle]::Regular)
    Mono     = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Regular)
    Button   = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
}
$fonts = $script:fonts

# ════════════════════════════════════════════════════════════════════════
# COMPOSANTS D'INTERFACE PROFESSIONNELS
# ════════════════════════════════════════════════════════════════════════

function New-ModernButton {
    param(
        [string]$Text,
        [System.Drawing.Size]$Size,
        [System.Drawing.Point]$Location,
        [scriptblock]$Click,
        [System.Drawing.Color]$BackColor = $colors.AccentColor,
        [System.Drawing.Color]$HoverColor = $colors.AccentHover,
        [System.Drawing.Color]$PressColor = $colors.AccentPress,
        [System.Drawing.Color]$ForeColor = [System.Drawing.Color]::White,
        [bool]$Enabled = $true
    )
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text
    $btn.Size = $Size
    $btn.Location = $Location
    $btn.Font = $fonts.Button
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn.FlatAppearance.BorderSize = 0
    $btn.BackColor = if ($Enabled) { $BackColor } else { $colors.DisabledColor }
    $btn.ForeColor = $ForeColor
    $btn.Enabled = $Enabled
    $btn.Cursor = if ($Enabled) { [System.Windows.Forms.Cursors]::Hand } else { [System.Windows.Forms.Cursors]::Default }

    $btn.Tag = @{
        BaseColor  = $BackColor
        HoverColor = $HoverColor
        PressColor = $PressColor
    }

    if ($Click) { $btn.Add_Click($Click) }

    $btn.Add_MouseEnter({
        if ($this.Enabled) { $this.BackColor = $this.Tag.HoverColor }
    })
    $btn.Add_MouseLeave({
        if ($this.Enabled) { $this.BackColor = $this.Tag.BaseColor }
    })
    $btn.Add_MouseDown({
        if ($this.Enabled) { $this.BackColor = $this.Tag.PressColor }
    })
    $btn.Add_MouseUp({
        if ($this.Enabled) { $this.BackColor = $this.Tag.HoverColor }
    })

    return $btn
}

function New-ModernCheckBox {
    param(
        [string]$Text,
        [System.Drawing.Point]$Location,
        [bool]$Checked = $true,
        [scriptblock]$CheckChanged,
        [bool]$Enabled = $true
    )
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $Text
    $cb.Location = $Location
    $cb.Size = New-Object System.Drawing.Size(820, 26)
    $cb.Font = $fonts.Normal
    $cb.ForeColor = $colors.ForeColor
    $cb.BackColor = $colors.Transparent
    $cb.Checked = $Checked
    $cb.Enabled = $Enabled
    $cb.Cursor = [System.Windows.Forms.Cursors]::Hand
    $cb.AutoSize = $true
    if ($CheckChanged) { $cb.Add_CheckedChanged($CheckChanged) }
    return $cb
}

function New-ModernCard {
    param(
        [string]$Title,
        [System.Drawing.Point]$Location,
        [System.Drawing.Size]$Size,
        [System.Drawing.Color]$AccentLineColor = $colors.AccentColor
    )
    $card = New-Object System.Windows.Forms.Panel
    $card.Location = $Location
    $card.Size = $Size
    $card.BackColor = $colors.CardBack

    # Titre de la carte épurée
    $headerLbl = New-Object System.Windows.Forms.Label
    $headerLbl.Text = $Title
    $headerLbl.Font = $fonts.SubTitle
    $headerLbl.ForeColor = $colors.ForeColor
    $headerLbl.Location = New-Object System.Drawing.Point(18, 12)
    $headerLbl.Size = New-Object System.Drawing.Size(($Size.Width - 36), 24)
    $headerLbl.AutoEllipsis = $true
    $card.Controls.Add($headerLbl)

    # Référence pour mise à jour multilingue
    $card.Tag = @{ Header = $headerLbl; Accent = $AccentLineColor }

    # Bordure 1px sobre et barre supérieure d'accent colorée (Dashboard Pro)
    $card.Add_Paint({
        param($s, $e)
        $g = $e.Graphics
        $tag = $s.Tag
        $borderPen = New-Object System.Drawing.Pen($script:colors.BorderColor, 1)
        $g.DrawRectangle($borderPen, 0, 0, $s.Width - 1, $s.Height - 1)
        $borderPen.Dispose()

        # Ligne d'accent supérieure de 3px
        $accentPen = New-Object System.Drawing.Pen($tag.Accent, 3)
        $g.DrawLine($accentPen, 1, 1, $s.Width - 2, 1)
        $accentPen.Dispose()
    })

    return $card
}

function Update-UIProgress {
    param(
        [string]$Activity,
        [int]$Current,
        [int]$Total,
        [string]$Status,
        [int]$Percent
    )
    if ($script:ProgressBar -and $script:ProgressBar.IsHandleCreated) {
        $action = {
            if ($Total -gt 0) {
                $p = [math]::Min(100, [math]::Max(0, $Percent))
                $script:ProgressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Blocks
                $script:ProgressBar.Value = $p
            }
        }
        if ($script:ProgressBar.InvokeRequired) {
            $script:ProgressBar.Invoke([Action]$action)
        } else {
            & $action
        }
    }
    [System.Windows.Forms.Application]::DoEvents()
}

function Append-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    $script:LogLines += $entry

    if ($script:LogBox -and $script:LogBox.IsHandleCreated) {
        $action = {
            $color = switch ($Level) {
                "SUCCESS" { $script:colors.LogSuccessColor }
                "WARN"    { $script:colors.LogWarnColor }
                "ERROR"   { $script:colors.LogErrorColor }
                default   { $script:colors.LogForeColor }
            }
            $script:LogBox.SelectionStart = $script:LogBox.TextLength
            $script:LogBox.SelectionLength = 0
            $script:LogBox.SelectionColor = $color
            $script:LogBox.AppendText($entry + "`r`n")
            $script:LogBox.SelectionColor = $script:colors.LogForeColor
            $script:LogBox.ScrollToCaret()
        }
        if ($script:LogBox.InvokeRequired) {
            $script:LogBox.Invoke([Action]$action)
        } else {
            & $action
        }
    }
}

# ════════════════════════════════════════════════════════════════════════
# BOÎTE DE DIALOGUE : SÉLECTION DE LA LANGUE (AU DÉMARRAGE)
# ════════════════════════════════════════════════════════════════════════

function Show-LanguageDialog {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "REDADZDOptimiser - Select Language / Choisir la langue / اختيار اللغة"
    $dlg.Size = New-Object System.Drawing.Size(480, 320)
    $dlg.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $dlg.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dlg.MaximizeBox = $false
    $dlg.MinimizeBox = $false
    $dlg.BackColor = $colors.BackColor
    $dlg.ForeColor = $colors.ForeColor
    $dlg.TopMost = $true

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Choose your language / Choisissez votre langue / اختر لغتك :"
    $lbl.Font = $fonts.SubTitle
    $lbl.ForeColor = $colors.AccentColor
    $lbl.Location = New-Object System.Drawing.Point(32, 22)
    $lbl.Size = New-Object System.Drawing.Size(420, 28)
    $dlg.Controls.Add($lbl)

    $script:chosenLang = "FR"

    $btnFR = New-ModernButton -Text "🇫🇷  Français" -Size (New-Object System.Drawing.Size(400, 46)) -Location (New-Object System.Drawing.Point(32, 66)) -Click {
        $script:chosenLang = "FR"
        $dlg.Close()
    } -BackColor $colors.CardBack -HoverColor $colors.AccentColor -PressColor $colors.AccentPress -ForeColor $colors.ForeColor

    $btnFR.Add_Paint({
        param($s, $e)
        $p = New-Object System.Drawing.Pen($script:colors.BorderColor, 1)
        $e.Graphics.DrawRectangle($p, 0, 0, $s.Width - 1, $s.Height - 1)
        $p.Dispose()
    })

    $btnEN = New-ModernButton -Text "🇬🇧  English" -Size (New-Object System.Drawing.Size(400, 46)) -Location (New-Object System.Drawing.Point(32, 124)) -Click {
        $script:chosenLang = "EN"
        $dlg.Close()
    } -BackColor $colors.CardBack -HoverColor $colors.AccentColor -PressColor $colors.AccentPress -ForeColor $colors.ForeColor

    $btnEN.Add_Paint({
        param($s, $e)
        $p = New-Object System.Drawing.Pen($script:colors.BorderColor, 1)
        $e.Graphics.DrawRectangle($p, 0, 0, $s.Width - 1, $s.Height - 1)
        $p.Dispose()
    })

    $btnAR = New-ModernButton -Text "🇸🇦  العربية" -Size (New-Object System.Drawing.Size(400, 46)) -Location (New-Object System.Drawing.Point(32, 182)) -Click {
        $script:chosenLang = "AR"
        $dlg.Close()
    } -BackColor $colors.CardBack -HoverColor $colors.AccentColor -PressColor $colors.AccentPress -ForeColor $colors.ForeColor

    $btnAR.Add_Paint({
        param($s, $e)
        $p = New-Object System.Drawing.Pen($script:colors.BorderColor, 1)
        $e.Graphics.DrawRectangle($p, 0, 0, $s.Width - 1, $s.Height - 1)
        $p.Dispose()
    })

    $dlg.Controls.Add($btnFR)
    $dlg.Controls.Add($btnEN)
    $dlg.Controls.Add($btnAR)

    [void]$dlg.ShowDialog()
    return $script:chosenLang
}


# ════════════════════════════════════════════════════════════════════════
# GESTION DES PRÉRÉGLAGES (MINIMAL / STANDARD / MAX)
# ════════════════════════════════════════════════════════════════════════

function Set-PresetButtonState {
    param(
        [System.Windows.Forms.Button]$Btn,
        [bool]$Active,
        [System.Drawing.Color]$ActiveColor
    )
    if (-not $Btn) { return }
    $Btn.Tag.IsActive = $Active
    if ($Active) {
        $Btn.BackColor = $ActiveColor
        $Btn.ForeColor = [System.Drawing.Color]::White
        $Btn.Font = $fonts.Button
        $Btn.Tag.BaseColor = $ActiveColor
        $Btn.Tag.HoverColor = $ActiveColor
    } else {
        $Btn.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 252)
        $Btn.ForeColor = [System.Drawing.Color]::FromArgb(71, 85, 105)
        $Btn.Font = $fonts.Normal
        $Btn.Tag.BaseColor = [System.Drawing.Color]::FromArgb(248, 250, 252)
        $Btn.Tag.HoverColor = [System.Drawing.Color]::FromArgb(241, 245, 249)
    }
    $Btn.Invalidate()
}

function Apply-Preset {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Minimal", "Standard", "Max")]
        [string]$Preset
    )
    $script:CurrentPreset = $Preset

    # Mise à jour graphique des 3 boutons
    $isMin = ($Preset -eq "Minimal")
    $isStd = ($Preset -eq "Standard")
    $isMax = ($Preset -eq "Max")

    Set-PresetButtonState $script:BtnPresetMin $isMin $colors.SuccessColor
    Set-PresetButtonState $script:BtnPresetStd $isStd $colors.AccentColor
    Set-PresetButtonState $script:BtnPresetMax $isMax $colors.PurpleAccent

    # Application des cases à cocher selon le niveau
    switch ($Preset) {
        "Minimal" {
            # 1. Point de restauration
            if ($script:CbRestorePoint)       { $script:CbRestorePoint.Checked = $true }
            # 2. Débloat (Désactivé en Minimal pour sécurité absolue)
            if ($script:CbApps)               { $script:CbApps.Checked = $false }
            if ($script:CbAppsAllUsers)       { $script:CbAppsAllUsers.Checked = $false }
            # 3. Services & Tâches
            if ($script:CbServices)           { $script:CbServices.Checked = $false }
            if ($script:CbServicesSC)         { $script:CbServicesSC.Checked = $false }
            if ($script:CbTasks)              { $script:CbTasks.Checked = $false }
            # 4. Performances
            if ($script:CbAutoKillOnOptimize) { $script:CbAutoKillOnOptimize.Checked = $false }
            if ($script:CbPowerPlan)          { $script:CbPowerPlan.Checked = $true }
            if ($script:CbForegroundPriority) { $script:CbForegroundPriority.Checked = $false }
            if ($script:CbDisableCoreParking) { $script:CbDisableCoreParking.Checked = $false }
            # 5. Confidentialité
            if ($script:CbPrivacyReg)         { $script:CbPrivacyReg.Checked = $true }
            if ($script:CbPrivacyBackup)      { $script:CbPrivacyBackup.Checked = $true }
            if ($script:CbGPO)                { $script:CbGPO.Checked = $false }
            if ($script:CbHosts)              { $script:CbHosts.Checked = $false }
            if ($script:CbHostsBackup)        { $script:CbHostsBackup.Checked = $true }
            if ($script:CbFirewall)           { $script:CbFirewall.Checked = $false }
            # 6. Nettoyage
            if ($script:CbDisk)               { $script:CbDisk.Checked = $true }
            if ($script:CbDiskRecycle)        { $script:CbDiskRecycle.Checked = $true }
            if ($script:CbDiskWinUpdate)      { $script:CbDiskWinUpdate.Checked = $false }
            if ($script:CbRegClean)           { $script:CbRegClean.Checked = $false }
            if ($script:CbRegBackup)          { $script:CbRegBackup.Checked = $true }
            if ($script:CbRegAggressive)      { $script:CbRegAggressive.Checked = $false }
            # 7. Maintenance
            if ($script:CbDISM)               { $script:CbDISM.Checked = $false }
            if ($script:CbSFC)                { $script:CbSFC.Checked = $true }
            if ($script:CbChkdsk)             { $script:CbChkdsk.Checked = $false }
        }
        "Standard" {
            # 1. Point de restauration
            if ($script:CbRestorePoint)       { $script:CbRestorePoint.Checked = $true }
            # 2. Débloat (Bloatwares préinstallés supprimés)
            if ($script:CbApps)               { $script:CbApps.Checked = $true }
            if ($script:CbAppsAllUsers)       { $script:CbAppsAllUsers.Checked = $true }
            # 3. Services & Tâches (Désactivation télémétrie)
            if ($script:CbServices)           { $script:CbServices.Checked = $true }
            if ($script:CbServicesSC)         { $script:CbServicesSC.Checked = $true }
            if ($script:CbTasks)              { $script:CbTasks.Checked = $true }
            # 4. Performances
            if ($script:CbAutoKillOnOptimize) { $script:CbAutoKillOnOptimize.Checked = $true }
            if ($script:CbPowerPlan)          { $script:CbPowerPlan.Checked = $true }
            if ($script:CbForegroundPriority) { $script:CbForegroundPriority.Checked = $true }
            if ($script:CbDisableCoreParking) { $script:CbDisableCoreParking.Checked = $true }
            # 5. Confidentialité (GPO, Registre, Hosts, Pare-feu)
            if ($script:CbPrivacyReg)         { $script:CbPrivacyReg.Checked = $true }
            if ($script:CbPrivacyBackup)      { $script:CbPrivacyBackup.Checked = $true }
            if ($script:CbGPO)                { $script:CbGPO.Checked = $true }
            if ($script:CbHosts)              { $script:CbHosts.Checked = $true }
            if ($script:CbHostsBackup)        { $script:CbHostsBackup.Checked = $true }
            if ($script:CbFirewall)           { $script:CbFirewall.Checked = $true }
            # 6. Nettoyage
            if ($script:CbDisk)               { $script:CbDisk.Checked = $true }
            if ($script:CbDiskRecycle)        { $script:CbDiskRecycle.Checked = $true }
            if ($script:CbDiskWinUpdate)      { $script:CbDiskWinUpdate.Checked = $true }
            if ($script:CbRegClean)           { $script:CbRegClean.Checked = $false }
            if ($script:CbRegBackup)          { $script:CbRegBackup.Checked = $true }
            if ($script:CbRegAggressive)      { $script:CbRegAggressive.Checked = $false }
            # 7. Maintenance (DISM + SFC)
            if ($script:CbDISM)               { $script:CbDISM.Checked = $true }
            if ($script:CbSFC)                { $script:CbSFC.Checked = $true }
            if ($script:CbChkdsk)             { $script:CbChkdsk.Checked = $false }
        }
        "Max" {
            # 1. Point de restauration
            if ($script:CbRestorePoint)       { $script:CbRestorePoint.Checked = $true }
            # 2. Débloat maximal
            if ($script:CbApps)               { $script:CbApps.Checked = $true }
            if ($script:CbAppsAllUsers)       { $script:CbAppsAllUsers.Checked = $true }
            # 3. Services & Tâches
            if ($script:CbServices)           { $script:CbServices.Checked = $true }
            if ($script:CbServicesSC)         { $script:CbServicesSC.Checked = $true }
            if ($script:CbTasks)              { $script:CbTasks.Checked = $true }
            # 4. Performances Extrêmes
            if ($script:CbAutoKillOnOptimize) { $script:CbAutoKillOnOptimize.Checked = $true }
            if ($script:CbPowerPlan)          { $script:CbPowerPlan.Checked = $true }
            if ($script:CbForegroundPriority) { $script:CbForegroundPriority.Checked = $true }
            if ($script:CbDisableCoreParking) { $script:CbDisableCoreParking.Checked = $true }
            # 5. Confidentialité
            if ($script:CbPrivacyReg)         { $script:CbPrivacyReg.Checked = $true }
            if ($script:CbPrivacyBackup)      { $script:CbPrivacyBackup.Checked = $true }
            if ($script:CbGPO)                { $script:CbGPO.Checked = $true }
            if ($script:CbHosts)              { $script:CbHosts.Checked = $true }
            if ($script:CbHostsBackup)        { $script:CbHostsBackup.Checked = $true }
            if ($script:CbFirewall)           { $script:CbFirewall.Checked = $true }
            # 6. Nettoyage Approfondi (Disque + Registre complet)
            if ($script:CbDisk)               { $script:CbDisk.Checked = $true }
            if ($script:CbDiskRecycle)        { $script:CbDiskRecycle.Checked = $true }
            if ($script:CbDiskWinUpdate)      { $script:CbDiskWinUpdate.Checked = $true }
            if ($script:CbRegClean)           { $script:CbRegClean.Checked = $true }
            if ($script:CbRegBackup)          { $script:CbRegBackup.Checked = $true }
            if ($script:CbRegAggressive)      { $script:CbRegAggressive.Checked = $true }
            # 7. Maintenance Intégrale (DISM + SFC + Chkdsk)
            if ($script:CbDISM)               { $script:CbDISM.Checked = $true }
            if ($script:CbSFC)                { $script:CbSFC.Checked = $true }
            if ($script:CbChkdsk)             { $script:CbChkdsk.Checked = $true }
        }
    }

    # Mise à jour du texte descriptif
    $strings = $script:I18N[$script:CurrentLang]
    if ($lblPresetDesc -and $strings) {
        $lblPresetDesc.Text = switch ($Preset) {
            "Minimal"  { $strings.PresetDescMin }
            "Standard" { $strings.PresetDescStd }
            "Max"      { $strings.PresetDescMax }
        }
    }
    if ($script:LogBox) {
        Append-Log ($strings.PresetAppliedLog -f $Preset) "INFO"
    }
}

# ════════════════════════════════════════════════════════════════════════
# APPLICATION DYNAMIQUE DE LA LANGUE (STABLE & PROPRE)
# ════════════════════════════════════════════════════════════════════════

function Apply-Language {
    param([string]$Lang)

    $Lang = $Lang.ToUpper()
    if (-not $script:I18N.ContainsKey($Lang)) {
        $Lang = "FR"
    }
    $script:CurrentLang = $Lang
    $strings = $script:I18N[$Lang]

    # Fenêtre & Header
    $form.Text = $strings.AppTitle
    $subtitleLabel.Text = $strings.SubTitle
    $adminBadge.Text = if ($isAdmin) { $strings.AdminOk } else { $strings.AdminErr }
    if ($script:LangLabel) { $script:LangLabel.Text = $strings.LangLabel }

    # Barre de préréglages & Copyright
    if ($lblPresetTitle) { $lblPresetTitle.Text = $strings.PresetLabel }
    if ($script:BtnPresetMin) { $script:BtnPresetMin.Text = $strings.BtnPresetMin }
    if ($script:BtnPresetStd) { $script:BtnPresetStd.Text = $strings.BtnPresetStd }
    if ($script:BtnPresetMax) { $script:BtnPresetMax.Text = $strings.BtnPresetMax }
    if ($lblPresetDesc) {
        $lblPresetDesc.Text = switch ($script:CurrentPreset) {
            "Minimal"  { $strings.PresetDescMin }
            "Standard" { $strings.PresetDescStd }
            "Max"      { $strings.PresetDescMax }
            default    { $strings.PresetDescStd }
        }
    }
    if ($copyrightLabel) { $copyrightLabel.Text = $strings.CopyrightText }

    # Synchroniser le sélecteur
    if ($script:LangCombo) {
        $expectedIdx = switch ($Lang) { "FR" { 0 } "EN" { 1 } "AR" { 2 } default { 0 } }
        if ($script:LangCombo.SelectedIndex -ne $expectedIdx) {
            $script:SuppressLangEvent = $true
            $script:LangCombo.SelectedIndex = $expectedIdx
            $script:SuppressLangEvent = $false
        }
    }

    # Titres des onglets
    if ($debloatTab -and $debloatTab.Page)   { $debloatTab.Page.Text = $strings.TabDebloat }
    if ($perfTab -and $perfTab.Page)         { $perfTab.Page.Text = $strings.TabPerf }
    if ($softwareTab -and $softwareTab.Page) { $softwareTab.Page.Text = $strings.TabSoftware }
    if ($networkTab -and $networkTab.Page)   { $networkTab.Page.Text = $strings.TabNetwork }
    if ($startupTab -and $startupTab.Page)   { $startupTab.Page.Text = $strings.TabStartup }
    if ($privacyTab -and $privacyTab.Page)   { $privacyTab.Page.Text = $strings.TabPrivacy }
    if ($cleanupTab -and $cleanupTab.Page) { $cleanupTab.Page.Text = $strings.TabCleanup }
    if ($repairTab -and $repairTab.Page)   { $repairTab.Page.Text = $strings.TabRepair }
    if ($logsTab -and $logsTab.Page)       { $logsTab.Page.Text = $strings.TabLogs }
    if ($script:TabControl) { $script:TabControl.Invalidate() }

    # Onglet 1 : Débloat
    if ($cardApps -and $cardApps.Tag) { $cardApps.Tag.Header.Text = $strings.GbApps }
    if ($script:CbApps) { $script:CbApps.Text = $strings.CbApps }
    if ($script:CbAppsAllUsers) { $script:CbAppsAllUsers.Text = $strings.CbAppsAllUsers }
    if ($lblAppsList) { $lblAppsList.Text = $strings.LblAppsList + ($script:AppsToRemove -join ", ") }

    if ($cardServices -and $cardServices.Tag) { $cardServices.Tag.Header.Text = $strings.GbServices }
    if ($script:CbServices) { $script:CbServices.Text = $strings.CbServices }
    if ($script:CbServicesSC) { $script:CbServicesSC.Text = $strings.CbServicesSC }
    if ($lblServicesList) { $lblServicesList.Text = $strings.LblServicesList + (($script:ServicesToDisable | ForEach-Object { "$($_.Name) ($($_.DisplayName))" }) -join "; ") }

    if ($cardTasks -and $cardTasks.Tag) { $cardTasks.Tag.Header.Text = $strings.GbTasks }
    if ($script:CbTasks) { $script:CbTasks.Text = $strings.CbTasks }
    if ($lblTasksCount) { $lblTasksCount.Text = "$($script:TasksToDisable.Count) " + $strings.LblTasksSuffix }

    # Onglet 2 : Performances
    if ($cardPerfMonitor -and $cardPerfMonitor.Tag) { $cardPerfMonitor.Tag.Header.Text = $strings.GbPerfMonitor }
    if ($btnFlushRam) { $btnFlushRam.Text = $strings.BtnFlushRam }
    if ($lblPerfLiveNotice) { $lblPerfLiveNotice.Text = $strings.PerfLiveNotice }
    if ($lblRamTip) { $lblRamTip.Text = $strings.PerfRamTip }

    if ($cardPerfKill -and $cardPerfKill.Tag) { $cardPerfKill.Tag.Header.Text = $strings.GbPerfKill }
    if ($lblKillInfo) { $lblKillInfo.Text = $strings.PerfKillInfo }
    if ($lblKillTargets) { $lblKillTargets.Text = $strings.PerfKillTargets }
    if ($btnKillProcesses) { $btnKillProcesses.Text = $strings.BtnKillProcesses }
    if ($script:CbAutoKillOnOptimize) { $script:CbAutoKillOnOptimize.Text = $strings.CbAutoKillOnOptimize }

    if ($cardPerfCpu -and $cardPerfCpu.Tag) { $cardPerfCpu.Tag.Header.Text = $strings.GbPerfCpu }
    if ($script:CbPowerPlan) { $script:CbPowerPlan.Text = $strings.CbPowerPlan }
    if ($lblSubPowerPlan) { $lblSubPowerPlan.Text = $strings.SubPowerPlan }
    if ($script:CbForegroundPriority) { $script:CbForegroundPriority.Text = $strings.CbForegroundPriority }
    if ($lblSubForegroundPriority) { $lblSubForegroundPriority.Text = $strings.SubForegroundPriority }
    if ($script:CbDisableCoreParking) { $script:CbDisableCoreParking.Text = $strings.CbDisableCoreParking }
    if ($btnApplyCpu) { $btnApplyCpu.Text = $strings.BtnApplyCpu }

    # Onglet Logiciels
    if ($cardBrowsers -and $cardBrowsers.Tag) { $cardBrowsers.Tag.Header.Text = $strings.GbBrowsers }
    if ($cardUtilities -and $cardUtilities.Tag) { $cardUtilities.Tag.Header.Text = $strings.GbUtilities }
    if ($cardGamingApps -and $cardGamingApps.Tag) { $cardGamingApps.Tag.Header.Text = $strings.GbGamingApps }
    if ($cardDevOffice -and $cardDevOffice.Tag) { $cardDevOffice.Tag.Header.Text = $strings.GbDevOffice }
    if ($btnSelectAllApps) { $btnSelectAllApps.Text = $strings.BtnSelectAllApps }
    if ($btnDeselectAllApps) { $btnDeselectAllApps.Text = $strings.BtnDeselectAllApps }
    if ($btnInstallApps) { $btnInstallApps.Text = $strings.BtnInstallApps }

    # Onglet Réseau
    if ($cardDnsSelector -and $cardDnsSelector.Tag) { $cardDnsSelector.Tag.Header.Text = $strings.GbDnsSelector }
    if ($rbDnsCloudflare) { $rbDnsCloudflare.Text = $strings.OptDnsCloudflare }
    if ($rbDnsGoogle) { $rbDnsGoogle.Text = $strings.OptDnsGoogle }
    if ($rbDnsQuad9) { $rbDnsQuad9.Text = $strings.OptDnsQuad9 }
    if ($rbDnsDhcp) { $rbDnsDhcp.Text = $strings.OptDnsDhcp }
    if ($btnApplyDns) { $btnApplyDns.Text = $strings.BtnApplyDns }
    if ($cardGamingNetwork -and $cardGamingNetwork.Tag) { $cardGamingNetwork.Tag.Header.Text = $strings.GbGamingNetwork }
    if ($script:CbNetThrottling) { $script:CbNetThrottling.Text = $strings.CbNetThrottling }
    if ($script:CbNagleAlgo) { $script:CbNagleAlgo.Text = $strings.CbNagleAlgo }
    if ($btnApplyGamingNet) { $btnApplyGamingNet.Text = $strings.BtnApplyGamingNet }
    if ($cardResetNetwork -and $cardResetNetwork.Tag) { $cardResetNetwork.Tag.Header.Text = $strings.GbResetNetwork }
    if ($lblResetNetworkDesc) { $lblResetNetworkDesc.Text = $strings.LblResetNetworkDesc }
    if ($btnResetNetStack) { $btnResetNetStack.Text = $strings.BtnResetNetStack }

    # Onglet Démarrage
    if ($cardStartupManager -and $cardStartupManager.Tag) { $cardStartupManager.Tag.Header.Text = $strings.GbStartupManager }
    if ($lblStartupDesc) { $lblStartupDesc.Text = $strings.LblStartupDesc }
    if ($btnRefreshStartup) { $btnRefreshStartup.Text = $strings.BtnRefreshStartup }
    if ($btnDisableStartup) { $btnDisableStartup.Text = $strings.BtnDisableStartup }
    if ($lvStartup -and $lvStartup.Columns.Count -ge 4) {
        $lvStartup.Columns[0].Text = $strings.ColStartupName
        $lvStartup.Columns[1].Text = $strings.ColStartupLocation
        $lvStartup.Columns[2].Text = $strings.ColStartupStatus
        $lvStartup.Columns[3].Text = $strings.ColStartupCommand
    }

    # Onglet 6 : Confidentialité
    if ($cardPrivacyReg -and $cardPrivacyReg.Tag) { $cardPrivacyReg.Tag.Header.Text = $strings.GbPrivacyReg }
    if ($script:CbPrivacyReg) { $script:CbPrivacyReg.Text = $strings.CbPrivacyReg }
    if ($script:CbPrivacyBackup) { $script:CbPrivacyBackup.Text = $strings.CbPrivacyBackup }
    if ($lblPrivacyRegCount) { $lblPrivacyRegCount.Text = "$($script:PrivacyRegistrySettings.Count) " + $strings.LblPrivacyRegSuffix }

    if ($cardGPO -and $cardGPO.Tag) { $cardGPO.Tag.Header.Text = $strings.GbGPO }
    if ($script:CbGPO) { $script:CbGPO.Text = $strings.CbGPO }
    if ($lblGPOCount) { $lblGPOCount.Text = $strings.LblGPOCount }

    if ($cardHosts -and $cardHosts.Tag) { $cardHosts.Tag.Header.Text = $strings.GbHosts }
    if ($script:CbHosts) { $script:CbHosts.Text = $strings.CbHosts }
    if ($script:CbHostsBackup) { $script:CbHostsBackup.Text = $strings.CbHostsBackup }

    if ($cardFirewall -and $cardFirewall.Tag) { $cardFirewall.Tag.Header.Text = $strings.GbFirewall }
    if ($script:CbFirewall) { $script:CbFirewall.Text = $strings.CbFirewall }

    # Onglet 3 : Nettoyage
    if ($cardDisk -and $cardDisk.Tag) { $cardDisk.Tag.Header.Text = $strings.GbDisk }
    if ($script:CbDisk) { $script:CbDisk.Text = $strings.CbDisk }
    if ($script:CbDiskRecycle) { $script:CbDiskRecycle.Text = $strings.CbDiskRecycle }
    if ($script:CbDiskWinUpdate) { $script:CbDiskWinUpdate.Text = $strings.CbDiskWinUpdate }
    if ($lblDiskPaths) { $lblDiskPaths.Text = $strings.LblDiskPaths + (($script:CleanupPaths | ForEach-Object { $_.Description }) -join "; ") }

    if ($cardRegClean -and $cardRegClean.Tag) { $cardRegClean.Tag.Header.Text = $strings.GbRegClean }
    if ($script:CbRegClean) { $script:CbRegClean.Text = $strings.CbRegClean }
    if ($script:CbRegBackup) { $script:CbRegBackup.Text = $strings.CbRegBackup }
    if ($script:CbRegAggressive) { $script:CbRegAggressive.Text = $strings.CbRegAggressive }
    if ($warnLabel) { $warnLabel.Text = $strings.WarnReg }

    # Onglet 4 : Maintenance
    if ($cardRepair -and $cardRepair.Tag) { $cardRepair.Tag.Header.Text = $strings.GbRepair }
    if ($script:CbDISM) { $script:CbDISM.Text = $strings.CbDISM }
    if ($script:CbSFC) { $script:CbSFC.Text = $strings.CbSFC }
    if ($script:CbChkdsk) { $script:CbChkdsk.Text = $strings.CbChkdsk }
    if ($infoLabel) { $infoLabel.Text = $strings.InfoRepair }

    if ($cardRestore -and $cardRestore.Tag) { $cardRestore.Tag.Header.Text = $strings.GbRestore }
    if ($script:CbRestorePoint) { $script:CbRestorePoint.Text = $strings.CbRestorePoint }
    if ($infoRestore) { $infoRestore.Text = $strings.InfoRestore }

    # Onglet 5 : Logs & Boutons d'action
    if ($btnClearLog) { $btnClearLog.Text = $strings.BtnClearLog }
    if ($btnSaveLog)  { $btnSaveLog.Text = $strings.BtnSaveLog }
    if ($script:BtnCancel) { $script:BtnCancel.Text = $strings.BtnCancel }
    if ($script:BtnDryRun) { $script:BtnDryRun.Text = $strings.BtnDryRun }
    if ($script:BtnRun) {
        $script:BtnRun.Text = if ($script:IsRunning) { $strings.BtnRunning } else { $strings.BtnRun }
    }
}

# ════════════════════════════════════════════════════════════════════════
# CRÉATION DE LA FENÊTRE PRINCIPALE (STYLE WINDOWS 11 FLUENT PRO)
# ════════════════════════════════════════════════════════════════════════

$form = New-Object System.Windows.Forms.Form
$form.Text = "REDADZDOptimiser Professional"
$form.Size = New-Object System.Drawing.Size(1020, 780)
$form.MinimumSize = New-Object System.Drawing.Size(980, 720)
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.BackColor = $colors.BackColor
$form.ForeColor = $colors.ForeColor
$form.Font = $fonts.Normal
$form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon((Get-Process -Id $PID).Path)

# Layout global en 4 lignes : Header (70px), Préréglages (48px), Onglets (100%), Barre d'action (66px)
$mainLayout = New-Object System.Windows.Forms.TableLayoutPanel
$mainLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
$mainLayout.ColumnCount = 1
$mainLayout.RowCount = 4
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 70))) | Out-Null
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 48))) | Out-Null
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 66))) | Out-Null
$mainLayout.BackColor = $colors.BackColor
$form.Controls.Add($mainLayout)

# ════════════════════════════════════════════════════════════════════════
# 1. HEADER (BANDEAU SUPÉRIEUR CLAIR & ÉPURÉ)
# ════════════════════════════════════════════════════════════════════════

$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$headerPanel.BackColor = $colors.HeaderBack
$headerPanel.Padding = New-Object System.Windows.Forms.Padding(24, 10, 24, 10)
$mainLayout.Controls.Add($headerPanel, 0, 0)

# Bordure inférieure subtile
$headerPanel.Add_Paint({
    param($s, $e)
    $pen = New-Object System.Drawing.Pen($script:colors.BorderColor, 1)
    $e.Graphics.DrawLine($pen, 0, $s.Height - 1, $s.Width, $s.Height - 1)
    $pen.Dispose()
})

# Titre Principal
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "⚡ REDADZDOptimiser"
$titleLabel.Font = $fonts.Title
$titleLabel.ForeColor = $colors.AccentColor
$titleLabel.AutoSize = $true
$titleLabel.Location = New-Object System.Drawing.Point(22, 12)
$headerPanel.Controls.Add($titleLabel)

# Sous-titre descriptif
$subtitleLabel = New-Object System.Windows.Forms.Label
$subtitleLabel.Text = "Centre d'Optimisation Windows 10/11  •  Débloat, Confidentialité, Nettoyage & Intégrité"
$subtitleLabel.Font = $fonts.Small
$subtitleLabel.ForeColor = $colors.MutedColor
$subtitleLabel.AutoSize = $true
$subtitleLabel.Location = New-Object System.Drawing.Point(24, 40)
$headerPanel.Controls.Add($subtitleLabel)

# Badge Administrateur (Pill moderne vert pastel ou rouge pastel)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$adminBadge = New-Object System.Windows.Forms.Label
$adminBadge.Text = if ($isAdmin) { "✓ ADMINISTRATEUR (Élevé)" } else { "⚠ NON-ADMIN (Droits limités)" }
$adminBadge.Font = $fonts.Badge
$adminBadge.ForeColor = if ($isAdmin) { $colors.AdminOkFore } else { $colors.AdminErrFore }
$adminBadge.BackColor = if ($isAdmin) { $colors.AdminOkBack } else { $colors.AdminErrBack }
$adminBadge.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$adminBadge.Size = New-Object System.Drawing.Size(195, 26)
$adminBadge.Anchor = [System.Windows.Forms.AnchorStyles]'Top, Right'
$adminBadge.Location = New-Object System.Drawing.Point(($form.Width - 235), 12)
$adminBadge.Add_Paint({
    param($s, $e)
    $borderCol = if ($isAdmin) { $script:colors.AdminOkBorder } else { $script:colors.AdminErrBorder }
    $p = New-Object System.Drawing.Pen($borderCol, 1)
    $e.Graphics.DrawRectangle($p, 0, 0, $s.Width - 1, $s.Height - 1)
    $p.Dispose()
})
$headerPanel.Controls.Add($adminBadge)

# Version Windows
$winVer = [System.Environment]::OSVersion.Version
$verLabel = New-Object System.Windows.Forms.Label
$verLabel.Text = "Windows $($winVer.Major).$($winVer.Minor) Build $($winVer.Build)"
$verLabel.Font = $fonts.Small
$verLabel.ForeColor = $colors.DisabledColor
$verLabel.AutoSize = $true
$verLabel.Anchor = [System.Windows.Forms.AnchorStyles]'Top, Right'
$verLabel.Location = New-Object System.Drawing.Point(($form.Width - 235), 42)
$headerPanel.Controls.Add($verLabel)

# Sélecteur de Langue dynamique
$script:LangLabel = New-Object System.Windows.Forms.Label
$script:LangLabel.Text = "Langue :"
$script:LangLabel.Font = $fonts.Small
$script:LangLabel.ForeColor = $colors.MutedColor
$script:LangLabel.AutoSize = $true
$script:LangLabel.Anchor = [System.Windows.Forms.AnchorStyles]'Top, Right'
$script:LangLabel.Location = New-Object System.Drawing.Point(($form.Width - 415), 24)
$headerPanel.Controls.Add($script:LangLabel)

$script:LangCombo = New-Object System.Windows.Forms.ComboBox
$script:LangCombo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$script:LangCombo.Items.AddRange(@("🇫🇷 Français", "🇬🇧 English", "🇸🇦 العربية"))
$script:LangCombo.BackColor = [System.Drawing.Color]::White
$script:LangCombo.ForeColor = $colors.ForeColor
$script:LangCombo.Font = $fonts.Normal
$script:LangCombo.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$script:LangCombo.Size = New-Object System.Drawing.Size(130, 26)
$script:LangCombo.Anchor = [System.Windows.Forms.AnchorStyles]'Top, Right'
$script:LangCombo.Location = New-Object System.Drawing.Point(($form.Width - 360), 20)
$script:LangCombo.Add_SelectedIndexChanged({
    if (-not $script:SuppressLangEvent) {
        $sel = switch ($this.SelectedIndex) {
            0 { "FR" }
            1 { "EN" }
            2 { "AR" }
            Default { "FR" }
        }
        Apply-Language -Lang $sel
    }
})
$headerPanel.Controls.Add($script:LangCombo)

# ════════════════════════════════════════════════════════════════════════
# 1.5. MENU HORIZONTAL DES PRÉRÉGLAGES (TWEAK MINIMAL / STANDARD / MAX)
# ════════════════════════════════════════════════════════════════════════

$presetPanel = New-Object System.Windows.Forms.Panel
$presetPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$presetPanel.BackColor = $colors.CardBack
$presetPanel.Padding = New-Object System.Windows.Forms.Padding(24, 6, 24, 6)
$mainLayout.Controls.Add($presetPanel, 0, 1)

# Ligne inférieure de séparation fine
$presetPanel.Add_Paint({
    param($s, $e)
    $pen = New-Object System.Drawing.Pen($script:colors.BorderColor, 1)
    $e.Graphics.DrawLine($pen, 0, $s.Height - 1, $s.Width, $s.Height - 1)
    $pen.Dispose()
})

$lblPresetTitle = New-Object System.Windows.Forms.Label
$lblPresetTitle.Text = "⚡ Préréglages :"
$lblPresetTitle.Font = $fonts.SubTitle
$lblPresetTitle.ForeColor = $colors.ForeColor
$lblPresetTitle.Location = New-Object System.Drawing.Point(24, 13)
$lblPresetTitle.AutoSize = $true
$presetPanel.Controls.Add($lblPresetTitle)

function New-PresetButton {
    param(
        [string]$Text,
        [System.Drawing.Point]$Location,
        [scriptblock]$Click
    )
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text
    $btn.Location = $Location
    $btn.Size = New-Object System.Drawing.Size(155, 30)
    $btn.Font = $fonts.Normal
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn.FlatAppearance.BorderSize = 0
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btn.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 252)
    $btn.ForeColor = [System.Drawing.Color]::FromArgb(71, 85, 105)
    $btn.Tag = @{
        BaseColor  = [System.Drawing.Color]::FromArgb(248, 250, 252)
        HoverColor = [System.Drawing.Color]::FromArgb(241, 245, 249)
        IsActive   = $false
    }
    $btn.Add_MouseEnter({
        if (-not $this.Tag.IsActive) { $this.BackColor = $this.Tag.HoverColor }
    })
    $btn.Add_MouseLeave({
        if (-not $this.Tag.IsActive) { $this.BackColor = $this.Tag.BaseColor }
    })
    $btn.Add_Paint({
        param($s, $e)
        if (-not $s.Tag.IsActive) {
            $pen = New-Object System.Drawing.Pen($script:colors.BorderColor, 1)
            $e.Graphics.DrawRectangle($pen, 0, 0, $s.Width - 1, $s.Height - 1)
            $pen.Dispose()
        }
    })
    if ($Click) { $btn.Add_Click($Click) }
    return $btn
}

$script:BtnPresetMin = New-PresetButton -Text "🌱 Tweak Minimal" -Location (New-Object System.Drawing.Point(145, 9)) -Click {
    Apply-Preset -Preset "Minimal"
}
$presetPanel.Controls.Add($script:BtnPresetMin)

$script:BtnPresetStd = New-PresetButton -Text "⚡ Tweak Standard" -Location (New-Object System.Drawing.Point(310, 9)) -Click {
    Apply-Preset -Preset "Standard"
}
$presetPanel.Controls.Add($script:BtnPresetStd)

$script:BtnPresetMax = New-PresetButton -Text "🚀 Tweak Max" -Location (New-Object System.Drawing.Point(475, 9)) -Click {
    Apply-Preset -Preset "Max"
}
$presetPanel.Controls.Add($script:BtnPresetMax)

$lblPresetDesc = New-Object System.Windows.Forms.Label
$lblPresetDesc.Text = "(Recommandé : Débloat, télémétrie, nettoyage & CPU)"
$lblPresetDesc.Font = $fonts.Small
$lblPresetDesc.ForeColor = $colors.MutedColor
$lblPresetDesc.Location = New-Object System.Drawing.Point(645, 15)
$lblPresetDesc.AutoSize = $true
$presetPanel.Controls.Add($lblPresetDesc)

# ════════════════════════════════════════════════════════════════════════
# 2. ONGLETS PRINCIPAUX (STYLE MODERNE CLAIR AVEC ACCENT ROYAL)
# ════════════════════════════════════════════════════════════════════════

$script:TabControl = New-Object System.Windows.Forms.TabControl
$script:TabControl.Dock = [System.Windows.Forms.DockStyle]::Fill
$script:TabControl.Font = $fonts.SubTitle
$script:TabControl.ItemSize = New-Object System.Drawing.Size(106, 38)
$script:TabControl.SizeMode = [System.Windows.Forms.TabSizeMode]::Fixed
$script:TabControl.Appearance = [System.Windows.Forms.TabAppearance]::Normal
$script:TabControl.BackColor = $colors.BackColor
$script:TabControl.ForeColor = $colors.ForeColor
$mainLayout.Controls.Add($script:TabControl, 0, 2)

# OwnerDraw personnalisé : fond blanc pour l'actif avec ligne d'accent bleue, gris clair pour inactif
$script:TabControl.DrawMode = [System.Windows.Forms.TabDrawMode]::OwnerDrawFixed
$script:TabControl.Add_DrawItem({
    param($sender, $e)
    $tab = $sender
    $g = $e.Graphics
    $tabRect = $tab.GetTabRect($e.Index)
    $tabText = $tab.TabPages[$e.Index].Text
    $isSelected = ($e.State -band [System.Windows.Forms.DrawItemState]::Selected)

    # Fond de l'onglet
    $bg = if ($isSelected) { $script:colors.CardBack } else { $script:colors.TabInactiveBack }
    $backBrush = New-Object System.Drawing.SolidBrush($bg)
    $g.FillRectangle($backBrush, $tabRect)
    $backBrush.Dispose()

    # Ligne d'accent inférieure pour l'onglet actif (Bleu Royal Moderne)
    if ($isSelected) {
        $accentPen = New-Object System.Drawing.Pen($script:colors.AccentColor, 3)
        $g.DrawLine($accentPen, [int]$tabRect.Left, [int]($tabRect.Bottom - 2), [int]$tabRect.Right, [int]($tabRect.Bottom - 2))
        $accentPen.Dispose()
    } else {
        $subtlePen = New-Object System.Drawing.Pen($script:colors.BorderColor, 1)
        $g.DrawLine($subtlePen, [int]$tabRect.Left, [int]($tabRect.Bottom - 1), [int]$tabRect.Right, [int]($tabRect.Bottom - 1))
        $subtlePen.Dispose()
    }

    # Texte de l'onglet
    $textColor = if ($isSelected) { $script:colors.AccentColor } else { $script:colors.MutedColor }
    $textBrush = New-Object System.Drawing.SolidBrush($textColor)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $fontToUse = if ($isSelected) { $script:fonts.SubTitle } else { $script:fonts.Normal }
    $rectF = [System.Drawing.RectangleF]$tabRect
    $g.DrawString($tabText, $fontToUse, $textBrush, $rectF, $sf)

    $textBrush.Dispose()
    $sf.Dispose()
})

# Fonction de création d'onglet avec défilement fluide
function New-TabPage {
    param([string]$Title)
    $page = New-Object System.Windows.Forms.TabPage
    $page.Text = $Title
    $page.BackColor = $colors.BackColor
    $page.ForeColor = $colors.ForeColor
    $page.Padding = New-Object System.Windows.Forms.Padding(12)

    $scroll = New-Object System.Windows.Forms.Panel
    $scroll.Dock = [System.Windows.Forms.DockStyle]::Fill
    $scroll.AutoScroll = $true
    $scroll.BackColor = $colors.BackColor
    $page.Controls.Add($scroll)

    return @{ Page = $page; Scroll = $scroll }
}

# ────────────────────────────────────────────────────────────────────────
# ONGLET 1 : DÉBLOAT
# ────────────────────────────────────────────────────────────────────────
$debloatTab = New-TabPage -Title "🗑️ Débloat"
$script:TabControl.TabPages.Add($debloatTab.Page)

$yPos = 14

# Carte Apps
$cardApps = New-ModernCard -Title "Applications provisionnées à supprimer" -Location (New-Object System.Drawing.Point(12, $yPos)) -Size (New-Object System.Drawing.Size(890, 275)) -AccentLineColor $colors.AccentColor
$debloatTab.Scroll.Controls.Add($cardApps)

$script:CbApps = New-ModernCheckBox -Text "Supprimer les bloatwares préinstallés (Xbox, Bing, Solitaire, Feedback, Cartes, etc.)" -Location (New-Object System.Drawing.Point(20, 44)) -Checked $true
$cardApps.Controls.Add($script:CbApps)

$script:CbAppsAllUsers = New-ModernCheckBox -Text "Appliquer à tous les profils d'utilisateurs de cette machine (Recommandé)" -Location (New-Object System.Drawing.Point(40, 72)) -Checked $true
$cardApps.Controls.Add($script:CbAppsAllUsers)

$lblAppsList = New-Object System.Windows.Forms.Label
$lblAppsList.Text = "Applications ciblées : " + ($script:AppsToRemove -join ", ")
$lblAppsList.Font = $fonts.Small
$lblAppsList.ForeColor = $colors.MutedColor
$lblAppsList.Location = New-Object System.Drawing.Point(20, 105)
$lblAppsList.Size = New-Object System.Drawing.Size(850, 155)
$lblAppsList.AutoSize = $false
$cardApps.Controls.Add($lblAppsList)

$yPos += 290

# Carte Services
$cardServices = New-ModernCard -Title "Services système de télémétrie à désactiver" -Location (New-Object System.Drawing.Point(12, $yPos)) -Size (New-Object System.Drawing.Size(890, 195)) -AccentLineColor $colors.CyanAccent
$debloatTab.Scroll.Controls.Add($cardServices)

$script:CbServices = New-ModernCheckBox -Text "Désactiver les services de tracking et collecte en arrière-plan (DiagTrack, dmwappushservice, WER)" -Location (New-Object System.Drawing.Point(20, 44)) -Checked $true
$cardServices.Controls.Add($script:CbServices)

$script:CbServicesSC = New-ModernCheckBox -Text "Forcer la désactivation via Service Controller (SC config = disabled)" -Location (New-Object System.Drawing.Point(40, 72)) -Checked $true
$cardServices.Controls.Add($script:CbServicesSC)

$lblServicesList = New-Object System.Windows.Forms.Label
$lblServicesList.Text = "Services ciblés : " + (($script:ServicesToDisable | ForEach-Object { "$($_.Name) ($($_.DisplayName))" }) -join "; ")
$lblServicesList.Font = $fonts.Small
$lblServicesList.ForeColor = $colors.MutedColor
$lblServicesList.Location = New-Object System.Drawing.Point(20, 102)
$lblServicesList.Size = New-Object System.Drawing.Size(850, 80)
$lblServicesList.AutoSize = $false
$cardServices.Controls.Add($lblServicesList)

$yPos += 210

# Carte Tâches
$cardTasks = New-ModernCard -Title "Tâches planifiées de collecte à désactiver" -Location (New-Object System.Drawing.Point(12, $yPos)) -Size (New-Object System.Drawing.Size(890, 115)) -AccentLineColor $colors.IndigoAccent
$debloatTab.Scroll.Controls.Add($cardTasks)

$script:CbTasks = New-ModernCheckBox -Text "Désactiver les tâches de collecte de données (CEIP, Customer Experience, Error Reporting)" -Location (New-Object System.Drawing.Point(20, 44)) -Checked $true
$cardTasks.Controls.Add($script:CbTasks)

$lblTasksCount = New-Object System.Windows.Forms.Label
$lblTasksCount.Text = "$($script:TasksToDisable.Count) tâches planifiées ciblées"
$lblTasksCount.Font = $fonts.Small
$lblTasksCount.ForeColor = $colors.MutedColor
$lblTasksCount.Location = New-Object System.Drawing.Point(20, 75)
$lblTasksCount.AutoSize = $true
$cardTasks.Controls.Add($lblTasksCount)

# ────────────────────────────────────────────────────────────────────────
# ONGLET 2 : PERFORMANCES (RAM & PROCESSEUR)
# ────────────────────────────────────────────────────────────────────────
$perfTab = New-TabPage -Title "⚡ Performances"
$script:TabControl.TabPages.Add($perfTab.Page)

$yPosPerf = 14

# ── Carte 1: Surveillance des Ressources (RAM & CPU) ──
$cardPerfMonitor = New-ModernCard -Title "Surveillance des Ressources en temps réel" -Location (New-Object System.Drawing.Point(12, $yPosPerf)) -Size (New-Object System.Drawing.Size(890, 215)) -AccentLineColor $colors.SuccessColor
$perfTab.Scroll.Controls.Add($cardPerfMonitor)

# RAM
$lblRamMetric = New-Object System.Windows.Forms.Label
$lblRamMetric.Text = "Mémoire Vive (RAM) : Calcul en cours..."
$lblRamMetric.Font = $fonts.SubTitle
$lblRamMetric.ForeColor = $colors.ForeColor
$lblRamMetric.Location = New-Object System.Drawing.Point(20, 44)
$lblRamMetric.Size = New-Object System.Drawing.Size(600, 22)
$cardPerfMonitor.Controls.Add($lblRamMetric)

$pbRam = New-Object System.Windows.Forms.ProgressBar
$pbRam.Location = New-Object System.Drawing.Point(20, 70)
$pbRam.Size = New-Object System.Drawing.Size(610, 22)
$pbRam.Minimum = 0
$pbRam.Maximum = 100
$pbRam.Value = 0
$pbRam.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
$cardPerfMonitor.Controls.Add($pbRam)

$btnFlushRam = New-ModernButton -Text "🚀 Vider le cache & RAM" -Size (New-Object System.Drawing.Size(225, 48)) -Location (New-Object System.Drawing.Point(645, 44)) -BackColor $colors.SuccessColor -HoverColor $colors.SuccessHover -PressColor $colors.SuccessPress -Click {
    if ($script:IsRunning) { return }
    $origText = $btnFlushRam.Text
    $btnFlushRam.Enabled = $false
    $btnFlushRam.Text = "⏳ ..."
    [System.Windows.Forms.Application]::DoEvents()
    try {
        $res = Optimize-RAM
        Append-Log "✓ Nettoyage RAM : ~$($res.FreedMB) Mo libérés sur $($res.ProcessCount) processus" "SUCCESS"
        $m = Get-SystemPerformanceMetrics
        if ($m) {
            $ramPct = [int]$m.RamPercent
            if ($pbRam) { $pbRam.Value = [math]::Min(100, [math]::Max(0, $ramPct)) }
            if ($lblRamMetric) {
                $lblRamMetric.Text = ($script:I18N[$script:CurrentLang].PerfRamFormat -f $m.UsedRamGB, $m.TotalRamGB, $ramPct)
            }
        }
        $btnFlushRam.Text = ($script:I18N[$script:CurrentLang].BtnFlushRamDone -f [int]$res.FreedMB)
    } catch {
        Append-Log "Erreur nettoyage RAM: $_" "ERROR"
        $btnFlushRam.Text = $origText
    } finally {
        $btnFlushRam.Enabled = $true
    }
}
$cardPerfMonitor.Controls.Add($btnFlushRam)

# CPU
$lblCpuMetric = New-Object System.Windows.Forms.Label
$lblCpuMetric.Text = "Processeur (CPU) : Calcul en cours..."
$lblCpuMetric.Font = $fonts.SubTitle
$lblCpuMetric.ForeColor = $colors.ForeColor
$lblCpuMetric.Location = New-Object System.Drawing.Point(20, 106)
$lblCpuMetric.Size = New-Object System.Drawing.Size(600, 22)
$cardPerfMonitor.Controls.Add($lblCpuMetric)

$pbCpu = New-Object System.Windows.Forms.ProgressBar
$pbCpu.Location = New-Object System.Drawing.Point(20, 132)
$pbCpu.Size = New-Object System.Drawing.Size(610, 22)
$pbCpu.Minimum = 0
$pbCpu.Maximum = 100
$pbCpu.Value = 0
$pbCpu.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
$cardPerfMonitor.Controls.Add($pbCpu)

$lblPerfLiveNotice = New-Object System.Windows.Forms.Label
$lblPerfLiveNotice.Text = "● Surveillance continue en direct • 1.5s"
$lblPerfLiveNotice.Font = $fonts.Small
$lblPerfLiveNotice.ForeColor = $colors.MutedColor
$lblPerfLiveNotice.Location = New-Object System.Drawing.Point(645, 134)
$lblPerfLiveNotice.Size = New-Object System.Drawing.Size(225, 20)
$cardPerfMonitor.Controls.Add($lblPerfLiveNotice)

$lblRamTip = New-Object System.Windows.Forms.Label
$lblRamTip.Text = "Astuce : La purge de la mémoire vide en toute sécurité le cache inactif des processus en arrière-plan sans fermer vos applications."
$lblRamTip.Font = $fonts.Small
$lblRamTip.ForeColor = $colors.MutedColor
$lblRamTip.Location = New-Object System.Drawing.Point(20, 168)
$lblRamTip.Size = New-Object System.Drawing.Size(850, 36)
$cardPerfMonitor.Controls.Add($lblRamTip)

$yPosPerf += 230

# ── Carte 2: Fermeture des Processus d'Arrière-Plan ──
$cardPerfKill = New-ModernCard -Title "Nettoyeur de Processus d'Arrière-Plan Inutiles" -Location (New-Object System.Drawing.Point(12, $yPosPerf)) -Size (New-Object System.Drawing.Size(890, 175)) -AccentLineColor $colors.ErrorColor
$perfTab.Scroll.Controls.Add($cardPerfKill)

$lblKillInfo = New-Object System.Windows.Forms.Label
$lblKillInfo.Text = "Ferme immédiatement les processus d'arrière-plan gourmands ou dormants (Phone Link, Game Bar, Widgets, Télémétrie Microsoft, Edge idle) tout en protégeant les processus système vitaux."
$lblKillInfo.Font = $fonts.Normal
$lblKillInfo.ForeColor = $colors.ForeColor
$lblKillInfo.Location = New-Object System.Drawing.Point(20, 42)
$lblKillInfo.Size = New-Object System.Drawing.Size(850, 36)
$cardPerfKill.Controls.Add($lblKillInfo)

$lblKillTargets = New-Object System.Windows.Forms.Label
$lblKillTargets.Text = "Processus ciblés : PhoneExperienceHost, GameBarPresenceWriter, Widgets, Cortana, NewsAndInterests, FeedbackHub, Edge (idle)"
$lblKillTargets.Font = $fonts.Small
$lblKillTargets.ForeColor = $colors.MutedColor
$lblKillTargets.Location = New-Object System.Drawing.Point(20, 80)
$lblKillTargets.Size = New-Object System.Drawing.Size(850, 20)
$cardPerfKill.Controls.Add($lblKillTargets)

$btnKillProcesses = New-ModernButton -Text "🛑 Fermer les processus inutiles" -Size (New-Object System.Drawing.Size(260, 42)) -Location (New-Object System.Drawing.Point(20, 112)) -BackColor $colors.ErrorColor -HoverColor $colors.ErrorHover -PressColor $colors.ErrorPress -Click {
    if ($script:IsRunning) { return }
    $origText = $btnKillProcesses.Text
    $btnKillProcesses.Enabled = $false
    $btnKillProcesses.Text = "⏳ ..."
    [System.Windows.Forms.Application]::DoEvents()
    try {
        $res = Stop-UnnecessaryProcesses
        Append-Log "✓ Processus d'arrière-plan arrêtés : $($res.TerminatedCount) processus" "SUCCESS"
        $btnKillProcesses.Text = ($script:I18N[$script:CurrentLang].BtnKillProcessesDone -f $res.TerminatedCount)
        $m = Get-SystemPerformanceMetrics
        if ($m -and $lblCpuMetric) {
            $lblCpuMetric.Text = ($script:I18N[$script:CurrentLang].PerfCpuFormat -f [math]::Round([double]$m.CpuPercent, 1), $m.ProcessCount)
        }
    } catch {
        Append-Log "Erreur arrêt processus: $_" "ERROR"
        $btnKillProcesses.Text = $origText
    } finally {
        $btnKillProcesses.Enabled = $true
    }
}
$cardPerfKill.Controls.Add($btnKillProcesses)

$script:CbAutoKillOnOptimize = New-ModernCheckBox -Text "Inclure la fermeture des processus inutiles lors de l'Optimisation Globale" -Location (New-Object System.Drawing.Point(300, 122)) -Checked $true
$cardPerfKill.Controls.Add($script:CbAutoKillOnOptimize)

$yPosPerf += 190

# ── Carte 3: Optimisations Processeur & Énergie ──
$cardPerfCpu = New-ModernCard -Title "Optimisations Processeur (CPU) & Alimentation" -Location (New-Object System.Drawing.Point(12, $yPosPerf)) -Size (New-Object System.Drawing.Size(890, 235)) -AccentLineColor $colors.IndigoAccent
$perfTab.Scroll.Controls.Add($cardPerfCpu)

$script:CbPowerPlan = New-ModernCheckBox -Text "Activer le plan d'alimentation 'Performances Élevées' / 'Performances Optimales'" -Location (New-Object System.Drawing.Point(20, 40)) -Checked $true
$cardPerfCpu.Controls.Add($script:CbPowerPlan)

$lblSubPowerPlan = New-Object System.Windows.Forms.Label
$lblSubPowerPlan.Text = "Débloque la fréquence maximale du CPU et supprime les bridages d'économie d'énergie."
$lblSubPowerPlan.Font = $fonts.Small
$lblSubPowerPlan.ForeColor = $colors.MutedColor
$lblSubPowerPlan.Location = New-Object System.Drawing.Point(42, 64)
$lblSubPowerPlan.Size = New-Object System.Drawing.Size(820, 18)
$cardPerfCpu.Controls.Add($lblSubPowerPlan)

$script:CbForegroundPriority = New-ModernCheckBox -Text "Priorité CPU maximale aux applications au premier plan (Win32PrioritySeparation = 0x26)" -Location (New-Object System.Drawing.Point(20, 88)) -Checked $true
$cardPerfCpu.Controls.Add($script:CbForegroundPriority)

$lblSubForegroundPriority = New-Object System.Windows.Forms.Label
$lblSubForegroundPriority.Text = "Alloue 3x plus de temps processeur à la fenêtre active (Jeux, logiciels) pour une réactivité instantanée."
$lblSubForegroundPriority.Font = $fonts.Small
$lblSubForegroundPriority.ForeColor = $colors.MutedColor
$lblSubForegroundPriority.Location = New-Object System.Drawing.Point(42, 112)
$lblSubForegroundPriority.Size = New-Object System.Drawing.Size(820, 18)
$cardPerfCpu.Controls.Add($lblSubForegroundPriority)

$script:CbDisableCoreParking = New-ModernCheckBox -Text "Désactiver la mise en veille forcée des cœurs du processeur (Core Parking OFF)" -Location (New-Object System.Drawing.Point(20, 136)) -Checked $true
$cardPerfCpu.Controls.Add($script:CbDisableCoreParking)

$btnApplyCpu = New-ModernButton -Text "⚡ Appliquer les réglages CPU" -Size (New-Object System.Drawing.Size(260, 40)) -Location (New-Object System.Drawing.Point(20, 175)) -BackColor $colors.AccentColor -HoverColor $colors.AccentHover -PressColor $colors.AccentPress -Click {
    if ($script:IsRunning) { return }
    $origText = $btnApplyCpu.Text
    $btnApplyCpu.Enabled = $false
    $btnApplyCpu.Text = "⏳ ..."
    [System.Windows.Forms.Application]::DoEvents()
    try {
        $res = Optimize-CPU -HighPerformancePower:$script:CbPowerPlan.Checked `
                             -ForegroundPriority:$script:CbForegroundPriority.Checked `
                             -DisableCoreParking:$script:CbDisableCoreParking.Checked
        Append-Log "✓ Réglages CPU appliqués : Plan=$($res.PowerPlan), Priorité=$($res.PrioritySeparation), Parking=$($res.CoreParking)" "SUCCESS"
        $btnApplyCpu.Text = $script:I18N[$script:CurrentLang].BtnApplyCpuDone
    } catch {
        Append-Log "Erreur optimisation CPU: $_" "ERROR"
        $btnApplyCpu.Text = $origText
    } finally {
        $btnApplyCpu.Enabled = $true
    }
}
$cardPerfCpu.Controls.Add($btnApplyCpu)


# ────────────────────────────────────────────────────────────────────────
# ONGLET 3 : LOGICIELS (WINGET INSTALLER)
# ────────────────────────────────────────────────────────────────────────
$softwareTab = New-TabPage -Title "📦 Logiciels"
$script:TabControl.TabPages.Add($softwareTab.Page)

$yPosSoft = 14

# Barre d'actions rapides logiciels
$btnSelectAllApps = New-ModernButton -Text "✓ Tout cocher" -Size (New-Object System.Drawing.Size(130, 32)) -Location (New-Object System.Drawing.Point(12, $yPosSoft)) -Click {
    foreach ($cb in $script:AppCheckBoxes) { $cb.Checked = $true }
} -BackColor $colors.CardBack -HoverColor $colors.AccentColor -PressColor $colors.AccentPress -ForeColor $colors.ForeColor
$softwareTab.Scroll.Controls.Add($btnSelectAllApps)

$btnDeselectAllApps = New-ModernButton -Text "✕ Tout décocher" -Size (New-Object System.Drawing.Size(140, 32)) -Location (New-Object System.Drawing.Point(150, $yPosSoft)) -Click {
    foreach ($cb in $script:AppCheckBoxes) { $cb.Checked = $false }
} -BackColor $colors.CardBack -HoverColor $colors.AccentColor -PressColor $colors.AccentPress -ForeColor $colors.ForeColor
$softwareTab.Scroll.Controls.Add($btnDeselectAllApps)

$btnInstallApps = New-ModernButton -Text "🚀 Installer les applications cochées (Winget)" -Size (New-Object System.Drawing.Size(320, 32)) -Location (New-Object System.Drawing.Point(300, $yPosSoft)) -Click {
    if ($script:IsRunning) { return }
    $selected = @()
    foreach ($cb in $script:AppCheckBoxes) {
        if ($cb.Checked -and $cb.Tag) { $selected += $cb.Tag }
    }
    if ($selected.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Veuillez cocher au moins une application à installer !",
            "Information",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }
    $origText = $btnInstallApps.Text
    $btnInstallApps.Enabled = $false
    $btnInstallApps.Text = $script:I18N[$script:CurrentLang].BtnInstallingApps
    $script:TabControl.SelectedTab = $logsTab.Page
    [System.Windows.Forms.Application]::DoEvents()
    try {
        Append-Log "Démarrage de l'installation de $($selected.Count) application(s) via Winget..." "INFO"
        $res = Install-WingetApps -AppIds $selected -OnProgress {
            param($app, $cur, $tot)
            Update-UIProgress "Installation Winget: $app" $cur $tot "" ([int](($cur / $tot) * 100))
        }
        Append-Log ($script:I18N[$script:CurrentLang].InstallAppsDone -f $res.Installed.Count, $res.Failed.Count) "SUCCESS"
    } catch {
        Append-Log "Erreur installation applications : $_" "ERROR"
    } finally {
        $btnInstallApps.Enabled = $true
        $btnInstallApps.Text = $origText
        Update-UIProgress "Prêt" 0 0 "" 0
    }
} -BackColor $colors.SuccessColor -HoverColor $colors.SuccessHover -PressColor $colors.SuccessPress
$softwareTab.Scroll.Controls.Add($btnInstallApps)

$yPosSoft += 44

$script:AppCheckBoxes = @()

# 1. Navigateurs Web
$cardBrowsers = New-ModernCard -Title "Navigateurs Web" -Location (New-Object System.Drawing.Point(12, $yPosSoft)) -Size (New-Object System.Drawing.Size(890, 130)) -AccentLineColor $colors.AccentColor
$softwareTab.Scroll.Controls.Add($cardBrowsers)

$cbChrome = New-ModernCheckBox -Text "Google Chrome" -Location (New-Object System.Drawing.Point(20, 42)) -Checked $false
$cbChrome.Tag = "Google.Chrome"
$cardBrowsers.Controls.Add($cbChrome); $script:AppCheckBoxes += $cbChrome

$cbBrave = New-ModernCheckBox -Text "Brave Browser (Sécurisé & Sans pub)" -Location (New-Object System.Drawing.Point(20, 72)) -Checked $true
$cbBrave.Tag = "Brave.Brave"
$cardBrowsers.Controls.Add($cbBrave); $script:AppCheckBoxes += $cbBrave

$cbFirefox = New-ModernCheckBox -Text "Mozilla Firefox" -Location (New-Object System.Drawing.Point(450, 42)) -Checked $false
$cbFirefox.Tag = "Mozilla.Firefox"
$cardBrowsers.Controls.Add($cbFirefox); $script:AppCheckBoxes += $cbFirefox

$cbOperaGX = New-ModernCheckBox -Text "Opera GX Gaming Browser" -Location (New-Object System.Drawing.Point(450, 72)) -Checked $false
$cbOperaGX.Tag = "Opera.OperaGX"
$cardBrowsers.Controls.Add($cbOperaGX); $script:AppCheckBoxes += $cbOperaGX

$yPosSoft += 145

# 2. Utilitaires & Fichiers
$cardUtilities = New-ModernCard -Title "Utilitaires & Fichiers" -Location (New-Object System.Drawing.Point(12, $yPosSoft)) -Size (New-Object System.Drawing.Size(890, 160)) -AccentLineColor $colors.CyanAccent
$softwareTab.Scroll.Controls.Add($cardUtilities)

$cb7zip = New-ModernCheckBox -Text "7-Zip (Compresseur de fichiers ultra-rapide)" -Location (New-Object System.Drawing.Point(20, 42)) -Checked $true
$cb7zip.Tag = "7zip.7zip"
$cardUtilities.Controls.Add($cb7zip); $script:AppCheckBoxes += $cb7zip

$cbWinrar = New-ModernCheckBox -Text "WinRAR" -Location (New-Object System.Drawing.Point(20, 72)) -Checked $false
$cbWinrar.Tag = "RARLab.WinRAR"
$cardUtilities.Controls.Add($cbWinrar); $script:AppCheckBoxes += $cbWinrar

$cbVLC = New-ModernCheckBox -Text "VLC Media Player (Lecteur multimédia tous formats)" -Location (New-Object System.Drawing.Point(20, 102)) -Checked $true
$cbVLC.Tag = "VideoLAN.VLC"
$cardUtilities.Controls.Add($cbVLC); $script:AppCheckBoxes += $cbVLC

$cbNotepad = New-ModernCheckBox -Text "Notepad++ (Éditeur de texte avancé)" -Location (New-Object System.Drawing.Point(450, 42)) -Checked $true
$cbNotepad.Tag = "Notepad++.Notepad++"
$cardUtilities.Controls.Add($cbNotepad); $script:AppCheckBoxes += $cbNotepad

$cbPowerToys = New-ModernCheckBox -Text "Microsoft PowerToys (Boîte à outils Windows officielle)" -Location (New-Object System.Drawing.Point(450, 72)) -Checked $false
$cbPowerToys.Tag = "Microsoft.PowerToys"
$cardUtilities.Controls.Add($cbPowerToys); $script:AppCheckBoxes += $cbPowerToys

$yPosSoft += 175

# 3. Jeux & Streaming
$cardGamingApps = New-ModernCard -Title "Jeux & Streaming" -Location (New-Object System.Drawing.Point(12, $yPosSoft)) -Size (New-Object System.Drawing.Size(890, 130)) -AccentLineColor $colors.PurpleAccent
$softwareTab.Scroll.Controls.Add($cardGamingApps)

$cbSteam = New-ModernCheckBox -Text "Steam" -Location (New-Object System.Drawing.Point(20, 42)) -Checked $true
$cbSteam.Tag = "Valve.Steam"
$cardGamingApps.Controls.Add($cbSteam); $script:AppCheckBoxes += $cbSteam

$cbDiscord = New-ModernCheckBox -Text "Discord" -Location (New-Object System.Drawing.Point(20, 72)) -Checked $true
$cbDiscord.Tag = "Discord.Discord"
$cardGamingApps.Controls.Add($cbDiscord); $script:AppCheckBoxes += $cbDiscord

$cbEpic = New-ModernCheckBox -Text "Epic Games Launcher" -Location (New-Object System.Drawing.Point(450, 42)) -Checked $false
$cbEpic.Tag = "EpicGames.EpicGamesLauncher"
$cardGamingApps.Controls.Add($cbEpic); $script:AppCheckBoxes += $cbEpic

$cbOBS = New-ModernCheckBox -Text "OBS Studio (Enregistrement & Streaming vidéo)" -Location (New-Object System.Drawing.Point(450, 72)) -Checked $false
$cbOBS.Tag = "OBSProject.OBSStudio"
$cardGamingApps.Controls.Add($cbOBS); $script:AppCheckBoxes += $cbOBS

$yPosSoft += 145

# 4. Bureautique & Développement
$cardDevOffice = New-ModernCard -Title "Bureautique & Développement" -Location (New-Object System.Drawing.Point(12, $yPosSoft)) -Size (New-Object System.Drawing.Size(890, 130)) -AccentLineColor $colors.IndigoAccent
$softwareTab.Scroll.Controls.Add($cardDevOffice)

$cbVSCode = New-ModernCheckBox -Text "Visual Studio Code" -Location (New-Object System.Drawing.Point(20, 42)) -Checked $true
$cbVSCode.Tag = "Microsoft.VisualStudioCode"
$cardDevOffice.Controls.Add($cbVSCode); $script:AppCheckBoxes += $cbVSCode

$cbLibreOffice = New-ModernCheckBox -Text "LibreOffice (Suite bureautique complète gratuite)" -Location (New-Object System.Drawing.Point(20, 72)) -Checked $false
$cbLibreOffice.Tag = "TheDocumentFoundation.LibreOffice"
$cardDevOffice.Controls.Add($cbLibreOffice); $script:AppCheckBoxes += $cbLibreOffice

$cbAdobeReader = New-ModernCheckBox -Text "Adobe Acrobat Reader" -Location (New-Object System.Drawing.Point(450, 42)) -Checked $false
$cbAdobeReader.Tag = "Adobe.Acrobat.Reader.64-bit"
$cardDevOffice.Controls.Add($cbAdobeReader); $script:AppCheckBoxes += $cbAdobeReader

$cbAnyDesk = New-ModernCheckBox -Text "AnyDesk (Accès et assistance à distance)" -Location (New-Object System.Drawing.Point(450, 72)) -Checked $false
$cbAnyDesk.Tag = "AnyDeskSoftwareGmbH.AnyDesk"
$cardDevOffice.Controls.Add($cbAnyDesk); $script:AppCheckBoxes += $cbAnyDesk

# ────────────────────────────────────────────────────────────────────────
# ONGLET 4 : RÉSEAU & DNS
# ────────────────────────────────────────────────────────────────────────
$networkTab = New-TabPage -Title "🌐 Réseau & DNS"
$script:TabControl.TabPages.Add($networkTab.Page)

$yPosNet = 14

# 1. Carte Sélecteur DNS
$cardDnsSelector = New-ModernCard -Title "Sélecteur DNS Rapide & Sécurisé" -Location (New-Object System.Drawing.Point(12, $yPosNet)) -Size (New-Object System.Drawing.Size(890, 205)) -AccentLineColor $colors.AccentColor
$networkTab.Scroll.Controls.Add($cardDnsSelector)

$rbDnsCloudflare = New-Object System.Windows.Forms.RadioButton
$rbDnsCloudflare.Text = "⚡ Cloudflare (1.1.1.1 / 1.0.0.1 - Vitesse max & Jeux en ligne)"
$rbDnsCloudflare.Location = New-Object System.Drawing.Point(20, 40)
$rbDnsCloudflare.Size = New-Object System.Drawing.Size(800, 24)
$rbDnsCloudflare.Font = $fonts.Normal
$rbDnsCloudflare.ForeColor = $colors.ForeColor
$rbDnsCloudflare.Checked = $true
$cardDnsSelector.Controls.Add($rbDnsCloudflare)

$rbDnsGoogle = New-Object System.Windows.Forms.RadioButton
$rbDnsGoogle.Text = "🔒 Google DNS (8.8.8.8 / 8.8.4.4 - Haute compatibilité)"
$rbDnsGoogle.Location = New-Object System.Drawing.Point(20, 68)
$rbDnsGoogle.Size = New-Object System.Drawing.Size(800, 24)
$rbDnsGoogle.Font = $fonts.Normal
$rbDnsGoogle.ForeColor = $colors.ForeColor
$cardDnsSelector.Controls.Add($rbDnsGoogle)

$rbDnsQuad9 = New-Object System.Windows.Forms.RadioButton
$rbDnsQuad9.Text = "🛡️ Quad9 (9.9.9.9 - Sécurité anti-malware renforcée)"
$rbDnsQuad9.Location = New-Object System.Drawing.Point(20, 96)
$rbDnsQuad9.Size = New-Object System.Drawing.Size(800, 24)
$rbDnsQuad9.Font = $fonts.Normal
$rbDnsQuad9.ForeColor = $colors.ForeColor
$cardDnsSelector.Controls.Add($rbDnsQuad9)

$rbDnsDhcp = New-Object System.Windows.Forms.RadioButton
$rbDnsDhcp.Text = "🔄 Automatique / FAI (DHCP standard par défaut)"
$rbDnsDhcp.Location = New-Object System.Drawing.Point(20, 124)
$rbDnsDhcp.Size = New-Object System.Drawing.Size(800, 24)
$rbDnsDhcp.Font = $fonts.Normal
$rbDnsDhcp.ForeColor = $colors.ForeColor
$cardDnsSelector.Controls.Add($rbDnsDhcp)

$btnApplyDns = New-ModernButton -Text "⚡ Appliquer le serveur DNS sélectionné" -Size (New-Object System.Drawing.Size(300, 36)) -Location (New-Object System.Drawing.Point(20, 155)) -Click {
    $prov = if ($rbDnsCloudflare.Checked) { "Cloudflare" } elseif ($rbDnsGoogle.Checked) { "Google" } elseif ($rbDnsQuad9.Checked) { "Quad9" } else { "DHCP" }
    try {
        $res = Set-SystemDns -Provider $prov
        Append-Log "✓ Configuration DNS ($prov) appliquée avec succès." "SUCCESS"
        [System.Windows.Forms.MessageBox]::Show(
            $script:I18N[$script:CurrentLang].BtnApplyDnsDone,
            "DNS",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    } catch {
        Append-Log "Erreur configuration DNS : $_" "ERROR"
    }
} -BackColor $colors.AccentColor -HoverColor $colors.AccentHover -PressColor $colors.AccentPress
$cardDnsSelector.Controls.Add($btnApplyDns)

$yPosNet += 220

# 2. Carte Gaming & Latence
$cardGamingNetwork = New-ModernCard -Title "Optimisations Latence Réseau & Gaming (Ping TCP/IP)" -Location (New-Object System.Drawing.Point(12, $yPosNet)) -Size (New-Object System.Drawing.Size(890, 160)) -AccentLineColor $colors.SuccessColor
$networkTab.Scroll.Controls.Add($cardGamingNetwork)

$script:CbNetThrottling = New-ModernCheckBox -Text "Désactiver la limitation de bande passante multimédia (NetworkThrottlingIndex)" -Location (New-Object System.Drawing.Point(20, 42)) -Checked $true
$cardGamingNetwork.Controls.Add($script:CbNetThrottling)

$script:CbNagleAlgo = New-ModernCheckBox -Text "Désactiver l'algorithme Nagle (TcpAckFrequency & TCPNoDelay = 1)" -Location (New-Object System.Drawing.Point(20, 72)) -Checked $true
$cardGamingNetwork.Controls.Add($script:CbNagleAlgo)

$btnApplyGamingNet = New-ModernButton -Text "🚀 Appliquer les optimisations réseau gaming" -Size (New-Object System.Drawing.Size(320, 36)) -Location (New-Object System.Drawing.Point(20, 108)) -Click {
    try {
        Optimize-NetworkGaming
        Append-Log "✓ Optimisations latence réseau gaming TCP/IP appliquées." "SUCCESS"
        [System.Windows.Forms.MessageBox]::Show(
            $script:I18N[$script:CurrentLang].BtnApplyGamingDone,
            "Réseau Gaming",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    } catch {
        Append-Log "Erreur optimisation réseau gaming : $_" "ERROR"
    }
} -BackColor $colors.SuccessColor -HoverColor $colors.SuccessHover -PressColor $colors.SuccessPress
$cardGamingNetwork.Controls.Add($btnApplyGamingNet)

$yPosNet += 175

# 3. Carte Réinitialisation Réseau
$cardResetNetwork = New-ModernCard -Title "Dépannage & Réinitialisation Réseau" -Location (New-Object System.Drawing.Point(12, $yPosNet)) -Size (New-Object System.Drawing.Size(890, 130)) -AccentLineColor $colors.WarningColor
$networkTab.Scroll.Controls.Add($cardResetNetwork)

$lblResetNetworkDesc = New-Object System.Windows.Forms.Label
$lblResetNetworkDesc.Text = "Vide le cache DNS et réinitialise Winsock et la pile TCP/IP pour réparer les erreurs de connexion."
$lblResetNetworkDesc.Location = New-Object System.Drawing.Point(20, 42)
$lblResetNetworkDesc.Size = New-Object System.Drawing.Size(850, 24)
$lblResetNetworkDesc.Font = $fonts.Normal
$lblResetNetworkDesc.ForeColor = $colors.MutedColor
$cardResetNetwork.Controls.Add($lblResetNetworkDesc)

$btnResetNetStack = New-ModernButton -Text "🧹 Vider le cache DNS & Réinitialiser Winsock / IP" -Size (New-Object System.Drawing.Size(340, 36)) -Location (New-Object System.Drawing.Point(20, 76)) -Click {
    try {
        Reset-NetworkStack
        Append-Log "✓ Cache DNS vidé et pile réseau Winsock/TCP-IP réinitialisée avec succès." "SUCCESS"
        [System.Windows.Forms.MessageBox]::Show(
            $script:I18N[$script:CurrentLang].BtnResetNetDone,
            "Réseau",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    } catch {
        Append-Log "Erreur réinitialisation réseau : $_" "ERROR"
    }
} -BackColor $colors.WarningColor -HoverColor $colors.WarningHover -PressColor $colors.WarningPress
$cardResetNetwork.Controls.Add($btnResetNetStack)

# ────────────────────────────────────────────────────────────────────────
# ONGLET 5 : DÉMARRAGE WINDOWS (STARTUP MANAGER)
# ────────────────────────────────────────────────────────────────────────
$startupTab = New-TabPage -Title "🚀 Démarrage"
$script:TabControl.TabPages.Add($startupTab.Page)

$yPosStart = 14

$cardStartupManager = New-ModernCard -Title "Gestionnaire des Applications au Démarrage de Windows" -Location (New-Object System.Drawing.Point(12, $yPosStart)) -Size (New-Object System.Drawing.Size(890, 520)) -AccentLineColor $colors.IndigoAccent
$startupTab.Scroll.Controls.Add($cardStartupManager)

$lblStartupDesc = New-Object System.Windows.Forms.Label
$lblStartupDesc.Text = "Désactivez les logiciels superflus au démarrage pour faire démarrer votre PC en quelques secondes."
$lblStartupDesc.Location = New-Object System.Drawing.Point(20, 42)
$lblStartupDesc.Size = New-Object System.Drawing.Size(850, 22)
$lblStartupDesc.Font = $fonts.Normal
$lblStartupDesc.ForeColor = $colors.MutedColor
$cardStartupManager.Controls.Add($lblStartupDesc)

$lvStartup = New-Object System.Windows.Forms.ListView
$lvStartup.Location = New-Object System.Drawing.Point(20, 72)
$lvStartup.Size = New-Object System.Drawing.Size(850, 380)
$lvStartup.View = [System.Windows.Forms.View]::Details
$lvStartup.FullRowSelect = $true
$lvStartup.GridLines = $true
$lvStartup.MultiSelect = $false
$lvStartup.Font = $fonts.Normal
$lvStartup.Columns.Add("Nom", 220) | Out-Null
$lvStartup.Columns.Add("Emplacement", 140) | Out-Null
$lvStartup.Columns.Add("Statut", 90) | Out-Null
$lvStartup.Columns.Add("Commande / Chemin", 390) | Out-Null
$cardStartupManager.Controls.Add($lvStartup)

function Update-StartupList {
    $lvStartup.Items.Clear()
    $items = Get-StartupPrograms
    foreach ($item in $items) {
        $lvi = New-Object System.Windows.Forms.ListViewItem($item.Name)
        $lvi.SubItems.Add($item.Location) | Out-Null
        $lvi.SubItems.Add($item.Status) | Out-Null
        $lvi.SubItems.Add($item.Command) | Out-Null
        $lvi.Tag = $item
        $lvStartup.Items.Add($lvi) | Out-Null
    }
}

$btnRefreshStartup = New-ModernButton -Text "🔄 Actualiser la liste" -Size (New-Object System.Drawing.Size(180, 36)) -Location (New-Object System.Drawing.Point(20, 465)) -Click {
    Update-StartupList
} -BackColor $colors.AccentColor -HoverColor $colors.AccentHover -PressColor $colors.AccentPress
$cardStartupManager.Controls.Add($btnRefreshStartup)

$btnDisableStartup = New-ModernButton -Text "🛑 Désactiver l'application sélectionnée" -Size (New-Object System.Drawing.Size(280, 36)) -Location (New-Object System.Drawing.Point(215, 465)) -Click {
    if ($lvStartup.SelectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Veuillez sélectionner une application dans la liste.",
            "Information",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }
    $selected = $lvStartup.SelectedItems[0].Tag
    if ($selected) {
        $res = Disable-StartupProgram -Name $selected.Name -Location $selected.Location
        if ($res) {
            Append-Log ($script:I18N[$script:CurrentLang].StartupDisabledDone -f $selected.Name) "SUCCESS"
            Update-StartupList
        }
    }
} -BackColor $colors.ErrorColor -HoverColor $colors.ErrorHover -PressColor $colors.ErrorPress
$cardStartupManager.Controls.Add($btnDisableStartup)

# ────────────────────────────────────────────────────────────────────────
# ONGLET 6 : CONFIDENTIALITÉ
# ────────────────────────────────────────────────────────────────────────
$privacyTab = New-TabPage -Title "🔒 Confidentialité"
$script:TabControl.TabPages.Add($privacyTab.Page)

$yPos = 14

# Registre Télémétrie
$cardPrivacyReg = New-ModernCard -Title "Registre Windows - Confidentialité & Données personnelles" -Location (New-Object System.Drawing.Point(12, $yPos)) -Size (New-Object System.Drawing.Size(890, 155)) -AccentLineColor $colors.AccentColor
$privacyTab.Scroll.Controls.Add($cardPrivacyReg)

$script:CbPrivacyReg = New-ModernCheckBox -Text "Appliquer les restrictions de confidentialité (Télémétrie=0, Publicités=OFF, Cortana=OFF)" -Location (New-Object System.Drawing.Point(20, 44)) -Checked $true
$cardPrivacyReg.Controls.Add($script:CbPrivacyReg)

$script:CbPrivacyBackup = New-ModernCheckBox -Text "Sauvegarder les clés avant toute modification (fichier .reg dans les sauvegardes)" -Location (New-Object System.Drawing.Point(40, 72)) -Checked $true
$cardPrivacyReg.Controls.Add($script:CbPrivacyBackup)

$lblPrivacyRegCount = New-Object System.Windows.Forms.Label
$lblPrivacyRegCount.Text = "$($script:PrivacyRegistrySettings.Count) paramètres de registre configurés"
$lblPrivacyRegCount.Font = $fonts.Small
$lblPrivacyRegCount.ForeColor = $colors.MutedColor
$lblPrivacyRegCount.Location = New-Object System.Drawing.Point(20, 110)
$lblPrivacyRegCount.AutoSize = $true
$cardPrivacyReg.Controls.Add($lblPrivacyRegCount)

$yPos += 170

# Stratégies GPO
$cardGPO = New-ModernCard -Title "Stratégies de groupe locales (GPO)" -Location (New-Object System.Drawing.Point(12, $yPos)) -Size (New-Object System.Drawing.Size(890, 120)) -AccentLineColor $colors.CyanAccent
$privacyTab.Scroll.Controls.Add($cardGPO)

$script:CbGPO = New-ModernCheckBox -Text "Renforcer les stratégies GPO anti-tracking (DataCollection, AppCompat, Search, Edge)" -Location (New-Object System.Drawing.Point(20, 44)) -Checked $true
$cardGPO.Controls.Add($script:CbGPO)

$lblGPOCount = New-Object System.Windows.Forms.Label
$lblGPOCount.Text = "13 stratégies de groupe renforcées"
$lblGPOCount.Font = $fonts.Small
$lblGPOCount.ForeColor = $colors.MutedColor
$lblGPOCount.Location = New-Object System.Drawing.Point(20, 78)
$lblGPOCount.AutoSize = $true
$cardGPO.Controls.Add($lblGPOCount)

$yPos += 135

# Fichier HOSTS
$cardHosts = New-ModernCard -Title "Fichier HOSTS - Filtrage des serveurs Microsoft" -Location (New-Object System.Drawing.Point(12, $yPos)) -Size (New-Object System.Drawing.Size(890, 120)) -AccentLineColor $colors.IndigoAccent
$privacyTab.Scroll.Controls.Add($cardHosts)

$script:CbHosts = New-ModernCheckBox -Text "Bloquer les serveurs de tracking Microsoft via le fichier hosts (0.0.0.0)" -Location (New-Object System.Drawing.Point(20, 44)) -Checked $true
$cardHosts.Controls.Add($script:CbHosts)

$script:CbHostsBackup = New-ModernCheckBox -Text "Sauvegarder le fichier hosts original avant modification" -Location (New-Object System.Drawing.Point(40, 72)) -Checked $true
$cardHosts.Controls.Add($script:CbHostsBackup)

$yPos += 135

# Pare-feu
$cardFirewall = New-ModernCard -Title "Pare-feu Windows - Règles de filtrage sortant" -Location (New-Object System.Drawing.Point(12, $yPos)) -Size (New-Object System.Drawing.Size(890, 100)) -AccentLineColor $colors.AccentColor
$privacyTab.Scroll.Controls.Add($cardFirewall)

$script:CbFirewall = New-ModernCheckBox -Text "Créer des règles pare-feu sortantes pour isoler les services espions (DiagTrack)" -Location (New-Object System.Drawing.Point(20, 44)) -Checked $true
$cardFirewall.Controls.Add($script:CbFirewall)

# ────────────────────────────────────────────────────────────────────────
# ONGLET 3 : NETTOYAGE
# ────────────────────────────────────────────────────────────────────────
$cleanupTab = New-TabPage -Title "🧹 Nettoyage"
$script:TabControl.TabPages.Add($cleanupTab.Page)

$yPos = 14

# Disque
$cardDisk = New-ModernCard -Title "Optimisation et Nettoyage de l'espace disque" -Location (New-Object System.Drawing.Point(12, $yPos)) -Size (New-Object System.Drawing.Size(890, 260)) -AccentLineColor $colors.AccentColor
$cleanupTab.Scroll.Controls.Add($cardDisk)

$script:CbDisk = New-ModernCheckBox -Text "Nettoyer les fichiers temporaires, caches système, journaux d'erreurs et prefetch" -Location (New-Object System.Drawing.Point(20, 44)) -Checked $true
$cardDisk.Controls.Add($script:CbDisk)

$script:CbDiskRecycle = New-ModernCheckBox -Text "Vider la corbeille de tous les disques locaux" -Location (New-Object System.Drawing.Point(40, 72)) -Checked $true
$cardDisk.Controls.Add($script:CbDiskRecycle)

$script:CbDiskWinUpdate = New-ModernCheckBox -Text "Nettoyer les anciens composants obsolètes Windows Update (DISM /StartComponentCleanup)" -Location (New-Object System.Drawing.Point(40, 98)) -Checked $true
$cardDisk.Controls.Add($script:CbDiskWinUpdate)

$lblDiskPaths = New-Object System.Windows.Forms.Label
$lblDiskPaths.Text = "Emplacements nettoyés : " + (($script:CleanupPaths | ForEach-Object { $_.Description }) -join "; ")
$lblDiskPaths.Font = $fonts.Small
$lblDiskPaths.ForeColor = $colors.MutedColor
$lblDiskPaths.Location = New-Object System.Drawing.Point(20, 130)
$lblDiskPaths.Size = New-Object System.Drawing.Size(850, 115)
$lblDiskPaths.AutoSize = $false
$cardDisk.Controls.Add($lblDiskPaths)

$yPos += 275

# Registre
$cardRegClean = New-ModernCard -Title "Nettoyage du Registre (Mode Sécurisé)" -Location (New-Object System.Drawing.Point(12, $yPos)) -Size (New-Object System.Drawing.Size(890, 160)) -AccentLineColor $colors.WarningColor
$cleanupTab.Scroll.Controls.Add($cardRegClean)

$script:CbRegClean = New-ModernCheckBox -Text "Activer la suppression des clés d'installation orphelines (Uninstall obsolètes)" -Location (New-Object System.Drawing.Point(20, 44)) -Checked $false
$cardRegClean.Controls.Add($script:CbRegClean)

$script:CbRegBackup = New-ModernCheckBox -Text "Sauvegarder les clés du registre avant suppression (.reg)" -Location (New-Object System.Drawing.Point(40, 72)) -Checked $true
$cardRegClean.Controls.Add($script:CbRegBackup)

$script:CbRegAggressive = New-ModernCheckBox -Text "Mode approfondi (extensions orphelines, CLSID invalides) - Recommandé aux utilisateurs avertis" -Location (New-Object System.Drawing.Point(40, 98)) -Checked $false
$cardRegClean.Controls.Add($script:CbRegAggressive)

$warnLabel = New-Object System.Windows.Forms.Label
$warnLabel.Text = "ℹ Nettoyage sécurisé : seules les clés orphelines orphelines vérifiées sans dépendances sont purgées."
$warnLabel.Font = $fonts.Small
$warnLabel.ForeColor = $colors.WarningColor
$warnLabel.Location = New-Object System.Drawing.Point(20, 128)
$warnLabel.AutoSize = $true
$cardRegClean.Controls.Add($warnLabel)

# ────────────────────────────────────────────────────────────────────────
# ONGLET 4 : MAINTENANCE
# ────────────────────────────────────────────────────────────────────────
$repairTab = New-TabPage -Title "🔧 Maintenance"
$script:TabControl.TabPages.Add($repairTab.Page)

$yPos = 14

$cardRepair = New-ModernCard -Title "Vérification et Restauration de l'intégrité système" -Location (New-Object System.Drawing.Point(12, $yPos)) -Size (New-Object System.Drawing.Size(890, 220)) -AccentLineColor $colors.AccentColor
$repairTab.Scroll.Controls.Add($cardRepair)

$script:CbDISM = New-ModernCheckBox -Text "DISM /RestoreHealth (Vérifie et répare l'image Windows via le magasin de composants)" -Location (New-Object System.Drawing.Point(20, 44)) -Checked $true
$cardRepair.Controls.Add($script:CbDISM)

$script:CbSFC = New-ModernCheckBox -Text "SFC /Scannow (Analyse et répare automatiquement les fichiers système protégés)" -Location (New-Object System.Drawing.Point(20, 72)) -Checked $true
$cardRepair.Controls.Add($script:CbSFC)

$script:CbChkdsk = New-ModernCheckBox -Text "Chkdsk /f /r (Planifie une vérification minutieuse des disques au prochain redémarrage)" -Location (New-Object System.Drawing.Point(20, 98)) -Checked $false
$cardRepair.Controls.Add($script:CbChkdsk)

$infoLabel = New-Object System.Windows.Forms.Label
$infoLabel.Text = "Ordre recommandé : DISM (3-8 min) → SFC (2-5 min) → Redémarrage système."
$infoLabel.Font = $fonts.Small
$infoLabel.ForeColor = $colors.MutedColor
$infoLabel.Location = New-Object System.Drawing.Point(20, 135)
$infoLabel.Size = New-Object System.Drawing.Size(850, 70)
$infoLabel.AutoSize = $false
$cardRepair.Controls.Add($infoLabel)

$yPos += 235

# Point de restauration
$cardRestore = New-ModernCard -Title "Point de Restauration Système" -Location (New-Object System.Drawing.Point(12, $yPos)) -Size (New-Object System.Drawing.Size(890, 110)) -AccentLineColor $colors.SuccessColor
$repairTab.Scroll.Controls.Add($cardRestore)

$script:CbRestorePoint = New-ModernCheckBox -Text "Créer un point de restauration système AVANT toute action (FORTEMENT RECOMMANDÉ)" -Location (New-Object System.Drawing.Point(20, 44)) -Checked $true
$cardRestore.Controls.Add($script:CbRestorePoint)

$infoRestore = New-Object System.Windows.Forms.Label
$infoRestore.Text = "Permet d'annuler tous les changements en un clic via 'REDADZDOptimiser_Restore.ps1' ou la Restauration Windows."
$infoRestore.Font = $fonts.Small
$infoRestore.ForeColor = $colors.MutedColor
$infoRestore.Location = New-Object System.Drawing.Point(20, 75)
$infoRestore.AutoSize = $true
$cardRestore.Controls.Add($infoRestore)

# ────────────────────────────────────────────────────────────────────────
# ONGLET 5 : JOURNAL (CONSOLE DÉVELOPPEUR)
# ────────────────────────────────────────────────────────────────────────
$logsTab = New-TabPage -Title "📋 Journal"
$script:TabControl.TabPages.Add($logsTab.Page)

$logPanel = New-Object System.Windows.Forms.Panel
$logPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$logPanel.BackColor = $colors.LogBackColor
$logPanel.Padding = New-Object System.Windows.Forms.Padding(12)
$logsTab.Page.Controls.Add($logPanel)

# Zone de texte monospace pour logs
$script:LogBox = New-Object System.Windows.Forms.RichTextBox
$script:LogBox.Dock = [System.Windows.Forms.DockStyle]::Fill
$script:LogBox.BackColor = $colors.LogBackColor
$script:LogBox.ForeColor = $colors.LogForeColor
$script:LogBox.Font = $fonts.Mono
$script:LogBox.ReadOnly = $true
$script:LogBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$script:LogBox.WordWrap = $true
$script:LogBox.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
$logPanel.Controls.Add($script:LogBox)

# Barre d'outils du journal
$logToolbar = New-Object System.Windows.Forms.FlowLayoutPanel
$logToolbar.Dock = [System.Windows.Forms.DockStyle]::Bottom
$logToolbar.Height = 46
$logToolbar.FlowDirection = [System.Windows.Forms.FlowDirection]::RightToLeft
$logToolbar.BackColor = $colors.HeaderBack
$logToolbar.Padding = New-Object System.Windows.Forms.Padding(12, 7, 12, 7)
$logsTab.Page.Controls.Add($logToolbar)

$logToolbar.Add_Paint({
    param($s, $e)
    $p = New-Object System.Drawing.Pen($script:colors.BorderColor, 1)
    $e.Graphics.DrawLine($p, 0, 0, $s.Width, 0)
    $p.Dispose()
})

$btnSaveLog = New-ModernButton -Text "💾 Exporter le journal" -Size (New-Object System.Drawing.Size(180, 32)) -Location (New-Object System.Drawing.Point(0,0)) -Click {
    $saveDlg = New-Object System.Windows.Forms.SaveFileDialog
    $saveDlg.Filter = "Fichier texte (*.txt)|*.txt|Tous fichiers (*.*)|*.*"
    $saveDlg.FileName = "REDADZDOptimiser_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    if ($saveDlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:LogBox.SaveFile($saveDlg.FileName, [System.Windows.Forms.RichTextBoxStreamType]::PlainText)
        Append-Log "Journal exporté avec succès : $($saveDlg.FileName)" "SUCCESS"
    }
} -BackColor $colors.CardBack -HoverColor $colors.AccentColor -PressColor $colors.AccentPress -ForeColor $colors.ForeColor

$btnSaveLog.Add_Paint({
    param($s, $e)
    $p = New-Object System.Drawing.Pen($script:colors.BorderColor, 1)
    $e.Graphics.DrawRectangle($p, 0, 0, $s.Width - 1, $s.Height - 1)
    $p.Dispose()
})

$btnClearLog = New-ModernButton -Text "🗑 Effacer le journal" -Size (New-Object System.Drawing.Size(170, 32)) -Location (New-Object System.Drawing.Point(0,0)) -Click {
    $script:LogBox.Clear()
    $script:LogLines = @()
} -BackColor $colors.CardBack -HoverColor $colors.ErrorColor -PressColor $colors.ErrorPress -ForeColor $colors.ForeColor

$btnClearLog.Add_Paint({
    param($s, $e)
    $p = New-Object System.Drawing.Pen($script:colors.BorderColor, 1)
    $e.Graphics.DrawRectangle($p, 0, 0, $s.Width - 1, $s.Height - 1)
    $p.Dispose()
})

$logToolbar.Controls.Add($btnSaveLog)
$logToolbar.Controls.Add($btnClearLog)

# ════════════════════════════════════════════════════════════════════════
# 3. BARRE BASSE D'ACTION (BOUTONS PRINCIPAUX + PROGRESSION)
# ════════════════════════════════════════════════════════════════════════

$bottomPanel = New-Object System.Windows.Forms.Panel
$bottomPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$bottomPanel.BackColor = $colors.BottomBack
$bottomPanel.Padding = New-Object System.Windows.Forms.Padding(24, 6, 24, 8)
$mainLayout.Controls.Add($bottomPanel, 0, 3)

# Ligne supérieure de séparation
$bottomPanel.Add_Paint({
    param($s, $e)
    $pen = New-Object System.Drawing.Pen($script:colors.BorderColor, 1)
    $e.Graphics.DrawLine($pen, 0, 0, $s.Width, 0)
    $pen.Dispose()
})

# Barre de progression moderne fluide
$script:ProgressBar = New-Object System.Windows.Forms.ProgressBar
$script:ProgressBar.Dock = [System.Windows.Forms.DockStyle]::Top
$script:ProgressBar.Height = 5
$script:ProgressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Blocks
$script:ProgressBar.ForeColor = $colors.AccentColor
$script:ProgressBar.BackColor = $colors.BorderColor
$bottomPanel.Controls.Add($script:ProgressBar)

# Ligne inférieure contenant le Copyright à gauche et les Boutons à droite
$actionRow = New-Object System.Windows.Forms.Panel
$actionRow.Dock = [System.Windows.Forms.DockStyle]::Fill
$actionRow.BackColor = $colors.Transparent
$bottomPanel.Controls.Add($actionRow)

# Copyright & Auteur (Anagou Reda 0542439514)
$copyrightLabel = New-Object System.Windows.Forms.Label
$copyrightLabel.Text = "© 2026 REDADZDOptimiser • Anagou Reda  |  Tél : 0542439514"
$copyrightLabel.Font = $fonts.Small
$copyrightLabel.ForeColor = $colors.MutedColor
$copyrightLabel.Location = New-Object System.Drawing.Point(0, 16)
$copyrightLabel.AutoSize = $true
$actionRow.Controls.Add($copyrightLabel)

# Conteneur des boutons d'action (Alignés à droite)
$btnFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$btnFlow.Dock = [System.Windows.Forms.DockStyle]::Right
$btnFlow.Width = 570
$btnFlow.Height = 44
$btnFlow.FlowDirection = [System.Windows.Forms.FlowDirection]::RightToLeft
$btnFlow.BackColor = $colors.Transparent
$actionRow.Controls.Add($btnFlow)

# Bouton ANNULER (Rouge Corail)
$script:BtnCancel = New-ModernButton -Text "✕ Annuler" -Size (New-Object System.Drawing.Size(130, 38)) -Location (New-Object System.Drawing.Point(0,0)) -Click {
    $script:CancelToken = $true
    Set-REDADZDOptimiserConfig -CancelRequested $true
    Append-Log ($script:I18N[$script:CurrentLang].CancelPrompt) "WARN"
} -BackColor $colors.ErrorColor -HoverColor $colors.ErrorHover -PressColor $colors.ErrorPress
$script:BtnCancel.Enabled = $false
$btnFlow.Controls.Add($script:BtnCancel)

# Bouton SIMULATION DRY-RUN (Ambre Chaleureux)
$script:BtnDryRun = New-ModernButton -Text "🔍 Simulation (Dry-Run)" -Size (New-Object System.Drawing.Size(200, 38)) -Location (New-Object System.Drawing.Point(0,0)) -Click {
    Start-Optimization -DryRun $true
} -BackColor $colors.WarningColor -HoverColor $colors.WarningHover -PressColor $colors.WarningPress
$btnFlow.Controls.Add($script:BtnDryRun)

# Bouton OPTIMISER MAINTENANT (Vert Émeraude Pro)
$script:BtnRun = New-ModernButton -Text "▶ OPTIMISER MAINTENANT" -Size (New-Object System.Drawing.Size(215, 38)) -Location (New-Object System.Drawing.Point(0,0)) -Click {
    Start-Optimization -DryRun $false
} -BackColor $colors.SuccessColor -HoverColor $colors.SuccessHover -PressColor $colors.SuccessPress
$btnFlow.Controls.Add($script:BtnRun)

# ════════════════════════════════════════════════════════════════════════
# LOGIQUE D'EXÉCUTION
# ════════════════════════════════════════════════════════════════════════

function Set-RunningState {
    param([bool]$Running)
    $script:IsRunning = $Running
    $strings = $script:I18N[$script:CurrentLang]

    $script:BtnRun.Enabled = -not $Running
    $script:BtnDryRun.Enabled = -not $Running
    $script:BtnCancel.Enabled = $Running

    $script:BtnRun.Text = if ($Running) { $strings.BtnRunning } else { $strings.BtnRun }

    if ($Running) {
        $script:ProgressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Marquee
        $script:ProgressBar.MarqueeAnimationSpeed = 30
    } else {
        $script:ProgressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Blocks
        $script:ProgressBar.Value = 0
    }
}

function Start-Optimization {
    param([bool]$DryRun = $false)

    if (-not $isAdmin) {
        [System.Windows.Forms.MessageBox]::Show(
            $script:I18N[$script:CurrentLang].AdminMsgBox,
            "Erreur",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return
    }

    if ($script:IsRunning) { return }
    $script:CancelToken = $false
    Set-REDADZDOptimiserConfig -CancelRequested $false

    # Basculer sur l'onglet Logs
    $script:TabControl.SelectedTab = $logsTab.Page

    Set-RunningState -Running $true

    $modeText = if ($DryRun) { "SIMULATION (Dry-Run)" } else { "OPTIMISATION RÉELLE" }
    Append-Log "==================================================" "INFO"
    Append-Log "  DÉMARRAGE DE L'EXÉCUTION : $modeText" "INFO"
    Append-Log "  Langue active : $($script:CurrentLang)" "INFO"
    Append-Log "==================================================" "INFO"

    $params = @{
        Language          = $script:CurrentLang
        DryRun            = $DryRun
        SkipRestorePoint  = (-not $script:CbRestorePoint.Checked)
        SkipApps          = (-not $script:CbApps.Checked)
        SkipServices      = (-not $script:CbServices.Checked)
        SkipTasks         = (-not $script:CbTasks.Checked)
        SkipPrivacy       = (-not ($script:CbPrivacyReg.Checked -or $script:CbGPO.Checked -or $script:CbHosts.Checked -or $script:CbFirewall.Checked))
        SkipCleanup       = (-not ($script:CbDisk.Checked -or $script:CbRegClean.Checked))
        SkipRepair        = (-not ($script:CbDISM.Checked -or $script:CbSFC.Checked -or $script:CbChkdsk.Checked))
        OptimizeRAM       = $true
        StopBloatProcesses = ($script:CbAutoKillOnOptimize -and $script:CbAutoKillOnOptimize.Checked)
        OptimizeCPU       = ($script:CbPowerPlan.Checked -or $script:CbForegroundPriority.Checked -or $script:CbDisableCoreParking.Checked)
    }

    Set-REDADZDOptimiserConfig -BackupRegistry ($script:CbPrivacyBackup.Checked -or $script:CbHostsBackup.Checked -or $script:CbRegBackup.Checked)

    try {
        [System.Windows.Forms.Application]::DoEvents()
        $results = Invoke-REDADZDOptimiser @params

        Append-Log "=== RÉSUMÉ DE L'OPÉRATION ===" "INFO"
        if ($results.Apps) { Append-Log "Apps : $($results.Apps.Removed) supprimées, $($results.Apps.Failed) échecs, $($results.Apps.Skipped) ignorées" "SUCCESS" }
        if ($results.Services) { Append-Log "Services : $($results.Services.Changed) modifiés, $($results.Services.Failed) échecs" "SUCCESS" }
        if ($results.Tasks) { Append-Log "Tâches : $($results.Tasks.Disabled) désactivées, $($results.Tasks.Failed) échecs" "SUCCESS" }
        if ($results.PrivacyRegistry) { Append-Log "Registre : $($results.PrivacyRegistry.Applied) clés appliquées, $($results.PrivacyRegistry.Failed) échecs" "SUCCESS" }
        if ($results.DiskCleanup) { Append-Log "Disque : ~$($results.DiskCleanup.FreedMB) MB libérés" "SUCCESS" }
        if ($results.RegistryCleanup) { Append-Log "Registre nettoyé : $($results.RegistryCleanup.Cleaned) clés orphelines" "SUCCESS" }
        if ($results.SystemRepair) { Append-Log "DISM : $($results.SystemRepair.DISM) | SFC : $($results.SystemRepair.SFC) | Chkdsk : $($results.SystemRepair.Chkdsk)" "SUCCESS" }
        if ($results.RestorePoint) { Append-Log "Point de restauration : CRÉÉ ✓" "SUCCESS" }
        if ($results.CPU) { Append-Log "CPU : Plan=$($results.CPU.PowerPlan) | Priorité=$($results.CPU.PrioritySeparation)" "SUCCESS" }
        if ($results.Processes) { Append-Log "Processus fermés : $($results.Processes.TerminatedCount) processus" "SUCCESS" }
        if ($results.RAM) { Append-Log "RAM libérée : ~$($results.RAM.FreedMB) Mo" "SUCCESS" }

        Append-Log "" "INFO"
        Append-Log "✅ OPÉRATION TERMINÉE AVEC SUCCÈS - Redémarrage recommandé" "SUCCESS"
    } catch {
        Append-Log "ERREUR FATALE LORS DE L'EXÉCUTION : $_" "ERROR"
    } finally {
        Set-RunningState -Running $false
    }
}

# ════════════════════════════════════════════════════════════════════════
# GESTION DE LA FERMETURE DE FENÊTRE
# ════════════════════════════════════════════════════════════════════════

$form.Add_FormClosing({
    if ($script:PerfTimer) {
        $script:PerfTimer.Stop()
        $script:PerfTimer.Dispose()
    }
    if ($script:IsRunning) {
        $result = [System.Windows.Forms.MessageBox]::Show(
            $script:I18N[$script:CurrentLang].ClosingConfirm,
            "Confirmation",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($result -eq [System.Windows.Forms.DialogResult]::No) {
            $_.Cancel = $true
        }
    }
})

# ════════════════════════════════════════════════════════════════════════
# INITIALISATION DE LA LANGUE & DÉMARRAGE
# ════════════════════════════════════════════════════════════════════════

$targetLang = if ($Language -and $Language.Trim() -ne "") {
    $Language.ToUpper()
} else {
    Show-LanguageDialog
}

Apply-Language -Lang $targetLang

$form.Add_Shown({
    $form.Activate()
    $form.Focus()

    # Démarrage de la surveillance en temps réel
    if ($script:PerfTimer) {
        $script:PerfTimer.Start()
        # Première lecture immédiate
        try {
            $m = Get-SystemPerformanceMetrics
            if ($m) {
                $ramPct = [int]$m.RamPercent
                if ($pbRam) { $pbRam.Value = [math]::Min(100, [math]::Max(0, $ramPct)) }
                if ($lblRamMetric) {
                    $lblRamMetric.Text = ($script:I18N[$script:CurrentLang].PerfRamFormat -f $m.UsedRamGB, $m.TotalRamGB, $ramPct)
                }
                $cpuVal = [math]::Round([double]$m.CpuPercent, 1)
                $cpuInt = [int][math]::Min(100, [math]::Max(0, [math]::Round($cpuVal)))
                if ($pbCpu) { $pbCpu.Value = $cpuInt }
                if ($lblCpuMetric) {
                    $lblCpuMetric.Text = ($script:I18N[$script:CurrentLang].PerfCpuFormat -f $cpuVal, $m.ProcessCount)
                }
            }
        } catch {}
    }

    # Application du préréglage Standard par défaut
    Apply-Preset -Preset "Standard"

    # Chargement initial des programmes de démarrage
    try { Update-StartupList } catch {}

    Append-Log "⚡ REDADZDOptimiser Professional ($($script:CurrentLang)) initialisé" "INFO"
    Append-Log "Système : Windows $($winVer.Major).$($winVer.Minor) Build $($winVer.Build)" "INFO"
    Append-Log "Privilèges administrateur : $isAdmin" "INFO"
    Append-Log ($script:I18N[$script:CurrentLang].ReadyLog) "INFO"

    if ($script:LogLines -and $script:LogBox) {
        foreach ($line in $script:LogLines) {
            $script:LogBox.AppendText($line + "`r`n")
        }
        $script:LogBox.ScrollToCaret()
    }
})

[void]$form.ShowDialog()
