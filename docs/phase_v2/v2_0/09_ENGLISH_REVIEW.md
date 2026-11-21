# V2-0 — Relecture anglaise (1re passe, 202 clés)

Relecture complète de la colonne `en` de `localization/translations.csv` (relecteur non natif).
Statuts : **OK** (aucune réserve), **CORRIGÉ** (modifié dans cette passe), **À VALIDER** (formulation
correcte mais à confirmer par un anglophone natif ou par le propriétaire).

## Corrigé dans cette passe
| Clé | Avant | Après | Raison |
|---|---|---|---|
| FRUIT_TAMARIN_FACT, LORE_TAMARIN_TEXT | « dakhar » | "dakhar" | guillemets français dans un texte anglais |
| LORE_PAIN_DE_SINGE_BENEFITS | « superfruit » | "superfruit" | idem |
| FRUIT_PAIN_DE_SINGE_FACT | Monkey bread is the fruit of the baobab… | Baobab fruit, or monkey bread, grows on the baobab… | cohérence avec le nom affiché « Baobab fruit » |
| SHARE_FRUIT_TEXT | I unlocked %s in Fruit Village! | I unlocked the %s in Fruit Village! | article manquant (« I unlocked the Mango ») |

## À valider (natif / propriétaire)
| Clé(s) | Texte actuel | Question |
|---|---|---|
| FRUIT_DITAKH_* | Detar | Nom courant de *Detarium senegalense* : « detar », « sweet detar » ou garder « Ditakh » (nom local, comme « bissap ») ? |
| FRUIT_MADD_* | Saba fruit | « saba fruit » est compris des botanistes ; un joueur anglophone le connaît-il ? Alternative : « Madd » (nom local). |
| FRUIT_SIDEM_* | Jujube | Correct ; vérifier que « jujube » (aussi un bonbon aux États-Unis) n'induit pas en erreur. |
| FRUIT_BISSAP_NAME / FACT | Hibiscus / « The red calyces of bissap… » | « calyces » est technique ; « The red petals… » est plus parlant mais botaniquement faux. Nom « Hibiscus » ou « Bissap » ? |
| LORE_TAMARIN_TEXT | The Dakar-Plateau district may owe its name… | Fidèle au français ; l'étymologie courante porte sur **Dakar** (la ville). À vérifier côté contenu (FR aussi). |
| FRUIT_*_GOAL | the Jujube, the Mango… | Majuscule sur les noms communs (« the Mango ») : choix de style du jeu à confirmer. |
| SETTINGS_AMBIANCE | Scenery | « Scenery », « Ambience » ou « Time of day » (le réglage choisit jour / soir / nuit) ? |
| SETTINGS_CONSENT | Consent | Libellé du bouton UMP : « Privacy choices » / « Ad choices » est plus courant dans les jeux. |
| GAMEOVER_CONTINUE_HINT | Removes the %d highest fruits | « Removes the top %d fruits » plus naturel ? |
| GAMEOVER_RIBBON_OVER | The basket overflows! | Ton à confirmer (« Basket full! » plus court). |
| DAILY_CLOCK_SUSPECT | Your phone's clock looks wrong: the gift will come back once it is set right. | Correct ; long : cet état n'a pas été capturé, débordement à vérifier (checklist A23). |
| POWERUP_PESTLE_NAME | Pestle | Mot peu courant pour des joueurs non natifs ; garder (référence au pilon africain) ou « Smash » ? |
| MISSION_KIND_SCORE_SINGLE_ONE | Score %d point in one game | Forme singulière jamais affichée en pratique (cibles > 1) ; OK. |
| NOTIF_STREAK | Your streak is in danger 🔥 Visit the market before midnight! | Ton marketing à valider. |

## OK sans réserve
Toutes les autres clés (menus, HUD, pause, fin de partie, missions, cadeau du jour, album, power-ups,
niveau, réglages, qualité, langues, notifications, faits et lore des fruits non listés ci-dessus) :
grammaire, pluriels (`_ONE` / `_OTHER`), formats `%d` / `%s` identiques au français (contrôle automatique),
aucun texte coupé sur les captures 720×1280.

## Hors relecture
- Voix enregistrées (FR / wolof) : non traduites, volontairement.
- Textes de la fiche store anglaise : hors V2-0.
