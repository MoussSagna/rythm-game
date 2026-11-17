extends SceneTree
## Tests rapides de la logique de rythme (sans affichage).
## Lancer : godot --headless -s res://tests/run_tests.gd

var _failures := 0


func _init() -> void:
	_test_chart()
	_test_judge_grades()
	_test_judge_misses_and_extra()
	_test_rank()
	print("\n%s" % ("TOUS LES TESTS PASSENT" if _failures == 0 else "%d ÉCHEC(S)" % _failures))
	quit(1 if _failures > 0 else 0)


func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func _test_chart() -> void:
	print("Chart")
	var c := Chart.load_from("res://data/charts/djembe_duo.json")
	check(c != null, "la partition se charge")
	check(is_equal_approx(c.bpm, 108.0), "BPM = 108")
	check(c.stream != null, "l'audio est chargé")
	check(c.notes.size() == 50, "50 notes à jouer")
	check(c.section_at(-1.0).is_empty(), "aucune section avant le début")
	check(c.section_at(c.step_to_time(16)).get("type") == "count", "mesure 2 = décompte")
	check(c.section_at(c.step_to_time(48)).get("type") == "response", "mesure 4 = réponse")
	check(is_equal_approx(c.step_to_time(4), 60.0 / 108.0), "4 steps = 1 temps")
	# Chaque note de réponse doit être exactement 1 mesure après un coup du maître
	var leads := {}
	for cue in c.cues_of("lead_hit"):
		leads[int(cue["step"])] = true
	var aligned := true
	for n in c.notes:
		if not leads.has(int(n["step"]) - 16):
			aligned = false
	check(aligned, "chaque note répond à un coup du maître une mesure plus tôt")


func _test_judge_grades() -> void:
	print("Judge : grades")
	var j := Judge.new(PackedFloat64Array([1.0, 2.0, 3.0, 4.0]))
	check(j.tap(1.02)["grade"] == Judge.Grade.PERFECT, "20 ms → Parfait")
	check(j.tap(1.93)["grade"] == Judge.Grade.GOOD, "-70 ms → Bien")
	var r := j.tap(3.13)
	check(r["grade"] == Judge.Grade.OK and r["offset"] > 0.0, "+130 ms → Juste (en retard)")
	check(j.tap(3.5)["grade"] == Judge.Grade.EXTRA, "frappe loin de toute note → en trop")
	check(j.tap(1.0)["grade"] == Judge.Grade.EXTRA, "une note déjà jouée ne compte pas deux fois")


func _test_judge_misses_and_extra() -> void:
	print("Judge : ratés et pénalités")
	var j := Judge.new(PackedFloat64Array([1.0, 1.25, 2.0]))
	j.tap(1.0)
	check(j.collect_misses(1.3).is_empty(), "pas encore raté dans la fenêtre")
	check(j.collect_misses(1.5) == [1], "note 2 ratée après la fenêtre")
	check(j.collect_misses(1.5).is_empty(), "un raté n'est compté qu'une fois")
	# Deux notes proches : la frappe va à la plus proche
	var k := Judge.new(PackedFloat64Array([1.0, 1.28]))
	check(k.tap(1.2)["index"] == 1, "la frappe est attribuée à la note la plus proche")


func _test_rank() -> void:
	print("Judge : rang")
	var times := PackedFloat64Array()
	for i in 20:
		times.append(float(i))
	var j := Judge.new(times)
	for i in 20:
		j.tap(float(i) + 0.01)
	check(j.rank() == "perfect", "tout parfait → perfect")
	check(is_equal_approx(j.accuracy(), 1.0), "précision 100 %")
	j.register_extra()
	check(j.accuracy() < 1.0, "une frappe en trop baisse la précision")

	var k := Judge.new(times)
	for i in 10:
		k.tap(float(i))
	k.collect_misses(100.0)
	check(k.rank() == "try_again", "moitié ratée → try_again")
	check(absf(k.mean_offset()) < 0.001, "écart moyen centré")
