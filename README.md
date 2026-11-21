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

### Option A : Interface Graphique (Recommandée)
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
