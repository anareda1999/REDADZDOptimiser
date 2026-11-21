<#
.SYNOPSIS
    REDADZDOptimiser - Script d'optimisation Windows complet (Débloat + Nettoyage + Vie Privée)

.DESCRIPTION
    Ce script effectue une optimisation complète de Windows 10/11 :
    - Crée un point de restauration
    - Supprime les applications provisionnées inutiles (niveau équilibré)
    - Désactive les services et tâches de télémétrie
    - Configure le registre pour la vie privée
    - Nettoie le disque (temp, cache, logs, Windows Update)
    - Répare les fichiers système (DISM + SFC)
    - Bloque la télémétrie via hosts + pare-feu + GPO
    - Support multilingue : Français (FR), English (EN), العربية (AR)

.NOTES
    Niveau: Équilibré (garde Store, Defender, Mises à jour, stabilité)
    Exécution: PowerShell 5.1+ EN TANT QU'ADMINISTRATEUR
    Date: 2026

.EXEMPLE
    # Exécution normale (Français)
    .\REDADZDOptimiser.ps1

    # Exécution en Anglais / Arabe
    .\REDADZDOptimiser.ps1 -Language EN
    .\REDADZDOptimiser.ps1 -Language AR

    # Mode simulation (dry-run)
    .\REDADZDOptimiser.ps1 -DryRun

    # Exécution silencieuse
    .\REDADZDOptimiser.ps1 -Force
#>

#Requires -Version 5.1

[CmdletBinding(DefaultParameterSetName="Full")]
param(
    # Langue
    [Parameter(ParameterSetName="Full")]
    [Parameter(ParameterSetName="Custom")]
    [ValidateSet("FR", "EN", "AR", "fr", "en", "ar")]
    [string]$Language = "FR",

    # Mode d'exécution
    [Parameter(ParameterSetName="Full")]
    [Parameter(ParameterSetName="Custom")]
    [switch]$DryRun,

    [Parameter(ParameterSetName="Full")]
    [Parameter(ParameterSetName="Custom")]
    [switch]$Force,

    # Options modulaires (ParameterSetName="Custom")
    [Parameter(ParameterSetName="Custom", Mandatory=$false)]
    [switch]$OnlyDebloat,

    [Parameter(ParameterSetName="Custom", Mandatory=$false)]
    [switch]$OnlyCleanup,

    [Parameter(ParameterSetName="Custom", Mandatory=$false)]
    [switch]$OnlyPrivacy,

    [Parameter(ParameterSetName="Custom", Mandatory=$false)]
    [switch]$OnlyRepair,

    # Options individuelles pour contrôle fin
    [Parameter(ParameterSetName="Custom")]
    [switch]$SkipRestorePoint,

    [Parameter(ParameterSetName="Custom")]
    [switch]$SkipApps,

    [Parameter(ParameterSetName="Custom")]
    [switch]$SkipServices,

    [Parameter(ParameterSetName="Custom")]
    [switch]$SkipTasks,

    [Parameter(ParameterSetName="Custom")]
    [switch]$SkipRegistry,

    [Parameter(ParameterSetName="Custom")]
    [switch]$SkipDiskCleanup,

    [Parameter(ParameterSetName="Custom")]
    [switch]$EnableRegistryCleanup,

    [Parameter(ParameterSetName="Custom")]
    [switch]$SkipSystemRepair,

    [Parameter(ParameterSetName="Custom")]
    [switch]$SkipHostsBlock,

    [Parameter(ParameterSetName="Custom")]
    [switch]$SkipFirewall,

    [Parameter(ParameterSetName="Custom")]
    [switch]$SkipGPO,

    [Parameter(ParameterSetName="Custom")]
    [switch]$SkipSCServices,

    # Avancé
    [Parameter(ParameterSetName="Custom")]
    [switch]$VerboseOutput,

    [Parameter(ParameterSetName="Custom")]
    [string]$LogPath
)

$Language = $Language.ToUpper()

# ─── Dictionnaire de localisation CLI ──────────────────────────────────
$script:CLI_I18N = @{
    "FR" = @{
        BannerTitle     = "REDADZDOptimiser - Optimisation Windows 10/11"
        BannerSubtitle  = "Niveau: Équilibré (Sécurisé)"
        AdminError      = "ERREUR: Ce script doit être exécuté EN TANT QU'ADMINISTRATEUR"
        AdminHint       = "Cliquez-droit sur PowerShell > 'Exécuter en tant qu'administrateur'"
        WinVerWarning   = "Windows 10 build < 19041 détecté. Certaines fonctionnalités peuvent ne pas fonctionner."
        PsVerWarning    = "PowerShell < 5.1 détecté. Recommandé: PowerShell 5.1+ ou PowerShell 7+"
        ModuleMissing   = "Module core introuvable: "
        ModuleHint      = "Placez REDADZDOptimiserCore.psm1 dans le même dossier que ce script."
        ModuleLoading   = "Chargement du module core..."
        ModuleSuccess   = "Module chargé avec succès"
        SummaryTitle    = "ACTIONS PRÉVUES"
        SimMode         = "MODE SIMULATION (DRY-RUN) - AUCUNE MODIFICATION RÉELLE"
        RealMode        = "MODE EXÉCUTION RÉELLE - MODIFICATIONS PERMANENTES"
        WarnModify      = "⚠  CE SCRIPT VA MODIFIER VOTRE SYSTÈME WINDOWS"
        WarnRestore     = "   Un point de restauration sera créé automatiquement."
        WarnUndo        = "   Vous pourrez annuler les changements avec REDADZDOptimiser_Restore.ps1"
        ConfirmPrompt   = "Continuer ? (o/N)"
        Cancelled       = "Annulé par l'utilisateur."
        Starting        = "▶ DÉBUT DE L'OPTIMISATION..."
        SummaryResults  = "RÉSUMÉ D'EXÉCUTION"
        RebootWarn      = "⚠  REDÉMARRAGE RECOMMANDÉ pour appliquer tous les changements"
        Completed       = "✅ OPTIMISATION TERMINÉE"
    }
    "EN" = @{
        BannerTitle     = "REDADZDOptimiser - Windows 10/11 Optimization"
        BannerSubtitle  = "Level: Balanced (Safe)"
        AdminError      = "ERROR: This script must be run AS ADMINISTRATOR"
        AdminHint       = "Right-click PowerShell > 'Run as administrator'"
        WinVerWarning   = "Windows 10 build < 19041 detected. Some features may not work."
        PsVerWarning    = "PowerShell < 5.1 detected. Recommended: PowerShell 5.1+ or PowerShell 7+"
        ModuleMissing   = "Core module not found: "
        ModuleHint      = "Place REDADZDOptimiserCore.psm1 in the same directory as this script."
        ModuleLoading   = "Loading core module..."
        ModuleSuccess   = "Module loaded successfully"
        SummaryTitle    = "PLANNED ACTIONS"
        SimMode         = "SIMULATION MODE (DRY-RUN) - NO REAL CHANGES"
        RealMode        = "REAL EXECUTION MODE - PERMANENT CHANGES"
        WarnModify      = "⚠  THIS SCRIPT WILL MODIFY YOUR WINDOWS SYSTEM"
        WarnRestore     = "   A system restore point will be created automatically."
        WarnUndo        = "   You can undo changes using REDADZDOptimiser_Restore.ps1"
        ConfirmPrompt   = "Continue? (y/N)"
        Cancelled       = "Cancelled by user."
        Starting        = "▶ STARTING OPTIMIZATION..."
        SummaryResults  = "EXECUTION SUMMARY"
        RebootWarn      = "⚠  RESTART RECOMMENDED to apply all changes"
        Completed       = "✅ OPTIMIZATION COMPLETED"
    }
    "AR" = @{
        BannerTitle     = "REDADZDOptimiser - تحسين وتسريع ويندوز 10/11"
        BannerSubtitle  = "المستوى: متوازن (آمن ومستقر)"
        AdminError      = "خطأ: يجب تشغيل هذا البرنامج بصلاحيات المسؤول (ADMINISTRATOR)"
        AdminHint       = "انقر بزر الفأرة الأيمن على PowerShell واختر 'تشغيل كمسؤول'"
        WinVerWarning   = "تم اكتشاف إصدار ويندوز قديم. قد لا تعمل بعض الميزات."
        PsVerWarning    = "PowerShell أقدم من 5.1. يوصى بإصدار 5.1 أو أحدث."
        ModuleMissing   = "لم يتم العثور على وحدة النواة: "
        ModuleHint      = "يرجى وضع ملف REDADZDOptimiserCore.psm1 في نفس المجلد."
        ModuleLoading   = "جاري تحميل وحدة النواة..."
        ModuleSuccess   = "تم تحميل الوحدة بنجاح"
        SummaryTitle    = "الإجراءات المجدولة"
        SimMode         = "وضع المحاكاة (DRY-RUN) - لن يتم تطبيق أي تعديلات فعلية"
        RealMode        = "وضع التنفيذ الفعلي - سيتم تطبيق التعديلات الدائمة"
        WarnModify      = "⚠  هذا البرنامج سيقوم بتعديل إعدادات نظام ويندوز"
        WarnRestore     = "   سيتم إنشاء نقطة استعادة للنظام تلقائياً."
        WarnUndo        = "   يمكنك التراجع عن التعديلات بواسطة REDADZDOptimiser_Restore.ps1"
        ConfirmPrompt   = "هل تريد المتابعة؟ (y/N)"
        Cancelled       = "تم الإلغاء بواسطة المستخدم."
        Starting        = "▶ بدء عملية التحسين..."
        SummaryResults  = "ملخص التنفيذ"
        RebootWarn      = "⚠  يوصى بإعادة تشغيل الجهاز لتطبيق كافة التغييرات"
        Completed       = "✅ اكتملت عملية التحسين بنجاح"
    }
}

$str = $script:CLI_I18N[$Language]
if (-not $str) { $str = $script:CLI_I18N["FR"] }

# ─── Vérifications préliminaires ────────────────────────────────────────
function Test-Prerequisites {
    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           $($str.BannerTitle.PadRight(50))   ║" -ForegroundColor Cyan
    Write-Host "║           $($str.BannerSubtitle.PadRight(50))   ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

    # Vérifier Admin
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error $str.AdminError
        Write-Host $str.AdminHint -ForegroundColor Yellow
        exit 1
    }

    # Vérifier version Windows
    $osVersion = [System.Environment]::OSVersion.Version
    $build = $osVersion.Build
    Write-Host "Windows Version: $($osVersion.Major).$($osVersion.Minor).$build" -ForegroundColor Gray

    if ($build -lt 19041) {
        Write-Warning $str.WinVerWarning
    }

    # Vérifier PowerShell
    $psVersion = $PSVersionTable.PSVersion.Major
    if ($psVersion -lt 5) {
        Write-Warning $str.PsVerWarning
    }

    # Vérifier module core
    if (-not $PSScriptRoot) {
        $PSScriptRoot = if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
    }
    $modulePath = Join-Path $PSScriptRoot "REDADZDOptimiserCore.psm1"
    if (-not (Test-Path $modulePath)) {
        $modulePath = Join-Path (Get-Location).Path "REDADZDOptimiserCore.psm1"
    }
    if (-not (Test-Path $modulePath)) {
        Write-Error "$($str.ModuleMissing)$modulePath"
        Write-Host $str.ModuleHint -ForegroundColor Yellow
        exit 1
    }

    return $true
}

# ─── Chargement du module ──────────────────────────────────────────────
function Load-CoreModule {
    if (-not $PSScriptRoot) {
        $PSScriptRoot = if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
    }
    $modulePath = Join-Path $PSScriptRoot "REDADZDOptimiserCore.psm1"
    if (-not (Test-Path $modulePath)) {
        $modulePath = Join-Path (Get-Location).Path "REDADZDOptimiserCore.psm1"
    }
    Write-Host $str.ModuleLoading -ForegroundColor Gray
    Import-Module $modulePath -Force -ErrorAction Stop
    Write-Host "$($str.ModuleSuccess)`n" -ForegroundColor Green
}

# ─── Affichage résumé des actions ───────────────────────────────────────
function Show-ActionSummary {
    param($Params)

    Write-Host "`n┌────────────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "│                    $($str.SummaryTitle.PadRight(43))   │" -ForegroundColor Cyan
    Write-Host "├────────────────────────────────────────────────────────────────┤" -ForegroundColor Cyan

    $actions = @()
    if ($Params.CreateRestorePoint) { $actions += "✓ Restore Point" }
    if ($Params.RemoveApps) { $actions += "✓ Remove Bloatware Apps" }
    if ($Params.ConfigureServices) { $actions += "✓ Disable Telemetry Services" }
    if ($Params.DisableTasks) { $actions += "✓ Disable Telemetry Tasks" }
    if ($Params.PrivacyRegistry) { $actions += "✓ Privacy Registry Tweaks" }
    if ($Params.DisableTelemetryGPO) { $actions += "✓ Apply Anti-Telemetry GPOs" }
    if ($Params.DisableTelemetryServices) { $actions += "✓ Disable Telemetry via SC" }
    if ($Params.BlockHosts) { $actions += "✓ Block Telemetry Domains in Hosts" }
    if ($Params.FirewallBlock) { $actions += "✓ Outbound Firewall Rules" }
    if ($Params.DiskCleanup) { $actions += "✓ Clean Temporary Files & Updates" }
    if ($Params.RegistryCleanup) { $actions += "⚠ Registry Cleanup (Orphaned Keys)" }
    if ($Params.SystemRepair) { $actions += "✓ System Repair (DISM + SFC)" }

    foreach ($action in $actions) {
        Write-Host "│ $action" -ForegroundColor White
    }

    Write-Host "├────────────────────────────────────────────────────────────────┤" -ForegroundColor Cyan
    if ($Params.DryRun) {
        Write-Host "│ $($str.SimMode.PadRight(62)) │" -ForegroundColor Yellow
    } else {
        Write-Host "│ $($str.RealMode.PadRight(62)) │" -ForegroundColor Red
    }
    Write-Host "└────────────────────────────────────────────────────────────────┘`n" -ForegroundColor Cyan
}

# ─── Confirmation utilisateur ──────────────────────────────────────────
function Confirm-Execution {
    param($Force, $DryRun)

    if ($Force -or $DryRun) { return $true }

    Write-Host $str.WarnModify -ForegroundColor Red
    Write-Host $str.WarnRestore -ForegroundColor Yellow
    Write-Host $str.WarnUndo -ForegroundColor Yellow
    Write-Host ""

    $confirm = Read-Host $str.ConfirmPrompt
    return ($confirm -eq "o" -or $confirm -eq "O" -or $confirm -eq "y" -or $confirm -eq "Y" -or $confirm -eq "ن")
}

# ─── Construction paramètres selon ParameterSet ────────────────────────
function Build-Parameters {
    param(
        $ParameterSetName,
        $Force,
        $DryRun,
        $VerboseOutput,
        $LogPath,
        $OnlyDebloat,
        $OnlyCleanup,
        $OnlyPrivacy,
        $OnlyRepair,
        $SkipRestorePoint,
        $SkipApps,
        $SkipServices,
        $SkipTasks,
        $SkipRegistry,
        $SkipDiskCleanup,
        $EnableRegistryCleanup,
        $SkipSystemRepair,
        $SkipHostsBlock,
        $SkipFirewall,
        $SkipGPO,
        $SkipSCServices
    )

    $params = @{
        CreateRestorePoint       = $true
        RemoveApps               = $true
        ConfigureServices        = $true
        DisableTasks             = $true
        PrivacyRegistry          = $true
        DiskCleanup              = $true
        RegistryCleanup          = $false
        SystemRepair             = $true
        BlockHosts               = $true
        FirewallBlock            = $true
        DisableTelemetryGPO      = $true
        DisableTelemetryServices = $true
        DryRun                   = $DryRun
        Verbose                  = $VerboseOutput -or $DryRun
    }

    if ($ParameterSetName -eq "Custom") {
        $params.CreateRestorePoint       = -not $SkipRestorePoint
        $params.RemoveApps               = -not $SkipApps
        $params.ConfigureServices        = -not $SkipServices
        $params.DisableTasks             = -not $SkipTasks
        $params.PrivacyRegistry          = -not $SkipRegistry
        $params.DiskCleanup              = -not $SkipDiskCleanup
        $params.RegistryCleanup          = $EnableRegistryCleanup
        $params.SystemRepair             = -not $SkipSystemRepair
        $params.BlockHosts               = -not $SkipHostsBlock
        $params.FirewallBlock            = -not $SkipFirewall
        $params.DisableTelemetryGPO      = -not $SkipGPO
        $params.DisableTelemetryServices = -not $SkipSCServices

        if ($OnlyDebloat) {
            $params.RemoveApps = $true
            $params.ConfigureServices = $true
            $params.DisableTasks = $true
            $params.PrivacyRegistry = $true
            $params.DisableTelemetryGPO = $true
            $params.DisableTelemetryServices = $true
            $params.BlockHosts = $true
            $params.FirewallBlock = $true
            $params.DiskCleanup = $false
            $params.SystemRepair = $false
            $params.CreateRestorePoint = $true
        }
        if ($OnlyCleanup) {
            $params.DiskCleanup = $true
            $params.SystemRepair = $true
            $params.RemoveApps = $false
            $params.ConfigureServices = $false
            $params.DisableTasks = $false
            $params.PrivacyRegistry = $false
            $params.DisableTelemetryGPO = $false
            $params.DisableTelemetryServices = $false
            $params.BlockHosts = $false
            $params.FirewallBlock = $false
        }
        if ($OnlyPrivacy) {
            $params.PrivacyRegistry = $true
            $params.DisableTelemetryGPO = $true
            $params.DisableTelemetryServices = $true
            $params.BlockHosts = $true
            $params.FirewallBlock = $true
            $params.RemoveApps = $false
            $params.ConfigureServices = $false
            $params.DiskCleanup = $false
            $params.SystemRepair = $false
        }
        if ($OnlyRepair) {
            $params.SystemRepair = $true
            if (-not $OnlyCleanup) {
                $params.DiskCleanup = $false
            }
            $params.RemoveApps = $false
            $params.ConfigureServices = $false
            $params.PrivacyRegistry = $false
            $params.DisableTelemetryGPO = $false
            $params.DisableTelemetryServices = $false
            $params.BlockHosts = $false
            $params.FirewallBlock = $false
        }
    }

    if ($LogPath) {
        $script:Config.LogPath = $LogPath
    }

    return $params
}

# ─── Affichage résultats ────────────────────────────────────────────────
function Show-Results {
    param($Results)

    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                    $($str.SummaryResults.PadRight(42)) ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green

    if ($Results.Apps) {
        Write-Host "Apps: $($Results.Apps.Removed) removed, $($Results.Apps.Failed) failed, $($Results.Apps.Skipped) skipped" -ForegroundColor Cyan
    }
    if ($Results.Services) {
        Write-Host "Services: $($Results.Services.Changed) changed, $($Results.Services.Failed) failed, $($Results.Services.Skipped) skipped" -ForegroundColor Cyan
    }
    if ($Results.Tasks) {
        Write-Host "Tasks: $($Results.Tasks.Disabled) disabled, $($Results.Tasks.Failed) failed, $($Results.Tasks.NotFound) not found" -ForegroundColor Cyan
    }
    if ($Results.PrivacyRegistry) {
        Write-Host "Registry: $($Results.PrivacyRegistry.Applied) applied, $($Results.PrivacyRegistry.Failed) failed" -ForegroundColor Cyan
    }
    if ($Results.DiskCleanup) {
        Write-Host "Disk: ~$($Results.DiskCleanup.FreedMB) MB freed, $($Results.DiskCleanup.Cleaned) folders cleaned" -ForegroundColor Cyan
    }
    if ($Results.RegistryCleanup) {
        Write-Host "Registry cleanup: $($Results.RegistryCleanup.Cleaned) keys, $($Results.RegistryCleanup.Failed) failed" -ForegroundColor Cyan
    }
    if ($Results.SystemRepair) {
        Write-Host "DISM: $($Results.SystemRepair.DISM) | SFC: $($Results.SystemRepair.SFC) | Chkdsk: $($Results.SystemRepair.Chkdsk)" -ForegroundColor Cyan
    }
    if ($Results.RestorePoint -eq $true) {
        Write-Host "Restore Point: CREATED ✓" -ForegroundColor Green
    }
    if ($Results.CPU) {
        Write-Host "CPU: Power plan=$($Results.CPU.PowerPlan) - Priority=$($Results.CPU.PrioritySeparation)" -ForegroundColor Cyan
    }
    if ($Results.Processes) {
        Write-Host "Processes: $($Results.Processes.TerminatedCount) stopped" -ForegroundColor Cyan
    }
    if ($Results.RAM) {
        Write-Host "RAM: ~$($Results.RAM.FreedMB) MB freed" -ForegroundColor Cyan
    }

    Write-Host "`nLog: $($script:Config.LogPath)" -ForegroundColor Gray
    Write-Host "`n$($str.RebootWarn)" -ForegroundColor Yellow
}

# ─── Point d'entrée principal ──────────────────────────────────────────
try {
    Test-Prerequisites

    Load-CoreModule

    $execParams = Build-Parameters `
        -ParameterSetName $PSCmdlet.ParameterSetName `
        -Force $Force `
        -DryRun $DryRun `
        -VerboseOutput $VerboseOutput `
        -LogPath $LogPath `
        -OnlyDebloat $OnlyDebloat `
        -OnlyCleanup $OnlyCleanup `
        -OnlyPrivacy $OnlyPrivacy `
        -OnlyRepair $OnlyRepair `
        -SkipRestorePoint $SkipRestorePoint `
        -SkipApps $SkipApps `
        -SkipServices $SkipServices `
        -SkipTasks $SkipTasks `
        -SkipRegistry $SkipRegistry `
        -SkipDiskCleanup $SkipDiskCleanup `
        -EnableRegistryCleanup $EnableRegistryCleanup `
        -SkipSystemRepair $SkipSystemRepair `
        -SkipHostsBlock $SkipHostsBlock `
        -SkipFirewall $SkipFirewall `
        -SkipGPO $SkipGPO `
        -SkipSCServices $SkipSCServices

    Show-ActionSummary -Params $execParams

    if (-not (Confirm-Execution -Force $Force -DryRun $DryRun)) {
        Write-Host $str.Cancelled -ForegroundColor Yellow
        exit 0
    }

    Write-Host "`n$($str.Starting)" -ForegroundColor Green
    $results = Invoke-REDADZDOptimiser @execParams

    Show-Results -Results $results

    Write-Host "`n$($str.Completed)" -ForegroundColor Green

} catch {
    Write-Error "ERREUR FATALE: $_"
    Write-Host "`nConsultez le log: $($script:Config.LogPath)" -ForegroundColor Red
    exit 1
}
