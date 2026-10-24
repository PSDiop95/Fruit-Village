class_name MissionDef
extends Resource
## Modèle de mission du jour. La difficulté (objectif, récompense) dépend du
## palier du joueur (MissionsConfig.tier_levels).

enum Kind { COMBOS, CREATE_RANK, GAMES, SCORE_SINGLE, POWERUPS, MERGES }

@export var id: StringName
@export var kind: Kind = Kind.GAMES
## Texte ; %d = objectif. Pour CREATE_RANK : « %d » puis « %s » (nom du fruit).
@export var text: String = "Joue %d parties"
## Rang concerné (CREATE_RANK uniquement), 0-based.
@export var rank: int = -1
@export var weight: float = 1.0
@export var min_level: int = 1
## Objectif par palier (index = palier).
@export var targets: PackedInt32Array = PackedInt32Array([3])
## Récompense en pièces par palier.
@export var rewards: PackedInt32Array = PackedInt32Array([40])


func target_for(tier: int) -> int:
	return targets[clampi(tier, 0, targets.size() - 1)]


func reward_for(tier: int) -> int:
	return rewards[clampi(tier, 0, rewards.size() - 1)]
