class_name MissionsCore
extends RefCounted
## Missions du jour : `active_count` missions tirées (pool pondéré) à chaque
## nouveau jour local, jamais deux du même type, objectif selon le palier du
## joueur. Progression par événements, récompense réclamée à la main.

signal progressed(index: int)
signal completed(index: int)
signal renewed

var config: MissionsConfig
## Jour local des missions actives (-1 = jamais tirées).
var day: int = -1
## Graine propre au joueur (missions différentes d'un joueur à l'autre).
var player_seed: int = 0
## [{id, target, reward, progress, claimed, doubled}]
var active: Array[Dictionary] = []


func _init(p_config: MissionsConfig, p_player_seed: int = 0) -> void:
	config = p_config
	player_seed = p_player_seed


## À appeler au lancement, au retour au premier plan, en fin de partie.
## Renvoie true si de nouvelles missions ont été tirées.
func refresh(today: int, level: int) -> bool:
	if today == day and not active.is_empty():
		return false
	_roll(today, level)
	return true


func _roll(today: int, level: int) -> void:
	day = today
	active.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([player_seed, today])
	var tier := config.tier_for_level(level)
	var pool: Array[MissionDef] = []
	for m in config.missions:
		if m.min_level <= level and m.weight > 0.0:
			pool.append(m)
	while active.size() < config.active_count and not pool.is_empty():
		var weights := PackedFloat32Array()
		for m in pool:
			weights.append(m.weight)
		var pick: MissionDef = pool[rng.rand_weighted(weights)]
		active.append({
			"id": String(pick.id), "target": pick.target_for(tier), "reward": pick.reward_for(tier),
			"progress": 0, "claimed": false, "doubled": false,
		})
		# Jamais deux missions du même type en même temps.
		pool = pool.filter(func(m: MissionDef) -> bool: return m.kind != pick.kind)
	renewed.emit()


func def_of(index: int) -> MissionDef:
	return config.get_def(StringName(active[index]["id"]))


func is_complete(index: int) -> bool:
	var m := active[index]
	return int(m["progress"]) >= int(m["target"])


func can_claim(index: int) -> bool:
	return index >= 0 and index < active.size() and is_complete(index) and not active[index]["claimed"]


func claimable_count() -> int:
	var n := 0
	for i in active.size():
		n += int(can_claim(i))
	return n


## Événement de jeu. `value` : quantité (ou score pour SCORE_SINGLE) ;
## `rank` : rang créé (CREATE_RANK).
func on_event(kind: MissionDef.Kind, value: int = 1, rank: int = -1) -> void:
	for i in active.size():
		var def := def_of(i)
		if def == null or def.kind != kind or active[i]["claimed"] or is_complete(i):
			continue
		if kind == MissionDef.Kind.CREATE_RANK and rank != def.rank:
			continue
		var before := int(active[i]["progress"])
		var target := int(active[i]["target"])
		var after: int
		if kind == MissionDef.Kind.SCORE_SINGLE:
			after = maxi(before, mini(value, target))
		else:
			after = mini(before + maxi(value, 0), target)
		if after == before:
			continue
		active[i]["progress"] = after
		progressed.emit(i)
		if after >= target:
			completed.emit(i)


## Réclame la récompense. `doubled` uniquement après le callback rewarded.
## Renvoie les pièces à créditer (0 si non réclamable).
func claim(index: int, doubled: bool = false) -> int:
	if not can_claim(index):
		return 0
	active[index]["claimed"] = true
	active[index]["doubled"] = doubled
	var reward := int(active[index]["reward"])
	return reward * (config.double_multiplier if doubled else 1)


func to_dict() -> Dictionary:
	return {"day": day, "seed": player_seed, "active": active.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	day = int(d.get("day", -1))
	player_seed = int(d.get("seed", player_seed))
	active.clear()
	var arr: Variant = d.get("active", [])
	if not arr is Array:
		return
	for e in arr:
		if e is Dictionary and config.get_def(StringName(str(e.get("id", "")))) != null:
			active.append({
				"id": str(e["id"]), "target": maxi(int(e.get("target", 1)), 1),
				"reward": maxi(int(e.get("reward", 0)), 0), "progress": maxi(int(e.get("progress", 0)), 0),
				"claimed": bool(e.get("claimed", false)), "doubled": bool(e.get("doubled", false)),
			})
