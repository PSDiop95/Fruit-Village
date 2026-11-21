# V2-0 — Récupération des sauvegardes (TD-10)

## Avant (V1)
Fichier `TAMPERED` (checksum invalide) : réglages gardés, **toute la progression remise à zéro, sans copie**.
Fichier `CORRUPT` : valeurs par défaut, copie `.corrupt` écrasée à chaque fois.

## Fichiers (même dossier que `save.json`)
| Fichier | Rôle |
|---|---|
| `save.json` | sauvegarde principale (SaveCodec v2, inchangé) |
| `save.json.bak` | copie de secours : dernier état écrit **et vérifié** par le jeu (réécrite après chaque sauvegarde réussie) |
| `save.json.<type>[-N]` | quarantaine : `tampered`, `corrupt`, `future`, `v1` (avant migration), `bak-invalid` ; copie vérifiée octet par octet, jamais écrasée (N = 2…20) |

## Décision au chargement
| Détecté (`last_status`) | Action | `recovery` |
|---|---|---|
| OK | chargé | NONE |
| MIGRATED (v1) | copie `.v1`, migration, réécriture v2 | NONE |
| MISSING | `.bak` valide → rechargé et réécrit | BACKUP (sinon NONE) |
| CORRUPT | quarantaine ; `.bak` valide → rechargé ; sinon défauts | BACKUP / RESET |
| TAMPERED | quarantaine ; `.bak` valide → rechargé + **clôture** ; sinon **récupération nettoyée** | BACKUP / SALVAGED |
| FUTURE (`FV3`… ou `version` > 2) | quarantaine ; données connues chargées, nettoyées, sections inconnues gardées | SALVAGED |

- **Clôture** (`SaveRecovery.fence`) : on repart de la copie de confiance et on y reporte seulement ce qui
  empêche un doublon : jour du cadeau / bouclier déjà pris (retard ≤ 2 jours), missions du jour réclamées
  ou doublées, récompense d'album donnée. Aucun gain n'est repris du fichier suspect.
- **Récupération nettoyée** (`SaveRecovery.salvage`) : progression gardée (score, album, XP, missions…),
  types et bornes contrôlés (puis `from_dict` de chaque système). Le solde ne peut pas dépasser
  `départ + gagné − dépensé` : un solde gonflé est ramené à cette valeur (pas à zéro).
- **Copie impossible** (disque plein, 20 copies différentes déjà présentes) : `writes_blocked = true`,
  rien n'est écrasé, la partie reste jouable sans écrire. État signalé.

## Signalement
- `SaveManager.integrity_issue(status, recovery)` (différé après le chargement).
- Statistique `save_recovery {status, recovery, blocked}` : **aucune valeur de la sauvegarde**, envoyée
  seulement avec consentement (au premier lancement le consentement n'est pas encore connu : perdue).
- `push_warning` dans le journal (noms de champs corrigés seulement).

## Récupération contrôlée (support)
1. Récupérer `save.json.tampered` (ou `.corrupt`, `.future`) sur l'appareil (`adb shell run-as`).
2. L'examiner hors du jeu ; si légitime, le replacer en `save.json` avec un checksum recalculé
   (`tests/fixtures/saves/make_fixtures.py` montre le calcul) ; au lancement suivant : statut OK.

## Limites connues
- Le checksum n'est pas une protection cryptographique (sel dans l'APK) : un tricheur qui le recalcule
  n'est pas détecté. L'invariant du portefeuille ne s'applique qu'aux fichiers suspects.
- Stock de power-ups d'un fichier suspect sans copie de secours : borné à 999 par type (règle V1), non vérifiable.
- `.bak` peut avoir une écriture de retard (coupure entre les deux écritures) : couvert par la clôture.

## Tests
`tests/unit/test_save_recovery.gd` (23 tests) + fixtures `tests/fixtures/saves/` (v1 valide, v2 valide,
corrompue, modifiée, incomplète, sections manquantes, version future ×2, grosse progression).
