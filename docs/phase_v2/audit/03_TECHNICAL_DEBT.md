# 03 — Dette technique, bugs connus et risques

Gravité : 🔴 bloquant V2 · 🟠 à traiter dans la phase concernée · 🟢 confort.
Chaque entrée : **constat [FAIT]** puis **recommandation [RECO]**.

## 1. Dettes structurelles

| ID | Gravité | Constat [FAIT] | Recommandation [RECO] |
|---|---|---|---|
| TD-01 | 🔴 | **Aucune localisation** : zéro `tr()`, pas de `locale/`, textes FR en dur dans le code UI (`title_screen.gd:68,76…`) et dans les `.tres` (`display_name`, `description` de `data/powerups.tres`, `data/fruits.tres`). Fiche store EN publiée alors que le jeu est FR seul. | Phase V2-0 : introduire `TranslationServer` + CSV/PO **avant** d'ajouter les écrans V2 (sinon chaque nouvel écran double la dette). Garder les clés FR actuelles comme valeurs par défaut. |
| TD-02 | 🟠 | `CLAUDE.md` décrit un projet différent : Godot 4.4, `data/physics.tres`, `locale/*.po`, pièces = score/100 (réel : `coin_score_divisor = 150`), déblocages (réel : missions 2, power-ups 3, cadeau 4, album 5). | Mettre à jour le cahier des charges en début de V2 (document, pas code) pour éviter que de futures sessions s'appuient sur des faits faux. |
| TD-03 | 🟠 | Dépendances inter-autoloads implicites par l'ordre de `project.godot` ; `GameMeta` (`scripts/meta/game_meta.gd`) appelle directement 6 autoloads. | Pour la V2 : un seul point d'entrée « fin de partie » (signal `GameMeta.finalized`) auquel les nouveaux managers (Achievements, Leaderboard, DailyChallenge) **s'abonnent**, plutôt que d'ajouter des appels dans `finalize()`. |
| TD-04 | 🟢 | `scaling_3d/mode=1` (FSR1) avec renderer Mobile : Godot avertit « FSR1 3D scaling is only available when using the Forward+ renderer » (journal GUT). Le réglage retombe sur un upscale bilinéaire. | Vérifier sur appareil si le rendu est acceptable ; sinon passer en mode bilinéaire explicite (gain de clarté de config). |
| TD-05 | 🟠 | Fichiers volumineux : `juice.gd` (855 l.), `game.gd` (679), `game_hud.gd` (627). | Ne pas refactoriser maintenant ; en V2, ajouter les modes via **composition** (un `GameMode` injecté dans `Game`) plutôt qu'en grossissant `game.gd`. |
| TD-06 | 🟢 | Presets Android 0/1 encore en `0.4.0-m4` (`export_presets.cfg:31,92`). | Aligner lors du prochain bump (ne pas toucher pendant l'audit). |

## 2. Sauvegarde et intégrité

| ID | Gravité | Constat [FAIT] | Recommandation [RECO] |
|---|---|---|---|
| TD-10 | 🔴 | Statut `TAMPERED` (`SaveManager.gd:126-131`) : **toute la progression est remise à zéro** sans copie de secours (seul `CORRUPT` crée un `.corrupt`). Avec la sauvegarde cloud, un fichier fusionné ou écrit par une autre version avec un checksum différent effacerait la progression. | Avant le cloud : (1) copier en `.tampered` avant reset ; (2) versionner le sel ; (3) tests de non-régression sur fichiers v1/v2 réels. |
| TD-11 | 🔴 | **Pas de rétrocompatibilité descendante** : une V1 qui lit un futur format `FV3` le traite comme JSON brut → `CORRUPT` → progression réinitialisée (`save_codec.gd:decode`). Risque réel en cas de rollback store ou de deux appareils sur des versions différentes (cloud). | Rester en **format v2** pour la V2 en ajoutant uniquement de nouvelles clés sous `systems` (le lecteur V1 ignore les clés inconnues). Ne passer en v3 qu'avec garde de version minimale côté cloud. |
| TD-12 | 🟠 | Le sel du checksum est dans le binaire (`SaveCodec.SALT`) : la sauvegarde n'est pas une source de vérité fiable. | **Jamais** stocker un droit d'achat (IAP non-consommable) uniquement en local : le revalider via le store (restauration). |
| TD-14 | 🟠 | `SaveManager.save_data()` reconstruit `systems` à partir des seuls systèmes **enregistrés** (`SaveManager.gd:save_data`) : les clés d'un système non enregistré (module désactivé, ou fichier V2 relu par un binaire V1) sont **supprimées** à la première écriture. | Tout module V2 doit s'enregistrer même désactivé ; documenter que le rollback V2→V1 perd les données V2 (la progression V1 est conservée). |
| TD-13 | 🟢 | Autosave en arrière-plan seulement si `_save_pending` ; écritures synchrones sur le thread principal à chaque `set_setting` / `record_game`. | Acceptable (fichier petit). Surveiller la taille quand les succès/défis s'ajoutent. |

## 3. Services en ligne

| ID | Gravité | Constat [FAIT] | Recommandation [RECO] |
|---|---|---|---|
| TD-20 | 🟠 | **Crashlytics désactivé** (`firebase/enable_crashlytics=false`), le helper existe dans `addons/godotx_firebase/firebase_crashlytics_helper.gd`. Visibilité crash = Android Vitals / Xcode Organizer uniquement. | Activer Crashlytics en V2-0 (plugin déjà embarqué : pas de nouvelle dépendance) — mettre à jour la fiche Data Safety (`docs/PLAY_CONSOLE.md:148` le signale déjà). |
| TD-21 | 🟠 | Analytics : si UMP est en erreur, `analytics_ok=false` → **aucun événement** pour ces joueurs (`admob_ads.gd:_finish_consent`). Événements perdus avant l'init Firebase (`firebase_analytics.gd`). | Vérifier dans la console Firebase le volume réel vs installations ; si l'écart est fort, examiner la configuration du message UMP (iOS et Android). |
| TD-22 | 🟢 | Jeton FCM reçu mais inutilisé (`firebase_push.gd:_on_token`). | Pas de serveur requis tant que les campagnes passent par la console. |
| TD-23 | 🟠 | Entitlement Game Center activé et contrôlé par la CI, mais aucune intégration. | Soit l'utiliser en V2 (LeaderboardManager iOS), soit documenter pourquoi il reste. |
| TD-24 | 🟠 | Partage : plugin natif absent ; `ShareService` copie le texte et enregistre l'image dans `user://share/` (invisible pour le joueur). Levier WhatsApp (spec §5.5) inopérant. | Ajouter un plugin de partage en V2 (nouvelle dépendance → hors audit, à arbitrer). |

## 4. Performances et build

| ID | Gravité | Constat [FAIT] | Recommandation [RECO] |
|---|---|---|---|
| TD-30 | 🟠 | Démarrage Galaxy A23 : 1re image 2,6 s, titre jouable ≈ 4,5 s (objectif 3 s non atteint, `docs/m5_rapport.md`). Mesure faite sur version code 1. | Chaque manager V2 doit s'initialiser **paresseusement** (après le titre, comme `AdsManager.begin()`), aucun appel réseau bloquant au démarrage. Remesurer sur code 6. |
| TD-31 | 🟢 | `addons/admob/assets/*` (musique de démo ~1,8 Mo) non exclu des presets (`exclude_filter` ne contient que `addons/admob/gdscript/sample/*`). Splash présent 3 fois. | ≈ 9 Mo récupérables (`docs/m5_rapport.md`). Utile car IAP + Play Games + plugin de partage vont grossir l'APK. |
| TD-32 | 🟢 | Fin de la suite GUT : 384 instances ObjectDB et 68 ressources encore utilisées à la sortie. | Hygiène des tests (pas d'impact prod). À nettoyer pour détecter de vraies fuites en V2. |
| TD-33 | 🟠 | Pas de CI Android ; tests GUT lancés à la main ou par la CI iOS en mode upload uniquement. | Ajouter un job GUT sur chaque PR (Linux headless) en V2-0. |
| TD-34 | 🟢 | Mesures de perf (`docs/perf_m3.md`) faites sur PC Intel UHD, pas sur appareil 2 Go. | Campagne de mesures sur un appareil bas de gamme avant V2-1. |

## 5. Gameplay / déterminisme

| ID | Gravité | Constat [FAIT] | Recommandation [RECO] |
|---|---|---|---|
| TD-40 | 🔴 (pour le Défi) | La graine ne garantit que la **séquence de fruits** (`Spawner`). La physique Jolt n'est pas garantie identique entre ARM/x86, Android/iOS, ni entre fréquences d'images. | Le Défi du jour doit promettre « mêmes fruits pour tous », pas « même partie ». Classement = score, sans rejouer de replay côté serveur. |
| TD-41 | 🟠 | Missions et cadeau utilisent le **jour local** (`MetaClock.day_of`, fuseau). Un défi « commun à tous » sur jour local donne des graines différentes selon le fuseau et permet de rejouer un défi en changeant de fuseau. | Défi du jour : jour **UTC** pour la graine ; jour local seulement pour l'affichage. |
| TD-42 | 🟠 | Power-ups Échange / Agrandir modifient la séquence sans avancer le tirage (`Spawner.replace_current`) — correct, mais `_power_rng` est seedé depuis la même graine (`game.gd:82`) : l'issue des power-ups est donc aussi reproductible. | À conserver ; décider si les power-ups sont autorisés en Défi (équité du classement). |

## 6. Bugs connus

[FAIT] Aucun ticket ni TODO ouvert dans le code (`grep TODO/FIXME` vide hors addons). Derniers correctifs livrés : plantage `IllegalStateException` AdMob (chargement avant fin d'init) et ANR WebView au démarrage — Android 1.0.0 (6) (`git log 97ebfe2`, `AdsManager.gd:21-27`, `admob_ads.gd:_finish_consent`). L'efficacité réelle de ces correctifs est **NEEDS_VERIFICATION** dans Android Vitals (taux de plantage < 1,09 %, ANR < 0,47 % — seuils `docs/LAUNCH_PLAN.md:58-59`).
