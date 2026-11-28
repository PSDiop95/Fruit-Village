# V2-0 — Checklist de validation sur Galaxy A23

Appareil de référence V1 : Galaxy A23, Android 14. Build à tester : **APK « AdMob test »** de la branche
`feature/fruit-village-v2-0` (`tools/build_android.sh admob` : debug, pubs de test Google, Firebase +
Crashlytics). Pour la mesure de démarrage, refaire aussi l'AAB release local (`tools/build_release.sh`)
installé avec bundletool **sans publication**. Noter pour chaque ligne : PASS / FAIL + valeur mesurée.

## Build préparé (21/11/2026)
- `build/fruit_village_admob_test.apk` : contenu de `main` après la PR #32, debug, arm64, Firebase + Crashlytics,
  pubs de test Google. SHA-256 `a2eea51a22b9b843524fc6ec7a888b4cdb0d3a699ab9f54bd693d409e7230961`.
  `check_build.sh debug` OK ; collecte Crashlytics `false` dans le manifeste.
- A23 connecté (SM-A235F, Android 14) : V1 1.0.0 (6) **installée depuis le Play Store** (clé Google). Le debug
  ne s'installe pas par-dessus (signature différente) ; il faut désinstaller, ce qui **efface la sauvegarde
  du Play Store** (non récupérable : `run-as` impossible sur une release). Test V1 → V2-0 : il faut un APK V1
  signé avec la même clé debug (build de `20f4afa`), ou le canal de test interne Play (hors périmètre : pas de publication).

- **Installé le 21/11/2026** (V1 Play désinstallée avec accord du propriétaire, sauvegarde Play effacée).
  1er lancement : TotalTime 7,3 s (préchauffage) ; Crashlytics 20.1.0 initialisé, aucun plantage.
  3 démarrages à froid : TotalTime 4,60 / 3,93 / 3,99 s. **Build debug** : non comparable au repère V1 (release) ;
  la mesure G0-10 se fait sur l'AAB release local ou face à un APK V1 debug sur le même téléphone.

- **V1 de référence installée le 28/11/2026** : APK AdMob test construit depuis `20f4afa`, même certificat debug
  que V2-0 (SHA-256 `0d9f93ef…`), donc mise à jour possible par `adb install -r`. Partie jouée par adb : aucun
  plantage ni ANR, 36–58 FPS en qualité Haut, Papaye atteinte, combo x5, passage niveau 2.
  Sauvegarde V1 de référence (`build/a23/v1_save_ref.json`, non suivie) : record **2639**, plus gros fruit
  **Papaye** (rang 7), **48 pièces** (48 gagnées, 0 dépensée), XP **82** (niveau 2), **8 fruits** à l'album,
  1 partie, missions débloquées. À retrouver à l'identique après la mise à jour V2-0.

- **Mise à jour V1 → V2-0 le 28/11/2026 : PASS.** `adb install -r` (date d'installation d'origine conservée),
  1er lancement TotalTime 5,76 s, aucun plantage ni ANR. Écran titre identique (48 pièces, niveau 2, Papaye) ;
  réglages V1 conservés (qualité Haut, ambiance Nuit). Sauvegarde comparée champ par champ à la référence V1 :
  **0 champ perdu**, seul `daily.last_seen` change (horodatage de la session), ajout de `settings.language` ;
  `save.json.bak` créé à la 1re écriture. Sélecteur FR | EN : bascule à chaud vérifiée (Réglages en anglais).

- **Mode avion le 28/11/2026 : PASS.** Démarrage à froid hors ligne (TotalTime 4,68 s), partie complète jusqu'à la
  fin (3 min 03, record 3091, combo x7, Papaye), missions mises à jour, 34–58 FPS, aucun plantage ni ANR. Sans
  réseau, aucune pub n'est proposée (« Doubler » masqué), aucun gel.
- **Sauvegarde modifiée : PASS.** Pièces passées à 999999 dans `save.json` (app arrêtée) → au lancement, solde
  légitime **69**, record / XP intacts, `save.json.tampered` en quarantaine, journal « Sauvegarde modifiée hors du
  jeu : copie en quarantaine, récupération ».
- **Sauvegarde supprimée : PASS.** `save.json` effacé → progression rechargée depuis `.bak` (69 pièces, record
  3091, XP 174), `save.json` réécrit.

- **Crashlytics (28/11/2026) : transmission BLOCKED.** Hors EEE (`gdprApplies=0`) le consentement est accordé
  d'office ; avec « Statistiques d'usage » activé, la collecte s'active ~13 s après le lancement (journaux FA).
  Le bouton « Test plantage » **ne fait pas planter l'app** : `crash()` du plugin godotx 3.1.0 lève une
  `NullPointerException` sur le thread de rendu de Godot, que le pont Java de Godot intercepte (journal
  « Forcing crash for testing… », même processus). Aucun rapport ne peut donc être produit par ce bouton.
  Conséquence plus large : sans NDK, Crashlytics ne voit que les plantages Java/Kotlin (plugins, AdMob, Firebase)
  et les ANR, **pas** les plantages natifs du moteur Godot. Options : plugin corrigé (lancer l'exception sur le
  thread UI), ou NDK (option B, non autorisée).
- **Session 20 min (28/11/2026) : PASS** (2e essai, hors ligne, appli redémarrée en mode avion pour qu'aucune
  pub ne soit chargée, arrêt automatique si le jeu n'est plus au premier plan). 20 minutes de jeu continu dans
  Fruit Village, même processus du début à la fin, **0 plantage, 0 ANR**, mémoire stable 635–713 Mo (pas de
  fuite), 49–60 FPS ; plusieurs parties enchaînées (record 5166, power-ups débloqués). Le 1er essai (pub de test
  au premier plan, appuis partis dans Chrome puis `com.mergerush.prototype`) est écarté.

- **Anomalie non reproduite** : après les tests de sauvegarde, la langue enregistrée est passée de `fr` à `en`
  sans action visible. Rejouée (FR, relance, modification, suppression, ouverture des Réglages) : non
  reproduite. Possible appui automatique parasite ; à surveiller.

## 0. Préparation
- [ ] `adb devices` voit l'appareil ; `adb logcat -c`.
- [ ] Désinstaller l'app, réinstaller l'APK V2-0. Garder aussi l'APK V1 (code 6) pour la mise à jour.
- [ ] Journaux pendant tous les tests : `adb logcat -s godot:V AndroidRuntime:E ActivityManager:I FirebaseCrashlytics:V`.

## 1. Démarrage à froid (critère : ≤ 110 % de V1, soit ≤ 4,95 s jusqu'au titre ; 1re image ≤ 2,9 s)
- [ ] Mode avion, appli fermée (`adb shell am force-stop com.smartiaservices.fruitvillage`).
- [ ] 5 lancements : `adb shell am start -W -n com.smartiaservices.fruitvillage/com.godot.game.GodotAppLauncher` (activité de lancement ; `GodotApp` n’est pas exportée) (valeur `TotalTime` = 1re image).
- [ ] Chronométrer jusqu'à l'écran titre jouable (vidéo d'écran `adb shell screenrecord`, ou balise logcat « title »). Moyenne et maximum.
- [ ] Premier lancement après installation mesuré à part (préchauffage des shaders).
- [ ] Faire la même série avec l'APK V1 (même appareil, même jour) pour comparer.

## 2. Mode avion (jeu V1 hors ligne)
- [x] Lancement, titre, partie complète, fusion jusqu'à la Papaye, fin de partie : aucun blocage.
- [x] Bouton pub (Continuer, Doubler) : message « pas de pub », aucun gel.
- [ ] Cadeau du jour, missions, album, power-ups : fonctionnent.
- [ ] Retour réseau en cours de partie : rien ne casse.

## 3. Sauvegardes
- [x] **Mise à jour V1 → V2-0** (PASS 28/11) : installer V1, jouer (record, pièces, album, série), installer V2-0 par-dessus (`adb install -r`) : tout est conservé.
- [ ] Fermeture forcée en pleine partie puis relance : record et pièces intacts.
- [x] Copie de secours présente (PASS 28/11) : `adb shell run-as com.smartiaservices.fruitvillage ls files/` → `save.json`, `save.json.bak`.
- [x] Fichier modifié : `run-as … sh -c "sed -i 's/\"coins\":[0-9]*/\"coins\":999999/' files/save.json"`, relance → solde légitime, `save.json.tampered` présent, logcat « Sauvegarde modifiée ».
- [x] Fichier supprimé (`rm files/save.json`), relance → progression rechargée depuis `.bak`.
- [ ] Cadeau du jour réclamé, puis fichier modifié, relance → le cadeau n'est **pas** réclamable une 2e fois.

## 4. Changement de langue
- [ ] Téléphone en anglais, 1re installation → jeu en anglais. Téléphone en français → français. Téléphone en wolof / allemand → français.
- [ ] Réglages → EN : tous les écrans ouverts basculent sans redémarrage (titre, réglages, pause, HUD).
- [ ] Relance : la langue choisie est conservée même si la langue du téléphone change.
- [ ] Parcours complet en anglais : titre, cadeau (y compris état « horloge suspecte » si reproductible), missions, album + carte de fruit + partage, power-ups (offre, pilon), pause, fin de partie, niveau supérieur, notification de rappel (avancer l'heure).
- [ ] Aucun texte coupé ni débordant (écran 1080×2408, plus long que 9:16) ; carte Réglages entière avec la barre de navigation.

## 5. Stabilité et ANR
- [x] Session de 20 min (≈ 6 parties) : aucun plantage, aucun « L'application ne répond pas ».
- [ ] 20 allers-retours arrière-plan / premier plan (bouton accueil) dont pendant une pub de test : pas d'ANR.
- [ ] Rotation verrouillée, écran éteint / rallumé en partie : reprise correcte.
- [ ] Après la session : Play Console « Android vitals » (si build interne) ou `adb shell dumpsys activity anr` vide.
- [ ] FPS en partie (menu debug F1 / 3 doigts → FPS) : ≥ 30 en qualité auto, comme en V1.

## 6. Crashlytics (option A)
- [ ] Consentement **refusé** (UMP de test) : menu debug → « Test plantage (Crashlytics) » → l'app se ferme ; relancer : **aucun** rapport dans la console Firebase sous 10 min.
- [ ] Consentement **accepté** + « Statistiques d'usage » activé : test de plantage, relance → rapport visible dans la console Firebase (Crashlytics) sous 10 min, avec version 1.0.0 (6) et fil d'Ariane (noms d'événements).
- [ ] Rapport : aucun identifiant utilisateur, aucune donnée personnelle dans les clés et journaux.
- [ ] « Statistiques d'usage » coupé dans les réglages : nouveau plantage de test → pas de rapport.
- [ ] Release (AAB local) : le menu debug et le bouton de plantage sont absents.

## Résultat
| Section | Statut | Valeurs / remarques |
|---|---|---|
| 1. Démarrage | | |
| 2. Mode avion | | |
| 3. Sauvegardes | | |
| 4. Langue | | |
| 5. Stabilité / ANR | | |
| 6. Crashlytics | | |
