extends GutHookScript
## Avant toute la suite : environnement indépendant de la machine (V2-0).
## La langue du système est fixée à « fr » (langue par défaut du jeu) pour que
## les tests V1, écrits en français, donnent le même résultat sur un poste
## anglais ou en CI. Les tests de localisation changent la langue eux-mêmes
## et la remettent ensuite.


func run() -> void:
	var locale: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null(^"Locale")
	if locale:
		locale.system_locale_override = "fr_FR"
		locale.apply()
