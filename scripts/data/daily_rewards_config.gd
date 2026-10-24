class_name DailyRewardsConfig
extends Resource
## Connexion quotidienne : calendrier, série, bouclier, anti-triche horloge,
## notifications locales.

@export var rewards: Array[DailyRewardDef] = []

@export_group("Bouclier de série")
## Un bouclier au plus tous les N jours.
@export var shield_cooldown_days: int = 7
## Jours manqués couverts par le bouclier.
@export var shield_max_missed_days: int = 1

@export_group("Horloge")
## Recul toléré de l'horloge (min) avant de suspendre la récompense.
@export var backward_tolerance_minutes: int = 10
## Avance incohérente (h) : l'horloge murale avance de plus que le temps
## réellement écoulé dans la session.
@export var forward_jump_hours: int = 48

@export_group("Notifications")
@export var notifications_max_per_day: int = 2
## Heure locale du rappel « récompense du jour ».
@export var reminder_hour: int = 12
## Heure locale du rappel « série en danger » (si non réclamée).
@export var streak_warning_hour: int = 19
@export var reminder_title: String = "Fruit Village"
@export var reminder_text: String = "Ta récompense du jour t'attend au marché !"
@export var streak_text: String = "Ta série est en danger 🔥 Passe au marché avant minuit !"
