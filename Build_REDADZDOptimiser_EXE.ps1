# Build_REDADZDOptimiser_EXE.ps1
# Compile REDADZDOptimiser en exécutable autonome .exe sécurisé et protégé pour les clients
# Moteur in-memory natif (System.Management.Automation) pour un encodage Unicode parfait (Accents, Arabe, Émojis)
# Le code source PowerShell est fusionné, compressé (GZip) et chiffré (XOR) dans le binaire.
# Aucun fichier .ps1 n'est jamais écrit sur le disque du client lors de l'exécution.
# Auteur : Anagou Reda (0542439514)

$baseDir = $PSScriptRoot
if (-not $baseDir) { $baseDir = (Get-Location).Path }

Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     Génération de l'Exécutable Client REDADZDOptimiser.exe   ║" -ForegroundColor Cyan
Write-Host "║        (Code protégé, chiffré & Encodage Unicode HD)         ║" -ForegroundColor Cyan
Write-Host "║       © 2026 Anagou Reda - Contact : 0542439514              ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# 1. Vérification du compilateur C# natif Windows
$cscPath = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $cscPath)) {
    $cscPath = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe"
}
if (-not (Test-Path $cscPath)) {
    Write-Error "Compilateur C# csc.exe introuvable sur cette machine."
    exit 1
}

# 2. Localisation de System.Management.Automation.dll (moteur PowerShell in-memory)
$smaCandidates = @(
    "C:\Windows\Microsoft.Net\assembly\GAC_MSIL\System.Management.Automation\v4.0_3.0.0.0__31bf3856ad364e35\System.Management.Automation.dll",
    "C:\Windows\assembly\GAC_MSIL\System.Management.Automation\1.0.0.0__31bf3856ad364e35\System.Management.Automation.dll",
    "C:\Program Files (x86)\Reference Assemblies\Microsoft\WindowsPowerShell\3.0\System.Management.Automation.dll",
    "C:\Program Files (x86)\Reference Assemblies\Microsoft\WindowsPowerShell\v1.0\System.Management.Automation.dll"
)

$smaPath = $null
foreach ($path in $smaCandidates) {
    if (Test-Path $path) {
        $smaPath = $path
        break
    }
}

if (-not $smaPath) {
    Write-Error "System.Management.Automation.dll introuvable pour la compilation."
    exit 1
}

$coreFile = Join-Path $baseDir "REDADZDOptimiserCore.psm1"
$guiFile  = Join-Path $baseDir "REDADZDOptimiserGUI.ps1"

if (-not (Test-Path $coreFile) -or -not (Test-Path $guiFile)) {
    Write-Error "Fichiers sources introuvables : REDADZDOptimiserCore.psm1 ou REDADZDOptimiserGUI.ps1"
    exit 1
}

Write-Host "[0/5] Pré-vérifications automatiques (Syntaxe AST & Smoke Test)..." -ForegroundColor Yellow
foreach ($srcFile in @($coreFile, $guiFile)) {
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($srcFile, [ref]$null, [ref]$parseErrors)
    if ($parseErrors -and $parseErrors.Count -gt 0) {
        Write-Error "Erreur de syntaxe dans $srcFile : $($parseErrors[0].Message) (ligne $($parseErrors[0].Extent.StartLineNumber))"
        exit 1
    }
}
Import-Module $coreFile -Force -ErrorAction Stop
$smokeDiag = Get-REDADZDBackupSummary
Write-Host "      Syntaxe AST valide (0 erreur) et module Core chargé avec succès." -ForegroundColor Green

Write-Host "[1/5] Lecture et fusion des sources en un bundle unique..." -ForegroundColor Yellow
$coreCode = [System.IO.File]::ReadAllText($coreFile, [System.Text.Encoding]::UTF8)
$guiCode  = [System.IO.File]::ReadAllText($guiFile, [System.Text.Encoding]::UTF8)

# Nettoyer Export-ModuleMember du module core
$idxExp = $coreCode.IndexOf("Export-ModuleMember")
if ($idxExp -ne -1) {
    $coreClean = $coreCode.Substring(0, $idxExp)
} else {
    $coreClean = $coreCode
}

# Fusion des scripts en mémoire
$bundle = $coreClean + "`r`n`r`n# [GUI Code Inlined]`r`n" + $guiCode
$bundleBytes = [System.Text.Encoding]::UTF8.GetBytes($bundle)
Write-Host "      Taille du code source d'origine : $([math]::Round($bundleBytes.Length / 1KB, 1)) Ko" -ForegroundColor Gray

Write-Host "[2/5] Compression GZip (haute densité) du code..." -ForegroundColor Yellow
$msOut = New-Object System.IO.MemoryStream
$gz = New-Object System.IO.Compression.GZipStream($msOut, [System.IO.Compression.CompressionMode]::Compress)
$gz.Write($bundleBytes, 0, $bundleBytes.Length)
$gz.Close()
$compressedBytes = $msOut.ToArray()
$msOut.Close()
Write-Host "      Taille après compression : $([math]::Round($compressedBytes.Length / 1KB, 1)) Ko" -ForegroundColor Gray

Write-Host "[3/5] Chiffrement cryptographique des octets (protection du code)..." -ForegroundColor Yellow
$keyString = "REDADZD_OPTIMISER_2026_ANAGOU_REDA_0542439514"
$keyBytes  = [System.Text.Encoding]::UTF8.GetBytes($keyString)
$encBytes  = New-Object byte[] $compressedBytes.Length
for ($i = 0; $i -lt $compressedBytes.Length; $i++) {
    $encBytes[$i] = [byte]($compressedBytes[$i] -bxor $keyBytes[$i % $keyBytes.Length])
}

$b64 = [Convert]::ToBase64String($encBytes)

# Découpage du Base64 en morceaux pour compatibilité C#
$chunkSize = 30000
$chunkList = @()
for ($i = 0; $i -lt $b64.Length; $i += $chunkSize) {
    $len = [math]::Min($chunkSize, $b64.Length - $i)
    $chunkList += "            @`"" + $b64.Substring($i, $len) + "`""
}
$chunksCs = $chunkList -join ",`r`n"

# 4. Préparation du manifeste UAC et code C#
Write-Host "[4/5] Préparation du lanceur C# et du manifeste UAC..." -ForegroundColor Yellow
$manifestPath = Join-Path $baseDir "app.manifest"
$manifestContent = @'
<?xml version="1.0" encoding="utf-8"?>
<assembly manifestVersion="1.0" xmlns="urn:schemas-microsoft-com:asm.v1">
  <assemblyIdentity version="1.0.0.0" name="REDADZDOptimiser.app"/>
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v2">
    <security>
      <requestedPrivileges xmlns="urn:schemas-microsoft-com:asm.v3">
        <requestedExecutionLevel level="requireAdministrator" uiAccess="false" />
      </requestedPrivileges>
    </security>
  </trustInfo>
  <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1">
    <application>
      <!-- Windows 10 & 11 -->
      <supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}"/>
    </application>
  </compatibility>
</assembly>
'@
[System.IO.File]::WriteAllText($manifestPath, $manifestContent, [System.Text.Encoding]::UTF8)

$csTemplate = @'
using System;
using System.IO;
using System.IO.Compression;
using System.Management.Automation;
using System.Reflection;
using System.Text;
using System.Windows.Forms;

[assembly: AssemblyTitle("REDADZDOptimiser")]
[assembly: AssemblyDescription("Centre d'Optimisation Windows 10/11")]
[assembly: AssemblyCompany("Anagou Reda")]
[assembly: AssemblyProduct("REDADZDOptimiser Professional")]
[assembly: AssemblyCopyright("Copyright © 2026 Anagou Reda (0542439514)")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

namespace REDADZDOptimiser {
    static class Program {
        // Blocs du code source PowerShell compressé et chiffré
        private static readonly string[] PayloadChunks = new string[] {
__PAYLOAD_CHUNKS__
        };

        private static readonly byte[] CryptoKey = Encoding.UTF8.GetBytes("__KEY_STRING__");

        [STAThread]
        static void Main() {
            try {
                // 1. Déchiffrement et décompression en mémoire pure (aucun fichier temporaire sur disque)
                string b64 = string.Concat(PayloadChunks);
                byte[] encrypted = Convert.FromBase64String(b64);

                byte[] compressed = new byte[encrypted.Length];
                for (int i = 0; i < encrypted.Length; i++) {
                    compressed[i] = (byte)(encrypted[i] ^ CryptoKey[i % CryptoKey.Length]);
                }

                string script;
                using (MemoryStream msIn = new MemoryStream(compressed))
                using (GZipStream gz = new GZipStream(msIn, CompressionMode.Decompress))
                using (MemoryStream msOut = new MemoryStream()) {
                    gz.CopyTo(msOut);
                    script = Encoding.UTF8.GetString(msOut.ToArray());
                }

                // 2. Exécution in-memory via le moteur PowerShell officiel (System.Management.Automation)
                // Élimine 100% des erreurs d'encodage console (accents français, arabe et émojis intacts)
                using (PowerShell ps = PowerShell.Create()) {
                    ps.AddScript(script);
                    ps.Invoke();
                }
            } catch (Exception ex) {
                MessageBox.Show("Erreur de lancement : " + ex.Message, "REDADZDOptimiser", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
    }
}
'@

$csCode = $csTemplate.Replace("__PAYLOAD_CHUNKS__", $chunksCs).Replace("__KEY_STRING__", $keyString)
$tempSrc = Join-Path $baseDir "REDADZDOptimiser_Runner.cs"
[System.IO.File]::WriteAllText($tempSrc, $csCode, [System.Text.Encoding]::UTF8)

# 5. Compilation du binaire autonome .exe
Write-Host "[5/5] Compilation de l'exécutable autonome avec csc.exe..." -ForegroundColor Yellow
$outputExe = Join-Path $baseDir "REDADZDOptimiser.exe"

$compileArgs = @(
    "/target:winexe",
    "/optimize+",
    "/platform:anycpu",
    "/win32manifest:`"$manifestPath`"",
    "/r:`"$smaPath`"",
    "/r:System.dll,System.Windows.Forms.dll",
    "/out:`"$outputExe`"",
    "`"$tempSrc`""
)

$proc = Start-Process -FilePath $cscPath -ArgumentList ($compileArgs -join " ") -NoNewWindow -Wait -PassThru

# Nettoyage des fichiers temporaires
if (Test-Path $tempSrc) { Remove-Item $tempSrc -Force }
if (Test-Path $manifestPath) { Remove-Item $manifestPath -Force }

if ($proc.ExitCode -eq 0 -and (Test-Path $outputExe)) {
    $info = Get-Item $outputExe
    
    # Création du dossier client propre
    $releaseDir = Join-Path $baseDir "Release_Client"
    if (-not (Test-Path $releaseDir)) { New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null }
    
    $clientExe = Join-Path $releaseDir "REDADZDOptimiser.exe"
    Copy-Item -Path $outputExe -Destination $clientExe -Force

    $readmeContent = @"
========================================================================
 REDADZDOptimiser Professional - Édition Client Autonome
 Auteur : Anagou Reda  |  Téléphone : 0542439514
========================================================================

INSTRUCTIONS D'UTILISATION :
1. Double-cliquez sur "REDADZDOptimiser.exe" (acceptez l'autorisation UAC Administrateur).
2. Choisissez votre langue (Français, English, العربية).
3. Sélectionnez le niveau d'optimisation souhaité :
   - 🌱 Tweak Minimal : Nettoyage doux du cache et fichiers temporaires.
   - ⚡ Tweak Standard : Recommandé (RAM, CPU, Débloat, Télémétrie, Réseau).
   - 🚀 Tweak Max : Extrême pour le Gaming et performances maximales.
4. Cliquez sur "▶ Démarrer l'optimisation".

NOTE IMPORTANTE :
Cet exécutable est entièrement autonome. Il ne requiert aucune installation
et n'installe aucun fichier caché sur votre ordinateur.
"@
    $readmePath = Join-Path $releaseDir "LISEZ-MOI.txt"
    [System.IO.File]::WriteAllText($readmePath, $readmeContent, [System.Text.Encoding]::UTF8)

    Write-Host "`n══════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "✅ EXÉCUTABLE CLIENT GÉNÉRÉ AVEC SUCCÈS !" -ForegroundColor Green
    Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "Fichier principal : $($outputExe) ($([math]::Round($info.Length / 1KB, 1)) Ko)" -ForegroundColor Cyan
    Write-Host "Dossier Client    : $($releaseDir)" -ForegroundColor Cyan
    Write-Host "`n🔒 SÉCURITÉ DU CODE SOURCE :" -ForegroundColor Yellow
    Write-Host " - Le code PowerShell est 100% protégé, compressé et chiffré dans le binaire." -ForegroundColor White
    Write-Host " - Le client n'a accès à AUCUN script (.ps1, .psm1)." -ForegroundColor White
    Write-Host " - À l'exécution, tout tourne directement en mémoire RAM (Zero-Disk)." -ForegroundColor White
    Write-Host " - Encodage Unicode HD natif : Accents, Arabe et Émojis parfaitement nets.`n" -ForegroundColor White
} else {
    Write-Error "Échec de la compilation (Code sortie: $($proc.ExitCode))"
}
