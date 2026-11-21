class_name Loc
extends RefCounted
## Accès aux traductions (TranslationServer, fichiers importés depuis
## localization/translations.csv). Les textes affichés passent TOUJOURS par
## une clé stable (MAJUSCULES_SOULIGNÉES) ; jamais un texte traduit comme
## identifiant.
##
## Arguments de format : StringName = clé traduite au moment de l'affichage
## (ex. nom d'un fruit), Callable = appelé au moment de l'affichage, autre =
## utilisé tel quel. Un nœud lié par set_text() est re-traduit
## automatiquement au changement de langue (refresh_tree).

const META := &"loc"


## Traduction d'une clé (la clé elle-même si elle est absente).
static func t(key: String) -> String:
	return String(TranslationServer.translate(key))


## Traduction formatée.
static func f(key: String, args: Array = []) -> String:
	var text := t(key)
	if args.is_empty():
		return text
	return text % resolve_args(args)


static func resolve_args(args: Array) -> Array:
	var out := []
	for a in args:
		if a is StringName:
			out.append(t(String(a)))
		elif a is Callable:
			out.append((a as Callable).call())
		else:
			out.append(a)
	return out


## Clé + forme plurielle (« KEY_ONE » / « KEY_OTHER ») selon la langue courante.
static func plural_key(key: String, n: int) -> String:
	return "%s_%s" % [key, LocaleCore.plural_form(TranslationServer.get_locale(), n)]


static func plural(key: String, n: int, args: Array = []) -> String:
	return f(plural_key(key, n), args if not args.is_empty() else [n])


## Fixe le texte d'un Label / Button / … et le garde lié à sa clé : il suit
## les changements de langue. L'auto-traduction de Godot est coupée sur ce
## nœud (le texte affiché est déjà traduit).
static func set_text(node: Object, key: String, args: Array = []) -> void:
	node.set_meta(META, [key, args])
	if node is Node:
		(node as Node).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	node.set("text", f(key, args))


## Comme set_text, avec forme plurielle.
static func set_plural(node: Object, key: String, n: int, args: Array = []) -> void:
	node.set_meta(META, [key, args if not args.is_empty() else [n], n])
	if node is Node:
		(node as Node).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	node.set("text", plural(key, n, args))


static func is_bound(node: Object) -> bool:
	return node.has_meta(META)


## Re-traduit tous les nœuds liés sous `root` (changement de langue).
static func refresh_tree(root: Node) -> void:
	if root == null:
		return
	_refresh(root)
	for n in root.find_children("*", "", true, false):
		_refresh(n)


static func _refresh(n: Node) -> void:
	if not n.has_meta(META):
		return
	var m: Array = n.get_meta(META)
	if m.size() >= 3:
		n.set("text", plural(m[0], int(m[2]), m[1]))
	else:
		n.set("text", f(m[0], m[1]))


# ---------------------------------------------------------------- Données

## Clé d'un texte de donnée : PREFIX_ID_FIELD (ex. FRUIT_MANGUE_NAME).
static func data_key(prefix: String, id: StringName, field: String) -> StringName:
	return StringName("%s_%s_%s" % [prefix, String(id).to_upper(), field])


static func fruit_name_key(id: StringName) -> StringName:
	return data_key("FRUIT", id, "NAME")


static func powerup_key(id: StringName, field: String) -> String:
	return String(data_key("POWERUP", id, field))


static func fruit_name(id: StringName) -> String:
	return t(fruit_name_key(id))


static func fruit_name_of(rank: int) -> String:
	return fruit_name(FruitCatalogNames.def_of(rank).id)
