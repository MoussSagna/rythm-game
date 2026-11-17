extends Control
## Menu principal (placeholder) : lancer un mini-jeu, calibrer la latence.

const DJEMBE_DUO := "res://scenes/minigames/djembe_duo/djembe_duo.tscn"
const CALIBRATION := "res://scenes/calibration/calibration.tscn"

var _latency_label: Label


func _ready() -> void:
	var col := UI.centered_column(self)

	col.add_child(UI.label("Rythm Game", 88, UI.OCHRE))
	col.add_child(UI.label("Un mini-jeu par genre musical", 30))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	col.add_child(spacer)

	var play := UI.button("Djembé Duo · Afrobeat")
	play.pressed.connect(_on_play_pressed)
	col.add_child(_centered(play))

	var calib := UI.button("Calibrer la latence", 32)
	calib.pressed.connect(func() -> void: _go_calibration(""))
	col.add_child(_centered(calib))

	# Réglage fin de la latence
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	var minus := UI.button("−", 40)
	minus.custom_minimum_size = Vector2(96, 96)
	minus.pressed.connect(func() -> void: _nudge(-10))
	var plus := UI.button("+", 40)
	plus.custom_minimum_size = Vector2(96, 96)
	plus.pressed.connect(func() -> void: _nudge(10))
	_latency_label = UI.label("", 30)
	_latency_label.custom_minimum_size = Vector2(300, 0)
	row.add_child(minus)
	row.add_child(_latency_label)
	row.add_child(plus)
	col.add_child(row)
	_refresh()


func _centered(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.add_child(c)
	return cc


func _refresh() -> void:
	_latency_label.text = ("Latence : %d ms" % Settings.latency_ms) if Settings.calibrated else "Latence : non calibrée"


func _nudge(ms: int) -> void:
	Settings.set_latency_ms(Settings.latency_ms + ms)
	_refresh()


func _on_play_pressed() -> void:
	if not Settings.calibrated:
		_go_calibration(DJEMBE_DUO)
	else:
		get_tree().change_scene_to_file(DJEMBE_DUO)


func _go_calibration(next_scene: String) -> void:
	Settings.after_calibration_scene = next_scene
	get_tree().change_scene_to_file(CALIBRATION)
