class_name SaveRecovery
extends RefCounted
## V2-0 (TD-10) : règles de récupération d'une sauvegarde suspecte (pure,
## testable, sans accès disque). SaveManager décide QUAND l'appliquer ;
## ce module décide QUOI garder.
##
## - fence() : on repart de la copie de secours (.bak, digne de confiance) et
##   on y reporte uniquement les champs « restrictifs » de la version suspecte
##   (récompense du jour déjà prise, mission déjà réclamée…) : jamais de
##   récompense touchée deux fois, jamais de gain repris du fichier suspect.
## - salvage() : pas de copie de secours valable. On garde la progression,
##   nettoyée (types, bornes) ; le solde de pièces ne peut pas dépasser ce que
##   le joueur a réellement gagné (départ + gagné − dépensé).

## Retard maximal (jours) admis entre la copie de secours et le fichier suspect
## pour reporter un jour de réclamation (la copie a au plus une écriture de
## retard, en cas de coupure entre les deux écritures).
const FENCE_DAYS := 2


## `trusted`, `suspect` : données v2 décodées ({"core", "systems", …}).
## Renvoie une copie de `trusted` avec les champs restrictifs de `suspect`.
static func fence(trusted: Dictionary, suspect: Dictionary) -> Dictionary:
	var out := trusted.duplicate(true)
	var t_sys := _dict(out, "systems")
	var s_sys := _dict(suspect, "systems")
	out["systems"] = t_sys
	# Cadeau du jour / bouclier de série déjà pris.
	if t_sys.get("daily") is Dictionary and s_sys.get("daily") is Dictionary:
		var t: Dictionary = t_sys["daily"]
		var s: Dictionary = s_sys["daily"]
		for f in ["last_claim_day", "last_shield_day"]:
			if not t.has(f) or not s.has(f):
				continue
			var tv := int(t[f])
			var sv := int(s[f])
			if sv > tv and sv <= tv + FENCE_DAYS:
				t[f] = sv
	# Missions du même jour déjà réclamées / doublées.
	if t_sys.get("missions") is Dictionary and s_sys.get("missions") is Dictionary:
		var t: Dictionary = t_sys["missions"]
		var s: Dictionary = s_sys["missions"]
		if int(t.get("day", -1)) == int(s.get("day", -2)) \
				and t.get("active") is Array and s.get("active") is Array:
			for te in t["active"]:
				if not te is Dictionary:
					continue
				for se in s["active"]:
					if se is Dictionary and str(se.get("id", "")) == str(te.get("id", "")):
						te["claimed"] = bool(te.get("claimed", false)) or bool(se.get("claimed", false))
						te["doubled"] = bool(te.get("doubled", false)) or bool(se.get("doubled", false))
	# Récompense d'album complet déjà donnée.
	if t_sys.get("collection") is Dictionary and s_sys.get("collection") is Dictionary:
		var t: Dictionary = t_sys["collection"]
		t["completion_claimed"] = bool(t.get("completion_claimed", false)) \
			or bool(s_sys["collection"].get("completion_claimed", false))
	return out


## Nettoie des données non vérifiées. Renvoie {"data": Dictionary,
## "issues": Array[String]} (noms de champs corrigés, sans valeurs).
## Les bornes fines (rangs, stock, xp…) restent appliquées par chaque système
## (from_dict) au chargement.
static func salvage(data: Dictionary, starting_coins: int) -> Dictionary:
	var out := data.duplicate(true)
	var issues: Array[String] = []
	if not out.get("core") is Dictionary:
		if out.has("core"):
			issues.append("core")
		out["core"] = {}
	if not out.get("systems") is Dictionary:
		if out.has("systems"):
			issues.append("systems")
		out["systems"] = {}
	var sys: Dictionary = out["systems"]
	for k in sys.keys():
		if not sys[k] is Dictionary:
			issues.append("systems.%s" % k)
			sys.erase(k)
	if sys.get("wallet") is Dictionary:
		var w: Dictionary = sys["wallet"]
		var earned := maxi(_int(w.get("earned", 0)), 0)
		var spent := maxi(_int(w.get("spent", 0)), 0)
		var coins := maxi(_int(w.get("coins", 0)), 0)
		var bound := maxi(starting_coins + earned - spent, 0)
		if coins > bound:
			issues.append("wallet.coins")
			coins = bound
		w["coins"] = coins
		w["earned"] = earned
		w["spent"] = spent
	return {"data": out, "issues": issues}


## Solde de pièces cohérent avec l'historique (invariant d'un portefeuille
## jamais modifié hors du jeu).
static func wallet_consistent(wallet: Dictionary, starting_coins: int) -> bool:
	return _int(wallet.get("coins", 0)) <= starting_coins + _int(wallet.get("earned", 0)) \
		- _int(wallet.get("spent", 0))


static func _dict(d: Dictionary, key: String) -> Dictionary:
	var v: Variant = d.get(key, {})
	return v if v is Dictionary else {}


static func _int(v: Variant) -> int:
	return int(v) if v is int or v is float or (v is String and (v as String).is_valid_int()) else 0
