# 06 — Stratégie de tests

## 1. Existant [FAIT]

Exécution du 21/11/2026 : `Godot 4.7.2 --headless -s addons/gut/gut_cmdln.gd -gexit` → **193/193 verts, 3 996 assertions, 136,9 s**. Configuration : `.gutconfig.json` (`res://tests/unit/`, préfixe `test_`).

| Fichier | Tests | Couverture |
|---|---|---|
| `test_logic.gd` | 16 | catalogue, MergeSystem (triple contact, ids 64 bits), Spawner seedé et pondéré, combo, danger |
| `test_game_physics.gd` | 13 | partie réelle : chute, fusion, game over, cooldown |
| `test_fun.gd` | 32 | réglages de feel, scénarios de partie, bornes d'équilibrage |
| `test_juice.gd` | 26 | effets, pools, ralenti, shake, Baobab |
| `test_meta.gd` | 33 | Wallet, Progression, Missions, DailyRewards + ClockGuard, InterstitialPolicy, RewardedSession, Collection, SaveCodec (roundtrip, tamper, migration v1, corrupt), notifications, FirebaseBoot, push |
| `test_meta_game.gd` | 31 | intégration méta ↔ partie, pubs mock (échec = aucune récompense), Continuer |
| `test_models.gd` | 8 | modèles 3D, colliders |
| `test_release.gd` | 26 | règles d'identifiants pub, exclusions d'export, Game Center, plist |
| `test_ui.gd` | 8 | navigation titre ↔ partie, réglages, game over, qualité |

Avertissements notables du journal : fuites à la sortie (384 ObjectDB, 68 ressources), FSR1 non disponible en Mobile. Aucune erreur de script.

Lacunes [FAIT] : pas de test de sauvegarde réelle V1 « capturée » sur appareil (seulement fixtures construites dans le test), pas de test de perf automatisé en CI, pas de test sur appareil automatisé, pas de CI Android.

## 2. Principes V2 [RECO]

1. **Tests Core d'abord** (règle CLAUDE.md §11) : chaque `*_core.gd` V2 est testé avant son UI, horloge `FakeClock`.
2. **Backends natifs mockés** : `MockIap`, `MockLeaderboard`, `MockCloudSave`, `MockRemoteConfig` sur le modèle de `MockAds` — aucun test ne dépend du réseau.
3. **Non-régression V1 obligatoire** : les 193 tests existants restent verts à chaque PR ; aucun test existant supprimé ni affaibli.
4. **Fixtures de sauvegarde figées** : ajouter `tests/fixtures/save_v1.json`, `save_v2_m4.json`, `save_v2_1.0.0.json` (copies anonymisées de vrais fichiers) et vérifier chargement + rétro-attribution + réécriture.
5. **CI** : job GUT headless sur chaque PR (Linux), en plus de la CI iOS.

## 3. Plan par niveau

### Unitaires (GUT)
| Module | Cas minimum |
|---|---|
| DailyChallenge | graine UTC identique sur 3 fuseaux ; changement de jour UTC ; essais (1 gratuit + 1 rewarded) ; horloge reculée |
| MarketOrders | chaque type d'objectif ; étoiles ; meilleure note ; déblocage séquentiel ; lâchers épuisés = fin |
| IAP | achat, annulation, attente, restauration, idempotence par transaction, `no_ads` bloque l'interstitiel seulement |
| Achievements | déblocage unique, compteurs, rétro-attribution V1 |
| Collection étendue | ancien format `found` lu sans perte |
| CloudSave | matrice de fusion par système, version distante plus récente, fichier V1 distant |
| RemoteConfig | défauts hors ligne, bornes, pas d'application en cours de partie |
| Analytics | chaque nouvel événement via `MemoryAnalytics` ; rien sans consentement |
| SaveManager | module désactivé → données conservées ; TAMPERED → copie de secours |

### Intégration (GUT, scènes réelles)
- Partie Défi complète : même graine → même séquence de 50 fruits.
- Partie Commande : objectif atteint → fin + récompense unique.
- Achat mock pendant la fin de partie → pas de double crédit, pas d'interstitiel ensuite.
- Démarrage : aucun manager V2 ne bloque l'affichage du titre (budget mesuré via `PerfProbe`).

### Appareils physiques
| Appareil | Pourquoi |
|---|---|
| Galaxy A23 (référence existante, Android 14) | régression démarrage / FPS |
| Android 2 Go RAM, Android 10 (minSdk 29) | bas de gamme cible |
| Android 13+ | permission notifications, Billing |
| iPhone ancien supporté + iPhone récent (Dynamic Island) | zone sûre, StoreKit, Game Center |

Scénarios manuels : reprendre `docs/QA_CHECKLIST.md` (32 points) + ajouts V2 : achat réel en sandbox (Play license testers / StoreKit sandbox), restauration après réinstallation, cloud sur 2 appareils, mode avion pendant achat, Défi du jour à minuit UTC, classement hors ligne puis en ligne.

### Mesures de non-régression perf (portes)
- Démarrage titre ≤ valeur V1 mesurée + 10 %.
- FPS moyen partie ≥ V1 − 5 % sur A23 ; 30 FPS min tenu.
- Taille de téléchargement < 60 Mo (cible CLAUDE.md).
- Android Vitals : plantages < 1,09 %, ANR < 0,47 % (seuils Google repris dans `docs/LAUNCH_PLAN.md`).
