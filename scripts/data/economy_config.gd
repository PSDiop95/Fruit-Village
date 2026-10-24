class_name EconomyConfig
extends Resource
## Économie des pièces (soft currency). Équilibrage : tools/sim_economy.gd.

## Pièces de fin de partie = round(score / coin_score_divisor).
@export var coin_score_divisor: float = 100.0
## Pièces offertes au tout premier lancement.
@export var starting_coins: int = 0
## Multiplicateur du bouton « Doubler » (rewarded) de l'écran de fin.
@export var double_multiplier: int = 2
## Plafond du solde (anti-débordement, sauvegarde trafiquée). 0 = aucun.
@export var max_balance: int = 999_999


func coins_for_score(score: int) -> int:
	if coin_score_divisor <= 0.0:
		return 0
	return maxi(int(round(score / coin_score_divisor)), 0)
