class_name MetaClock
extends RefCounted
## Horloge des systèmes méta : heure murale (unix, s), jour local, temps
## monotone de la session. Remplacée par FakeClock dans les tests.

const DAY := 86400


## Heure murale, secondes unix (UTC).
func now() -> int:
	return int(Time.get_unix_time_from_system())


## Décalage du fuseau local (s).
func utc_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


## Temps monotone depuis le lancement (s), insensible aux changements d'horloge.
func ticks() -> float:
	return Time.get_ticks_msec() / 1000.0


## Numéro du jour local (change à minuit, heure locale).
func day_of(unix: int) -> int:
	return floori(float(unix + utc_offset()) / DAY)


func today() -> int:
	return day_of(now())


## Secondes jusqu'à `hour` h locale du jour `day` (négatif si passé).
func seconds_until(day: int, hour: int) -> int:
	return day * DAY + hour * 3600 - utc_offset() - now()


func seconds_until_midnight() -> int:
	return seconds_until(today() + 1, 0)
