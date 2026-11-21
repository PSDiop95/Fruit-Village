# V2-0 — Règles du système de sauvegarde (TD-14)

## Format (inchangé, compatible V1)
`FV2 <sha256(SEL + json)[0:24]>` puis `{"version": 2, "core": {...}, "systems": {clé: {...}}}`.
V1 (JSON brut) migré automatiquement (copie `.v1` gardée).

## Ce qui est préservé à chaque écriture (V2-0)
| Donnée | V1 | V2-0 |
|---|---|---|
| Section d'un système enregistré | réécrite | réécrite (état à jour) |
| Section d'un système **non** enregistré (module absent, désactivé, version plus récente) | **supprimée** | **conservée telle quelle** |
| Réglage inconnu dans `core.settings` | supprimé | conservé |
| Champ inconnu dans `core` | supprimé | conservé |
| Champ inconnu à la racine | supprimé | conservé |

## Enregistrer un système
```gdscript
func _ready() -> void:
	SaveManager.register_system("ma_cle", self)   # appelle load_state(section ou {})

func save_state() -> Dictionary: ...
func load_state(d: Dictionary) -> void: ...      # {} = premier lancement : valeurs par défaut
```
Règles :
1. **Clé stable et unique** (minuscules). Jamais renommée.
2. Enregistrer dans `_ready()` de l'autoload, **même si la fonction est désactivée** ou verrouillée
   par le niveau : l'état est simplement inactif.
3. `load_state({})` doit donner un état neuf valide ; `load_state` doit borner les valeurs (`from_dict`).
4. Enregistrement tardif autorisé : la section lue au démarrage est conservée jusque-là, même après
   des écritures, puis remise au système.
5. `unregister_system(clé)` : le système part, sa section reste (dernier état).
6. **Aucune suppression de section sans règle de migration explicite** dans `SaveCodec.migrate`
   (avec test et fixture). Une clé n'est jamais réutilisée pour un autre sens.
7. Toute valeur restrictive (récompense déjà prise) doit être ajoutée à `SaveRecovery.fence`.

## Ordre d'initialisation sûr
`SaveManager` (charge le fichier) → `Locale` → `Audio` → `Analytics` → `Wallet` → `Progression` →
`Collection` → `Missions` → `DailyRewards` → `AdsManager` → `Notifications` (ordre de `project.godot`).
Un autoload qui lit un autre système ne le fait qu'après lui dans cette liste. Les initialisations non
essentielles (pubs, consentement) restent différées après l'écran titre (`AdsManager.begin()`).

## Écritures
- Atomiques (`.tmp` relu puis renommé), puis copie de secours `.bak` (même texte).
- Une par image au plus (`request_save`) ; forcée à la mise en arrière-plan.
- Suspendues si `writes_blocked` (voir 03_SAVE_RECOVERY_GUIDE.md).
- Outils et tests : `SaveManager.erase_files(path)` efface principal + secours + quarantaines
  (jamais appelé par le jeu).
