extends SceneTree
## Simulation économique (headless) : 1 000 joueurs virtuels sur 14 jours, sans
## achat ni pub, avec les VRAIES règles (WalletCore, MissionsCore,
## DailyRewardsCore, ProgressionCore) et les fichiers data/*.tres.
## Profils : occasionnel, régulier, accro (assiduité, parties/jour, niveau).
## Scores tirés autour des médianes mesurées par tools/bot_scores.gd.
##
## Usage : Godot --headless --path . -s tools/sim_economy.gd -- [joueurs] [dossier]
## Sorties : <dossier>/sim_economy_daily.csv (par profil et par jour),
##           <dossier>/sim_economy_summary.csv (par profil, 14 jours).
##
## Comportement simulé : le joueur réclame cadeau du jour et missions dès que
## possible ; en partie, il utilise au plus 1 power-up (stock d'abord, sinon il
## achète le moins cher qu'il peut s'offrir).

const DAYS := 14
const PROFILES := {
	"occasionnel": {"share": 0.5, "p_active": 0.55, "games": [1, 4], "score_k": 0.75, "spread": 0.45},
	"regulier": {"share": 0.35, "p_active": 0.85, "games": [3, 7], "score_k": 1.0, "spread": 0.40},
	"accro": {"share": 0.15, "p_active": 0.97, "games": [8, 16], "score_k": 1.3, "spread": 0.35},
}
## Médianes de score mesurées (bot_scores.csv) : débutant → joueur rodé.
const SCORE_NOVICE := 2200.0
const SCORE_SKILLED := 4500.0
## Parties pour passer de débutant à rodé (≈ 63 %).
const LEARN_GAMES := 40.0
## Points moyens par fusion (bot_scores.csv : score / fusions).
const POINTS_PER_MERGE := 21.0
## Probabilité de vouloir un power-up dans une partie quand il est possible.
const WANT_POWERUP := 0.9

var economy: EconomyConfig = load("res://data/economy.tres")
var powerups: PowerupsConfig = load("res://data/powerups.tres")
var missions_cfg: MissionsConfig = load("res://data/missions.tres")
var daily_cfg: DailyRewardsConfig = load("res://data/daily_rewards.tres")
var levels_cfg: LevelsConfig = load("res://data/levels.tres")
var rng := RandomNumberGenerator.new()


class Player:
	var profile: String
	var wallet: WalletCore
	var prog: ProgressionCore
	var missions: MissionsCore
	var daily: DailyRewardsCore
	var games: int = 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 1000
	var out := args[1] if args.size() > 1 else "res://docs/economy"
	rng.seed = 20261023
	var players: Array[Player] = []
	for name in PROFILES:
		for i in int(round(n * PROFILES[name]["share"])):
			players.append(_new_player(name, players.size()))
	# Stats[profil][jour] = Dictionary
	var stats := {}
	for name in PROFILES:
		stats[name] = []
		for d in DAYS:
			stats[name].append({"players": 0, "active": 0, "games": 0, "earn_game": 0,
				"earn_missions": 0, "earn_daily": 0, "earn_level": 0, "spent": 0,
				"pu_used": 0, "pu_bought": 0, "pu_gift": 0, "balance_sum": 0, "level_sum": 0})
	for d in DAYS:
		var day := 20000 + d
		for p in players:
			var s: Dictionary = stats[p.profile][d]
			s["players"] += 1
			_play_day(p, day, s)
			s["balance_sum"] += p.wallet.coins
			s["level_sum"] += p.prog.level
	_write(out, stats)
	quit()


func _new_player(profile: String, idx: int) -> Player:
	var p := Player.new()
	p.profile = profile
	p.wallet = WalletCore.new(economy.max_balance)
	p.wallet.earn(economy.starting_coins)
	p.prog = ProgressionCore.new(levels_cfg)
	p.missions = MissionsCore.new(missions_cfg, idx * 7919)
	p.daily = DailyRewardsCore.new(daily_cfg)
	return p


func _play_day(p: Player, day: int, s: Dictionary) -> void:
	var prof: Dictionary = PROFILES[p.profile]
	if rng.randf() > prof["p_active"]:
		return
	s["active"] += 1
	_claim_daily(p, day, s)
	var n: int = rng.randi_range(prof["games"][0], prof["games"][1])
	for g in n:
		_play_game(p, day, s)
		_claim_missions(p, day, s)
	_claim_daily(p, day, s)  # débloqué en cours de journée


func _claim_daily(p: Player, day: int, s: Dictionary) -> void:
	if not p.prog.is_unlocked(ProgressionCore.DAILY):
		return
	var r := p.daily.claim(day, true)
	if r == null:
		return
	s["earn_daily"] += p.wallet.earn(r.coins)
	if r.powerup != &"":
		p.wallet.add_stock(r.powerup, r.powerup_count)
		s["pu_gift"] += r.powerup_count


func _claim_missions(p: Player, day: int, s: Dictionary) -> void:
	if not p.prog.is_unlocked(ProgressionCore.MISSIONS):
		return
	p.missions.refresh(day, p.prog.level)
	for i in p.missions.active.size():
		var c := p.missions.claim(i)
		if c > 0:
			s["earn_missions"] += p.wallet.earn(c)


func _play_game(p: Player, day: int, s: Dictionary) -> void:
	var prof: Dictionary = PROFILES[p.profile]
	var learn := 1.0 - exp(-p.games / LEARN_GAMES)
	var median: float = lerpf(SCORE_NOVICE, SCORE_SKILLED, learn) * prof["score_k"]
	var score: int = int(maxf(median * exp(rng.randfn(0.0, prof["spread"])), 50.0))
	# Un power-up aide un peu (une fusion de plus, panier qui respire).
	var used := _maybe_use_powerup(p, s)
	if used:
		score = int(score * 1.08)
	p.games += 1
	s["games"] += 1
	var merges := int(score / POINTS_PER_MERGE)
	var combos := rng.randi_range(1, 3) + int(score / 1500)
	var max_rank := clampi(int(log(maxf(score, 1.0) / 20.0) / log(2.0)) + rng.randi_range(-1, 1), 3, 10)
	if p.prog.is_unlocked(ProgressionCore.MISSIONS):
		p.missions.refresh(day, p.prog.level)
		p.missions.on_event(MissionDef.Kind.GAMES)
		p.missions.on_event(MissionDef.Kind.SCORE_SINGLE, score)
		p.missions.on_event(MissionDef.Kind.MERGES, merges)
		p.missions.on_event(MissionDef.Kind.COMBOS, combos)
		for r in range(5, max_rank + 1):
			p.missions.on_event(MissionDef.Kind.CREATE_RANK, mini(1 << (max_rank - r), 8), r)
		if used:
			p.missions.on_event(MissionDef.Kind.POWERUPS)
	s["earn_game"] += p.wallet.earn(economy.coins_for_score(score))
	var before := p.prog.level
	for lv in p.prog.add_xp(levels_cfg.xp_for_game(score, merges)):
		s["earn_level"] += p.wallet.earn(levels_cfg.level_up_coins)
		if ProgressionCore.POWERUPS in p.prog.unlocks_at(lv):
			for d in powerups.powerups:
				p.wallet.add_stock(d.id, d.unlock_gift)
				s["pu_gift"] += d.unlock_gift
	if p.prog.level != before:
		p.missions.refresh(day, p.prog.level)


## Au plus un power-up par partie : stock d'abord, sinon achat du moins cher
## abordable. Renvoie true si un power-up a été utilisé.
func _maybe_use_powerup(p: Player, s: Dictionary) -> bool:
	if not p.prog.is_unlocked(ProgressionCore.POWERUPS) or rng.randf() > WANT_POWERUP:
		return false
	var ids := powerups.ids()
	ids.shuffle()
	for id in ids:
		if p.wallet.use_stock(id):
			s["pu_used"] += 1
			return true
	var by_price := powerups.powerups.duplicate()
	by_price.sort_custom(func(a: PowerupDef, b: PowerupDef) -> bool: return a.price < b.price)
	for d: PowerupDef in by_price:
		if p.wallet.buy(d.id, d.price):
			s["spent"] += d.price
			p.wallet.use_stock(d.id)
			s["pu_used"] += 1
			s["pu_bought"] += 1
			return true
	return false


func _write(out: String, stats: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var daily := PackedStringArray(["profil,jour,joueurs,actifs,parties,pieces_parties,pieces_missions,"
		+ "pieces_connexion,pieces_niveaux,pieces_gagnees,pieces_depensees,powerups_utilises,"
		+ "powerups_achetes,powerups_offerts,parties_par_powerup,solde_moyen,niveau_moyen,inflation_solde_pct"])
	var summary := PackedStringArray(["profil,joueurs,parties,parties_par_joueur_actif_jour,"
		+ "pieces_gagnees_par_partie,pieces_depensees_par_partie,powerups_utilises,parties_par_powerup,"
		+ "parties_par_powerup_achete,part_achetes_pct,solde_moyen_j14,niveau_moyen_j14,"
		+ "epargne_non_depensee_pct"])
	for name in stats:
		var prev_bal := 0.0
		var tot := {"games": 0, "earned": 0, "spent": 0, "pu": 0, "bought": 0, "active": 0}
		for d in DAYS:
			var s: Dictionary = stats[name][d]
			var earned: int = s["earn_game"] + s["earn_missions"] + s["earn_daily"] + s["earn_level"]
			var bal := float(s["balance_sum"]) / maxf(s["players"], 1)
			var infl := (bal - prev_bal) / prev_bal * 100.0 if prev_bal > 0.0 else 0.0
			prev_bal = bal
			daily.append("%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%.2f,%.1f,%.2f,%.1f" % [
				name, d + 1, s["players"], s["active"], s["games"], s["earn_game"], s["earn_missions"],
				s["earn_daily"], s["earn_level"], earned, s["spent"], s["pu_used"], s["pu_bought"],
				s["pu_gift"], float(s["games"]) / maxf(s["pu_used"], 1), bal,
				float(s["level_sum"]) / maxf(s["players"], 1), infl])
			tot["games"] += s["games"]
			tot["earned"] += earned
			tot["spent"] += s["spent"]
			tot["pu"] += s["pu_used"]
			tot["bought"] += s["pu_bought"]
			tot["active"] += s["active"]
		var last: Dictionary = stats[name][DAYS - 1]
		var players: int = last["players"]
		var bal14 := float(last["balance_sum"]) / maxf(players, 1)
		summary.append("%s,%d,%d,%.2f,%.1f,%.1f,%d,%.2f,%.2f,%.0f,%.0f,%.2f,%.0f" % [
			name, players, tot["games"], float(tot["games"]) / maxf(tot["active"], 1),
			float(tot["earned"]) / maxf(tot["games"], 1), float(tot["spent"]) / maxf(tot["games"], 1),
			tot["pu"], float(tot["games"]) / maxf(tot["pu"], 1),
			float(tot["games"]) / maxf(tot["bought"], 1), 100.0 * tot["bought"] / maxf(tot["pu"], 1),
			bal14, float(last["level_sum"]) / maxf(players, 1),
			100.0 * (tot["earned"] - tot["spent"]) / maxf(tot["earned"], 1)])
	for pair in [["sim_economy_daily.csv", daily], ["sim_economy_summary.csv", summary]]:
		var f := FileAccess.open(out.path_join(pair[0]), FileAccess.WRITE)
		f.store_string("\n".join(pair[1]) + "\n")
		f.close()
	print("\n".join(summary))
