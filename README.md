# Prototype - Plateforme Mobile

Jeu de plateforme "auto-run" : le personnage avance tout seul, un tap/clic = sauter
(double saut possible). Aucun bouton virtuel ni joystick nécessaire.
Progression par mondes/niveaux, générés procéduralement (pas besoin de dessiner
chaque niveau à la main).

## Comment tester

1. Installer **Godot 4.3 ou plus récent** (gratuit) : https://godotengine.org/download
2. Ouvrir Godot → "Importer" → sélectionner le fichier `project.godot` de ce dossier
3. Appuyer sur F5 (ou le bouton ▶) pour lancer
4. Clic gauche (ou tap sur mobile) = sauter

Le mode "simulation" des pubs est activé par défaut (`_mock_mode = true` dans
`ad_manager.gd`) : les pubs sont remplacées par un simple message dans la console
+ une pause d'une seconde, pour pouvoir tester tout le flux de jeu sans avoir
encore configuré de vrai compte AdMob.

## Structure du projet

```
project.godot           Config du projet (autoloads, résolution, écran de démarrage, icône)
icon.png                 Icône de l'app (générée à partir du personnage)
Main.tscn                Scène de jeu (générée par script)
assets/
  tiles.png              Feuille de tuiles de terrain (pack Kenney "Pixel Platformer")
  characters.png         Feuille de personnage (idle, marche, saut)
scenes/
  MainMenu.tscn          Menu principal (sélection monde/niveau)
scripts/
  main.gd                Génération des niveaux + logique de jeu + UI + parallax
  main_menu.gd           Menu : sélection niveau, pièces, vies, bonus, achats
  player.gd              Personnage : auto-run, saut, animations
  level_data.gd          Difficulté par monde/niveau
  ad_manager.gd          Pubs (rewarded + interstitiel), avec mode simulation
  save_manager.gd        Sauvegarde locale (pièces, vies, streak, achats)
  session.gd             Mémorise le niveau choisi entre le menu et le jeu
  sfx_manager.gd         Sons synthétisés (aucun fichier audio nécessaire)
```

## Système de vies (énergie)

C'est le cœur du levier "pubs prioritaires" que tu voulais :
- Le joueur commence avec **5 vies**
- Chaque mort consomme 1 vie
- Vies à 0 : impossible de relancer un niveau (bouton grisé dans le menu et
  dans l'écran "Perdu") — il faut soit **regarder une pub** (+1 vie
  immédiatement), soit **attendre ~20 min** pour en regagner une gratuitement
- Le bouton "Continuer ici (pub)" après une mort ne coûte pas de vie
  supplémentaire : c'est le levier pub le plus rentable, mis en avant en
  premier dans l'écran "Perdu"

## Sons

Aucun fichier audio à télécharger : les sons (saut, pièce, mort, niveau
terminé) sont générés à la volée avec `AudioStreamGenerator` (ondes sinus).
Ça garde le jeu à quasiment 0 Ko de son, désactivables via le bouton son du menu.

## Design / habillage visuel

Ajouté sans alourdir le projet (0 asset supplémentaire téléchargé) :
- **Fond en parallax** (ciel + collines) qui défile plus lentement que le
  premier plan, pour un effet de profondeur
- **Biome par monde** : les mondes alternent entre un thème "prairie" (vert)
  et "désert" (orange) — sol et collines changent de couleur en conséquence
- **UI stylisée** : panneaux et boutons à coins arrondis, couleurs
  cohérentes (vert = progression, violet = action liée à une pub, doré =
  achat, gris = neutre/menu), texte avec contour pour rester lisible
- **Petites animations ("juice")** : le personnage s'étire légèrement au
  saut et à l'atterrissage, les pièces "poppent" avant de disparaître
- **Menu** : carte centrale, grille de niveaux colorée selon le statut
  (vert = terminé, bleu = niveau suivant à jouer, gris = verrouillé)

Tout ça reste des `ColorRect`/`StyleBoxFlat`/tweens — zéro poids
supplémentaire en Ko, uniquement du code.

## Icône de l'app

`icon.png` (256x256, ~2,5 Ko) est généré à partir du personnage déjà présent
dans le pack Kenney (aucune image externe ajoutée), sur un fond dégradé
reprenant les couleurs des biomes du jeu. Déjà référencé dans `project.godot`.

## Bonus quotidien (streak de connexion) + son on/off

- Un bonus de pièces est proposé une fois par jour dans le menu, avec un
  streak sur 7 jours (augmente chaque jour consécutif, revient à 1 si tu
  rates un jour) — un levier de rétention classique
- Bouton son on/off dans le menu

## Sprites (pack Kenney "Pixel Platformer")

Le pack que tu as envoyé est intégré :
- `assets/tiles.png` : la feuille de tuiles de terrain (sol du niveau)
- `assets/characters.png` : la feuille de personnage (idle, marche, saut)

Ce pack ne contient ni pièces, ni pics, ni drapeau (c'est la version de base,
minimaliste) — ces éléments restent donc des formes colorées simples
(rectangle jaune = pièce, triangle rouge = pic), cohérent avec l'esprit
"léger et simple".

Les cases utilisées sont choisies par index dans `player.gd` (`CHAR_ROW`,
`COL_IDLE`, `COL_RUN`, `COL_JUMP`) et `main.gd` (`BIOMES`, colonnes/lignes
`ground_col`/`ground_row`). Change juste ces numéros si tu veux une autre
pose ou couleur.

## Passer aux vraies pubs (AdMob) — vérifié juillet 2026

1. Créer un compte AdMob : https://admob.google.com
2. Dans Godot : AssetLib → chercher "Admob" → installer **godot-admob**
   (godot-sdk-integrations, le plugin le plus à jour actuellement, unifié
   Android + iOS) : https://github.com/godot-sdk-integrations/godot-admob
3. Activer le plugin dans Project → Project Settings → Plugins
4. Ajouter un nœud "Admob" à `MainMenu.tscn`, renseigner App ID + IDs
   d'unités publicitaires dans l'Inspecteur (IDs de test pré-remplis par défaut)
5. Dans `ad_manager.gd`, passer `_mock_mode` à `false` et suivre les
   commentaires du fichier pour connecter les signaux du plugin

**Point d'attention important** : Google/AdMob interdit de bloquer totalement
la progression derrière une pub sans alternative claire, et limite la
fréquence des pubs interstitielles. Le système actuel (pub proposée mais pas
obligatoire, interstitiel limité à 1 fois tous les 3 niveaux, vies regagnables
gratuitement en attendant) respecte déjà ce principe — ne le rends pas plus
agressif, ça peut faire suspendre ton compte AdMob.

## Achats intégrés (suppression des pubs)

- **Android** : plugin officiel **GodotGooglePlayBilling** (recommandé par
  la doc Godot) : https://github.com/godot-sdk-integrations/godot-google-play-billing
  — télécharger, copier dans `addons/GodotGooglePlayBilling/`, activer le
  plugin, puis activer `gradle/use_gradle_build` dans le preset d'export Android
- **iOS** : plugin StoreKit dédié, ou une solution unifiée Android+iOS comme
  **godot-iap** (protocole OpenIAP) pour un seul code sur les deux plateformes

Le bouton "Supprimer les pubs" appelle actuellement
`AdManager.remove_ads_purchase()` en simulation — à remplacer par l'appel
réel une fois le plugin installé.

## Générer un APK 100% depuis ton téléphone (sans ordinateur)

Cette méthode utilise **GitHub Actions** : un service gratuit qui compile
ton jeu dans le cloud (avec un vrai Godot + SDK Android dedans) et te donne
un `.apk` à télécharger — piloté entièrement depuis ton navigateur et
**Termux** (un terminal Linux pour Android).

Deux fichiers sont déjà prêts dans ce projet pour ça :
`.github/workflows/android-debug.yml` (la recette de compilation) et
`export_presets.cfg` (la config d'export Android, en debug, sans keystore à
gérer toi-même).

### 1. Installer Termux (PAS depuis le Play Store — version obsolète)
- Navigateur → https://f-droid.org → "Download F-Droid" → installer l'APK
  (autoriser "sources inconnues" pour le navigateur si demandé)
- Ouvrir F-Droid → chercher "Termux" → installer → ouvrir

### 2. Préparer le projet dans Termux
```
termux-setup-storage
pkg update -y && pkg upgrade -y
pkg install git unzip -y
cd ~/storage/downloads
ls
```
Le fichier `plateforme-mobile.zip` (celui que je t'ai donné dans le chat)
doit apparaître dans la liste — c'est qu'il est bien dans tes téléchargements.
```
unzip plateforme-mobile.zip -d ~/game
cd ~/game/plateforme-mobile
```

### 3. Créer un token GitHub (remplace ton mot de passe pour git push)
- Navigateur → github.com → ta photo de profil → Settings → tout en bas
  "Developer settings" → "Personal access tokens" → "Tokens (classic)" →
  "Generate new token (classic)"
- Coche la case "repo" → Generate → **copie le token** (commence par `ghp_`)
  quelque part sûr (Notes...) — GitHub ne le remontre plus jamais après

### 4. Créer le dépôt GitHub
- github.com → icône "+" → "New repository"
- Nom : `plateforme-mobile` (ou ce que tu veux)
- **Public** (important : Actions gratuit et illimité en public)
- Ne coche PAS "Add a README" → Create repository

### 5. Envoyer le projet depuis Termux
```
git config --global user.email "ton-email@exemple.com"
git config --global user.name "TonPseudoGitHub"
git init
git branch -M main
git add .
git commit -m "Premier commit"
git remote add origin https://github.com/TON_PSEUDO/plateforme-mobile.git
git push -u origin main
```
- Nom d'utilisateur demandé : ton pseudo GitHub
- Mot de passe demandé : colle le **token** `ghp_...` (pas ton vrai mot de passe)

### 6. Récupérer l'APK
- Le push déclenche automatiquement la compilation. Sur github.com, ouvre
  ton dépôt → onglet **Actions**
- Tape sur le run en cours (ou terminé ✅), attends ~2-5 min
- En bas de la page : **Artifacts** → tape sur `plateforme-mobile-debug-apk`
  → ça télécharge un `.zip`
- Ouvre-le avec l'app Fichiers de ton téléphone, extrais-le → tu obtiens le
  `.apk` → tape dessus pour l'installer (autorise "installer des apps
  inconnues" si demandé)

**Si l'étape 6 échoue (❌ rouge)** : tape sur le run → tape sur l'étape en
rouge → copie le texte d'erreur → colle-le moi, je te dis exactement quoi
corriger. Le fichier `export_presets.cfg` est écrit du mieux possible sans
pouvoir le tester moi-même (pas de Godot dans mon environnement), donc une
petite retouche est possible au premier essai.

## Générer un APK avec un ordinateur (si tu en as un sous la main un jour)

Pas besoin de compte développeur ni de Play Console pour ça — juste pour
tester le jeu directement sur ton téléphone Android.

1. Installer **Godot 4.3+** : https://godotengine.org/download (Standard, pas .NET)
2. Installer **Android Studio** : https://developer.android.com/studio
   (ouvre-le une fois pour qu'il installe le SDK Android, puis tu peux le refermer)
3. Dans Godot : Editor → Editor Settings → Export → Android → renseigner le
   chemin vers le SDK Android (généralement auto-détecté après l'étape 2)
4. Project → Export → Add… → Android (les réglages par défaut suffisent pour
   un test — pas besoin de package name particulier ni de keystore, Godot en
   génère un automatiquement pour le mode debug)
5. Cliquer "Export Project", choisir un nom de fichier `.apk`, décocher
   "Export With Debug" n'est PAS nécessaire — laisse-le coché pour un test
6. Transfère le fichier `.apk` sur ton téléphone (câble USB, email à
   toi-même, Google Drive...) et ouvre-le depuis le téléphone pour l'installer
   (Android demandera d'autoriser "installer des apps inconnues" la première fois)

Pour publier vraiment sur le Play Store (avec ton nom d'app, ton icône, sans
avertissement "source inconnue"), il faut suivre la checklist complète
plus bas (keystore de production, AAB, Play Console).

## Publier sur le Play Store (Android) — checklist juillet 2026

1. Installer Android Studio (fournit le SDK Android + Java nécessaires à Godot)
2. Dans Godot : Editor → Manage Export Templates → télécharger les templates
   correspondant à ta version de Godot
3. Project → Export → Add… → Android :
   - Package name au format inversé (ex: `com.tonstudio.plateformemobile`)
   - Activer `gradle/use_gradle_build` (obligatoire pour AdMob/Billing)
   - **Règle Google Play en vigueur** : à partir du 31 août 2026, toute
     nouvelle app doit cibler Android 16 (API level 36) minimum — vérifie
     que ta version de Godot supporte ce niveau d'API avant de soumettre
   - Générer un **keystore de production** (`keytool -genkey ...`) et le
     conserver précieusement : impossible de mettre à jour l'app sans lui
4. Exporter en **AAB** (Android App Bundle), pas en APK brut
5. Dans la Play Console : créer la fiche app, remplir le formulaire
   **Data Safety** (mentionner la collecte de l'identifiant publicitaire via
   AdMob et des infos d'achat via Billing), ajouter l'URL de ta politique de
   confidentialité (voir `PRIVACY_POLICY.md`), remplir le questionnaire de
   classification par âge
6. Si le jeu peut plaire à des enfants, les règles Google "Families" sont
   plus strictes sur les pubs personnalisées — à vérifier avant de cibler
   cette audience

## Publier sur l'App Store (iOS)

Nécessite un Mac + Xcode + un compte Apple Developer Program (99$/an). Avec
le plugin AdMob, l'invite **App Tracking Transparency (ATT)** est gérée
automatiquement (obligatoire pour la pub personnalisée sur iOS). Soumission
ensuite via Xcode ou Transporter vers App Store Connect.

Guide export général : https://docs.godotengine.org/en/stable/tutorials/export/index.html

## Politique de confidentialité

Un modèle est fourni dans `PRIVACY_POLICY.md` — à compléter (nom du studio,
email de contact) et à héberger en ligne (une simple page web suffit) avant
soumission sur les stores. Je ne suis pas juriste : fais relire par un
professionnel si tu veux une garantie de conformité totale (RGPD notamment).
