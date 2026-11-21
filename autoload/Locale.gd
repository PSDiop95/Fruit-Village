extends Node
## Autoload Locale : applique la langue (logique : LocaleCore).
## Préférence persistée dans le réglage `language` de SaveManager
## (LocaleCore.AUTO = pas de choix : langue du système, sinon français).
## Changement de langue à chaud : TranslationServer, nœuds liés (Loc.set_text)
## re-traduits, signal `changed` pour les écrans à texte dynamique.

signal changed(language: String)

const SETTING := &"language"

## Langue appliquée (« fr » / « en »).
var language: String = LocaleCore.DEFAULT
## Remplace OS.get_locale() (tests : environnement indépendant de la machine).
var system_locale_override: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.setting_changed.connect(func(k: StringName, _v: Variant) -> void:
		if k == SETTING:
			apply())
	SaveManager.loaded.connect(apply)
	apply()


func system_locale() -> String:
	return system_locale_override if not system_locale_override.is_empty() else OS.get_locale()


## Préférence enregistrée (LocaleCore.AUTO si aucun choix).
func preference() -> String:
	return str(SaveManager.get_setting(SETTING))


## Choix explicite du joueur (persisté). LocaleCore.AUTO revient à la langue
## du système.
func set_language(code: String) -> void:
	var c := LocaleCore.normalize(code)
	SaveManager.set_setting(SETTING, c if c in LocaleCore.SUPPORTED else LocaleCore.AUTO)


func apply() -> void:
	var lang := LocaleCore.resolve(preference(), system_locale())
	var was := language
	language = lang
	if TranslationServer.get_locale() != lang:
		TranslationServer.set_locale(lang)
	if lang != was:
		if is_inside_tree():
			Loc.refresh_tree(get_tree().root)
		changed.emit(lang)
