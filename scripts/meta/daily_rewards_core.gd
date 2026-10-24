class_name DailyRewardsCore
extends RefCounted
## Calendrier de connexion 7 jours + série (flamme).
## - une récompense par jour local ;
## - jour manqué : série et calendrier repartent à zéro, sauf bouclier
##   (rewarded, au plus 1 tous les `shield_cooldown_days` jours) ;
## - horloge incohérente (ClockGuard) : pas de récompense, aucune pénalité.

var config: DailyRewardsConfig
var last_claim_day: int = -1
var streak: int = 0
## Prochaine case du calendrier (0..6).
var cycle: int = 0
var last_shield_day: int = -1_000_000
var guard := ClockGuard.new()


func _init(p_config: DailyRewardsConfig) -> void:
	config = p_config
	guard.configure(config)


func days() -> int:
	return config.rewards.size()


func claimed_today(today: int) -> bool:
	return last_claim_day == today


## Jours manqués depuis la dernière réclamation (0 = série intacte).
func missed_days(today: int) -> int:
	if last_claim_day < 0:
		return 0
	return maxi(today - last_claim_day - 1, 0)


func is_broken(today: int) -> bool:
	return streak > 0 and missed_days(today) > 0


func shield_available(today: int) -> bool:
	return is_broken(today) and missed_days(today) <= config.shield_max_missed_days \
		and today - last_shield_day >= config.shield_cooldown_days


## État à afficher. `coherent` : verdict de ClockGuard.
func status(today: int, coherent: bool) -> Dictionary:
	var broken := is_broken(today)
	return {
		"can_claim": coherent and not claimed_today(today) and today > last_claim_day,
		"claimed_today": claimed_today(today),
		"clock_suspect": not coherent,
		"broken": broken,
		"shield_available": broken and shield_available(today),
		## Case réclamable aujourd'hui (série cassée sans bouclier → case 1).
		"day_index": 0 if broken else cycle,
		"day_index_with_shield": cycle,
		"streak": 0 if broken else streak,
	}


## Réclame la récompense du jour. `use_shield` uniquement après le callback
## rewarded. Renvoie la case réclamée (null si impossible).
func claim(today: int, coherent: bool, use_shield: bool = false) -> DailyRewardDef:
	if not coherent or claimed_today(today) or today <= last_claim_day or days() == 0:
		return null
	if is_broken(today):
		if use_shield and shield_available(today):
			last_shield_day = today
		else:
			streak = 0
			cycle = 0
	elif last_claim_day >= 0 and missed_days(today) > 0:
		cycle = 0
	var reward := config.rewards[cycle]
	streak += 1
	cycle = (cycle + 1) % days()
	last_claim_day = today
	return reward


func to_dict() -> Dictionary:
	return {"last_claim_day": last_claim_day, "streak": streak, "cycle": cycle,
		"last_shield_day": last_shield_day, "last_seen": guard.last_seen}


func from_dict(d: Dictionary) -> void:
	last_claim_day = int(d.get("last_claim_day", -1))
	streak = maxi(int(d.get("streak", 0)), 0)
	cycle = clampi(int(d.get("cycle", 0)), 0, maxi(days() - 1, 0))
	last_shield_day = int(d.get("last_shield_day", -1_000_000))
	guard.last_seen = maxi(int(d.get("last_seen", 0)), 0)
