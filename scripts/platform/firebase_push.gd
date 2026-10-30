class_name FirebasePush
extends Node
## Notifications push (Firebase Cloud Messaging) sur Android et iOS : plugin
## Godotx, singleton GodotxFirebaseMessaging. Envoi depuis la console Firebase
## (Messaging > nouvelle campagne), aucun serveur de jeu.
## La permission est demandée au même moment que les rappels locaux (déblocage
## du cadeau du jour) ; ensuite, à chaque lancement, l'appel ne fait que
## réenregistrer l'appareil auprès d'APNs / FCM (pas de nouvelle fenêtre).
## Accès dynamique : le projet compile sans le plugin.

signal token_received(token: String)

const SINGLETON := "GodotxFirebaseMessaging"

## Jeton FCM de l'appareil (vide tant qu'il n'est pas reçu).
var token: String = ""
var granted: bool = false
## Singleton de remplacement (tests).
var messaging: Object

var _sdk_ready: bool = false
var _wants_permission: bool = false


static func available() -> bool:
	return FirebaseBoot.available() and Engine.has_singleton(SINGLETON)


func _ready() -> void:
	if messaging == null:
		messaging = Engine.get_singleton(SINGLETON)
	messaging.connect("messaging_permission_granted", _on_granted)
	messaging.connect("messaging_permission_denied", _on_denied)
	messaging.connect("messaging_token_received", _on_token)
	messaging.connect("messaging_error", _on_error)
	FirebaseBoot.when_ready(_on_core_ready)


func _on_core_ready(ok: bool) -> void:
	if not ok or not is_inside_tree():
		return
	messaging.call("initialize")
	_sdk_ready = true
	if _wants_permission:
		request_permission()


## Fenêtre système au premier appel, réenregistrement silencieux ensuite.
func request_permission() -> void:
	_wants_permission = true
	if not _sdk_ready:
		return
	_wants_permission = false
	messaging.call("request_permission")


func _on_granted() -> void:
	granted = true
	messaging.call("get_token")


func _on_denied() -> void:
	granted = false


func _on_token(t: String) -> void:
	token = t
	token_received.emit(t)
	if OS.is_debug_build():
		print("FCM token : ", t)


func _on_error(message: String) -> void:
	push_warning("FCM : %s" % message)
