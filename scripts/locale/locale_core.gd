class_name LocaleCore
extends RefCounted
## Choix de la langue (pur, testable) : préférence du joueur, sinon langue du
## système au démarrage, sinon français. Aucune dépendance au moteur.

const FR := "fr"
const EN := "en"
## Langues livrées, dans l'ordre d'affichage des réglages.
const SUPPORTED: Array[String] = [FR, EN]
const DEFAULT := FR
## Préférence « automatique » (aucun choix explicite : langue du système).
const AUTO := ""


## « en_US », « EN-gb », « fr » → code de langue seul (« en », « fr »).
static func normalize(code: String) -> String:
	var c := code.strip_edges().to_lower().replace("-", "_")
	return c.get_slice("_", 0) if not c.is_empty() else ""


static func is_supported(code: String) -> bool:
	return normalize(code) in SUPPORTED


## Langue à appliquer. `preference` : réglage du joueur (AUTO = aucun choix) ;
## `system_locale` : OS.get_locale().
static func resolve(preference: String, system_locale: String) -> String:
	var p := normalize(preference)
	if p in SUPPORTED:
		return p
	var s := normalize(system_locale)
	if s in SUPPORTED:
		return s
	return DEFAULT


## Forme plurielle à utiliser pour `n` : "ONE" ou "OTHER".
## Français : 0 et 1 au singulier ; anglais : 1 seul au singulier.
static func plural_form(language: String, n: int) -> String:
	if normalize(language) == FR:
		return "ONE" if absi(n) <= 1 else "OTHER"
	return "ONE" if absi(n) == 1 else "OTHER"
