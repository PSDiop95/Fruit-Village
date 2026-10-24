class_name NotificationPlanner
extends RefCounted
## Planifie les rappels locaux (pur, testable) : au plus
## `notifications_max_per_day` par jour local.
## - « récompense du jour » à reminder_hour, demain (ou aujourd'hui si pas
##   encore réclamée et l'heure pas passée) ;
## - « série en danger » à streak_warning_hour, le premier jour où la
##   récompense n'est pas encore réclamée, si une série est en cours.
## Tout est replanifié à chaque lancement / réclamation.

const ID_REMINDER := 1
const ID_STREAK := 2


## Renvoie [{id, delay (s), title, text}], trié par délai.
static func plan(clock: MetaClock, cfg: DailyRewardsConfig, claimed_today: bool,
		streak: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if cfg.notifications_max_per_day <= 0:
		return out
	var today := clock.today()
	var day := today + 1 if claimed_today else today
	var reminder := clock.seconds_until(day, cfg.reminder_hour)
	if reminder <= 0:
		reminder = clock.seconds_until(day + 1, cfg.reminder_hour)
		day += 1
	out.append({"id": ID_REMINDER, "delay": reminder, "title": cfg.reminder_title,
		"text": cfg.reminder_text})
	if streak > 0 and cfg.notifications_max_per_day >= 2:
		var warn_day := today + 1 if claimed_today else today
		var warn := clock.seconds_until(warn_day, cfg.streak_warning_hour)
		if warn <= 0:
			warn = clock.seconds_until(warn_day + 1, cfg.streak_warning_hour)
		out.append({"id": ID_STREAK, "delay": warn, "title": cfg.reminder_title,
			"text": cfg.streak_text})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["delay"] < b["delay"])
	return out
