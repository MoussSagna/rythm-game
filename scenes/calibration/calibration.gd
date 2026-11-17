extends Control
## Calibrage de la latence : le joueur tape sur 16 bips réguliers, à l'oreille.
##
## On mesure l'écart entre chaque frappe et le bip le plus proche, dans le même
## repère temporel que le jeu (Conductor). La médiane de ces écarts devient la
## latence du joueur : elle absorbe la latence de sortie audio réelle (casque
## Bluetooth inclus) et le délai de l'écran tactile.

const CHART_PATH := "res://data/charts/calibration.json"
const MENU := "res://scenes/menu/main_menu.tscn"
const SKIP_FIRST := 3        # on ignore les premiers bips, le temps de trouver le tempo
const MIN_VALID_TAPS := 8
const MAX_DISTANCE := 0.35   # au-delà, la frappe n'est rattachée à aucun bip

enum State { IDLE, RUNNING, DONE }

var _state := State.IDLE
var _chart: Chart
var _click_times: PackedFloat64Array
var _taps: Array[float] = []

var _title: Label
var _counter: Label
var _message: Label
var _start_btn: Button
var _continue_btn: Button
var _menu_btn: Button


func _ready() -> void:
	_chart = Chart.load_from(CHART_PATH)
	_click_times = _chart.note_times()
	Conductor.finished.connect(_on_finished)

	var col := UI.centered_column(self)
	_title = UI.label("Calibrage", 72, UI.OCHRE)
	_counter = UI.label("Prêt ?", 96)
	_message = UI.label(
		"Tu vas entendre %d bips réguliers.\nTape l'écran pile sur chaque bip, à l'oreille.\nUtilise le même casque ou les mêmes haut-parleurs que pour jouer." % _click_times.size(), 30)
	_start_btn = UI.button("Commencer")
	_start_btn.pressed.connect(_start)
	_continue_btn = UI.button("Jouer" if Settings.after_calibration_scene != "" else "Terminer")
	_continue_btn.pressed.connect(_continue)
	_continue_btn.visible = false
	_menu_btn = UI.button("Menu", 32)
	_menu_btn.pressed.connect(func() -> void: get_tree().change_scene_to_file(MENU))

	for c in [_title, _counter, _message]:
		col.add_child(c)
	for b in [_start_btn, _continue_btn, _menu_btn]:
		var cc := CenterContainer.new()
		cc.add_child(b)
		col.add_child(cc)


func _exit_tree() -> void:
	Conductor.stop()


func _start() -> void:
	_taps.clear()
	_state = State.RUNNING
	_start_btn.visible = false
	_continue_btn.visible = false
	_menu_btn.visible = false
	_counter.text = "0 / %d" % _click_times.size()
	_message.text = "Tape sur chaque bip…"
	Conductor.play(_chart)


func _input(event: InputEvent) -> void:
	if _state != State.RUNNING or not UI.is_tap(event):
		return
	get_viewport().set_input_as_handled()
	# Temps brut, SANS la latence actuelle : c'est justement ce qu'on mesure.
	_taps.append(Conductor.sample_time())
	_counter.text = "%d / %d" % [_taps.size(), _click_times.size()]


func _on_finished() -> void:
	if _state != State.RUNNING:
		return
	_state = State.DONE
	_menu_btn.visible = true
	_start_btn.text = "Refaire"
	_start_btn.visible = true

	var offsets: Array[float] = []
	for t in _taps:
		var best := INF
		for i in range(SKIP_FIRST, _click_times.size()):
			var d := t - _click_times[i]
			if absf(d) < absf(best):
				best = d
		if absf(best) <= MAX_DISTANCE:
			offsets.append(best)
	offsets.sort()

	if offsets.size() < MIN_VALID_TAPS:
		_counter.text = "Raté"
		_message.text = "Pas assez de frappes régulières. Recommence en tapant sur chaque bip."
		return

	var median := offsets[int(offsets.size() / 2.0)]
	var spread := offsets[int(offsets.size() * 0.8)] - offsets[int(offsets.size() * 0.2)]
	Settings.set_latency_ms(median * 1000.0)
	_counter.text = "%d ms" % Settings.latency_ms
	_message.text = "Latence mesurée. " + (
		"Tes frappes étaient irrégulières : refais le calibrage si le jeu semble encore décalé."
		if spread > 0.09 else "Mesure stable, tu peux jouer.")
	_continue_btn.visible = true


func _continue() -> void:
	var next := Settings.after_calibration_scene
	Settings.after_calibration_scene = ""
	get_tree().change_scene_to_file(next if next != "" else MENU)
