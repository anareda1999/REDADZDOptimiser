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

# ─── Chargement du module core (si non déjà chargé en mémoire) ────────
if (-not (Get-Command 'Invoke-REDADZDOptimiser' -ErrorAction SilentlyContinue)) {
    if (-not $PSScriptRoot) {
        $PSScriptRoot = if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
    }
    $script:ModulePath = Join-Path $PSScriptRoot "REDADZDOptimiserCore.psm1"

    if (Test-Path $script:ModulePath) {
        Import-Module $script:ModulePath -Force
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "Fichier REDADZDOptimiserCore.psm1 introuvable dans:`n$PSScriptRoot",
            "Erreur fatale",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        exit 1
    }
}

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

        TabDiag             = "🩺 Diagnostic & Santé"
        TitleDiag           = "Diagnostic Matériel & Recommandation d'Optimisation"
        DescDiag            = "Analyse approfondie de la santé des composants (RAM, Disque, CPU, Batterie) et sélection automatique du profil idéal."
        TabDebloat          = "🗑️ Débloat"
        TabPerf             = "⚡ Performance"
        TabSoftware         = "📦 Logiciels"
        TabNetwork          = "🌐 Réseau & DNS"
        TabStartup          = "🚀 Démarrage"
        TabPrivacy          = "🔒 Vie Privée"
        TabCleanup          = "🧹 Nettoyage"
        TabRepair           = "🔧 Maintenance"
        TabLogs             = "📋 Journal"
        TabAbout            = "⚙️ À propos & Support"

        # Titres & Eyebrows Header Style Kudu
        EyebrowCommon       = "ⓘ ESPACE DE TRAVAIL  •  REDADZDOptimiser"
        TitleDebloat        = "Suppression des Bloatwares"
        DescDebloat         = "Supprimez les applications préinstallées inutiles et désactivez la télémétrie Windows."
        TitlePerf           = "Optimisation des Performances & RAM"
        DescPerf            = "Surveillez les ressources en direct, videz le cache mémoire et tuez les processus inutiles."
        TitleSoftware       = "Installation Rapide de Logiciels"
        DescSoftware        = "Installez vos navigateurs, outils système, streaming et bureautique en un seul clic via Winget."
        TitleNetwork        = "Optimiseur Réseau & DNS Gaming"
        DescNetwork         = "Basculez vers les serveurs DNS les plus rapides et réduisez la latence paquets (Ping TCP/IP)."
        TitleStartup        = "Gestionnaire des Applications au Démarrage"
        DescStartup         = "Cochez les applications superflues au démarrage pour les désactiver ou réactivez celles requises."
        TitlePrivacy        = "Confidentialité & Sécurité Windows"
        DescPrivacy         = "Bloquez la collecte de données, le pistage publicitaire, les requêtes Cortana et les serveurs Microsoft."
        TitleCleanup        = "Nettoyage du Disque & Registre"
        DescCleanup         = "Libérez de l'espace de stockage en nettoyant les fichiers temporaires, la corbeille et le registre."
        TitleRepair         = "Maintenance & Restauration Système"
        DescRepair          = "Vérifiez et réparez les fichiers système protégés avec les outils officiels DISM et SFC."
        TitleLogs           = "Journal d'Exécution en Direct"
        DescLogs            = "Suivez chaque étape d'optimisation en temps réel avec coloration syntaxique et export."
        TitleAbout          = "À propos de REDADZDOptimiser"
        DescAbout           = "Centre d'optimisation Windows 10/11, conçu avec soin. Vérifiez l'état du système et rencontrez l'auteur."

        # Carte About & Support
        AboutAppTitle       = "REDADZDOptimiser v2.0 Professional"
        AboutAppSub         = "Licence Open Source & Protection  •  Développé par Anagou Reda"
        AboutStatusReady    = "✓ Votre système Windows est prêt et optimisable"
        BtnCheckState       = "🔄 Vérifier l'état système"
        BtnGithub           = "🌐 Dépôt GitHub ↗"
        BtnRestoreSec       = "🛡️ Point de Restauration"
        AboutSupportTitle   = "Support & Auteur : Anagou Reda"
        AboutSupportDesc    = "Besoin d'une assistance technique, d'un tweak sur-mesure ou d'une maintenance professionnelle ? Contactez le créateur."
        BtnCallAuthor       = "📞 Tél : 0542439514"
        AboutSpecsTitle     = "Spécifications du Système Windows Détecté"

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
        LblStartupDesc      = "Cochez les applications superflues au démarrage pour les désactiver ou réactivez celles dont vous avez besoin."
        BtnCheckAllStartup  = "☑️ Tout cocher"
        BtnUncheckAllStartup= "⬜ Tout décocher"
        BtnDisableStartup   = "🛑 Désactiver cochés"
        BtnEnableStartup    = "✅ Réactiver cochés"
        BtnRefreshStartup   = "🔄 Actualiser"
        ColStartupName      = "Nom"
        ColStartupLocation  = "Emplacement"
        ColStartupStatus    = "Statut"
        ColStartupCommand   = "Commande / Chemin"
        StartupDisabledDone = "✓ {0} application(s) désactivée(s) au démarrage."
        StartupEnabledDone  = "✓ {0} application(s) réactivée(s) au démarrage."
        StartupNoSelection  = "Veuillez cocher au moins une application dans la liste."

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

        TabDiag             = "🩺 Diagnostics & Health"
        TitleDiag           = "Hardware Diagnostics & Optimization Recommendation"
        DescDiag            = "Deep component health analysis (RAM, Disk, CPU, Battery) and automatic recommendation of the ideal profile."
        TabDebloat          = "🗑️ Debloat"
        TabPerf             = "⚡ Performance"
        TabSoftware         = "📦 Software"
        TabNetwork          = "🌐 Network & DNS"
        TabStartup          = "🚀 Startup"
        TabPrivacy          = "🔒 Privacy"
        TabCleanup          = "🧹 Cleanup"
        TabRepair           = "🔧 Maintenance"
        TabLogs             = "📋 Logs"
        TabAbout            = "⚙️ About & Support"

        # Headers & Eyebrows Kudu Style
        EyebrowCommon       = "ⓘ YOUR WORKSPACE  •  REDADZDOptimiser"
        TitleDebloat        = "Bloatware Removal"
        DescDebloat         = "Remove non-essential preinstalled apps and disable background telemetry services."
        TitlePerf           = "Performance & RAM Optimization"
        DescPerf            = "Monitor live resources, clear RAM cache, and terminate unwanted background processes."
        TitleSoftware       = "Essential Software Installer"
        DescSoftware        = "Batch install web browsers, utilities, gaming, and productivity tools with one click via Winget."
        TitleNetwork        = "Network & Gaming DNS Optimizer"
        DescNetwork         = "Switch to lightning-fast DNS providers and reduce online gaming packet latency."
        TitleStartup        = "Startup Applications Manager"
        DescStartup         = "Check non-essential startup apps to disable them, or re-enable apps you need."
        TitlePrivacy        = "Windows Privacy & Security"
        DescPrivacy         = "Block diagnostic data collection, advertising tracking, Cortana searches, and telemetry hosts."
        TitleCleanup        = "Disk Storage & Cache Cleanup"
        DescCleanup         = "Free up valuable storage space by cleaning temporary files, recycle bin, and obsolete registry keys."
        TitleRepair         = "System Maintenance & Component Repair"
        DescRepair          = "Analyze and restore corrupt Windows image components with official DISM and SFC tools."
        TitleLogs           = "Execution Live Log"
        DescLogs            = "Track every optimization action live with syntax highlighting and exportable log files."
        TitleAbout          = "About REDADZDOptimiser"
        DescAbout           = "Windows 10/11 optimization center, thoughtfully made. Check your system health and meet the author."

        # About & Support Cards
        AboutAppTitle       = "REDADZDOptimiser v2.0 Professional"
        AboutAppSub         = "Open Source License & Protected  •  Developed by Anagou Reda"
        AboutStatusReady    = "✓ Your Windows system is ready for optimization"
        BtnCheckState       = "🔄 Check System State"
        BtnGithub           = "🌐 GitHub Repository ↗"
        BtnRestoreSec       = "🛡️ System Restore Point"
        AboutSupportTitle   = "Support & Creator : Anagou Reda"
        AboutSupportDesc    = "Need technical assistance, custom tweaks, or IT maintenance for your PC or organization? Contact the creator directly."
        BtnCallAuthor       = "📞 Phone: 0542439514"
        AboutSpecsTitle     = "Detected Windows System Specifications"

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
        LblStartupDesc      = "Check non-essential startup apps to disable them, or re-enable apps you need."
        BtnCheckAllStartup  = "☑️ Select All"
        BtnUncheckAllStartup= "⬜ Deselect All"
        BtnDisableStartup   = "🛑 Disable Checked"
        BtnEnableStartup    = "✅ Enable Checked"
        BtnRefreshStartup   = "🔄 Refresh"
        ColStartupName      = "Name"
        ColStartupLocation  = "Location"
        ColStartupStatus    = "Status"
        ColStartupCommand   = "Command / Path"
        StartupDisabledDone = "✓ {0} application(s) disabled from startup."
        StartupEnabledDone  = "✓ {0} application(s) re-enabled at startup."
        StartupNoSelection  = "Please check at least one application in the list."

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
        TabAbout            = "⚙️ حول البرنامج والدعم"

        # العناوين ونمط Kudu
        EyebrowCommon       = "ⓘ مساحة العمل  •  REDADZDOptimiser"
        TitleDebloat        = "حذف التطبيقات الزائدة"
        DescDebloat         = "تخلص من التطبيقات المثبتة مسبقاً وعطل خدمات التتبع الخاملة."
        TitlePerf           = "تحسين أداء النظام والذاكرة"
        DescPerf            = "راقب استهلاك الموارد المباشر، فرغ كاش الذاكرة وأغلق العمليات الزائدة."
        TitleSoftware       = "تثبيت البرامج الأساسية"
        DescSoftware        = "ثبت المتصفحات والأدوات المساعدة وبرامج الألعاب والمكتب بضغطة واحدة عبر Winget."
        TitleNetwork        = "تحسين الشبكة و DNS للألعاب"
        DescNetwork         = "اختر أسرع خوادم DNS وقلل زمن استجابة حزم البيانات في الألعاب (Ping)."
        TitleStartup        = "إدارة برامج بدء التشغيل"
        DescStartup         = "حدد البرامج غير الضرورية لتعطيلها أو أعد تفعيل ما تحتاجه لتسريع الإقلاع."
        TitlePrivacy        = "الخصوصية وأمان ويندوز"
        DescPrivacy         = "احظر جمع البيانات التشخيصية والإعلانات الموجهة وخوادم التتبع لـ Microsoft."
        TitleCleanup        = "تنظيف القرص وسجل النظام"
        DescCleanup         = "وفر مساحة تخزين كبيرة عبر مسح الملفات المؤقتة وسلة المحذوفات ومفاتيح السجل المعزولة."
        TitleRepair         = "صيانة وإصلاح صورة ويندوز"
        DescRepair          = "افحص وأصلح ملفات النظام المحمية والتالفة باستخدام أدوات DISM و SFC الرسمية."
        TitleLogs           = "سجل التنفيذ الحي"
        DescLogs            = "تابع كل خطوات التحسين خطوة بخطوة في الوقت الفعلي مع إمكانية تصدير التقرير."
        TitleAbout          = "حول برنامج REDADZDOptimiser"
        DescAbout           = "مركز تحسين ويندوز 10/11، صُمم بعناية فائقة. تحقق من حالة نظامك وتواصل مع المطور."

        # بطاقات حول البرنامج والدعم
        AboutAppTitle       = "REDADZDOptimiser v2.0 Professional"
        AboutAppSub         = "ترخيص مفتوح المصدر وحماية برمجية  •  تطوير Anagou Reda"
        AboutStatusReady    = "✓ نظام ويندوز جاهز ومؤهل للتحسين الكامل"
        BtnCheckState       = "🔄 فحص حالة النظام"
        BtnGithub           = "🌐 مستودع GitHub ↗"
        BtnRestoreSec       = "🛡️ نقطة استعادة النظام"
        AboutSupportTitle   = "الدعم والمطور : Anagou Reda"
        AboutSupportDesc    = "هل تحتاج إلى مساعدة تقنية، تحسينات مخصصة لأجهزتك أو صيانة شاملة؟ تواصل مباشرة مع المطور."
        BtnCallAuthor       = "📞 هاتف : 0542439514"
        AboutSpecsTitle     = "مواصفات نظام ويندوز المكتشفة"

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

        # تبويب البرامج (Winget)
        GbBrowsers          = "متصفحات الويب"
        GbUtilities         = "الأدوات المساعدة وإدارة الملفات"
        GbGamingApps        = "الألعاب والبث"
        GbDevOffice         = "المكتب والتطوير"
        BtnSelectAllApps    = "✓ تحديد الكل"
        BtnDeselectAllApps  = "✕ إلغاء تحديد الكل"
        BtnInstallApps      = "🚀 تثبيت التطبيقات المحددة (Winget)"
        BtnInstallingApps   = "⏳ جارٍ التثبيت..."
        InstallAppsDone     = "✓ اكتمل التثبيت : تم تثبيت {0}، فشل {1}."

        # تبويب الشبكة و DNS
        GbDnsSelector       = "اختيار خادم DNS سريع وآمن"
        OptDnsCloudflare    = "⚡ Cloudflare (1.1.1.1 / 1.0.0.1 - سرعة قصوى للألعاب)"
        OptDnsGoogle        = "🔒 Google DNS (8.8.8.8 / 8.8.4.4 - توافق عالي)"
        OptDnsQuad9         = "🛡️ Quad9 (9.9.9.9 - حماية متقدمة ضد البرمجيات الخبيثة)"
        OptDnsDhcp          = "🔄 تلقائي / مزود الخدمة (DHCP الافتراضي)"
        BtnApplyDns         = "⚡ تطبيق خادم DNS المختار"
        BtnApplyDnsDone     = "✓ تم تطبيق DNS بنجاح!"
        GbGamingNetwork     = "تحسين استجابة الشبكة للألعاب (Ping TCP/IP)"
        CbNetThrottling     = "تعطيل خنق سرعة الشبكة للوسائط المتعددة (NetworkThrottlingIndex)"
        CbNagleAlgo         = "تعطيل خوارزمية Nagle لتسريع وصول الحزم (TcpAckFrequency = 1)"
        BtnApplyGamingNet   = "🚀 تطبيق تحسينات الشبكة للألعاب"
        BtnApplyGamingDone  = "✓ تم تطبيق تسريع TCP/IP للألعاب!"
        GbResetNetwork      = "إصلاح وإعادة ضبط إعدادات الشبكة"
        LblResetNetworkDesc = "يقوم بمسح كاش DNS وإعادة تهيئة Winsock و TCP/IP لحل مشاكل الاتصال."
        BtnResetNetStack    = "🧹 مسح كاش DNS وإعادة تعيين Winsock / IP"
        BtnResetNetDone     = "✓ تمت إعادة ضبط الشبكة ومسح الكاش بنجاح!"

        # تبويب إدارة الإقلاع (Startup Manager)
        GbStartupManager    = "إدارة تطبيقات بدء التشغيل (الإقلاع)"
        LblStartupDesc      = "حدد البرامج غير الضرورية لتعطيلها، أو أعد تفعيل البرامج التي تحتاجها لتسريع الإقلاع."
        BtnCheckAllStartup  = "☑️ تحديد الكل"
        BtnUncheckAllStartup= "⬜ إلغاء التحديد"
        BtnDisableStartup   = "🛑 تعطيل المحدد"
        BtnEnableStartup    = "✅ تفعيل المحدد"
        BtnRefreshStartup   = "🔄 تحديث"
        ColStartupName      = "الاسم"
        ColStartupLocation  = "الموقع"
        ColStartupStatus    = "الحالة"
        ColStartupCommand   = "الأمر / المسار"
        StartupDisabledDone = "✓ تم تعطيل {0} تطبيق(تطبيقات) عند بدء التشغيل."
        StartupEnabledDone  = "✓ تم تفعيل {0} تطبيق(تطبيقات) عند بدء التشغيل."
        StartupNoSelection  = "يرجى تحديد تطبيق واحد على الأقل في القائمة."

        # تبويب الأداء (Performance)
        GbPerfMonitor       = "مراقبة موارد النظام المباشرة"
        PerfRamFormat       = "استهلاك الذاكرة (RAM) : {0} جيجابايت / {1} جيجابايت ({2} %)"
        BtnFlushRam         = "🚀 تفريغ الذاكرة المؤقتة (RAM)"
        BtnFlushRamDone     = "✓ تم تفريغ كاش الذاكرة : تم تحرير ~{0} ميجابايت!"
        PerfCpuFormat       = "استهلاك المعالج (CPU) : {0} %  •  {1} عملية نشطة"
        PerfLiveNotice      = "● مراقبة حية مستمرة • 1.5 ثانية"
        PerfRamTip          = "فائدة : تنظيف الذاكرة يفرغ بأمان الكاش الخامل في الخلفية دون إغلاق أي من برامجك."
        GbPerfKill          = "إغلاق العمليات غير الضرورية في الخلفية"
        PerfKillInfo        = "إغلاق فوري للعمليات الخلفية المستهلكة للموارد (Phone Link، Game Bar، شريط الأخبار والودجات، تتبع Microsoft) مع الحماية الكاملة لعمليات النظام الأساسية."
        PerfKillTargets     = "العمليات المستهدفة: PhoneExperienceHost, GameBarPresenceWriter, Widgets, Cortana, NewsAndInterests, FeedbackHub, Edge (idle)"
        BtnKillProcesses    = "🛑 إنهاء العمليات غير الضرورية"
        BtnKillProcessesDone= "✓ تم إنهاء {0} عملية غير ضرورية في الخلفية بنجاح !"
        CbAutoKillOnOptimize= "تضمين إغلاق العمليات غير الضرورية تلقائياً أثناء التحسين الشامل"
        GbPerfCpu           = "تحسينات المعالج (CPU) وخطط الطاقة"
        CbPowerPlan         = "تفعيل خطة الطاقة 'الأداء العالي' / 'الأداء الأقصى' (High / Ultimate Performance)"
        SubPowerPlan        = "إلغاء قيود توفير الطاقة وإطلاق التردد الأقصى للمعالج باستمرار."
        CbForegroundPriority= "منح الأولوية القصوى لمعالجة النوافذ النشطة (Win32PrioritySeparation = 0x26)"
        SubForegroundPriority= "تخصيص 3 أضعاف موارد المعالج للعبة أو البرنامج المفتوح حالياً لضمان سرعة واستجابة فورية."
        CbDisableCoreParking= "تعطيل ركن الأنوية (Core Parking) لتشغيل كافة أنوية وخيوط المعالج بكفاءة 100%"
        BtnApplyCpu         = "⚡ تطبيق إعدادات المعالج والطاقة"
        BtnApplyCpuDone     = "✓ تم تطبيق إعدادات المعالج والطاقة بنجاح !"

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
    # Palette Modern Kudu / Slate Fluent
    SidebarBack     = [System.Drawing.Color]::FromArgb(248, 250, 252)      # #F8FAFC
    NavActiveBack   = [System.Drawing.Color]::FromArgb(254, 243, 199)      # #FEF3C7 (Ambre Chaud Kudu)
    NavActiveBar    = [System.Drawing.Color]::FromArgb(245, 158, 11)       # #F59E0B (Indicateur vertical ambre)
    NavActiveFore   = [System.Drawing.Color]::FromArgb(217, 119, 6)        # #D97706
    NavHoverBack    = [System.Drawing.Color]::FromArgb(241, 245, 249)      # #F1F5F9
    NavMutedFore    = [System.Drawing.Color]::FromArgb(100, 116, 139)      # #64748B
    WarmCardBack    = [System.Drawing.Color]::FromArgb(255, 251, 235)      # #FFFBEB (Carte Support Kudu)
    WarmCardBorder  = [System.Drawing.Color]::FromArgb(253, 230, 138)      # #FDE68A
    WarmCardTitle   = [System.Drawing.Color]::FromArgb(120, 53, 15)        # #78350F
    WarmCardDesc    = [System.Drawing.Color]::FromArgb(146, 64, 14)        # #92400E
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
    HeroTitle   = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
    Eyebrow     = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Bold)
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
            # 7. Maintenance (SFC scannow local rapide, DISM réservé au profil Max)
            if ($script:CbDISM)               { $script:CbDISM.Checked = $false }
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


# ─── Mise à jour dynamique du Header supérieur Kudu ────────────────────
function Update-HeaderForActivePage {
    if (-not $script:lblPageTitle -or -not $script:I18N) { return }
    $strings = $script:I18N[$script:CurrentLang]
    $idx = $script:ActiveNavIndex

    if ($script:lblEyebrow) {
        $script:lblEyebrow.Text = $strings.EyebrowCommon
    }

    switch ($idx) {
        0 {
            $script:lblPageTitle.Text = $strings.TitleDiag
            $script:lblPageDesc.Text  = $strings.DescDiag
        }
        1 {
            $script:lblPageTitle.Text = $strings.TitleDebloat
            $script:lblPageDesc.Text  = $strings.DescDebloat
        }
        2 {
            $script:lblPageTitle.Text = $strings.TitlePerf
            $script:lblPageDesc.Text  = $strings.DescPerf
        }
        3 {
            $script:lblPageTitle.Text = $strings.TitleSoftware
            $script:lblPageDesc.Text  = $strings.DescSoftware
        }
        4 {
            $script:lblPageTitle.Text = $strings.TitleNetwork
            $script:lblPageDesc.Text  = $strings.DescNetwork
        }
        5 {
            $script:lblPageTitle.Text = $strings.TitleStartup
            $script:lblPageDesc.Text  = $strings.DescStartup
        }
        6 {
            $script:lblPageTitle.Text = $strings.TitlePrivacy
            $script:lblPageDesc.Text  = $strings.DescPrivacy
        }
        7 {
            $script:lblPageTitle.Text = $strings.TitleCleanup
            $script:lblPageDesc.Text  = $strings.DescCleanup
        }
        8 {
            $script:lblPageTitle.Text = $strings.TitleRepair
            $script:lblPageDesc.Text  = $strings.DescRepair
        }
        9 {
            $script:lblPageTitle.Text = $strings.TitleLogs
            $script:lblPageDesc.Text  = $strings.DescLogs
        }
        10 {
            $script:lblPageTitle.Text = $strings.TitleAbout
            $script:lblPageDesc.Text  = $strings.DescAbout
        }
    }
}


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
    if ($diagTab -and $diagTab.Page)         { $diagTab.Page.Text = $strings.TabDiag }
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
    try {
        $m = Get-SystemPerformanceMetrics
        if ($m) {
            if ($lblRamMetric) {
                $lblRamMetric.Text = ($strings.PerfRamFormat -f $m.UsedRamGB, $m.TotalRamGB, [int]$m.RamPercent)
            }
            if ($lblCpuMetric) {
                $lblCpuMetric.Text = ($strings.PerfCpuFormat -f [math]::Round([double]$m.CpuPercent, 1), $m.ProcessCount)
            }
        }
    } catch {
        if ($lblRamMetric) {
            $lblRamMetric.Text = switch ($Lang) {
                "AR" { "استهلاك الذاكرة (RAM) : جاري الحساب..." }
                "EN" { "RAM Memory Usage: Calculating..." }
                default { "Mémoire Vive (RAM) : Calcul en cours..." }
            }
        }
        if ($lblCpuMetric) {
            $lblCpuMetric.Text = switch ($Lang) {
                "AR" { "استهلاك المعالج (CPU) : جاري الحساب..." }
                "EN" { "Processor (CPU) Usage: Calculating..." }
                default { "Processeur (CPU) : Calcul en cours..." }
            }
        }
    }

    # Réinitialisation du défilement horizontal sur toutes les pages pour éviter tout décalage
    if ($script:NavPages) {
        foreach ($pg in $script:NavPages) {
            if ($pg) {
                $pg.AutoScrollPosition = New-Object System.Drawing.Point(0, 0)
            }
        }
    }
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
    if ($btnCheckAllStartup) { $btnCheckAllStartup.Text = $strings.BtnCheckAllStartup }
    if ($btnUncheckAllStartup) { $btnUncheckAllStartup.Text = $strings.BtnUncheckAllStartup }
    if ($btnDisableStartup) { $btnDisableStartup.Text = $strings.BtnDisableStartup }
    if ($btnEnableStartup) { $btnEnableStartup.Text = $strings.BtnEnableStartup }
    if ($btnRefreshStartup) { $btnRefreshStartup.Text = $strings.BtnRefreshStartup }
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

    # Mise à jour du bandeau supérieur (Eyebrow + Titre + Desc)
    Update-HeaderForActivePage

    # Infobulles de la barre latérale de navigation Kudu
    if ($script:NavButtons -and $script:NavToolTip) {
        $tips = @(
            $strings.TabDiag,
            $strings.TabDebloat,
            $strings.TabPerf,
            $strings.TabSoftware,
            $strings.TabNetwork,
            $strings.TabStartup,
            $strings.TabPrivacy,
            $strings.TabCleanup,
            $strings.TabRepair,
            $strings.TabLogs,
            $strings.TabAbout
        )
        for ($k = 0; $k -lt [math]::Min($script:NavButtons.Count, $tips.Count); $k++) {
            if ($script:NavButtons[$k] -and $script:NavButtons[$k].Tag) {
                $script:NavButtons[$k].Tag.Tooltip = $tips[$k]
                $script:NavToolTip.SetToolTip($script:NavButtons[$k], $tips[$k])
            }
        }
    }

    # Onglet 10 : À propos & Support
    if ($lblAboutAppTitle)     { $lblAboutAppTitle.Text = $strings.AboutAppTitle }
    if ($lblAboutAppSub)       { $lblAboutAppSub.Text = $strings.AboutAppSub }
    if ($lblAboutStatus)       { $lblAboutStatus.Text = $strings.AboutStatusReady }
    if ($btnCheckSystemState)  { $btnCheckSystemState.Text = $strings.BtnCheckState }
    if ($btnAboutGithub)       { $btnAboutGithub.Text = $strings.BtnGithub }
    if ($btnAboutRestore)      { $btnAboutRestore.Text = $strings.BtnRestoreSec }
    if ($lblSupportTitle)      { $lblSupportTitle.Text = $strings.AboutSupportTitle }
    if ($lblSupportDesc)       { $lblSupportDesc.Text = $strings.AboutSupportDesc }
    if ($btnSupportCall)       { $btnSupportCall.Text = $strings.BtnCallAuthor }
    if ($cardSpecs -and $cardSpecs.Tag) { $cardSpecs.Tag.Header.Text = $strings.AboutSpecsTitle }
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

# ════════════════════════════════════════════════════════════════════════
# ARCHITECTURE MODERNE STYLE KUDU (NAVIGATION RAIL + HEADER + CANVAS)
# ════════════════════════════════════════════════════════════════════════

$form.Size = New-Object System.Drawing.Size(1100, 800)
$form.MinimumSize = New-Object System.Drawing.Size(1020, 740)

# ToolTip global pour navigation
$script:NavToolTip = New-Object System.Windows.Forms.ToolTip
$script:NavToolTip.InitialDelay = 150
$script:NavToolTip.ReshowDelay = 100
$script:NavToolTip.AutoPopDelay = 5000

# Helper pour boutons de préréglages
function New-PresetButton {
    param(
        [string]$Text,
        [System.Drawing.Point]$Location,
        [scriptblock]$Click
    )
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text
    $btn.Location = $Location
    $btn.Size = New-Object System.Drawing.Size(110, 28)
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

# ────────────────────────────────────────────────────────────────────────
# ────────────────────────────────────────────────────────────────────────
# 1. ARCHITECTURE SÉCURISÉE SANS CHEVAUCHEMENT (ROOT TABLELAYOUT)
# ────────────────────────────────────────────────────────────────────────

# Layout racine à 2 colonnes strictes : Colonne 0 (Sidebar 74px) | Colonne 1 (MainPanel 100%)
# Élimine 100% de tout risque de chevauchement entre la barre latérale et l'espace de travail
$rootLayout = New-Object System.Windows.Forms.TableLayoutPanel
$rootLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
$rootLayout.ColumnCount = 2
$rootLayout.RowCount = 1
$rootLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 74))) | Out-Null
$rootLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$rootLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$rootLayout.BackColor = $colors.BackColor
$rootLayout.Padding = New-Object System.Windows.Forms.Padding(0)
$rootLayout.Margin = New-Object System.Windows.Forms.Padding(0)
$form.Controls.Add($rootLayout)

# ── Colonne 0 : Rail de navigation vertical gauche (Style Kudu) ─────────
$sidebarPanel = New-Object System.Windows.Forms.Panel
$sidebarPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$sidebarPanel.BackColor = $colors.SidebarBack
$sidebarPanel.Margin = New-Object System.Windows.Forms.Padding(0)
$rootLayout.Controls.Add($sidebarPanel, 0, 0)

# Ligne séparatrice droite fine (1px)
$sidebarPanel.Add_Paint({
    param($s, $e)
    $pen = New-Object System.Drawing.Pen($script:colors.BorderColor, 1)
    $e.Graphics.DrawLine($pen, $s.Width - 1, 0, $s.Width - 1, $s.Height)
    $pen.Dispose()
})

# Haut de la barre latérale : Logo badge ambre Kudu
$sidebarTop = New-Object System.Windows.Forms.Panel
$sidebarTop.Dock = [System.Windows.Forms.DockStyle]::Top
$sidebarTop.Height = 68
$sidebarTop.BackColor = [System.Drawing.Color]::Transparent
$sidebarPanel.Controls.Add($sidebarTop)

$logoBadge = New-Object System.Windows.Forms.Panel
$logoBadge.Size = New-Object System.Drawing.Size(46, 46)
$logoBadge.Location = New-Object System.Drawing.Point(14, 11)
$logoBadge.BackColor = [System.Drawing.Color]::FromArgb(245, 158, 11) # Amber 500
$logoBadge.Cursor = [System.Windows.Forms.Cursors]::Hand
$logoBadge.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $f = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    $b = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString("⚡", $f, $b, (New-Object System.Drawing.RectangleF(0, 0, $s.Width, $s.Height)), $sf)
    $b.Dispose()
    $f.Dispose()
    $sf.Dispose()
})
$logoBadge.Add_Click({
    Select-NavPage -Index 10
})
$sidebarTop.Controls.Add($logoBadge)
$script:NavToolTip.SetToolTip($logoBadge, "REDADZDOptimiser Professional")

# Bas de la barre latérale : Bouton Paramètres / À propos (Gear)
$sidebarBottom = New-Object System.Windows.Forms.Panel
$sidebarBottom.Dock = [System.Windows.Forms.DockStyle]::Bottom
$sidebarBottom.Height = 58
$sidebarBottom.BackColor = [System.Drawing.Color]::Transparent
$sidebarPanel.Controls.Add($sidebarBottom)

# Milieu de la barre latérale : Pile d'icônes de navigation
$sidebarNav = New-Object System.Windows.Forms.Panel
$sidebarNav.Dock = [System.Windows.Forms.DockStyle]::Fill
$sidebarNav.BackColor = [System.Drawing.Color]::Transparent
$sidebarPanel.Controls.Add($sidebarNav)

# Helper pour boutons d'icônes de la barre latérale
function New-NavIconButton {
    param(
        [int]$Index,
        [string]$Icon,
        [string]$TooltipText,
        [System.Drawing.Point]$Location,
        [System.Drawing.Size]$Size = (New-Object System.Drawing.Size(54, 44))
    )
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Icon
    $btn.Location = $Location
    $btn.Size = $Size
    $btn.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 14.5, [System.Drawing.FontStyle]::Regular)
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn.FlatAppearance.BorderSize = 0
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btn.BackColor = [System.Drawing.Color]::Transparent
    $btn.ForeColor = $script:colors.NavMutedFore
    $btn.Tag = @{
        Index      = $Index
        IsActive   = ($Index -eq 0)
        IsHovered  = $false
        Tooltip    = $TooltipText
    }

    $btn.Add_MouseEnter({
        $this.Tag.IsHovered = $true
        $this.Invalidate()
    })
    $btn.Add_MouseLeave({
        $this.Tag.IsHovered = $false
        $this.Invalidate()
    })
    $btn.Add_Click({
        Select-NavPage -Index $this.Tag.Index
    })

    $btn.Add_Paint({
        param($s, $e)
        $g = $e.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

        if ($s.Tag.IsActive) {
            $brush = New-Object System.Drawing.SolidBrush($script:colors.NavActiveBack)
            $rect = New-Object System.Drawing.Rectangle(4, 2, $s.Width - 8, $s.Height - 4)
            $g.FillRectangle($brush, $rect)
            $brush.Dispose()

            $barBrush = New-Object System.Drawing.SolidBrush($script:colors.NavActiveBar)
            $g.FillRectangle($barBrush, 0, 7, 3.5, $s.Height - 14)
            $barBrush.Dispose()
        } elseif ($s.Tag.IsHovered) {
            $hoverBrush = New-Object System.Drawing.SolidBrush($script:colors.NavHoverBack)
            $rect = New-Object System.Drawing.Rectangle(4, 2, $s.Width - 8, $s.Height - 4)
            $g.FillRectangle($hoverBrush, $rect)
            $hoverBrush.Dispose()
        }
    })

    if ($script:NavToolTip) {
        $script:NavToolTip.SetToolTip($btn, $TooltipText)
    }

    return $btn
}

# ────────────────────────────────────────────────────────────────────────
# 2. COLONNE 1 : CONTENEUR PRINCIPAL DROIT (HEADER + CANVAS + BARRE D'ACTION)
# ────────────────────────────────────────────────────────────────────────

$rightMainPanel = New-Object System.Windows.Forms.Panel
$rightMainPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$rightMainPanel.BackColor = $colors.BackColor
$rightMainPanel.Margin = New-Object System.Windows.Forms.Padding(0)
$rootLayout.Controls.Add($rightMainPanel, 1, 0)

# 2.1. HEADER SUPÉRIEUR ÉPURÉ STYLE KUDU (Dock: Top, 84px)
$topHeader = New-Object System.Windows.Forms.Panel
$topHeader.Dock = [System.Windows.Forms.DockStyle]::Top
$topHeader.Height = 84
$topHeader.BackColor = $colors.CardBack
$rightMainPanel.Controls.Add($topHeader)

$topHeader.Add_Paint({
    param($s, $e)
    $pen = New-Object System.Drawing.Pen($script:colors.BorderColor, 1)
    $e.Graphics.DrawLine($pen, 0, $s.Height - 1, $s.Width, $s.Height - 1)
    $pen.Dispose()
})

# Panneau de droite pour Admin Badge + Langue (Largeur fixe 380px, Dock: Right)
$headerRight = New-Object System.Windows.Forms.Panel
$headerRight.Dock = [System.Windows.Forms.DockStyle]::Right
$headerRight.Width = 380
$headerRight.BackColor = [System.Drawing.Color]::Transparent
$topHeader.Controls.Add($headerRight)

# Badge Administrateur
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$adminBadge = New-Object System.Windows.Forms.Label
$adminBadge.Text = if ($isAdmin) { "✓ ADMINISTRATEUR (Élevé)" } else { "⚠ NON-ADMIN (Droits limités)" }
$adminBadge.Font = $fonts.Badge
$adminBadge.ForeColor = if ($isAdmin) { $colors.AdminOkFore } else { $colors.AdminErrFore }
$adminBadge.BackColor = if ($isAdmin) { $colors.AdminOkBack } else { $colors.AdminErrBack }
$adminBadge.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$adminBadge.Size = New-Object System.Drawing.Size(195, 26)
$adminBadge.Location = New-Object System.Drawing.Point(175, 12)
$adminBadge.Add_Paint({
    param($s, $e)
    $borderCol = if ($isAdmin) { $script:colors.AdminOkBorder } else { $script:colors.AdminErrBorder }
    $p = New-Object System.Drawing.Pen($borderCol, 1)
    $e.Graphics.DrawRectangle($p, 0, 0, $s.Width - 1, $s.Height - 1)
    $p.Dispose()
})
$headerRight.Controls.Add($adminBadge)

# Sélecteur de Langue
$script:LangCombo = New-Object System.Windows.Forms.ComboBox
$script:LangCombo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$script:LangCombo.Items.AddRange(@("🇫🇷 Français", "🇬🇧 English", "🇸🇦 العربية"))
$script:LangCombo.BackColor = [System.Drawing.Color]::White
$script:LangCombo.ForeColor = $colors.ForeColor
$script:LangCombo.Font = $fonts.Normal
$script:LangCombo.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$script:LangCombo.Size = New-Object System.Drawing.Size(135, 26)
$script:LangCombo.Location = New-Object System.Drawing.Point(30, 12)
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
$headerRight.Controls.Add($script:LangCombo)

# Version Windows
$winVer = [System.Environment]::OSVersion.Version
$verLabel = New-Object System.Windows.Forms.Label
$verLabel.Text = "Windows $($winVer.Major).$($winVer.Minor) Build $($winVer.Build)"
$verLabel.Font = $fonts.Small
$verLabel.ForeColor = $colors.DisabledColor
$verLabel.Size = New-Object System.Drawing.Size(340, 20)
$verLabel.Location = New-Object System.Drawing.Point(30, 48)
$verLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$headerRight.Controls.Add($verLabel)

# Panneau de gauche pour Titres & Eyebrow (Dock: Fill)
$headerLeft = New-Object System.Windows.Forms.Panel
$headerLeft.Dock = [System.Windows.Forms.DockStyle]::Fill
$headerLeft.BackColor = [System.Drawing.Color]::Transparent
$headerLeft.Padding = New-Object System.Windows.Forms.Padding(24, 8, 12, 8)
$topHeader.Controls.Add($headerLeft)

$script:lblEyebrow = New-Object System.Windows.Forms.Label
$script:lblEyebrow.Text = "ⓘ ESPACE DE TRAVAIL  •  REDADZDOptimiser"
$script:lblEyebrow.Font = $fonts.Eyebrow
$script:lblEyebrow.ForeColor = $colors.NavMutedFore
$script:lblEyebrow.AutoSize = $true
$script:lblEyebrow.Location = New-Object System.Drawing.Point(24, 10)
$headerLeft.Controls.Add($script:lblEyebrow)

$script:lblPageTitle = New-Object System.Windows.Forms.Label
$script:lblPageTitle.Text = "Suppression des Bloatwares"
$script:lblPageTitle.Font = New-Object System.Drawing.Font("Segoe UI", 16.5, [System.Drawing.FontStyle]::Bold)
$script:lblPageTitle.ForeColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
$script:lblPageTitle.AutoSize = $true
$script:lblPageTitle.Location = New-Object System.Drawing.Point(22, 26)
$headerLeft.Controls.Add($script:lblPageTitle)

$script:lblPageDesc = New-Object System.Windows.Forms.Label
$script:lblPageDesc.Text = "Supprimez les applications préinstallées inutiles et désactivez la télémétrie Windows."
$script:lblPageDesc.Font = $fonts.Small
$script:lblPageDesc.ForeColor = $colors.MutedColor
$script:lblPageDesc.AutoSize = $true
$script:lblPageDesc.Location = New-Object System.Drawing.Point(24, 56)
$headerLeft.Controls.Add($script:lblPageDesc)

# 2.2. BARRE BASSE EN 2 LIGNES DISTINCTES (PRÉRÉGLAGES AU-DESSUS, ACTIONS EN-DESSOUS) (Dock: Bottom, 88px)
$bottomBar = New-Object System.Windows.Forms.Panel
$bottomBar.Dock = [System.Windows.Forms.DockStyle]::Bottom
$bottomBar.Height = 88
$bottomBar.BackColor = $colors.CardBack
$rightMainPanel.Controls.Add($bottomBar)

$bottomBar.Add_Paint({
    param($s, $e)
    $pen = New-Object System.Drawing.Pen($script:colors.BorderColor, 1)
    $e.Graphics.DrawLine($pen, 0, 0, $s.Width, 0)
    $pen.Dispose()
})

# Barre de progression moderne fluide (Dock: Top, 4px)
$script:ProgressBar = New-Object System.Windows.Forms.ProgressBar
$script:ProgressBar.Dock = [System.Windows.Forms.DockStyle]::Top
$script:ProgressBar.Height = 4
$script:ProgressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Blocks
$script:ProgressBar.ForeColor = $colors.AccentColor
$script:ProgressBar.BackColor = $colors.BorderColor
$bottomBar.Controls.Add($script:ProgressBar)

# Ligne 1 : Bandeau des Préréglages (Dock: Top, 38px, fond doux)
$presetRow = New-Object System.Windows.Forms.Panel
$presetRow.Dock = [System.Windows.Forms.DockStyle]::Top
$presetRow.Height = 38
$presetRow.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 252)
$presetRow.Padding = New-Object System.Windows.Forms.Padding(16, 4, 16, 4)
$bottomBar.Controls.Add($presetRow)

$presetRow.Add_Paint({
    param($s, $e)
    $p = New-Object System.Drawing.Pen($script:colors.BorderColor, 1)
    $e.Graphics.DrawLine($p, 0, $s.Height - 1, $s.Width, $s.Height - 1)
    $p.Dispose()
})

$lblPresetTitle = New-Object System.Windows.Forms.Label
$lblPresetTitle.Text = "⚡ Préréglages :"
$lblPresetTitle.Font = $fonts.SubTitle
$lblPresetTitle.ForeColor = $colors.ForeColor
$lblPresetTitle.Location = New-Object System.Drawing.Point(16, 8)
$lblPresetTitle.AutoSize = $true
$presetRow.Controls.Add($lblPresetTitle)

$script:BtnPresetMin = New-PresetButton -Text "🌱 Minimal" -Location (New-Object System.Drawing.Point(125, 4)) -Click {
    Apply-Preset -Preset "Minimal"
}
$script:BtnPresetMin.Size = New-Object System.Drawing.Size(100, 28)
$presetRow.Controls.Add($script:BtnPresetMin)

$script:BtnPresetStd = New-PresetButton -Text "⚡ Standard" -Location (New-Object System.Drawing.Point(232, 4)) -Click {
    Run-DiagnosticScan
    Apply-Preset -Preset (if ($script:CurrentDiag -and $script:CurrentDiag.Recommendation) { $script:CurrentDiag.Recommendation.Profile } else { "Standard" })
}
$script:BtnPresetStd.Size = New-Object System.Drawing.Size(108, 28)
$presetRow.Controls.Add($script:BtnPresetStd)

$script:BtnPresetMax = New-PresetButton -Text "🚀 Max" -Location (New-Object System.Drawing.Point(348, 4)) -Click {
    Apply-Preset -Preset "Max"
}
$script:BtnPresetMax.Size = New-Object System.Drawing.Size(92, 28)
$presetRow.Controls.Add($script:BtnPresetMax)

$lblPresetDesc = New-Object System.Windows.Forms.Label
$lblPresetDesc.Text = "(Recommandé : Débloat, télémétrie, nettoyage & CPU)"
$lblPresetDesc.Font = $fonts.Small
$lblPresetDesc.ForeColor = $colors.MutedColor
$lblPresetDesc.Location = New-Object System.Drawing.Point(450, 9)
$lblPresetDesc.AutoSize = $true
$presetRow.Controls.Add($lblPresetDesc)

# Ligne 2 : Actions principales et Copyright (Dock: Fill, 46px)
$actionRow = New-Object System.Windows.Forms.Panel
$actionRow.Dock = [System.Windows.Forms.DockStyle]::Fill
$actionRow.BackColor = [System.Drawing.Color]::Transparent
$bottomBar.Controls.Add($actionRow)

$copyrightLabel = New-Object System.Windows.Forms.Label
$copyrightLabel.Text = "© 2026 REDADZDOptimiser • Anagou Reda  |  Tél : 0542439514"
$copyrightLabel.Font = $fonts.Small
$copyrightLabel.ForeColor = $colors.MutedColor
$copyrightLabel.Location = New-Object System.Drawing.Point(16, 14)
$copyrightLabel.AutoSize = $true
$actionRow.Controls.Add($copyrightLabel)

$actionFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$actionFlow.Dock = [System.Windows.Forms.DockStyle]::Right
$actionFlow.Width = 510
$actionFlow.Height = 44
$actionFlow.FlowDirection = [System.Windows.Forms.FlowDirection]::RightToLeft
$actionFlow.BackColor = [System.Drawing.Color]::Transparent
$actionFlow.Padding = New-Object System.Windows.Forms.Padding(4, 4, 16, 4)
$actionRow.Controls.Add($actionFlow)

# Bouton ANNULER
$script:BtnCancel = New-ModernButton -Text "✕ Annuler" -Size (New-Object System.Drawing.Size(105, 36)) -Location (New-Object System.Drawing.Point(0,0)) -Click {
    $script:CancelToken = $true
    Set-REDADZDOptimiserConfig -CancelRequested $true
    Append-Log ($script:I18N[$script:CurrentLang].CancelPrompt) "WARN"
} -BackColor $colors.ErrorColor -HoverColor $colors.ErrorHover -PressColor $colors.ErrorPress
$script:BtnCancel.Enabled = $false
$actionFlow.Controls.Add($script:BtnCancel)

# Bouton SIMULATION DRY-RUN
$script:BtnDryRun = New-ModernButton -Text "🔍 Simulation" -Size (New-Object System.Drawing.Size(145, 36)) -Location (New-Object System.Drawing.Point(0,0)) -Click {
    Start-Optimization -DryRun $true
} -BackColor $colors.WarningColor -HoverColor $colors.WarningHover -PressColor $colors.WarningPress
$actionFlow.Controls.Add($script:BtnDryRun)

# Bouton OPTIMISER MAINTENANT
$script:BtnRun = New-ModernButton -Text "▶ OPTIMISER MAINTENANT" -Size (New-Object System.Drawing.Size(205, 36)) -Location (New-Object System.Drawing.Point(0,0)) -Click {
    Start-Optimization -DryRun $false
} -BackColor $colors.SuccessColor -HoverColor $colors.SuccessHover -PressColor $colors.SuccessPress
$actionFlow.Controls.Add($script:BtnRun)

# 2.3. CONTENEUR CENTRAL DES VUES (CANVAS)
$script:ViewContainer = New-Object System.Windows.Forms.Panel
$script:ViewContainer.Dock = [System.Windows.Forms.DockStyle]::Fill
$script:ViewContainer.BackColor = $colors.BackColor
$rightMainPanel.Controls.Add($script:ViewContainer)
$script:ViewContainer.BringToFront()

# Tableaux de gestion de la navigation
$script:NavButtons = @()
$script:NavPages = New-Object System.Collections.Generic.List[System.Windows.Forms.Panel]
$script:ActiveNavIndex = 0

# Objet de compatibilité TabControl
$script:TabControl = [PSCustomObject]@{
    TabPages = [PSCustomObject]@{
        Add = { param($p) }
    }
    Invalidate = {}
}

# Fonction de sélection de vue et synchronisation du rail
function Select-NavPage {
    param([int]$Index)
    if ($Index -lt 0 -or $Index -ge $script:NavPages.Count) { return }
    $script:ActiveNavIndex = $Index

    for ($i = 0; $i -lt $script:NavPages.Count; $i++) {
        $page = $script:NavPages[$i]
        $btn  = if ($i -lt $script:NavButtons.Count) { $script:NavButtons[$i] } else { $null }
        $isActive = ($i -eq $Index)
        $page.Visible = $isActive
        if ($isActive) {
            $page.BringToFront()
            $page.AutoScrollPosition = New-Object System.Drawing.Point(0, 0)
        }
        if ($btn -and $btn.Tag) {
            $btn.Tag.IsActive = $isActive
            $btn.Invalidate()
        }
    }

    Update-HeaderForActivePage
}

# Fonction de création de page (verrouillage anti-décalage horizontal)
function New-TabPage {
    param(
        [string]$Title,
        [string]$Icon = "📄"
    )
    $page = New-Object System.Windows.Forms.Panel
    $page.Dock = [System.Windows.Forms.DockStyle]::Fill
    $page.AutoScroll = $true
    $page.BackColor = $script:colors.BackColor
    $page.Padding = New-Object System.Windows.Forms.Padding(16, 12, 16, 20)
    $page.Visible = ($script:NavPages.Count -eq 0)

    # Verrouillage strict du défilement horizontal (anti-décalage RTL et arabe)
    $page.HorizontalScroll.Maximum = 0
    $page.HorizontalScroll.Visible = $false
    $page.HorizontalScroll.Enabled = $false
    $page.AutoScrollPosition = New-Object System.Drawing.Point(0, 0)

    $script:ViewContainer.Controls.Add($page)
    $script:NavPages.Add($page)

    return @{ Page = $page; Scroll = $page; Title = $Title; Icon = $Icon }
}

# Création des 9 boutons de modules dans le rail de navigation
$navItems = @(
    @{ Icon = "🩺"; Tip = "Diagnostic & Santé" },
    @{ Icon = "🗑️"; Tip = "Débloat" },
    @{ Icon = "⚡"; Tip = "Performance & RAM" },
    @{ Icon = "📦"; Tip = "Logiciels" },
    @{ Icon = "🌐"; Tip = "Réseau & DNS" },
    @{ Icon = "🚀"; Tip = "Démarrage" },
    @{ Icon = "🛡️"; Tip = "Vie Privée" },
    @{ Icon = "🧹"; Tip = "Nettoyage" },
    @{ Icon = "🔧"; Tip = "Maintenance" },
    @{ Icon = "📋"; Tip = "Journal" }
)

$yRailOffset = 6
for ($n = 0; $n -lt $navItems.Count; $n++) {
    $item = $navItems[$n]
    $navBtn = New-NavIconButton -Index $n -Icon $item.Icon -TooltipText $item.Tip -Location (New-Object System.Drawing.Point(10, $yRailOffset))
    $sidebarNav.Controls.Add($navBtn)
    $script:NavButtons += $navBtn
    $yRailOffset += 48
}

# Bouton 10 : Gear (Paramètres / À propos & Support) en bas du rail
$gearNavBtn = New-NavIconButton -Index 10 -Icon "⚙️" -TooltipText "À propos & Support" -Location (New-Object System.Drawing.Point(10, 6))
$sidebarBottom.Controls.Add($gearNavBtn)
$script:NavButtons += $gearNavBtn

# ════════════════════════════════════════════════════════════════════════
# ONGLET 0 : DIAGNOSTIC DU PC, RECOMMANDATION TWEAK & SANTÉ MATÉRIELLE
# ════════════════════════════════════════════════════════════════════════
$diagTab = New-TabPage -Title "🩺 Diagnostic & Santé"

$yDiag = 14

# ── 1. Carte de Recommandation Intelligente du Profil ──
$cardRec = New-ModernCard -Title "Recommandation Intelligente du Profil d'Optimisation" -Location (New-Object System.Drawing.Point(12, $yDiag)) -Size (New-Object System.Drawing.Size(860, 205)) -AccentLineColor $colors.AccentColor
$diagTab.Scroll.Controls.Add($cardRec)

$lblRecHeaderBadge = New-Object System.Windows.Forms.Label
$lblRecHeaderBadge.Text = "ANALYSE DU SYSTÈME EN DIRECT"
$lblRecHeaderBadge.Font = $fonts.Badge
$lblRecHeaderBadge.ForeColor = $colors.AccentColor
$lblRecHeaderBadge.Location = New-Object System.Drawing.Point(20, 38)
$lblRecHeaderBadge.AutoSize = $true
$cardRec.Controls.Add($lblRecHeaderBadge)

$script:PillRecProfile = New-Object System.Windows.Forms.Label
$script:PillRecProfile.Text = "Profil Conseillé : ⚡ Tweak Standard"
$script:PillRecProfile.Font = New-Object System.Drawing.Font("Segoe UI", 12.5, [System.Drawing.FontStyle]::Bold)
$script:PillRecProfile.ForeColor = [System.Drawing.Color]::White
$script:PillRecProfile.BackColor = $colors.AccentColor
$script:PillRecProfile.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$script:PillRecProfile.Size = New-Object System.Drawing.Size(340, 34)
$script:PillRecProfile.Location = New-Object System.Drawing.Point(20, 58)
$cardRec.Controls.Add($script:PillRecProfile)

$script:PillRecScore = New-Object System.Windows.Forms.Label
$script:PillRecScore.Text = "Score de saturation : 30/100"
$script:PillRecScore.Font = $fonts.Badge
$script:PillRecScore.ForeColor = $colors.ForeColor
$script:PillRecScore.BackColor = [System.Drawing.Color]::FromArgb(241, 245, 249)
$script:PillRecScore.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$script:PillRecScore.Size = New-Object System.Drawing.Size(220, 34)
$script:PillRecScore.Location = New-Object System.Drawing.Point(375, 58)
$cardRec.Controls.Add($script:PillRecScore)

$script:LblRecReason = New-Object System.Windows.Forms.Label
$script:LblRecReason.Text = "Analyse en cours... Veuillez patienter quelques instants."
$script:LblRecReason.Font = $fonts.Normal
$script:LblRecReason.ForeColor = $colors.ForeColor
$script:LblRecReason.Location = New-Object System.Drawing.Point(20, 98)
$script:LblRecReason.Size = New-Object System.Drawing.Size(820, 48)
$script:LblRecReason.AutoSize = $false
$cardRec.Controls.Add($script:LblRecReason)

$script:BtnApplyRec = New-ModernButton -Text "⚡ Appliquer le profil recommandé" -Size (New-Object System.Drawing.Size(275, 38)) -Location (New-Object System.Drawing.Point(20, 152)) -Click {
    if ($script:CurrentDiag -and $script:CurrentDiag.Recommendation) {
        $p = $script:CurrentDiag.Recommendation.Profile
        Apply-Preset -Preset $p
        [System.Windows.Forms.MessageBox]::Show(
            "Le profil recommandé '$($script:CurrentDiag.Recommendation.Title)' a été sélectionné et activé avec succès !`nToutes les cases associées sont désormais prêtes.",
            "Recommandation Appliquée",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
} -BackColor $colors.SuccessColor -HoverColor $colors.SuccessHover -PressColor $colors.SuccessPress
$cardRec.Controls.Add($script:BtnApplyRec)

$script:BtnQuickRun = New-ModernButton -Text "▶ Lancer l'Optimisation" -Size (New-Object System.Drawing.Size(210, 38)) -Location (New-Object System.Drawing.Point(305, 152)) -Click {
    Start-Optimization -DryRun $false
} -BackColor $colors.AccentColor -HoverColor $colors.AccentHover -PressColor $colors.AccentPress
$cardRec.Controls.Add($script:BtnQuickRun)

$script:BtnRescan = New-ModernButton -Text "🔄 Réanalyser le PC" -Size (New-Object System.Drawing.Size(185, 38)) -Location (New-Object System.Drawing.Point(525, 152)) -Click {
    Run-DiagnosticScan
} -BackColor $colors.CardBack -HoverColor $colors.NavHoverBack -PressColor $colors.BorderColor -ForeColor $colors.ForeColor
$script:BtnRescan.Add_Paint({
    param($s, $e)
    $p = New-Object System.Drawing.Pen($script:colors.BorderColor, 1)
    $e.Graphics.DrawRectangle($p, 0, 0, $s.Width - 1, $s.Height - 1)
    $p.Dispose()
})
$cardRec.Controls.Add($script:BtnRescan)

$yDiag += 220

# ── 2. Carte des Conseils Personnalisés par Composant ──
$cardAdvice = New-ModernCard -Title "Conseils Personnalisés par Composant (RAM, Disque, Processeur & Batterie)" -Location (New-Object System.Drawing.Point(12, $yDiag)) -Size (New-Object System.Drawing.Size(860, 245)) -AccentLineColor $colors.WarningColor
$diagTab.Scroll.Controls.Add($cardAdvice)

# Ligne 1 : RAM
$lblIconRam = New-Object System.Windows.Forms.Label
$lblIconRam.Text = "🧠 Mémoire RAM :"
$lblIconRam.Font = $fonts.SubTitle
$lblIconRam.ForeColor = $colors.AccentColor
$lblIconRam.Location = New-Object System.Drawing.Point(20, 42)
$lblIconRam.Size = New-Object System.Drawing.Size(155, 20)
$cardAdvice.Controls.Add($lblIconRam)

$script:LblAdviceRam = New-Object System.Windows.Forms.Label
$script:LblAdviceRam.Text = "Calcul des conseils RAM en cours..."
$script:LblAdviceRam.Font = $fonts.Small
$script:LblAdviceRam.ForeColor = $colors.ForeColor
$script:LblAdviceRam.Location = New-Object System.Drawing.Point(180, 42)
$script:LblAdviceRam.Size = New-Object System.Drawing.Size(660, 36)
$cardAdvice.Controls.Add($script:LblAdviceRam)

# Ligne 2 : Disque
$lblIconDisk = New-Object System.Windows.Forms.Label
$lblIconDisk.Text = "💽 Disque Dur (C:) :"
$lblIconDisk.Font = $fonts.SubTitle
$lblIconDisk.ForeColor = $colors.WarningColor
$lblIconDisk.Location = New-Object System.Drawing.Point(20, 88)
$lblIconDisk.Size = New-Object System.Drawing.Size(155, 20)
$cardAdvice.Controls.Add($lblIconDisk)

$script:LblAdviceDisk = New-Object System.Windows.Forms.Label
$script:LblAdviceDisk.Text = "Calcul des conseils Disque en cours..."
$script:LblAdviceDisk.Font = $fonts.Small
$script:LblAdviceDisk.ForeColor = $colors.ForeColor
$script:LblAdviceDisk.Location = New-Object System.Drawing.Point(180, 88)
$script:LblAdviceDisk.Size = New-Object System.Drawing.Size(660, 36)
$cardAdvice.Controls.Add($script:LblAdviceDisk)

# Ligne 3 : Processeur
$lblIconCpu = New-Object System.Windows.Forms.Label
$lblIconCpu.Text = "💻 Processeur (CPU) :"
$lblIconCpu.Font = $fonts.SubTitle
$lblIconCpu.ForeColor = $colors.CyanAccent
$lblIconCpu.Location = New-Object System.Drawing.Point(20, 134)
$lblIconCpu.Size = New-Object System.Drawing.Size(155, 20)
$cardAdvice.Controls.Add($lblIconCpu)

$script:LblAdviceCpu = New-Object System.Windows.Forms.Label
$script:LblAdviceCpu.Text = "Calcul des conseils CPU en cours..."
$script:LblAdviceCpu.Font = $fonts.Small
$script:LblAdviceCpu.ForeColor = $colors.ForeColor
$script:LblAdviceCpu.Location = New-Object System.Drawing.Point(180, 134)
$script:LblAdviceCpu.Size = New-Object System.Drawing.Size(660, 36)
$cardAdvice.Controls.Add($script:LblAdviceCpu)

# Ligne 4 : Batterie
$lblIconBat = New-Object System.Windows.Forms.Label
$lblIconBat.Text = "🔋 Batterie / Secteur :"
$lblIconBat.Font = $fonts.SubTitle
$lblIconBat.ForeColor = $colors.SuccessColor
$lblIconBat.Location = New-Object System.Drawing.Point(20, 180)
$lblIconBat.Size = New-Object System.Drawing.Size(155, 20)
$cardAdvice.Controls.Add($lblIconBat)

$script:LblAdviceBat = New-Object System.Windows.Forms.Label
$script:LblAdviceBat.Text = "Calcul des conseils Batterie en cours..."
$script:LblAdviceBat.Font = $fonts.Small
$script:LblAdviceBat.ForeColor = $colors.ForeColor
$script:LblAdviceBat.Location = New-Object System.Drawing.Point(180, 180)
$script:LblAdviceBat.Size = New-Object System.Drawing.Size(660, 36)
$cardAdvice.Controls.Add($script:LblAdviceBat)

$yDiag += 260

# ── 3. Carte d'État de Santé Détaillé des Composants Matériels ──
$cardHwHealth = New-ModernCard -Title "État de Santé Détaillé des Composants (S.M.A.R.T., Batterie, RAM & CPU)" -Location (New-Object System.Drawing.Point(12, $yDiag)) -Size (New-Object System.Drawing.Size(860, 275)) -AccentLineColor $colors.SuccessColor
$diagTab.Scroll.Controls.Add($cardHwHealth)

# Block A : Disque Dur (Top Left)
$lblHwDiskHeader = New-Object System.Windows.Forms.Label
$lblHwDiskHeader.Text = "💽 Santé Disque & Stockage :"
$lblHwDiskHeader.Font = $fonts.SubTitle
$lblHwDiskHeader.ForeColor = $colors.ForeColor
$lblHwDiskHeader.Location = New-Object System.Drawing.Point(20, 42)
$lblHwDiskHeader.AutoSize = $true
$cardHwHealth.Controls.Add($lblHwDiskHeader)

$script:LblHwDiskInfo = New-Object System.Windows.Forms.Label
$script:LblHwDiskInfo.Text = "Lecture S.M.A.R.T. et espace..."
$script:LblHwDiskInfo.Font = $fonts.Small
$script:LblHwDiskInfo.ForeColor = $colors.MutedColor
$script:LblHwDiskInfo.Location = New-Object System.Drawing.Point(20, 68)
$script:LblHwDiskInfo.Size = New-Object System.Drawing.Size(395, 65)
$cardHwHealth.Controls.Add($script:LblHwDiskInfo)

# Block B : Batterie & Alimentation (Top Right)
$lblHwBatHeader = New-Object System.Windows.Forms.Label
$lblHwBatHeader.Text = "🔋 Santé Batterie & Alimentation :"
$lblHwBatHeader.Font = $fonts.SubTitle
$lblHwBatHeader.ForeColor = $colors.ForeColor
$lblHwBatHeader.Location = New-Object System.Drawing.Point(440, 42)
$lblHwBatHeader.AutoSize = $true
$cardHwHealth.Controls.Add($lblHwBatHeader)

$script:LblHwBatInfo = New-Object System.Windows.Forms.Label
$script:LblHwBatInfo.Text = "Vérification alimentation..."
$script:LblHwBatInfo.Font = $fonts.Small
$script:LblHwBatInfo.ForeColor = $colors.MutedColor
$script:LblHwBatInfo.Location = New-Object System.Drawing.Point(440, 68)
$script:LblHwBatInfo.Size = New-Object System.Drawing.Size(395, 65)
$cardHwHealth.Controls.Add($script:LblHwBatInfo)

# Block C : Mémoire RAM (Bottom Left)
$lblHwRamHeader = New-Object System.Windows.Forms.Label
$lblHwRamHeader.Text = "🧠 Santé Mémoire Vive (RAM) :"
$lblHwRamHeader.Font = $fonts.SubTitle
$lblHwRamHeader.ForeColor = $colors.ForeColor
$lblHwRamHeader.Location = New-Object System.Drawing.Point(20, 145)
$lblHwRamHeader.AutoSize = $true
$cardHwHealth.Controls.Add($lblHwRamHeader)

$script:LblHwRamInfo = New-Object System.Windows.Forms.Label
$script:LblHwRamInfo.Text = "Lecture modules RAM..."
$script:LblHwRamInfo.Font = $fonts.Small
$script:LblHwRamInfo.ForeColor = $colors.MutedColor
$script:LblHwRamInfo.Location = New-Object System.Drawing.Point(20, 172)
$script:LblHwRamInfo.Size = New-Object System.Drawing.Size(395, 80)
$cardHwHealth.Controls.Add($script:LblHwRamInfo)

# Block D : Processeur (CPU) (Bottom Right)
$lblHwCpuHeader = New-Object System.Windows.Forms.Label
$lblHwCpuHeader.Text = "💻 Santé Processeur (CPU) :"
$lblHwCpuHeader.Font = $fonts.SubTitle
$lblHwCpuHeader.ForeColor = $colors.ForeColor
$lblHwCpuHeader.Location = New-Object System.Drawing.Point(440, 145)
$lblHwCpuHeader.AutoSize = $true
$cardHwHealth.Controls.Add($lblHwCpuHeader)

$script:LblHwCpuInfo = New-Object System.Windows.Forms.Label
$script:LblHwCpuInfo.Text = "Lecture cœurs et fréquences..."
$script:LblHwCpuInfo.Font = $fonts.Small
$script:LblHwCpuInfo.ForeColor = $colors.MutedColor
$script:LblHwCpuInfo.Location = New-Object System.Drawing.Point(440, 172)
$script:LblHwCpuInfo.Size = New-Object System.Drawing.Size(395, 80)
$cardHwHealth.Controls.Add($script:LblHwCpuInfo)

# ── Fonctions de Diagnostic et Mise à jour de l'UI ──
function Update-DiagnosticUI {
    param($Diag)
    if (-not $Diag) { return }

    # Mise à jour de la recommandation
    $rec = $Diag.Recommendation
    if ($script:PillRecProfile) {
        $script:PillRecProfile.Text = "Profil Conseillé : " + $rec.Title
        $script:PillRecProfile.BackColor = switch ($rec.Profile) {
            "Max"     { $script:colors.PurpleAccent }
            "Minimal" { $script:colors.SuccessColor }
            default   { $script:colors.AccentColor }
        }
    }
    if ($script:PillRecScore) {
        $script:PillRecScore.Text = "Score de besoin : $($rec.Score)/100"
    }
    if ($script:LblRecReason) {
        $script:LblRecReason.Text = $rec.Reason
    }
    if ($script:BtnApplyRec) {
        $script:BtnApplyRec.Text = "⚡ Activer le profil $($rec.Title)"
    }

    # Mise à jour des conseils personnalisés
    if ($script:LblAdviceRam)  { $script:LblAdviceRam.Text  = $rec.AdviceRAM }
    if ($script:LblAdviceDisk) { $script:LblAdviceDisk.Text = $rec.AdviceDisk }
    if ($script:LblAdviceCpu)  { $script:LblAdviceCpu.Text  = $rec.AdviceCPU }
    if ($script:LblAdviceBat)  { $script:LblAdviceBat.Text  = $rec.AdviceBattery }

    # Mise à jour de l'état de santé
    if ($script:LblHwDiskInfo) {
        $d = $Diag.Disk
        $script:LblHwDiskInfo.Text = "• Modèle : $($d.Model)`n• Type : $($d.Type) | S.M.A.R.T. : $($d.SmartStatus)`n• Espace C: : $($d.FreeGB) Go libres / $($d.TotalGB) Go ($($d.FreePercent)% libre)`n• État : $($d.Health)"
    }
    if ($script:LblHwBatInfo) {
        $b = $Diag.Battery
        $script:LblHwBatInfo.Text = "• Statut : $($b.StatusText)`n• Niveau de charge : $($b.ChargePercent)%`n• État de santé : $($b.HealthText)"
    }
    if ($script:LblHwRamInfo) {
        $r = $Diag.RAM
        $script:LblHwRamInfo.Text = "• Capacité totale : $($r.TotalGB) Go ($($r.UsagePercent)% utilisée)`n• Mémoire libre : $($r.FreeGB) Go disponibles`n• Barrettes : $($r.ModuleCount) module(s) détecté(s) à $($r.SpeedMHz) MHz`n• Santé : $($r.Health)"
    }
    if ($script:LblHwCpuInfo) {
        $c = $Diag.CPU
        $script:LblHwCpuInfo.Text = "• Modèle : $($c.Name)`n• Cœurs / Threads : $($c.Cores) cœurs physiques / $($c.Threads) threads`n• Vitesse de base : $($c.SpeedMHz) MHz`n• Santé : $($c.Health)"
    }
}

function Run-DiagnosticScan {
    try {
        Append-Log "🩺 Démarrage du scan matériel et analyse de santé système..." "INFO"
        $diag = Get-SystemHardwareHealthAndDiagnostics
        $script:CurrentDiag = $diag
        Update-DiagnosticUI -Diag $diag
        Append-Log "✓ Diagnostic terminé : Profil recommandé = $($diag.Recommendation.Title) (Score: $($diag.Recommendation.Score)/100)" "SUCCESS"
    } catch {
        Append-Log "Erreur lors du scan matériel : $_" "WARN"
    }
}

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
$cardPerfMonitor = New-ModernCard -Title "Surveillance des Ressources en temps réel" -Location (New-Object System.Drawing.Point(12, $yPosPerf)) -Size (New-Object System.Drawing.Size(860, 215)) -AccentLineColor $colors.SuccessColor
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
$pbRam.Size = New-Object System.Drawing.Size(570, 22)
$pbRam.Minimum = 0
$pbRam.Maximum = 100
$pbRam.Value = 0
$pbRam.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
$cardPerfMonitor.Controls.Add($pbRam)

$btnFlushRam = New-ModernButton -Text "🚀 Vider le cache & RAM" -Size (New-Object System.Drawing.Size(235, 48)) -Location (New-Object System.Drawing.Point(605, 44)) -BackColor $colors.SuccessColor -HoverColor $colors.SuccessHover -PressColor $colors.SuccessPress -Click {
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
$pbCpu.Size = New-Object System.Drawing.Size(570, 22)
$pbCpu.Minimum = 0
$pbCpu.Maximum = 100
$pbCpu.Value = 0
$pbCpu.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
$cardPerfMonitor.Controls.Add($pbCpu)

$lblPerfLiveNotice = New-Object System.Windows.Forms.Label
$lblPerfLiveNotice.Text = "● Surveillance continue en direct • 1.5s"
$lblPerfLiveNotice.Font = $fonts.Small
$lblPerfLiveNotice.ForeColor = $colors.MutedColor
$lblPerfLiveNotice.Location = New-Object System.Drawing.Point(605, 134)
$lblPerfLiveNotice.Size = New-Object System.Drawing.Size(235, 20)
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
$cardPerfKill = New-ModernCard -Title "Nettoyeur de Processus d'Arrière-Plan Inutiles" -Location (New-Object System.Drawing.Point(12, $yPosPerf)) -Size (New-Object System.Drawing.Size(860, 175)) -AccentLineColor $colors.ErrorColor
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

$btnKillProcesses = New-ModernButton -Text "🛑 Fermer les processus inutiles" -Size (New-Object System.Drawing.Size(250, 40)) -Location (New-Object System.Drawing.Point(20, 112)) -BackColor $colors.ErrorColor -HoverColor $colors.ErrorHover -PressColor $colors.ErrorPress -Click {
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

$script:CbAutoKillOnOptimize = New-ModernCheckBox -Text "Inclure la fermeture des processus inutiles lors de l'Optimisation Globale" -Location (New-Object System.Drawing.Point(285, 120)) -Checked $true
$cardPerfKill.Controls.Add($script:CbAutoKillOnOptimize)

$yPosPerf += 190

# ── Carte 3: Optimisations Processeur & Énergie ──
$cardPerfCpu = New-ModernCard -Title "Optimisations Processeur (CPU) & Alimentation" -Location (New-Object System.Drawing.Point(12, $yPosPerf)) -Size (New-Object System.Drawing.Size(860, 235)) -AccentLineColor $colors.IndigoAccent
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
    Select-NavPage -Index 9
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

$cbDuckDuckGo = New-ModernCheckBox -Text "DuckDuckGo Browser (Confidentialité maximale)" -Location (New-Object System.Drawing.Point(450, 72)) -Checked $false
$cbDuckDuckGo.Tag = "DuckDuckGo.DesktopBrowser"
$cardBrowsers.Controls.Add($cbDuckDuckGo); $script:AppCheckBoxes += $cbDuckDuckGo

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

$cbFoxitReader = New-ModernCheckBox -Text "Foxit PDF Reader (Rapide & Léger)" -Location (New-Object System.Drawing.Point(450, 42)) -Checked $false
$cbFoxitReader.Tag = "Foxit.FoxitReader"
$cardDevOffice.Controls.Add($cbFoxitReader); $script:AppCheckBoxes += $cbFoxitReader

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
$lblStartupDesc.Text = "Cochez les applications superflues au démarrage pour les désactiver ou réactivez celles dont vous avez besoin."
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
$lvStartup.MultiSelect = $true
$lvStartup.CheckBoxes = $true
$lvStartup.Font = $fonts.Normal
$lvStartup.Columns.Add("Nom", 220) | Out-Null
$lvStartup.Columns.Add("Emplacement", 150) | Out-Null
$lvStartup.Columns.Add("Statut", 90) | Out-Null
$lvStartup.Columns.Add("Commande / Chemin", 370) | Out-Null
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
        if ($item.Status -eq "Désactivé") {
            $lvi.ForeColor = $colors.MutedColor
        }
        $lvStartup.Items.Add($lvi) | Out-Null
    }
}

$btnCheckAllStartup = New-ModernButton -Text "☑️ Tout cocher" -Size (New-Object System.Drawing.Size(125, 36)) -Location (New-Object System.Drawing.Point(20, 465)) -Click {
    foreach ($item in $lvStartup.Items) {
        $item.Checked = $true
    }
} -BackColor $colors.CardBack -HoverColor $colors.AccentColor -PressColor $colors.AccentPress -ForeColor $colors.ForeColor
$cardStartupManager.Controls.Add($btnCheckAllStartup)

$btnUncheckAllStartup = New-ModernButton -Text "⬜ Tout décocher" -Size (New-Object System.Drawing.Size(125, 36)) -Location (New-Object System.Drawing.Point(152, 465)) -Click {
    foreach ($item in $lvStartup.Items) {
        $item.Checked = $false
    }
} -BackColor $colors.CardBack -HoverColor $colors.AccentColor -PressColor $colors.AccentPress -ForeColor $colors.ForeColor
$cardStartupManager.Controls.Add($btnUncheckAllStartup)

$btnDisableStartup = New-ModernButton -Text "🛑 Désactiver cochés" -Size (New-Object System.Drawing.Size(185, 36)) -Location (New-Object System.Drawing.Point(284, 465)) -Click {
    $targetItems = @($lvStartup.CheckedItems)
    if ($targetItems.Count -eq 0 -and $lvStartup.SelectedItems.Count -gt 0) {
        $targetItems = @($lvStartup.SelectedItems)
    }
    if ($targetItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            $script:I18N[$script:CurrentLang].StartupNoSelection,
            "Information",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }
    $count = 0
    foreach ($item in $targetItems) {
        $data = $item.Tag
        if ($data -and $data.Status -eq "Activé") {
            $res = Disable-StartupProgram -Name $data.Name -Location $data.Location
            if ($res) { $count++ }
        }
    }
    if ($count -gt 0) {
        Append-Log ($script:I18N[$script:CurrentLang].StartupDisabledDone -f $count) "SUCCESS"
        Update-StartupList
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "Aucune application active sélectionnée à désactiver.",
            "Information",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
} -BackColor $colors.ErrorColor -HoverColor $colors.ErrorHover -PressColor $colors.ErrorPress
$cardStartupManager.Controls.Add($btnDisableStartup)

$btnEnableStartup = New-ModernButton -Text "✅ Réactiver cochés" -Size (New-Object System.Drawing.Size(185, 36)) -Location (New-Object System.Drawing.Point(476, 465)) -Click {
    $targetItems = @($lvStartup.CheckedItems)
    if ($targetItems.Count -eq 0 -and $lvStartup.SelectedItems.Count -gt 0) {
        $targetItems = @($lvStartup.SelectedItems)
    }
    if ($targetItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            $script:I18N[$script:CurrentLang].StartupNoSelection,
            "Information",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }
    $count = 0
    foreach ($item in $targetItems) {
        $data = $item.Tag
        if ($data -and $data.Status -eq "Désactivé") {
            $res = Enable-StartupProgram -Name $data.Name -Location $data.Location
            if ($res) { $count++ }
        }
    }
    if ($count -gt 0) {
        Append-Log ($script:I18N[$script:CurrentLang].StartupEnabledDone -f $count) "SUCCESS"
        Update-StartupList
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "Aucune application désactivée sélectionnée à réactiver.",
            "Information",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
} -BackColor $colors.SuccessColor -HoverColor $colors.SuccessHover -PressColor $colors.SuccessPress
$cardStartupManager.Controls.Add($btnEnableStartup)

$btnRefreshStartup = New-ModernButton -Text "🔄 Actualiser" -Size (New-Object System.Drawing.Size(160, 36)) -Location (New-Object System.Drawing.Point(668, 465)) -Click {
    Update-StartupList
} -BackColor $colors.AccentColor -HoverColor $colors.AccentHover -PressColor $colors.AccentPress
$cardStartupManager.Controls.Add($btnRefreshStartup)

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

$script:CbDISM = New-ModernCheckBox -Text "DISM /RestoreHealth (Vérifie et répare l'image Windows via le magasin de composants)" -Location (New-Object System.Drawing.Point(20, 44)) -Checked $false
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
# ────────────────────────────────────────────────────────────────────────
# ONGLET 10 : À PROPOS & SUPPORT (STYLE KUDU v3.13)
# ────────────────────────────────────────────────────────────────────────
$aboutTab = New-TabPage -Title "⚙️ À propos & Support"

$yAbout = 14

# 1. Carte Principale de l'Application (Style Kudu v3.13 About)
$cardAboutApp = New-Object System.Windows.Forms.Panel
$cardAboutApp.Location = New-Object System.Drawing.Point(12, $yAbout)
$cardAboutApp.Size = New-Object System.Drawing.Size(890, 175)
$cardAboutApp.BackColor = $script:colors.CardBack
$cardAboutApp.Add_Paint({
    param($s, $e)
    $pen = New-Object System.Drawing.Pen($script:colors.BorderColor, 1)
    $e.Graphics.DrawRectangle($pen, 0, 0, $s.Width - 1, $s.Height - 1)
    $pen.Dispose()
})
$aboutTab.Scroll.Controls.Add($cardAboutApp)

# Badge Logo Ambre dans la carte (Grand carré 60x60)
$aboutLogoBadge = New-Object System.Windows.Forms.Panel
$aboutLogoBadge.Size = New-Object System.Drawing.Size(60, 60)
$aboutLogoBadge.Location = New-Object System.Drawing.Point(24, 22)
$aboutLogoBadge.BackColor = [System.Drawing.Color]::FromArgb(245, 158, 11) # Amber 500
$aboutLogoBadge.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $f = New-Object System.Drawing.Font("Segoe UI", 22, [System.Drawing.FontStyle]::Bold)
    $b = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString("⚡", $f, $b, (New-Object System.Drawing.RectangleF(0, 0, $s.Width, $s.Height)), $sf)
    $b.Dispose()
    $f.Dispose()
    $sf.Dispose()
})
$cardAboutApp.Controls.Add($aboutLogoBadge)

$lblAboutAppTitle = New-Object System.Windows.Forms.Label
$lblAboutAppTitle.Text = "REDADZDOptimiser v2.0 Professional"
$lblAboutAppTitle.Font = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
$lblAboutAppTitle.ForeColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
$lblAboutAppTitle.Location = New-Object System.Drawing.Point(100, 20)
$lblAboutAppTitle.AutoSize = $true
$cardAboutApp.Controls.Add($lblAboutAppTitle)

$lblAboutAppSub = New-Object System.Windows.Forms.Label
$lblAboutAppSub.Text = "Licence Open Source & Protection  •  Développé par Anagou Reda"
$lblAboutAppSub.Font = $fonts.Small
$lblAboutAppSub.ForeColor = $colors.MutedColor
$lblAboutAppSub.Location = New-Object System.Drawing.Point(102, 48)
$lblAboutAppSub.AutoSize = $true
$cardAboutApp.Controls.Add($lblAboutAppSub)

# Status Pill vert pastel (comme "You're up to date")
$pillStatus = New-Object System.Windows.Forms.Panel
$pillStatus.Location = New-Object System.Drawing.Point(102, 78)
$pillStatus.Size = New-Object System.Drawing.Size(340, 28)
$pillStatus.BackColor = [System.Drawing.Color]::FromArgb(236, 253, 245) # Emerald 50
$pillStatus.Add_Paint({
    param($s, $e)
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(167, 243, 208), 1)
    $e.Graphics.DrawRectangle($pen, 0, 0, $s.Width - 1, $s.Height - 1)
    $pen.Dispose()
})
$cardAboutApp.Controls.Add($pillStatus)

$lblAboutStatus = New-Object System.Windows.Forms.Label
$lblAboutStatus.Text = "✓ Votre système Windows est prêt et optimisable"
$lblAboutStatus.Font = $fonts.Badge
$lblAboutStatus.ForeColor = [System.Drawing.Color]::FromArgb(4, 120, 87) # Emerald 700
$lblAboutStatus.Dock = [System.Windows.Forms.DockStyle]::Fill
$lblAboutStatus.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$pillStatus.Controls.Add($lblAboutStatus)

# Boutons d'action rapides de la carte principale
$btnCheckSystemState = New-ModernButton -Text "🔄 Vérifier l'état système" -Size (New-Object System.Drawing.Size(195, 34)) -Location (New-Object System.Drawing.Point(102, 122)) -Click {
    $m = Get-SystemPerformanceMetrics
    if ($m) {
        Append-Log "État système vérifié : CPU $($m.CpuPercent)%, RAM utilisée $($m.UsedRamGB) Go / $($m.TotalRamGB) Go ($($m.RamPercent)%), $($m.ProcessCount) processus actifs." "SUCCESS"
        [System.Windows.Forms.MessageBox]::Show(
            "Système vérifié avec succès !`n`nCPU : $($m.CpuPercent)%`nRAM : $($m.UsedRamGB) Go / $($m.TotalRamGB) Go ($($m.RamPercent)%)`nProcessus en cours : $($m.ProcessCount)`nEspace disque : Prêt",
            "Vérification Système",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
} -BackColor $colors.CardBack -HoverColor $colors.AccentColor -PressColor $colors.AccentPress -ForeColor $colors.ForeColor
$btnCheckSystemState.Add_Paint({
    param($s, $e)
    $p = New-Object System.Drawing.Pen($script:colors.BorderColor, 1)
    $e.Graphics.DrawRectangle($p, 0, 0, $s.Width - 1, $s.Height - 1)
    $p.Dispose()
})
$cardAboutApp.Controls.Add($btnCheckSystemState)

$btnAboutGithub = New-ModernButton -Text "🌐 Dépôt GitHub ↗" -Size (New-Object System.Drawing.Size(165, 34)) -Location (New-Object System.Drawing.Point(308, 122)) -Click {
    try {
        [System.Diagnostics.Process]::Start("https://github.com/") | Out-Null
    } catch {}
} -BackColor $colors.CardBack -HoverColor $colors.AccentColor -PressColor $colors.AccentPress -ForeColor $colors.ForeColor
$btnAboutGithub.Add_Paint({
    param($s, $e)
    $p = New-Object System.Drawing.Pen($script:colors.BorderColor, 1)
    $e.Graphics.DrawRectangle($p, 0, 0, $s.Width - 1, $s.Height - 1)
    $p.Dispose()
})
$cardAboutApp.Controls.Add($btnAboutGithub)

$btnAboutRestore = New-ModernButton -Text "🛡️ Point de Restauration" -Size (New-Object System.Drawing.Size(195, 34)) -Location (New-Object System.Drawing.Point(484, 122)) -Click {
    Append-Log "Création manuelle d'un point de restauration..." "INFO"
    try {
        Enable-ComputerRestore -Drive "C:" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "REDADZDOptimiser_Manual_Checkpoint" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Append-Log "Point de restauration créé avec succès !" "SUCCESS"
        [System.Windows.Forms.MessageBox]::Show(
            "Point de restauration système créé avec succès !",
            "Point de Restauration",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    } catch {
        Append-Log "Impossible de créer le point de restauration : $_" "WARN"
        [System.Windows.Forms.MessageBox]::Show(
            "Notification : $_",
            "Point de Restauration",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
    }
} -BackColor $colors.CardBack -HoverColor $colors.SuccessColor -PressColor $colors.SuccessPress -ForeColor $colors.ForeColor
$btnAboutRestore.Add_Paint({
    param($s, $e)
    $p = New-Object System.Drawing.Pen($script:colors.BorderColor, 1)
    $e.Graphics.DrawRectangle($p, 0, 0, $s.Width - 1, $s.Height - 1)
    $p.Dispose()
})
$cardAboutApp.Controls.Add($btnAboutRestore)

$yAbout += 190

# 2. Carte Support Kudu (Fond Ambre Chaud, Bordure Dorée, Badge Cœur)
$cardSupport = New-Object System.Windows.Forms.Panel
$cardSupport.Location = New-Object System.Drawing.Point(12, $yAbout)
$cardSupport.Size = New-Object System.Drawing.Size(890, 115)
$cardSupport.BackColor = $script:colors.WarmCardBack # #FFFBEB
$cardSupport.Add_Paint({
    param($s, $e)
    $pen = New-Object System.Drawing.Pen($script:colors.WarmCardBorder, 1.5)
    $e.Graphics.DrawRectangle($pen, 0, 0, $s.Width - 1, $s.Height - 1)
    $pen.Dispose()
})
$aboutTab.Scroll.Controls.Add($cardSupport)

# Badge Cœur Doré (comme Kudu)
$heartBadge = New-Object System.Windows.Forms.Panel
$heartBadge.Size = New-Object System.Drawing.Size(50, 50)
$heartBadge.Location = New-Object System.Drawing.Point(24, 28)
$heartBadge.BackColor = [System.Drawing.Color]::FromArgb(254, 240, 138) # Yellow 200
$heartBadge.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $f = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    $b = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(180, 83, 9)) # Amber 700
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString("♥", $f, $b, (New-Object System.Drawing.RectangleF(0, 0, $s.Width, $s.Height)), $sf)
    $b.Dispose()
    $f.Dispose()
    $sf.Dispose()
})
$cardSupport.Controls.Add($heartBadge)

$lblSupportTitle = New-Object System.Windows.Forms.Label
$lblSupportTitle.Text = "Support & Auteur : Anagou Reda"
$lblSupportTitle.Font = New-Object System.Drawing.Font("Segoe UI", 11.5, [System.Drawing.FontStyle]::Bold)
$lblSupportTitle.ForeColor = $script:colors.WarmCardTitle # #78350F
$lblSupportTitle.Location = New-Object System.Drawing.Point(90, 24)
$lblSupportTitle.AutoSize = $true
$cardSupport.Controls.Add($lblSupportTitle)

$lblSupportDesc = New-Object System.Windows.Forms.Label
$lblSupportDesc.Text = "Besoin d'une assistance technique, d'un tweak sur-mesure ou d'une maintenance professionnelle ? Contactez le créateur."
$lblSupportDesc.Font = $fonts.Small
$lblSupportDesc.ForeColor = $script:colors.WarmCardDesc # #92400E
$lblSupportDesc.Location = New-Object System.Drawing.Point(92, 52)
$lblSupportDesc.Size = New-Object System.Drawing.Size(560, 48)
$lblSupportDesc.AutoSize = $false
$cardSupport.Controls.Add($lblSupportDesc)

# Bouton Téléphone / Contact à droite (comme View sponsorships de Kudu)
$btnSupportCall = New-ModernButton -Text "📞 Tél : 0542439514" -Size (New-Object System.Drawing.Size(195, 42)) -Location (New-Object System.Drawing.Point(670, 34)) -Click {
    try {
        [System.Windows.Forms.Clipboard]::SetText("0542439514")
    } catch {}
    [System.Windows.Forms.MessageBox]::Show(
        "Coordonnées de l'auteur :`n`nNom : Anagou Reda`nTéléphone : 0542439514`n`nLe numéro 0542439514 a été copié dans votre presse-papiers !",
        "Contact & Support Auteur",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
} -BackColor [System.Drawing.Color]::White -HoverColor [System.Drawing.Color]::FromArgb(254, 243, 199) -PressColor [System.Drawing.Color]::FromArgb(253, 230, 138) -ForeColor [System.Drawing.Color]::FromArgb(180, 83, 9)
$btnSupportCall.Font = $fonts.Button
$btnSupportCall.Add_Paint({
    param($s, $e)
    $p = New-Object System.Drawing.Pen($script:colors.WarmCardBorder, 1.5)
    $e.Graphics.DrawRectangle($p, 0, 0, $s.Width - 1, $s.Height - 1)
    $p.Dispose()
})
$cardSupport.Controls.Add($btnSupportCall)

$yAbout += 130

# 3. Spécifications du Système Windows Détecté
$cardSpecs = New-ModernCard -Title "Spécifications du Système Windows Détecté" -Location (New-Object System.Drawing.Point(12, $yAbout)) -Size (New-Object System.Drawing.Size(890, 230)) -AccentLineColor $colors.AccentColor
$aboutTab.Scroll.Controls.Add($cardSpecs)

$sysSpecs = @(
    @{ Label = "Système d'exploitation :"; Val = "Windows $($winVer.Major).$($winVer.Minor) (Build $($winVer.Build))" },
    @{ Label = "Nom de la machine :"; Val = "$($env:COMPUTERNAME)" },
    @{ Label = "Utilisateur connecté :"; Val = "$($env:USERNAME)" },
    @{ Label = "Privilèges d'exécution :"; Val = if ($isAdmin) { "Élevé (Administrateur)" } else { "Standard (Limité)" } },
    @{ Label = "Architecture processeur :"; Val = "$($env:PROCESSOR_ARCHITECTURE) ($([System.Environment]::ProcessorCount) cœurs logiques)" },
    @{ Label = "Protection du binaire :"; Val = "Chiffré AES/XOR + In-Memory Execution (Zéro fuite disque)" }
)

$specY = 48
foreach ($spec in $sysSpecs) {
    $lblSpName = New-Object System.Windows.Forms.Label
    $lblSpName.Text = $spec.Label
    $lblSpName.Font = $fonts.SubTitle
    $lblSpName.ForeColor = $colors.ForeColor
    $lblSpName.Location = New-Object System.Drawing.Point(24, $specY)
    $lblSpName.Size = New-Object System.Drawing.Size(220, 22)
    $cardSpecs.Controls.Add($lblSpName)

    $lblSpVal = New-Object System.Windows.Forms.Label
    $lblSpVal.Text = $spec.Val
    $lblSpVal.Font = $fonts.Normal
    $lblSpVal.ForeColor = $colors.MutedColor
    $lblSpVal.Location = New-Object System.Drawing.Point(250, $specY)
    $lblSpVal.Size = New-Object System.Drawing.Size(600, 22)
    $cardSpecs.Controls.Add($lblSpVal)

    $specY += 28
}

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
    Select-NavPage -Index 9

    Set-RunningState -Running $true

    $modeText = if ($DryRun) { "SIMULATION (Dry-Run)" } else { "OPTIMISATION RÉELLE" }
    Append-Log "==================================================" "INFO"
    Append-Log "  DÉMARRAGE DE L'EXÉCUTION : $modeText" "INFO"
    Append-Log "  Langue active : $($script:CurrentLang)" "INFO"
    Append-Log "==================================================" "INFO"

    $hasDism = [bool]($script:CbDISM -and $script:CbDISM.Checked)
    $hasSfc = [bool]($script:CbSFC -and $script:CbSFC.Checked)
    $hasChkdsk = [bool]($script:CbChkdsk -and $script:CbChkdsk.Checked)

    $params = @{
        Language                 = $script:CurrentLang
        DryRun                   = $DryRun
        CreateRestorePoint       = [bool]($script:CbRestorePoint -and $script:CbRestorePoint.Checked)
        RemoveApps               = [bool]($script:CbApps -and $script:CbApps.Checked)
        AppsAllUsers             = [bool]($script:CbAppsAllUsers -and $script:CbAppsAllUsers.Checked)
        ConfigureServices        = [bool]($script:CbServices -and $script:CbServices.Checked)
        DisableTelemetryServices = [bool]($script:CbServicesSC -and $script:CbServicesSC.Checked)
        DisableTasks             = [bool]($script:CbTasks -and $script:CbTasks.Checked)
        PrivacyRegistry          = [bool]($script:CbPrivacyReg -and $script:CbPrivacyReg.Checked)
        DisableTelemetryGPO      = [bool]($script:CbGPO -and $script:CbGPO.Checked)
        BlockHosts               = [bool]($script:CbHosts -and $script:CbHosts.Checked)
        FirewallBlock            = [bool]($script:CbFirewall -and $script:CbFirewall.Checked)
        DiskCleanup              = [bool]($script:CbDisk -and $script:CbDisk.Checked)
        CleanRecycleBin          = [bool]($script:CbDiskRecycle -and $script:CbDiskRecycle.Checked)
        CleanWinUpdate           = [bool]($script:CbDiskWinUpdate -and $script:CbDiskWinUpdate.Checked)
        RegistryCleanup          = [bool]($script:CbRegClean -and $script:CbRegClean.Checked)
        RegCleanAggressive       = [bool]($script:CbRegAggressive -and $script:CbRegAggressive.Checked)
        SystemRepair             = [bool]($hasDism -or $hasSfc -or $hasChkdsk)
        RunDISM                  = $hasDism
        RunSFC                   = $hasSfc
        RunChkdsk                = $hasChkdsk
        OptimizeCPU              = [bool](($script:CbPowerPlan -and $script:CbPowerPlan.Checked) -or ($script:CbForegroundPriority -and $script:CbForegroundPriority.Checked) -or ($script:CbDisableCoreParking -and $script:CbDisableCoreParking.Checked))
        HighPerformancePower     = [bool]($script:CbPowerPlan -and $script:CbPowerPlan.Checked)
        ForegroundPriority       = [bool]($script:CbForegroundPriority -and $script:CbForegroundPriority.Checked)
        DisableCoreParking       = [bool]($script:CbDisableCoreParking -and $script:CbDisableCoreParking.Checked)
        StopBloatProcesses       = [bool]($script:CbAutoKillOnOptimize -and $script:CbAutoKillOnOptimize.Checked)
        OptimizeRAM              = $true
    }

    $backupNeeded = [bool](($script:CbPrivacyBackup -and $script:CbPrivacyBackup.Checked) -or ($script:CbHostsBackup -and $script:CbHostsBackup.Checked) -or ($script:CbRegBackup -and $script:CbRegBackup.Checked))
    Set-REDADZDOptimiserConfig -BackupRegistry $backupNeeded

    try {
        [System.Windows.Forms.Application]::DoEvents()
        $results = Invoke-REDADZDOptimiser @params

        Append-Log "=== RÉSUMÉ DE L'OPÉRATION ===" "INFO"
        if ($results.Apps) { Append-Log "Apps : $($results.Apps.Removed) supprimées, $($results.Apps.Failed) protégées, $($results.Apps.Skipped) ignorées" "SUCCESS" }
        if ($results.Services) { Append-Log "Services : $($results.Services.Changed) modifiés, $($results.Services.Failed) protégés, $($results.Services.Skipped) déjà configurés" "SUCCESS" }
        if ($results.Tasks) { Append-Log "Tâches : $($results.Tasks.Disabled) désactivées, $($results.Tasks.Failed) protégées" "SUCCESS" }
        if ($results.PrivacyRegistry) { Append-Log "Registre : $($results.PrivacyRegistry.Applied) clés appliquées, $($results.PrivacyRegistry.Failed) échecs" "SUCCESS" }
        if ($results.DiskCleanup) { Append-Log "Disque : ~$($results.DiskCleanup.FreedMB) Mo libérés" "SUCCESS" }
        if ($results.RegistryCleanup) { Append-Log "Registre nettoyé : $($results.RegistryCleanup.Cleaned) clés orphelines" "SUCCESS" }
        if ($results.SystemRepair) { Append-Log "DISM : $($results.SystemRepair.DISM) | SFC : $($results.SystemRepair.SFC) | Chkdsk : $($results.SystemRepair.Chkdsk)" "SUCCESS" }
        if ($results.RestorePoint) { Append-Log "Point de restauration : CRÉÉ ✓" "SUCCESS" }
        if ($results.CPU) { Append-Log "CPU : Plan=$($results.CPU.PowerPlan) | Priorité=$($results.CPU.PrioritySeparation)" "SUCCESS" }
        if ($results.Processes) { Append-Log "Processus fermés : $($results.Processes.TerminatedCount) processus" "SUCCESS" }
        if ($results.RAM) { Append-Log "RAM libérée : ~$($results.RAM.FreedMB) Mo" "SUCCESS" }

        Append-Log "" "INFO"
        Append-Log "✅ OPÉRATION TERMINÉE AVEC SUCCÈS - Redémarrage recommandé" "SUCCESS"
    } catch {
        Append-Log "ERREUR LORS DE L'EXÉCUTION : $_" "ERROR"
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

    # Lancement du diagnostic initial et recommandation intelligente
    Run-DiagnosticScan
    $initPreset = if ($script:CurrentDiag -and $script:CurrentDiag.Recommendation) { $script:CurrentDiag.Recommendation.Profile } else { "Standard" }
    Apply-Preset -Preset $initPreset
    Select-NavPage -Index 0

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
