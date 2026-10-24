class_name WalletCore
extends RefCounted
## Pièces et stock de power-ups. Invariants : solde jamais négatif, achat
## refusé si fonds insuffisants, montants négatifs ignorés.

signal coins_changed(coins: int, delta: int, reason: StringName)
signal stock_changed(id: StringName, count: int)

var coins: int = 0
var max_balance: int = 999_999
var earned_total: int = 0
var spent_total: int = 0
var _stock: Dictionary = {}  # StringName -> int


func _init(p_max_balance: int = 999_999) -> void:
	max_balance = p_max_balance


## Ajoute des pièces. Renvoie le montant réellement crédité.
func earn(amount: int, reason: StringName = &"") -> int:
	if amount <= 0:
		return 0
	var before := coins
	coins = mini(coins + amount, max_balance) if max_balance > 0 else coins + amount
	var delta := coins - before
	earned_total += delta
	if delta != 0:
		coins_changed.emit(coins, delta, reason)
	return delta


func can_afford(amount: int) -> bool:
	return amount >= 0 and coins >= amount


## Débite `amount`. Refusé (false, solde inchangé) si fonds insuffisants.
func spend(amount: int, reason: StringName = &"") -> bool:
	if amount < 0 or coins < amount:
		return false
	if amount == 0:
		return true
	coins -= amount
	spent_total += amount
	coins_changed.emit(coins, -amount, reason)
	return true


func stock_of(id: StringName) -> int:
	return int(_stock.get(id, 0))


func add_stock(id: StringName, count: int = 1) -> void:
	if count <= 0:
		return
	_stock[id] = stock_of(id) + count
	stock_changed.emit(id, stock_of(id))


## Consomme une unité du stock. false si stock vide.
func use_stock(id: StringName) -> bool:
	if stock_of(id) <= 0:
		return false
	_stock[id] = stock_of(id) - 1
	stock_changed.emit(id, stock_of(id))
	return true


## Achète une unité de power-up (pièces → stock).
func buy(id: StringName, price: int) -> bool:
	if not spend(price, StringName("buy_%s" % id)):
		return false
	add_stock(id, 1)
	return true


func to_dict() -> Dictionary:
	var st := {}
	for k in _stock:
		st[String(k)] = _stock[k]
	return {"coins": coins, "earned": earned_total, "spent": spent_total, "stock": st}


## Valeurs absurdes (négatives, hors plafond) ramenées dans les bornes.
func from_dict(d: Dictionary) -> void:
	coins = clampi(int(d.get("coins", 0)), 0, max_balance if max_balance > 0 else 1 << 40)
	earned_total = maxi(int(d.get("earned", 0)), 0)
	spent_total = maxi(int(d.get("spent", 0)), 0)
	_stock.clear()
	var st: Variant = d.get("stock", {})
	if st is Dictionary:
		for k in st:
			var n := int(st[k])
			if n > 0:
				_stock[StringName(k)] = mini(n, 999)
