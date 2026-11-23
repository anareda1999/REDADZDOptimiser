# REDADZDOptimiser Professional - Optimisation Windows 10/11 (FR / EN / AR)

Un ensemble d'outils professionnel pour **optimiser**, **nettoyer**, **sécuriser** et **réparer** Windows 10 et 11.
Doté d'une interface graphique moderne, claire et élégante (inspirée de **Windows 11 Fluent Design / Slate Pro**) : fond lumineux et épuré, cartes blanches avec liserés d'accentuation, typographie sombre haute lisibilité et boutons d'action ergonomiques.
Supporte trois langues : **Français (FR)**, **English (EN)** et **العربية (AR)** avec affichage stable.

---

## 🎨 Nouveau Design Professionnel & Clair (Windows 11 Fluent)

- **Canvas & Arrière-plan :** Fond gris clair moderne et épuré (`#F1F5F9` - Slate 100), reposant pour les yeux et contrasté.
- **Cartes de Sections :** Cartes blanches pures (`#FFFFFF`) avec bordures fines élégantes (`#E2E8F0`) et liseré supérieur d'accentuation coloré (Indigo, Bleu azur, Émeraude).
- **Navigation par Onglets :** Onglets larges (160 px), fond blanc pour l'onglet actif avec barre d'accentuation Bleu Royal (`#2563EB`) de 3 px.
- **Typographie :** Texte foncé haute lisibilité (`#0F172A` - Slate 900) et descriptions secondaires ardoise (`#64748B`).
- **Badges d'État Modernes :** Badge administrateur pastille vert menthe doux (`#ECFDF5` / `#047857`) ou rouge pâle (`#FEF2F2` / `#B91C1C`).
- **Boutons d'Action Ergonomiques :**
  - ▶ **OPTIMISER MAINTENANT** en Vert Émeraude Pro (`#10B981`)
  - 🔍 **Simulation (Dry-Run)** en Ambre Chaleureux (`#D97706`)
  - ✕ **Annuler** en Rouge Corail (`#DC2626`)
- **Console Développeur (Journal) :** Terminal bleu nuit profond (`#0F172A`) avec coloration syntaxique (`[SUCCESS]` en vert émeraude, `[WARN]` en ambre, `[ERROR]` en rouge corail).

---


## 📦 Nouvelles Fonctionnalités Majeures

### 1. 📦 Installateur de Logiciels Essentiels (Winget)
Installez vos applications favorites en un seul clic via le gestionnaire officiel Microsoft Winget :
- **Navigateurs :** Google Chrome, Brave Browser, Mozilla Firefox, Opera GX.
- **Utilitaires :** 7-Zip, WinRAR, VLC Media Player, Notepad++, Microsoft PowerToys.
- **Gaming & Streaming :** Steam, Discord, Epic Games Launcher, OBS Studio.
- **Bureautique & Dev :** Visual Studio Code, LibreOffice, Adobe Acrobat Reader, AnyDesk.

### 2. 🌐 Optimiseur Réseau, Ping & DNS Gaming
- **Sélecteur DNS en 1 clic :** Basculez instantanément entre **Cloudflare (1.1.1.1)**, **Google DNS (8.8.8.8)**, **Quad9 (9.9.9.9)** ou le DNS automatique de votre FAI (DHCP).
- **Tweaks TCP/IP Gaming :** Désactivation de la limitation de bande passante multimédia (*NetworkThrottlingIndex*) et de l'algorithme Nagle (*TcpAckFrequency & TCPNoDelay*) pour éliminer la latence et stabiliser le ping en jeu.
- **Réinitialisation Réseau :** Vidage du cache DNS (`ipconfig /flushdns`) et réinitialisation complète de la pile Winsock / IP pour réparer les erreurs de connexion.

### 3. 🚀 Gestionnaire de Démarrage Windows (Startup Manager)
- Affiche en direct tous les logiciels qui se lancent au démarrage de Windows (Registre HKCU/HKLM et dossiers Startup).
- Permet de désactiver en un clic les applications superflues pour réduire le temps de démarrage du PC à moins de 8 secondes.

---

## 🎛️ Préréglages d'Optimisation Rapide (Menu Horizontal)

L'interface graphique intègre désormais un **sélecteur de profils horizontal** au sommet des onglets permettant d'ajuster automatiquement les cases à cocher en un seul clic :

1. **🌱 Tweak Minimal (Léger & Sécurisé) :**
   - *Pour :* Bureautique, télétravail, utilisateurs prudents voulant préserver toutes les fonctionnalités.
   - *Actions :* Point de restauration système, purge des fichiers temporaires et caches, vidage corbeille, plan d'alimentation Haute Performance, vérification d'intégrité SFC rapide, restrictions de base de télémétrie dans le registre. Ne supprime aucune application préinstallée et ne touche pas aux services système sensibles.

2. **⚡ Tweak Standard (Équilibré & Recommandé) :**
   - *Pour :* 95% des utilisateurs souhaitant un Windows rapide, épuré et respectueux de la vie privée.
   - *Actions :* Tout le profil Minimal **+** suppression des bloatwares inutiles (Xbox, Bing, etc.), désactivation des services et tâches de télémétrie (DiagTrack, dmwappushservice), blocage DNS des serveurs de tracking via Hosts et pare-feu, règles GPO renforcées, nettoyage approfondi Windows Update (DISM), réparations complètes DISM & SFC, priorité CPU au premier plan et désactivation du Core Parking.

3. **🚀 Tweak Max (Performances Extrêmes & Gaming) :**
   - *Pour :* Gamers, monteurs vidéo et passionnés cherchant chaque pourcent de FPS et de réactivité.
   - *Actions :* Tout le profil Standard **+** nettoyage approfondi du registre (clés orphelines, extensions invalides avec sauvegarde .reg automatique), planification d'une vérification minutieuse des disques au redémarrage (Chkdsk /f /r), et arrêt automatique de tous les processus d'arrière-plan inutiles.

---

## 👤 Auteur & Copyright

- **Auteur :** Anagou Reda
- **Contact / Téléphone :** `0542439514`
- **Projet :** REDADZDOptimiser Professional

## ⚡ Onglet Performances (Surveillance RAM, Processeur & Processus)

- **Surveillance en temps réel :** Jauges en direct de l'utilisation de la RAM et du Processeur (CPU) actualisées toutes les 1.5 secondes sans ralentissement.
- **Vider le cache & RAM (EmptyWorkingSet) :** Purge instantanée et sécurisée de la mémoire vive inactive des processus en tâche de fond pour libérer immédiatement des centaines de Mo ou Go de RAM sans fermer vos applications ouvertes.
- **Nettoyeur de Processus d'Arrière-Plan :** Arrête en un clic les processus dormants ou inutiles (télémétrie Microsoft, Phone Link, Game Bar Xbox, Widgets Windows 11, Cortana, instances Edge et Skype en tâche de fond) tout en protégeant rigoureusement les processus système vitaux (Explorer, DWM, etc.).
- **Optimisations Processeur & Énergie :**
  - Activation des plans d'alimentation *Performances Élevées* ou *Performances Optimales (Ultimate)* pour débloquer la fréquence d'horloge maximale du CPU.
  - Priorité CPU maximale aux applications et jeux au premier plan (`Win32PrioritySeparation = 0x26`).
  - Désactivation de la mise en veille forcée des cœurs CPU (*Core Parking OFF*).

---

## 🌐 Choix de la Langue au Démarrage

- **Interface Graphique (GUI) :**
  - Au lancement, une fenêtre claire et moderne permet de choisir la langue :
    - 🇫🇷 **Français**
    - 🇬🇧 **English**
    - 🇸🇦 **العربية**
  - Possibilité de changer de langue à tout instant via la liste déroulante en haut à droite.
  - Lancement direct avec langue forcée : `.\REDADZDOptimiserGUI.ps1 -Language AR`

- **Lanceur Batch (`Run_REDADZDOptimiser.bat`) :**
  - Menu d'accueil bilingue sécurisé (1: FR, 2: EN, 3: AR) empêchant tout écran vide sous console CMD.

- **Ligne de commande (`REDADZDOptimiser.ps1`) :**
  - Paramètre `-Language` : `.\REDADZDOptimiser.ps1 -Language EN` ou `.\REDADZDOptimiser.ps1 -Language AR`.

---

## ⚠️ Avertissements Importants

- **Exécutez TOUJOURS en tant qu'Administrateur** (clic droit → "Exécuter en tant qu'administrateur")
- **Créez un point de restauration** avant toute action (activé par défaut)
- **Redémarrage recommandé** après optimisation pour appliquer l'ensemble des changements
- **Testez d'abord avec `-DryRun`** pour simuler les actions sans rien modifier

---

## 📁 Fichiers Inclus (Structure Propre)

| Fichier | Rôle |
|---|---|
| `Launch_REDADZDOptimiser_GUI.bat` | Lanceur direct de l'interface graphique (auto-élévation admin) |
| `Run_REDADZDOptimiser.bat` | Menu interactif complet (GUI, CLI, Dry-Run, Restauration, Multilingue) |
| `REDADZDOptimiserGUI.ps1` | Interface graphique moderne WinForms (FR/EN/AR, thème Fluent Pro, onglets, logs) |
| `REDADZDOptimiser.ps1` | Script principal d'optimisation en ligne de commande |
| `REDADZDOptimiserCore.psm1` | Moteur principal d'optimisation (fonctions réutilisables, sécurité) |
| `REDADZDOptimiser_Restore.ps1` | Script complet de restauration et annulation |
| `README.md` | Documentation |

---

## 🚀 Utilisation Rapide

### ⚡ Option 0 : Commande Magique (One-Liner - Sans rien télécharger)
Ouvrez simplement **PowerShell** en tant qu'Administrateur et collez cette commande unique :
```powershell
irm https://raw.githubusercontent.com/anareda1999/REDADZDOptimiser/main/Launch.ps1 | iex
```
*Le programme se charge et se lance automatiquement sans aucune manipulation technique.*

---

### 📦 Option A : Exécutable Autonome (.exe) - RECOMMANDÉ
Double-cliquez directement sur :
```text
REDADZDOptimiser.exe
```
*(Auto-élévation administrateur UAC intégrée, aucune connaissance technique requise)*

---

### Option B : Lanceur Batch GUI
Double-cliquez sur :
Double-cliquez sur :
```cmd
Launch_REDADZDOptimiser_GUI.bat
```
Ou dans PowerShell (Admin) :
```powershell
.\REDADZDOptimiserGUI.ps1
```

### Option B : Menu Général Interactif
Double-cliquez sur :
```cmd
Run_REDADZDOptimiser.bat
```

### Option C : Ligne de Commande
```powershell
# Exécution complète (confirmation interactive)
.\REDADZDOptimiser.ps1

# En Anglais ou en Arabe
.\REDADZDOptimiser.ps1 -Language EN
.\REDADZDOptimiser.ps1 -Language AR

# Mode simulation (aucune modification)
.\REDADZDOptimiser.ps1 -DryRun

# Nettoyage et maintenance uniquement
.\REDADZDOptimiser.ps1 -OnlyCleanup -OnlyRepair
```

---

## 🔄 Restauration & Annulation

Pour annuler les modifications apportées :
```powershell
# Restauration interactive
.\REDADZDOptimiser_Restore.ps1

# Afficher les points de restauration existants
.\REDADZDOptimiser_Restore.ps1 -ListRestorePoints
```
