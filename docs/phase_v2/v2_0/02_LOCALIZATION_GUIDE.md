# V2-0 — Guide de localisation (FR / EN)

## Principe
- Système natif Godot : `localization/translations.csv` (colonnes `keys,fr,en`), importé en
  `translations.fr.translation` / `translations.en.translation` (générés à l'import, ignorés par git).
- Déclaré dans `project.godot` (`[internationalization]`), langue de repli **`fr`**.
- Tout texte affiché passe par une **clé stable** (`MAJUSCULES_SOULIGNÉES`), jamais par un texte
  traduit utilisé comme identifiant.

## Choix de la langue
| Ordre | Source | Code |
|---|---|---|
| 1 | Choix du joueur (Réglages, en-tête : `FR` / `EN`) | réglage `language` (`"fr"`/`"en"`) |
| 2 | Langue du téléphone au démarrage | `OS.get_locale()` |
| 3 | Défaut | `fr` |

- Réglage `language` = `""` (`LocaleCore.AUTO`) tant que le joueur n'a rien choisi.
- Langue inconnue (wolof, allemand…) → français.
- Choix enregistré tout de suite (SaveManager), relu au lancement.
- Logique pure : `scripts/locale/locale_core.gd` (`resolve`, `normalize`, `plural_form`).
- Autoload `Locale` (juste après SaveManager) : applique la langue, émet `changed(language)`.

## Écrire un texte dans le code
```gdscript
Loc.set_text(label, "MENU_PLAY")                       # lié : suit les changements de langue
Loc.set_text(label, "HUD_RECORD", [best])               # format %d / %s
Loc.set_text(label, "HUD_GOAL_REACH", [Loc.fruit_name_key(id)])  # StringName = clé traduite à l'affichage
Loc.set_text(label, "%s", [Missions.describe.bind(i)])  # Callable = recalculé à l'affichage
Loc.set_plural(label, "DAILY_STREAK", n)                # DAILY_STREAK_ONE / DAILY_STREAK_OTHER
Loc.t("KEY") / Loc.f("KEY", [args])                     # texte ponctuel (non lié)
```
- Un nœud lié par `Loc.set_text` est re-traduit à chaud (`Loc.refresh_tree`) : aucun redémarrage.
- Écrans à contenu dynamique : écouter `Locale.changed` (ex. titre, notifications replanifiées).
- Pluriels : FR singulier pour 0 et 1 ; EN singulier pour 1 seulement.

## Textes de données
Clés dérivées de l'`id` (les `.tres` restent la référence française, vérifiée par test) :
`FRUIT_<ID>_{NAME,FACT,GOAL,COUNT_ONE,COUNT_OTHER}`, `LORE_<ID>_{TEXT,BENEFITS}`,
`POWERUP_<ID>_{NAME,DESC}`, `AMBIANCE_<ID>_SHORT`, `MISSION_KIND_<KIND>_{ONE,OTHER}`,
`FEATURE_*`, `QUALITY_*`, `LANGUAGE_NAME_*`, `LANGUAGE_CODE_*`.

## Ajouter un texte / une langue
1. Ajouter la ligne au CSV (FR **et** EN, mêmes `%s`/`%d`).
2. Utiliser la clé dans le code. Lancer `tests/unit/test_locale.gd` : il échoue si une clé utilisée
   manque, si une traduction est vide, si les formats diffèrent ou si un écran anglais garde du français.
3. Nouvelle langue : colonne CSV + `LocaleCore.SUPPORTED` + `LANGUAGE_NAME_XX` / `LANGUAGE_CODE_XX`
   + `project.godot` (fichier `.translation`). Le wolof n'est pas livré (textes non validés).

## Non traduit (volontairement)
- Outils de développement absents des builds release : menu debug (`OS.is_debug_build`), compteur FPS,
  sonde perf, pub et consentement simulés (`MockAdOverlay`, `MockConsentDialog`).
- Voix enregistrées de la vendeuse (audio français / wolof).
- Noms propres identiques dans les deux langues (« Fruit Village », « Album », « Missions »…).

## Débordements
- Captures EN de tous les écrans méta et de partie (`tools/capture_m4.gd -- <dossier> en`) : aucun texte coupé.
- La carte Réglages mesurait déjà 1899 px sur 1920 en V1 : le choix de langue est dans l'en-tête
  (aucune hauteur ajoutée), vérifié par `test_settings_card_fits_portrait_screen` (FR et EN).
