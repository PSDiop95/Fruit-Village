# 05 — Stratégie de migration et compatibilité

## 1. État actuel de la sauvegarde [FAIT]

- Fichier : `user://save.json` (`SaveManager.DEFAULT_SAVE_PATH`).
- Format **v2** (`scripts/meta/save_codec.gd`) : ligne `FV2 <sha256(sel+json)[0:24]>` puis JSON
  `{"version": 2, "core": {best_score, best_rank, games_played, settings}, "systems": {wallet, progression, collection, missions, daily, ads}}`.
- Migration v1 → v2 automatique (fruits déjà atteints ajoutés à l'album) ; réécriture immédiate après migration.
- Écriture atomique (`.tmp` relu puis renommé).
- Statuts : `OK`, `MISSING`, `CORRUPT` (copie `.corrupt` + défauts), `TAMPERED` (réglages conservés, **progression remise à zéro, sans copie**), `MIGRATED`.
- Lecture tolérante : clés inconnues ignorées (`_read_settings` ne lit que `DEFAULT_SETTINGS` ; `_systems_data` conserve toutes les clés mais un système absent ne les lit pas).

## 2. Règles de migration V2 [RECO]

1. **Rester en format v2.** Les données V2 s'ajoutent comme nouvelles entrées de `systems` (`challenge`, `orders`, `achievements`, `iap`, `leaderboard_queue`, `cloud`) et nouveaux réglages. Un binaire V1 relira un fichier V2 sans perte de ses propres données (vérifié par lecture du code : `SaveManager.save_data()` ne réécrit que les systèmes enregistrés — ⚠️ **un V1 qui ré-enregistre supprime les clés V2 inconnues** de `systems`, car `systems` est reconstruit depuis `_systems` seuls).
   → Conséquence : un rollback V2 → V1 perd les données V2 mais **conserve** la progression V1. Acceptable si documenté ; sinon il faudrait modifier V1 (interdit).
2. **Nouveaux champs dans les systèmes existants** : uniquement additifs, avec valeur par défaut dans `from_dict` (ex. compteurs par fruit dans `collection`). Jamais renommer ni changer le type d'une clé existante (`coins`, `xp`, `found`, `streak`, `cycle`, `last_claim_day`, `lifetime_games`…).
3. **Pas de changement du sel ni de l'algorithme de checksum** en V2. Si nécessaire plus tard : accepter l'ancien et le nouveau en lecture pendant au moins une version.
4. **Format v3 interdit** tant qu'une part significative du parc est en V1 (TD-11 : V1 lirait v3 comme `CORRUPT`).
5. **Corriger `TAMPERED` avant le cloud** : copie `.tampered` avant reset (modification de `SaveManager.gd` à planifier en V2-0, pas pendant l'audit).
6. **Rétro-attribution** au premier lancement V2 : succès, étoiles, déblocages calculés depuis les données V1 ; idempotente (drapeau `systems.v2_migration_done`).
7. **Courbe XP, prix, gains** : inchangés en V2-0/V2-1 (contrainte « ne pas modifier l'économie V1 »). Tout réglage ultérieur passe par RemoteConfig borné et un test A/B.

## 3. Compatibilité des achats (IAP)

- Non-consommable « Retirer les pubs » : source de vérité = store (restauration au lancement + bouton « Restaurer ») ; copie locale = cache.
- Consommables (pièces) : crédit `Wallet.earn` + `SaveManager.save_data()` **avant** acquittement/finalisation de la transaction ; journal des identifiants de transaction déjà crédités (idempotence).

## 4. Sauvegarde cloud

| Cas | Règle |
|---|---|
| Premier lien du compte, cloud vide | téléverser la sauvegarde locale |
| Cloud présent, local vierge (réinstallation) | restaurer le cloud sans question |
| Les deux non vides | fusion par système (voir 04 §7) ; en cas de doute sur les pièces, montrer un choix explicite « cet appareil / sauvegarde cloud » |
| Fichier cloud d'une version plus récente | ne pas l'écraser ; proposer la mise à jour |
| Fichier cloud V1 (v2 sans clés V2) | lecture normale + rétro-attribution |

## 5. Compatibilité plateformes et versions

- Identifiants d'application inchangés (`com.smartiaservices.fruitvillage` Android et iOS).
- Version Android : `version/code` strictement croissant (actuel 6) ; iOS : numéro de build par la CI.
- Godot reste en **4.7.2** pendant la V2 (même version que la CI iOS, clé de cache `ios.yml`). Toute montée de version = phase dédiée.
- Plugins natifs ajoutés en V2 : vérifier alignement 16 Ko (`tools/inspect_build.py`) et liste des permissions (`ALLOWED_PERMISSIONS`) — à mettre à jour dans la phase concernée.

## 6. Déploiement

- Android : déploiement progressif Play (5 % → 20 % → 50 % → 100 %) avec seuils d'arrêt `docs/LAUNCH_PLAN.md:58-59`.
- iOS : TestFlight interne → externe → phased release App Store.
- Fonctionnalités V2 derrière des interrupteurs dans `data/*.tres` (puis RemoteConfig) pour pouvoir désactiver un module sans nouvelle version.
- ⚠️ Même règle qu'au §2.1 : un module **désactivé** doit quand même appeler `register_system()` (et rendre son état tel quel), sinon `SaveManager.save_data()` effacera ses données à la première écriture. Prévoir un test « module désactivé → données conservées ».
