class_name Ambiances
extends Resource
## Liste ordonnée des ambiances (data/ambiances.tres) et choix de l'ambiance
## active : réglage joueur, ou « Auto » selon l'heure locale du téléphone.

const PATH := "res://data/ambiances.tres"
## Réglage « ambiance » : -1 = Auto (heure locale).
const AUTO := -1

@export var list: Array[AmbianceDef] = []
## Auto : heures de début (incluses) du jour et du coucher ; la nuit sinon.
@export var day_from_hour: int = 7
@export var dusk_from_hour: int = 17
@export var night_from_hour: int = 20
## Index dans `list` pour jour / coucher / nuit (mode Auto).
@export var day_index: int = 0
@export var dusk_index: int = 1
@export var night_index: int = 2


static func load_default() -> Ambiances:
	return load(PATH) as Ambiances


## Index de l'ambiance pour un réglage (AUTO ou index) à une heure donnée (0..23).
func resolve(setting: int, hour: int) -> int:
	if setting >= 0 and setting < list.size():
		return setting
	if hour >= day_from_hour and hour < dusk_from_hour:
		return day_index
	if hour >= dusk_from_hour and hour < night_from_hour:
		return dusk_index
	return night_index


## Ambiance active (réglage joueur + heure locale actuelle).
func current() -> AmbianceDef:
	var hour := int(Time.get_datetime_dict_from_system().get("hour", 12))
	return list[resolve(int(SaveManager.get_setting(&"ambiance")), hour)]
