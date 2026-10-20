extends GutTest
## Tests de la logique pure : catalogue, fusions, tirage, combos, danger.

var catalog: FruitCatalog = load("res://data/fruits.tres")


# --- Catalogue

func test_catalog_has_11_fruits_with_growing_radius() -> void:
	assert_eq(catalog.count(), 11)
	for i in range(1, catalog.count()):
		assert_gt(catalog.get_def(i).radius, catalog.get_def(i - 1).radius,
			"rayon croissant au rang %d" % i)


func test_only_5_smallest_are_droppable() -> void:
	assert_eq(catalog.droppable_ranks(), [0, 1, 2, 3, 4] as Array[int])


func test_merge_points() -> void:
	assert_eq(catalog.merge_points(0), catalog.get_def(1).points)
	assert_eq(catalog.merge_points(catalog.max_rank()), catalog.top_merge_points)


# --- MergeSystem

func test_merge_pair_accepted_once() -> void:
	var m := MergeSystem.new()
	assert_true(m.request(1, 2))
	assert_false(m.request(2, 1), "même paire inversée refusée")
	assert_eq(m.flush().size(), 1)


func test_triple_contact_merges_only_one_pair() -> void:
	var m := MergeSystem.new()
	assert_true(m.request(1, 2))
	assert_false(m.request(2, 3), "2 déjà engagé")
	assert_false(m.request(1, 3), "1 déjà engagé")
	var pairs := m.flush()
	assert_eq(pairs.size(), 1)
	assert_eq(pairs[0], PackedInt64Array([1, 2]))


func test_flush_resets_state() -> void:
	var m := MergeSystem.new()
	m.request(1, 2)
	m.flush()
	assert_false(m.has_pending())
	assert_true(m.request(1, 3), "après flush, 1 est libre")


func test_64bit_ids_preserved() -> void:
	var m := MergeSystem.new()
	var big := 9_000_000_000_123
	m.request(big, big + 1)
	assert_eq(m.flush()[0][0], big, "id 64 bits intact")


func test_self_pair_rejected() -> void:
	assert_false(MergeSystem.new().request(5, 5))


# --- Spawner

func test_spawner_same_seed_same_sequence() -> void:
	var a := Spawner.new()
	var b := Spawner.new()
	a.setup(catalog.droppable_ranks(), 42)
	b.setup(catalog.droppable_ranks(), 42)
	for i in 50:
		assert_eq(a.take(), b.take())


func test_spawner_only_droppable_and_preview_consistent() -> void:
	var s := Spawner.new()
	s.setup(catalog.droppable_ranks(), 7)
	for i in 200:
		var next: int = s.upcoming()[0]
		var r := s.take()
		assert_between(r, 0, 4)
		assert_eq(s.current(), next, "l'aperçu annonce bien le fruit suivant")


func test_spawner_weighted_is_deterministic_and_biased() -> void:
	var w := PackedFloat32Array([1.0, 0.0, 0.0, 0.0, 3.0])
	var a := Spawner.new()
	var b := Spawner.new()
	a.setup(catalog.droppable_ranks(), 99, 1, w)
	b.setup(catalog.droppable_ranks(), 99, 1, w)
	var counts := {}
	for i in 2000:
		var r := a.take()
		assert_eq(r, b.take())
		counts[r] = counts.get(r, 0) + 1
	assert_eq(counts.keys().size(), 2, "poids nul → jamais tiré")
	assert_gt(counts[4], counts[0] * 2, "poids 3 tiré ~3x plus que poids 1")


func test_catalog_weights_aligned() -> void:
	assert_eq(catalog.droppable_weights().size(), catalog.droppable_ranks().size())


# --- Combo

func test_combo_chain_and_reset() -> void:
	var c := ComboTracker.new()
	c.configure(1.5, 8)
	assert_eq(c.register(0.0), 1)
	assert_eq(c.register(1.0), 2)
	assert_eq(c.register(2.4), 3)
	assert_eq(c.register(5.0), 1, "fenêtre dépassée → retour à x1")


func test_combo_capped() -> void:
	var c := ComboTracker.new()
	c.configure(1.5, 3)
	for i in 10:
		c.register(i * 0.1)
	assert_eq(c.multiplier(), 3)


# --- Danger

func test_danger_states() -> void:
	var d := DangerMonitor.new()
	d.configure(1.0, 2.0)
	var ids: Array[int] = [10]
	assert_eq(d.update(ids, 0.5), DangerMonitor.State.SAFE)
	assert_eq(d.update(ids, 0.6), DangerMonitor.State.WARNING)
	assert_eq(d.update(ids, 1.0), DangerMonitor.State.GAME_OVER)


func test_danger_resets_when_fruit_leaves_zone() -> void:
	var d := DangerMonitor.new()
	d.configure(1.0, 2.0)
	var ids: Array[int] = [10]
	var none: Array[int] = []
	d.update(ids, 1.5)
	assert_eq(d.update(none, 0.1), DangerMonitor.State.SAFE)
	assert_eq(d.update(ids, 0.5), DangerMonitor.State.SAFE, "le compteur repart de zéro")
