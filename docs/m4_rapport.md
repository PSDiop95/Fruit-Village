# M4 — Méta & pub : rapport

Règle d'or tenue : la pub est un cadeau choisi (rewarded, bouton bleu « ▶ »),
masqué quand aucune pub n'est prête ; l'interstitiel n'existe qu'entre deux
parties, sous 6 règles de fréquence testées. UI dans le langage M3 (cartes
`PanelCard` sur fond flouté, boutons peints, `Pill`, `PanelSection`, titres
orange contourés).

## Tests

`tests/unit/` — **152/152 verts en headless** (101 M1–M3 inchangés + 51 M4) :

| Fichier | Couvre |
|---|---|
| `test_meta.gd` (30) | Wallet (jamais négatif, achat refusé), progression/déblocages, missions (minuit local, pas de doublon de type, progression, doublement), connexion 7 jours / série cassée / bouclier / horloge qui recule ou saute, interstitiel (toutes les règles, horloge simulée), rewarded (récompense seulement sur callback), album, codec de sauvegarde (checksum, migration v1, fichiers corrompus), notifications (≤ 2/jour) |
| `test_meta_game.gd` (21) | AdsManager + MockAds piloté (pause + son coupé, reprise après fermeture / échec, pas de récompense à la fermeture), interstitiel bout à bout, Continuer (3 fruits les plus hauts, 1 fois, partie comptée 1 fois), Agrandir plafonné au rang 6, Pilon via `Game.remove_fruit` (+ annulation), Secouer (prix, 20 s), clôture de partie, migration v1→v2 réelle, fichier corrompu / trafiqué, aller-retour des systèmes, consentement analytics |

Commande : `Godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit`

## Architecture

| Système | Logique pure (RefCounted, testée) | Autoload fin (signaux) |
|---|---|---|
| Pièces + stock | `scripts/meta/wallet_core.gd` | `Wallet` |
| XP / niveau / déblocages | `progression_core.gd` | `Progression` |
| Missions du jour | `missions_core.gd` | `Missions` |
| Connexion + série + anti-triche | `daily_rewards_core.gd`, `clock_guard.gd` | `DailyRewards` |
| Album | `collection_core.gd` | `Collection` |
| Pub | `interstitial_policy.gd`, `rewarded_session.gd`, `scripts/ads/*` | `AdsManager` |
| Analytics | `scripts/analytics/*` | `Analytics` |
| Notifications | `scripts/platform/notification_planner.gd` | `Notifications` |
| Horloge | `meta_clock.gd` / `fake_clock.gd` (tests, simulation) | — |

Aucun système ne connaît l'UI. Pont partie → méta : `GameMeta` (missions, album,
analytics en direct ; pièces, XP à la clôture). Power-ups : `PowerupController`
(passe par `Game.remove_fruit`, `Game.shake_basket`, le Spawner et le MergeSystem M1).

Données : `data/economy.tres`, `powerups.tres`, `missions.tres`,
`daily_rewards.tres`, `levels.tres`, `ads.tres`, `fruits_lore.tres`.

### Sauvegarde v2

`SaveCodec` : 1re ligne `FV2 <checksum>` puis JSON `{core, systems}`.
Écriture atomique (`.tmp` complet, relu, renommé). Migration v1 → v2 (les
fruits déjà atteints en M1–M3 sont acquis dans l'album). Fichier illisible →
valeurs par défaut + copie `.corrupt` ; fichier modifié à la main → progression
remise à zéro, réglages gardés. Autosave à la mise en arrière-plan.
Le checksum décourage l'édition ; ce n'est pas une protection forte (sel dans l'APK).

### Fin de partie

Game over → carte de résultats (M3) avec offre « ▶ Continuer » 6 s si une
rewarded est prête et pas encore utilisée → sinon clôture : pièces, XP,
missions, puis « ▶ Doubler » et « Niveau supérieur ! ». Une partie continuée
n'est comptée qu'une fois.

## Plugins choisis

| Besoin | Choix | Pourquoi | État |
|---|---|---|---|
| AdMob + UMP | **Poing Studios « Godot AdMob » v5.1.0** (installé) (sept. 2026, testé jusqu'à Godot 4.7.2) — github.com/poingstudios/godot-admob-plugin | Le plus maintenu (releases régulières, nightly oct. 2026), Android + iOS, UMP intégré, pubs simulées dans l'éditeur, MIT | Installé, APK Gradle produit ; adaptateur `AdMobAds` vérifié contre le code du plugin. **Non exécuté sur téléphone** |
| Firebase Analytics | **Godotx Firebase** (godot-x/firebase, v2.5.0, cible Godot 4.7) | Seul plugin Firebase à jour avec Analytics + consentement (`set_consent`, collecte désactivée par défaut) | `FirebaseAnalytics` écrit, non exécuté |
| Notifications locales | **Notification Scheduler** (godot-mobile-plugins, v5.2) | Le plus suivi ; canaux, permission Android 13+, annulation | Interface + **mock** ; `AndroidNotifications` écrit, **non validé sur téléphone** |
| Partage natif | **Share** (godot-mobile-plugins/godot-share) | Même éditeur que ci-dessus | Interface ; sans plugin : image dans `user://share/` + texte copié |

Les noms de méthodes AdMob/UMP diffèrent légèrement entre README et doc du
plugin : l'adaptateur teste plusieurs variantes (`get_can_request_ads`, etc.).
À valider au premier build Gradle.

## APK de test (Android, debug)

| Fichier | Preset | Pub | Taille |
|---|---|---|---|
| `build/fruit_village_m4_mockads.apk` | `Android MockAds` (sans Gradle) | Pubs simulées (le singleton AdMob est absent → `MockAds`) | 43,6 Mo |
| `build/fruit_village_m4_admob_test.apk` | `Android AdMob test` (Gradle) | AdMob + UMP réels, **identifiants de test Google** (manifeste : `ca-app-pub-3940256099942544~3347511713`) | 116,5 Mo |

Les deux : `com.fruitvillage.game` 0.4.0-m4 (code 4), arm64, minSdk 24,
signés avec la clé debug. 116 Mo = moteur debug non strippé des builds Gradle
(`libgodot_android.so` 76 Mo) ; un export release reviendra sous les 60 Mo.
Firebase est installé mais **désactivé** dans le preset tant que
`google-services.json` n'est pas fourni (le build Gradle échouerait sans).

Chaîne installée (hors projet) : `C:\Users\hp\android-tools` — JDK Temurin
17.0.20.1, SDK Android (platform-tools, build-tools 35.0.1 et 36.0.0,
plateformes 35 et 36, licences SDK acceptées), modèles d'export Godot 4.7.2
(Android). Réglages éditeur mis à jour (copie : `editor_settings-4.7.tres.bak-m4`),
keystore debug créé. Plugins dans le projet : `addons/admob` (v5.1.0, bibliothèque
Android `ads` seule, sans médiation), `addons/godotx_firebase` (3.1.0) +
`android/firebase_core`, `android/firebase_analytics`.

Commandes :
`Godot --headless --path . --export-debug "Android MockAds" build/fruit_village_m4_mockads.apk`
`Godot --headless --path . --install-android-build-template --export-debug "Android AdMob test" build/fruit_village_m4_admob_test.apk`

Adaptateur AdMob relu contre le code du plugin installé : énums UMP alignés,
`show_privacy_options_form` présent, détection par le singleton natif
`PoingGodotAdMob`.

### Vérifié sur téléphone (Samsung Galaxy A23 SM-A235F, Android 14, Adreno 610)

Captures : `docs/screens/phone/`.

| APK | Vérifié |
|---|---|
| MockAds | Lancement, UI M4, débordement → offre « Continuer » ; « ▶ Doubler » → pub simulée → pièces +11 → +22 après `ad_rewarded`, bouton retiré |
| AdMob test | SDK Google Mobile Ads initialisé après UMP, pubs préchargées ; « ▶ Continuer » → **vraie pub de test Google** (« Test Ad ») → `admob_reward_granted` → `ad_rewarded` → partie relancée, 3 fruits du haut retirés. Aucun clic sur la pub |

Consentement : aucun formulaire affiché. L'App ID de test n'a pas de message
UMP et le téléphone n'est pas en zone EEE ; à revérifier avec le vrai compte
AdMob (message RGPD à créer dans AdMob > Confidentialité et messages). Hash de
l'appareil pour forcer la zone EEE en test : `4374E651C8BCC1A62F95DA10CDF785B4`.

### Performance (Galaxy A23) — corrigée

Sonde `scripts/debug/perf_probe.gd` (debug ; `adb shell run-as com.fruitvillage.game touch files/perf_probe`, résultats « PERF » dans logcat), panier rempli :

| Niveau | Avant | Après | Avec voile flou : avant → après |
|---|---|---|---|
| Haut | 38 | 38–40 | 19,5 → 89 |
| Moyen | 38 | 45–60 (instable, chauffe) | 19,4 → 89 |
| Bas | 45 | **62–64** | 20,7 → 89 |

En vraie partie, qualité Auto (= Bas détecté) : **57 FPS** pendant un combo
(19 fruits, 21 effets), **58 FPS** sur l'écran de fin avec 43 fruits.

Changements :
- `VisualQuality.resolve(AUTO)` utilise maintenant la détection (avant : Haut
  partout, choix M3). Adreno 605–613 → Bas ; Adreno 616–619, Mali-G57/G68 →
  Moyen au plus. Le test M3 « Auto = haut de gamme » passe toujours sur PC
  (détecté Haut), mais il dépend désormais de la machine.
- Par niveau (`data/visual.tres`) : résolution 3D 62 / 70 / 80 %, MSAA
  aucun / aucun / 2x, glow en Haut seulement. Appliqué en partie et au titre.
- Repli automatique activé (`juice.tres : auto_quality = true`) : un niveau de
  moins si < 45 FPS sur 4 s (réglage Auto seulement).
- Voile flou (`BlurBackdrop`) : une capture unique de la dernière image,
  réduite au 1/12, au lieu d'une copie d'écran avec mipmaps à chaque frame ; la
  3D cachée sous un voile opaque n'est plus rendue.
- Compromis visuel : en Bas, pas de contour ni de rim light (style M3 un peu
  plus plat sur l'entrée de gamme).

### Firebase — branché

`google-services.json` (projet `fruitvillage`) à la racine, Core + Analytics
activés dans le preset AdMob test, plugin Gradle `google-services` ajouté à
`android/build/build.gradle` (versionné ; `tools/build_android.sh` le
réapplique si le modèle est réinstallé). Vérifié sur le téléphone : collecte
refusée par défaut, puis accordée après le consentement UMP, App ID Firebase
reconnu, `game_start` et les autres événements reçus (visible en DebugView ;
mode debug activé sur le téléphone, à couper avec
`adb shell setprop debug.firebase.analytics.app .none.`).
Correctif au passage : `has_method()` est faux sur les singletons Java et sur
les méthodes statiques du plugin AdMob, d'où des appels directs.

Build : `tools/build_android.sh [mock|admob]`.

## Économie — simulation et recommandation

`tools/bot_scores.gd` : 50 parties réelles (Jolt) jouées par 2 bots →
`docs/economy/bot_scores.csv`. Médiane ≈ **2 600 points**, ~130 fusions,
~21 pts/fusion, plus gros fruit moyen ≈ Papaye — même au hasard.

`tools/sim_economy.gd` : 1 000 joueurs, 14 jours, vraies règles et vrais `.tres`,
profils occasionnel (50 %) / régulier (35 %) / accro (15 %), joueur **dépensier
maximal** (achète le moins cher dès qu'il peut, 1 power-up/partie) →
`docs/economy/sim_economy_daily.csv` et `sim_economy_summary.csv`.

| Profil | Parties/jour actif | Pièces/partie | Parties par power-up **acheté** | Parties par power-up (cadeaux compris) | Solde J14 | Niveau J14 |
|---|---|---|---|---|---|---|
| Occasionnel | 2,5 | 43,8 | **5,6** | 2,3 | 153 | 5,6 |
| Régulier | 5,0 | 51,1 | **4,1** | 2,7 | 151 | 11,6 |
| Accro | 11,9 | 52,9 | **3,9** | 3,1 | 153 | 20,7 |

Inflation : nulle (solde moyen stable ~150, l'argent circule). Réglages retenus :
gain = score / **150** ; prix Secouer 200, Échange 200, Pilon 250, Agrandir 300 ;
missions 20–70 ; calendrier 20/25/Échange/35/Pilon/50/Coffre (100 + Agrandir) ;
bonus de niveau 30 ; XP ~85/partie, courbe croissante.

Recommandation : garder ces valeurs pour le test interne. La cible « 1 power-up
toutes les 3 à 5 parties » est tenue pour les achats ; avec les cadeaux
d'onboarding (1 de chaque au niveau 3 + 3/semaine au calendrier) le rythme est
plus généreux les premiers jours (2,3–3,1), voulu pour faire découvrir les
power-ups. Si les mesures réelles le confirment trop généreux : passer le
Coffre à 100 pièces seules. Le diviseur s'écarte du « score / 100 » du cahier
des charges : à 100, on tombait à 1 power-up toutes les 1,2–1,9 parties.

## À valider / limites

- **Textes de l'album** (`data/fruits_lore.tres`, `validated = false`) : à
  relire. Noms wolof renseignés seulement si sûrs (Sidem, Dakhar, Ditax, Madd,
  Bouye) ; étymologie de Dakar (tamarinier) à vérifier.
- Pièce, flamme : dessinées en code (style M3 cerné). À remplacer par des
  icônes peintes si vous en fournissez.
- Réglages : la carte remplit l'écran en 9:16 (section Vie privée ajoutée) ;
  sur tablette 4:3 elle déborderait.
- Analytics : consentement = « UMP autorise les pubs » ET réglage joueur ; le
  détail des finalités TCF n'est pas lu.

## Captures (`docs/screens/`)

`m4_titre`, `m4_cadeau`, `m4_missions`, `m4_album`, `m4_album_carte`,
`m4_reglages`, `m4_partie_powerups`, `m4_powerup_offre`, `m4_pilon`,
`m4_continuer`, `m4_pub_simulee`, `m4_fin_recompenses`, `m4_niveau`
(`tools/capture_m4.gd`, rendu réel 720x1280).

## Politique de confidentialité

`https://fruit-village.netlify.app/` (FR/EN : AdMob, Firebase, contact) —
`data/ads.tres : privacy_policy_url`. Accessible depuis Réglages > Vie privée
(« Confidentialité ») et le formulaire de consentement simulé. À renseigner
aussi dans la fiche Play Store et dans le message RGPD d'AdMob.

## Identifiants AdMob (24/10/2026)

- App ID `ca-app-pub-8091937083176290~6673200969` : `project.godot`
  (`admob/general/android/app_id`), présent dans le manifeste.
- Blocs rewarded et interstitiel : `ads_ids.cfg` (non versionné), lus en
  release uniquement. Debug : blocs de test Google (vérifié sur le A23).
- En release, un bloc manquant désactive ce format (jamais de pub de test en
  production).
