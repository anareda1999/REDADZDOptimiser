# Build_REDADZDOptimiser_EXE.ps1
# Compile REDADZDOptimiser en exécutable autonome .exe avec auto-élévation Admin et Copyright
# Auteur : Anagou Reda (0542439514)

[CmdletBinding()]
param()

$baseDir = $PSScriptRoot
if (-not $baseDir) { $baseDir = (Get-Location).Path }

Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        Compilation de REDADZDOptimiser.exe (C# / .NET)        ║" -ForegroundColor Cyan
Write-Host "║       © 2026 Anagou Reda - Contact : 0542439514              ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$cscPath = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $cscPath)) {
    $cscPath = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe"
}
if (-not (Test-Path $cscPath)) {
    Write-Error "Compilateur C# csc.exe introuvable sur cette machine."
    exit 1
}

$tempSrc = Join-Path $baseDir "REDADZDOptimiser_Runner.cs"
$manifestPath = Join-Path $baseDir "app.manifest"
$outputExe = Join-Path $baseDir "REDADZDOptimiser.exe"

# Manifeste Windows avec demande automatique de privilèges administrateur (UAC)
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

# Code C# du lanceur autonome
$csCode = @'
using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Reflection;
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
        [STAThread]
        static void Main(string[] args) {
            try {
                ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072 | (SecurityProtocolType)768; // Tls12 | Tls11
                string appDir = AppDomain.CurrentDomain.BaseDirectory;
                string localGui = Path.Combine(appDir, "REDADZDOptimiserGUI.ps1");

                string targetGui = localGui;

                // Si les fichiers scripts ne sont pas dans le dossier local, téléchargement vers %TEMP%
                if (!File.Exists(localGui)) {
                    string tempDir = Path.Combine(Path.GetTempPath(), "REDADZDOptimiser");
                    if (!Directory.Exists(tempDir)) Directory.CreateDirectory(tempDir);
                    targetGui = Path.Combine(tempDir, "REDADZDOptimiserGUI.ps1");

                    string baseUrl = "https://raw.githubusercontent.com/anareda1999/REDADZDOptimiser/main/";
                    string[] files = new string[] {
                        "REDADZDOptimiserGUI.ps1",
                        "REDADZDOptimiserCore.psm1",
                        "REDADZDOptimiser.ps1",
                        "REDADZDOptimiser_Restore.ps1"
                    };

                    using (WebClient client = new WebClient()) {
                        foreach (var f in files) {
                            string dest = Path.Combine(tempDir, f);
                            try {
                                client.DownloadFile(baseUrl + f, dest);
                            } catch { }
                        }
                    }
                }

                if (!File.Exists(targetGui)) {
                    MessageBox.Show("Fichier REDADZDOptimiserGUI.ps1 introuvable.", "Erreur", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return;
                }

                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = "powershell.exe";
                psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + targetGui + "\"";
                psi.UseShellExecute = true;
                psi.Verb = "runas";

                Process.Start(psi);
            } catch (Exception ex) {
                MessageBox.Show("Erreur au lancement : " + ex.Message, "REDADZDOptimiser", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
    }
}
'@
[System.IO.File]::WriteAllText($tempSrc, $csCode, [System.Text.Encoding]::UTF8)

Write-Host "Compilation de $outputExe..." -ForegroundColor Yellow
$compileArgs = @(
    "/target:winexe",
    "/optimize+",
    "/platform:anycpu",
    "/win32manifest:`"$manifestPath`"",
    "/r:System.dll,System.Windows.Forms.dll",
    "/out:`"$outputExe`"",
    "`"$tempSrc`""
)

$proc = Start-Process -FilePath $cscPath -ArgumentList ($compileArgs -join " ") -NoNewWindow -Wait -PassThru

# Nettoyage des fichiers intermédiaires
if (Test-Path $tempSrc) { Remove-Item $tempSrc -Force }
if (Test-Path $manifestPath) { Remove-Item $manifestPath -Force }

if ($proc.ExitCode -eq 0 -and (Test-Path $outputExe)) {
    $info = Get-Item $outputExe
    Write-Host "`n✅ Exécutable généré avec succès !" -ForegroundColor Green
    Write-Host "Fichier : $($info.FullName) ($([math]::Round($info.Length / 1KB, 1)) Ko)" -ForegroundColor Cyan
    Write-Host "Double-cliquez directement sur REDADZDOptimiser.exe pour lancer l'optimiseur avec élévation UAC automatique.`n" -ForegroundColor White
} else {
    Write-Error "Échec de la compilation (Code sortie: $($proc.ExitCode))"
}
