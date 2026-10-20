# Merge Marché — Cahier des charges (CLAUDE.md)

> Fichier de référence pour Claude Code. À placer à la racine du projet Godot.
> Objectif business : jeu très addictif, financé par la pub (rewarded d'abord), pour financer les autres projets.

---

## 0. Benchmark (ce qu'on copie, ce qu'on améliore)

### 0.1 Référence n°1 : Suika Game (Aladdin X)
- Origine : « Merge Big Watermelon » (Chine, 2021). Explosion en 2023 grâce aux streamers → **10 M+ téléchargements**, n°1 eShop Japon 2023 et 2024, appli payante la plus téléchargée sur iPhone au Japon en 2024.
- Règles : on lâche un fruit dans un bocal, 2 identiques fusionnent en un fruit plus gros. Game over si un fruit dépasse la ligne. **11 fruits**, seuls les **5 plus petits** tombent, **le suivant est affiché** à l'avance. Deux pastèques fusionnées disparaissent.
- Pourquoi c'est addictif :
  1. **Règle comprise en 3 secondes**, aucune explication.
  2. **Physique imprévisible** : rebonds, roulades, réactions en chaîne inattendues → « encore une ».
  3. **Combos en cascade** : une fusion en déclenche d'autres = pic de dopamine.
  4. **Tension croissante** : le bocal se remplit, chaque lâcher compte.
  5. **But clair et lointain** : voir la pastèque (rare = mémorable, partageable).
  6. **Parties courtes** (3–10 min), relance en 1 tap.

### 0.2 Ce que les clones mobiles à succès ajoutent
| Élément | Pratique du marché | Pour nous |
|---|---|---|
| Rewarded | Secouer, supprimer un fruit, continuer après game over | ✅ Cœur de la monétisation |
| Méta-progression | Skins, thèmes de bocal, collection | ✅ Étals de marché + collection de fruits |
| Missions/défis du jour | Standard des hybrid-casual | ✅ |
| Classement | Hebdo, entre amis | ✅ Phase 2 |
| Interstitiel | Après game over | ⚠️ Limité (voir §7) |

### 0.3 Repères chiffrés (à confronter à nos mesures)
- Rétention médiane (tous genres) : **J1 ≈ 22 %, J7 ≈ 3–4 %**. Top quartile : **J1 25–33 %, J7 7–8 %**. Notre cible : **J1 ≥ 35 %, J7 ≥ 10 %**.
- Session médiane ≈ **3,1–3,5 min**, ≈ **3,8 sessions/jour**.
- ARPDAU casual pub seule : **0,01–0,05 $**. Hybrid-casual (pub + IAP) : **0,15–0,50 $**. → Il faut des **IAP** à terme.
- eCPM rewarded Android casual : **≈ 8,90 $ Europe/USA**, ≈ 2 $ LATAM, < 2 $ Asie du Sud-Est ; l'Afrique de l'Ouest est dans le bas de fourchette. → **Habillage africain, audience mondiale** (UA ciblée Tier 1 + diaspora).

### 0.4 Notre différenciation
1. **Univers inédit** : fruits d'Afrique de l'Ouest, marché vivant (Sandaga, Treichville, Kermel).
2. **Vraie 3D stylisée** là où la majorité des clones est en 2D plate.
3. **Découverte culturelle** : chaque nouveau fruit = carte « Le savais-tu ? » → curiosité, partage.
4. **Moment « Baobab »** : l'ultime fusion est un événement visuel spectaculaire, conçu pour être filmé et partagé.

---

## 1. Vision
- Plateforme : Android d'abord (Android 8+, 2 Go RAM), iOS ensuite
- Moteur : **Godot 4.4+ / GDScript**, **3D low-poly stylisée**, renderer **Mobile** (fallback Compatibility), portrait 1080x1920
- Physique : **Jolt** (intégré à Godot 4.4+), **jeu en 2,5D** : objets 3D, mouvements verrouillés sur le plan X/Y (axe Z bloqué)
- APK cible : < 60 Mo, **100 % hors ligne**
- Langues : FR, EN, Wolof (textes courts)

## 2. Gameplay cœur

### 2.1 Règles
- Le joueur fait glisser le doigt pour viser, relâche pour lâcher le fruit dans le **panier** (calebasse/bassine 3D vue de face).
- 2 fruits identiques qui se touchent → fusion en fruit du rang supérieur, au point de contact.
- **Fruit suivant** affiché en haut à droite.
- **Game over** : un fruit reste > 2 s au-dessus de la ligne rouge (ligne qui clignote dès 1 s = alerte).
- Deux **Pains de singe** fusionnés → **Moment Baobab** (§4.3), gros bonus, ils disparaissent.

### 2.2 Les 11 fruits (rang, taille croissante)
| # | Fruit | Couleur dominante | Tombe ? | Points fusion |
|---|---|---|---|---|
| 1 | Sidem (jujube) | Brun-rouge | ✅ | 1 |
| 2 | Bissap (calice) | Rouge profond | ✅ | 3 |
| 3 | Tamarin (dakhar) | Brun | ✅ | 6 |
| 4 | Ditakh | Vert foncé | ✅ | 10 |
| 5 | Madd (saba) | Orange | ✅ | 15 |
| 6 | Goyave | Vert clair / rose | ❌ | 21 |
| 7 | Mangue | Jaune-orange | ❌ | 28 |
| 8 | Papaye | Orange vif | ❌ | 36 |
| 9 | Ananas | Jaune + vert | ❌ | 45 |
| 10 | Noix de coco | Brun / blanc | ❌ | 55 |
| 11 | Pain de singe (fruit du baobab) | Vert velours | ❌ | 66 |
| ★ | 2 Pains de singe → **Baobab** | — | — | 500 + bonus |

> Ordre et noms ajustables dans `data/fruits.tres`. Les couleurs doivent rester **distinguables par la forme ET la couleur** (daltonisme).

### 2.3 Physique (le « feel », à régler finement)
- Colliders **sphères** (ou capsules pour mangue/papaye), masses ∝ taille.
- Rebond faible, friction moyenne → les fruits roulent un peu mais se calent.
- Fusion : le nouveau fruit **apparaît à 70 % de sa taille et grossit en 0,15 s** (évite les explosions de physique) + petite impulsion vers le haut.
- **Cooldown de lâcher** 0,4 s (anti-spam).
- **Physique déterministe** autant que possible (pas de random caché) : le joueur doit sentir que c'est sa faute.
- Tous les paramètres dans `data/physics.tres`.

### 2.4 Score & combos
- Points de fusion (tableau ci-dessus) × **multiplicateur de combo** : fusions enchaînées en < 1,5 s → x2, x3, x4… (affiché en gros).
- Meilleur score local + record de la semaine.
- **Plus gros fruit atteint** = méta-objectif affiché sur l'écran titre.

## 3. Modes de jeu
| Mode | Description | Phase |
|---|---|---|
| **Marché classique** | Mode infini façon Suika | V1 |
| **Défi du jour** | Même graine aléatoire pour tous, 1 essai gratuit + 1 via rewarded, classement du jour | V1 |
| **Commandes du marché** | Niveaux à objectifs (« Fais 3 mangues en 25 lâchers », « Atteins la papaye sans dépasser la ligne ») → 3 étoiles | V1.1 |
| **Rush** | 90 s, score max | Phase 2 |

> Les **niveaux à objectifs** (Commandes) transforment un jeu infini en jeu à progression : c'est le levier de rétention J7 des hybrid-casual.

## 4. Visuel, animations & effets

### 4.1 Direction artistique
- **Low-poly lissé / cartoon**, formes rondes et « juteuses », couleurs saturées, **toon shading** 2–3 tons + **outline** fin.
- **Fruits avec visages** (yeux + bouche simples, expressions qui changent) : clé de l'attachement, comme les meilleurs jeux du genre.
  - Au repos : sourire. Écrasé : grimace. Près de la ligne : peur. Fusion : yeux fermés de joie.
- Panier = **calebasse ou bassine émaillée** à motifs wax, posée sur un étal en bois.
- Fond : **marché flou en profondeur** (bâches colorées, étals, silhouettes animées), lumière chaude de fin d'après-midi.
- Thèmes de fond déblocables : Sandaga (Dakar), Treichville (Abidjan), Kermel, marché flottant, nuit au marché (lampes), Tabaski.

### 4.2 Animations des fruits (squash & stretch partout)
- **Apparition** en haut : pop + léger rebond.
- **Chute** : stretch vertical léger proportionnel à la vitesse.
- **Impact** : squash (aplatissement) puis retour élastique (0,12 s).
- **Idle** : respiration douce, clignement des yeux aléatoire.
- **Fusion** : les 2 fruits s'aspirent l'un vers l'autre (0,08 s) → flash blanc → nouveau fruit en pop élastique.
- **Danger** : les fruits proches de la ligne tremblent.

### 4.3 Effets « juice »
| Événement | Effet |
|---|---|
| Fusion | Éclaboussure de jus de la couleur du fruit (particules), anneau d'onde, son croissant selon le rang |
| Combo x2+ | Texte « COMBO x3 ! » avec rebond, **hit-stop** 40 ms, léger zoom caméra |
| Nouveau fruit découvert (1re fois) | Ralenti, projecteur, carte « Le savais-tu ? » + bouton partage |
| Grosse fusion (rang ≥ 8) | **Screen shake** léger, confettis wax, vibration |
| **Moment Baobab** | Ralenti, le panier s'illumine, un **baobab 3D pousse** en fond, pluie de feuilles et de pièces, foule du marché qui applaudit, son de **sabar** |
| Ligne de danger | Ligne qui pulse en rouge, musique filtrée (passe-bas), battement de cœur |
| Game over | Fruits qui « tombent » en ralenti, résumé (score, plus gros fruit, record) |
| Score | Compteur qui roule, chiffres flottants « +28 » au point de fusion |

### 4.4 Son (ambiance marché)
- Musique : boucle **afrobeat / mbalax** légère, tempo qui monte quand le panier se remplit.
- Fond : **ambiance de marché** discrète (voix, appels de vendeurs, klaxons lointains).
- Fusions : notes de **kora / balafon** en gamme montante selon le rang (fusion de rang 8 = note plus aiguë que rang 3) → combo = mélodie.
- Voix courtes de vendeuse : « Dieuredieuf ! », « Waaw ! », « Ndekki li ! » (à enregistrer).
- Option : couper musique / sons / vibrations séparément.

### 4.5 Contraintes perf (2 Go RAM)
- Fruits < 800 triangles, **une texture palette** unique 256x256, visages via texture d'expressions.
- Max ~60 fruits simultanés (bien au-delà d'une partie réelle).
- Particules plafonnées, **pool d'objets** pour fruits et particules.
- 60 FPS visé, 30 FPS min, **qualité auto** (Bas/Moyen/Haut), option « effets réduits ».

## 5. Gamification (rétention)

### 5.1 Session
- **Objectif visible** en permanence : « Prochain : atteins la Papaye ! » (le prochain fruit jamais atteint).
- **Barre de record** : où tu es par rapport à ton meilleur score.
- **Bonus « Panier propre »** : vider sous la mi-hauteur = bonus.

### 5.2 Quotidien
- **Récompense de connexion** 7 jours (jour 7 = thème de fond ou power-up rare).
- **Série** avec flamme ; « bouclier » de série via rewarded.
- **3 missions du jour** (« Fais 5 combos », « Atteins 2 mangues », « Joue 3 parties ») → pièces.
- **Défi du jour** (§3) avec classement.

### 5.3 Long terme
- **Album des fruits** : 11 cartes à collectionner (illustration + anecdote : bissap = boisson nationale, ditakh = riche en vitamine C, baobab = arbre à palabres…). Album complet = thème doré.
- **Étals & skins** : paniers (calebasse, bassine émaillée, panier tressé, glacière…), fonds de marché, effets de fusion — achetés en **pièces** ou en IAP.
- **Niveau joueur** (XP) qui débloque progressivement : missions (niv. 2), défi du jour (niv. 3), Commandes (niv. 5) → onboarding naturel.
- **Succès** (30+) : « Premier Baobab », « Combo x6 », « 100 mangues », « Reine du marché ».

### 5.4 Power-ups (pièces ou rewarded)
| Power-up | Effet |
|---|---|
| **Secouer le panier** | Secousse physique qui provoque souvent des fusions |
| **Coup de pilon** | Écrase (supprime) un fruit choisi |
| **Échange** | Change le fruit à lâcher |
| **Agrandir** | Le prochain fruit lâché monte d'un rang |

### 5.5 Social (levier WhatsApp)
- **Partage** : image du panier + score + plus gros fruit (« J'ai fait pousser un Baobab ! ») avec lien.
- **Clip auto** des 5 dernières secondes du Moment Baobab à partager (phase 2).
- **Parrainage** : bonus aux deux joueurs.
- **Classement hebdo** amis + mondial (phase 2, backend léger).

## 6. Économie
- **Pièces** (soft) : gagnées en jouant (score / 100), missions, connexion.
- **Diamants** (premium, phase 2) : IAP.
- Coût power-up : 100–300 pièces. 1 partie moyenne ≈ 30–60 pièces → environ 1 power-up toutes les 3–5 parties sans payer.
- Tout dans `data/economy.tres`.

## 7. Monétisation
**Principe : la pub est un cadeau que le joueur choisit, jamais une punition.**

### 7.1 Rewarded (priorité)
| Placement | Moment |
|---|---|
| **Continuer** (supprime les 3 fruits du haut) | Écran game over, 1 fois par partie |
| **Secouer le panier** gratuit | Bouton dans la partie |
| **Doubler les pièces** de la partie | Écran de fin |
| Essai supplémentaire du défi du jour | Défi |
| Bouclier de série | Connexion |
| Coffre bonus | Après mission |

### 7.2 Interstitiel
- Uniquement **entre deux parties**, max 1 toutes les **3 parties ET 3 minutes**.
- Jamais avant la **5e partie** ni juste après un rewarded.
- Pas de bannière.

### 7.3 IAP (V1.1)
- **Retirer les pubs forcées** (≈ 2,99 $) : best-seller du genre.
- Pack de démarrage (pièces + panier exclusif), packs de pièces, thèmes premium.
- Plus tard : paiement mobile money hors Play Store (CinetPay / PayDunya) pour l'Afrique.

### 7.4 Technique
- **AdMob** + médiation (AppLovin MAX ou LevelPlay en phase 2 pour monter l'eCPM).
- Consentement **UMP** (RGPD).
- `AdsManager` derrière une interface (mock en dev).

## 8. Analytics & tuning
Événements Firebase : `game_start`, `game_over` (score, fruit max, durée), `merge` (rang), `new_fruit_discovered`, `ad_offered` / `ad_watched` (placement), `powerup_used`, `mission_done`, `share`.
KPIs à suivre chaque semaine : J1/J7, durée de session, parties/jour, taux de vue rewarded par placement, % joueurs atteignant chaque fruit (**courbe de difficulté**).
> Si < 5 % des joueurs voient la Mangue en 3 jours → panier trop petit ou spawn trop dur.

## 9. Technique
```
res://
  autoload/  GameState.gd, SaveManager.gd, AdsManager.gd, Audio.gd, Analytics.gd, Locale.gd
  data/      fruits.tres, physics.tres, economy.tres, missions.tres, levels/ (Commandes)
  scenes/    Main.tscn, Game.tscn, Fruit.tscn, Basket.tscn, ui/…
  scripts/   MergeSystem.gd, Spawner.gd, ComboTracker.gd, DangerLine.gd, Juice.gd
  assets/    models/ (.glb), shaders/ (toon, outline), textures/, vfx/, sfx/, music/, fonts/
  locale/    fr.po, en.po, wo.po
  tests/     (GUT)
```
- **Fruit** = `RigidBody3D` + `CollisionShape3D` sphère, `axis_lock_linear_z`, rotations X/Y verrouillées (rotation Z libre pour le roulé).
- **MergeSystem** : file de fusions traitée une fois par frame physique, chaque fruit marqué `merging` pour éviter les doubles fusions (bug classique des clones).
- **Spawner** : générateur aléatoire **seedé** (requis pour le défi du jour).
- Sauvegarde JSON locale + autosave à la pause.
- Tests GUT : fusion simple, triple contact simultané, combo, game over, graine du défi reproductible.

## 10. Jalons
1. **M1 — Cœur jouable (2–3 j)** : panier, lâcher, physique, fusion des 11 fruits (sphères colorées), score, game over, fruit suivant. → **Test du fun**, on ajuste la physique jusqu'à ce que ce soit addictif.
2. **M2 — Juice (2–3 j)** : squash & stretch, visages, particules de jus, combos, hit-stop, sons kora/balafon, Moment Baobab.
3. **M3 — Habillage 3D (3–4 j)** : modèles des fruits, panier, fond de marché, toon shader, UI.
4. **M4 — Méta & pub (3 j)** : pièces, power-ups, missions, connexion 7 j, album, AdMob rewarded/interstitiel, analytics.
5. **M5 — Release (1–2 j)** : icône, captures, vidéo store (le Moment Baobab !), AAB signé, test interne.
6. **V1.1** : Commandes (niveaux), défi du jour classé, IAP, thèmes.

## 11. Règles pour Claude Code
- Jalon par jalon ; pas de M(n+1) sans validation de M(n).
- **M1 doit être fun avec des sphères colorées** avant tout habillage. Si ce n'est pas fun, on règle la physique, pas les graphismes.
- Toute valeur d'équilibrage dans `data/`, jamais en dur.
- GDScript typé, signaux plutôt que couplage direct.
- Tests GUT sur le MergeSystem avant l'UI.
- Placeholders tant que les assets finaux ne sont pas fournis.
