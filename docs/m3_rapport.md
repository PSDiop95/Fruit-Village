# M3 — Habillage 3D : rapport

Règle d'or respectée : **la collision ne change pas**. Fruits = sphères de
`data/fruits.tres`, panier = 3 boîtes M1 de `Game._build_basket`. Tests :
`test_collision_inchangee_par_le_modele`, `test_basket_collision_unchanged`,
`test_basket_model_never_enters_play_area`. Tests M1/M2 non modifiés et verts.

## Pipeline

| Étape | Outil |
|---|---|
| Palette unique 256x256 (alpha = matière : velours / mat / brillant) | `tools/blender/palette_def.py` → `make_palette.py` → `assets/textures/palette.png` |
| Modélisation (1 script par asset, sans aléatoire, ré-exécutable) | `tools/blender/fruit_<id>.py`, `basket_calebasse.py`, `stall_sandaga.py`, `decor_sandaga.py` |
| Aperçu live dans Blender (MCP) | `common.preview(module, pos)` / `common.preview_prop(...)` → collection `MergeFruits` |
| Export batch + vérification + promotion | `python tools/build_models.py` (Blender headless → `_staging` → `tools/verify_models.gd` → `assets/models/`) |
| Refus d'export | triangles ≥ 800, rayon ≠ fruits.tres ±3 %, matériau ≠ `palette`, pas de `face_anchor` |

Normes : `.glb`, 1 unité = 1 m, origine au centre du fruit, avant = +Z (Godot),
aucune image embarquée (le jeu lit `palette.png` via un matériau partagé).

## Assets produits

| Asset | Fichier | Triangles |
|---|---|---|
| 11 fruits | `assets/models/fruit_<id>.glb` | 460 – 760 |
| Panier calebasse (bord en U, frise wax, cavité, ventre) | `basket_calebasse.glb` | 978 |
| Étal bois + nappe wax | `stall_sandaga.glb` | 104 |
| Décor lointain / moyen / proche, passante | `decor_far/mid/near/passant.glb` | 186 / 3192 / 86 / 272 |
| Palette | `assets/textures/palette.png` (+ `palette.json`) | — |
| Shaders | `toon.gdshader`, `toon_low.gdshader` (+ `toon_common.gdshaderinc`), `outline.gdshader`, `decor.gdshader`, `blob_shadow.gdshader` | — |
| Thème UI | `assets/ui/theme.tres` (généré : `tools/make_theme.gd`) | — |
| Icône / splash (placeholders) | `assets/ui/icon.png`, `assets/ui/splash.png` (`tools/make_icon.gd`) | — |
| Références visuelles | `docs/refs/fruits/` | — |

Réglages : `data/visual.tres` (lumière, toon, grain de peau, contour, halo,
décor, passants, ombres, qualité). Aucune valeur visuelle en dur.

## Placeholders restants — à fournir

| Élément | État actuel | À fournir |
|---|---|---|
| **Police** | Police système grasse (Segoe UI sur PC, Roboto sur Android) | `Fredoka-SemiBold.ttf` ou `Baloo2-Bold.ttf` (licence OFL) dans `assets/fonts/` : prise en compte automatiquement, puis relancer `tools/make_theme.gd` |
| **Logo** | Texte « Merge Marché » sur cartouche + frise wax | Logo illustré (PNG transparent, ~1000 px de large) |
| **Icône** | Rendu 3D sidem + mangue + pain de singe sur orange | Illustration finale 512x512 (+ icône adaptative Android : avant-plan / fond 432x432) |
| **Splash** | Même rendu + titre | Illustration 1080x1920 |
| **Sons** | Placeholders synthétiques M2 (`tools/gen_sounds.py`) | Notes kora / balafon, boucle afrobeat/mbalax, ambiance marché, voix (« Dieuredieuf ! », « Waaw ! », « Ndekki li ! ») |

## Performance

Voir `docs/perf_m3.md` (mesuré sur PC, iGPU Intel UHD, 1080x1920, vsync coupé).

- Triangles : 25 000 – 56 000 à l'écran (cible < 100 000).
- Draw calls **3D** : 37 – 46 jusqu'à ~27 fruits, en Haut comme en Bas (cible < 60).
  Visages et taches d'ombre de tous les fruits regroupés en MultiMesh (`FruitBatcher`).
- Draw calls **UI 2D** : 22 au repos, jusqu'à ~49 pendant les textes « +15 » /
  « COMBO » de M2. Total 59 – 90 : au-dessus de 60 pendant les combos.
- FPS : 240 – 290 sur PC. **Non mesuré sur téléphone 2 Go** : à faire au test interne.
- Qualité auto : RAM < 2,6 Go ou GPU d'entrée de gamme connu → Bas ; < 4,5 Go → Moyen ;
  sinon Haut. Baisse automatique si FPS < 45 (mode Auto uniquement).
- Bas = sans contour ni rim light. Textures en ETC2 (`import_etc2_astc`), palette sans perte.
- APK : non exporté (pas de SDK Android ni de templates sur cette machine). Assets :
  2,4 Mo → APK estimé ~25 – 30 Mo (moteur Godot arm64 compris), cible < 60 Mo.

## Décisions et écarts

- **Ombres** : ombres dynamiques coupées. En vue de face, les fruits touchent
  presque le fond du panier : leur ombre portée reste cachée derrière eux (et
  aucune ombre n'était rendue dans cette config). Remplacées par des taches
  d'ombre sous chaque fruit, à tous les niveaux de qualité (moins chères).
- **Fruits allongés** (mangue, papaye, ananas, pain de singe) : élargis à
  0,80 – 0,84 de la hauteur pour rester proches de la sphère de collision.
- **Hit-stop** : `juice.tres` → `time_scale_max_step = 0.034`. Une frame lente
  (chargement, à-coup) ne consomme plus tout un hit-stop d'un coup.
- **Numéros de rang** sous les visages coupés (`show_rank_numbers = false`) : les
  modèles se distinguent par la forme et la couleur.
- Scène principale : `scenes/Main.tscn` (titre ↔ partie). `Game.tscn` reste
  jouable seul (tests).

## Captures (`docs/screens/`)

`m3_planche_fruits`, `m3_titre`, `m3_reglages`, `m3_partie_debut`,
`m3_partie_moitie`, `m3_baobab`, `m3_pause`, `m3_game_over`.
Regénérer : `Godot --path . --resolution 720x1280 -s tools/capture_m3.gd -- docs/screens`
(Linux CI : `xvfb-run -a godot ...`).
