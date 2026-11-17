extends Node2D
## Mini-jeu « Djembé Duo » (Afrobeat, 108 BPM) — appel-réponse.
##
## Le maître joue un rythme d'une mesure (déjà présent dans la musique, décrit
## par les cues "lead_hit"), puis le joueur doit le répéter à la mesure suivante
## (les "notes" de la partition).
##
## Visuels en formes simples (placeholders) dessinés dans _draw() : à remplacer
## par les sprites de la DA. Toute la logique de timing passe par Conductor et Judge.

const CHART_PATH := "res://data/charts/djembe_duo.json"
const MENU := "res://scenes/menu/main_menu.tscn"
const HIT_SFX := preload("res://audio/sfx/player_hit.wav")

const S := 2.0               # échelle des personnages (coordonnées d'origine du prototype web)
const IDLE_ANGLE := 70.0     # angle des bras au repos (degrés)
const LEAD_SKIN := Color("5b3421")
const PLAYER_SKIN := Color("7a4a2c")
const DRUM_WOOD := Color("8b4a22")
const DRUM_SKIN := Color("f3dfb6")

enum Mouth { SMILE, SAD, BIG, OOPS }

var _chart: Chart
var _judge: Judge
var _lead_hits := PackedFloat64Array()
var _count_cues: Array = []
var _lead_idx := 0
var _t := -10.0              # temps visuel courant (secondes depuis le temps 0)
var _ended := false

var _player_last := -INF
var _player_side := 0
var _sad_until := -INF
var _happy_until := -INF
var _oops_until := -INF

var _hit_player: AudioStreamPlayer
var _hud: Control
var _phase_label: Label
var _hint_label: Label
var _pause_overlay: ColorRect


func _ready() -> void:
	_chart = Chart.load_from(CHART_PATH)
	_judge = Judge.new(_chart.note_times())
	for c in _chart.cues_of("lead_hit"):
		_lead_hits.append(c["time"])
	_count_cues = _chart.cues_of("count")

	_hit_player = AudioStreamPlayer.new()
	_hit_player.stream = HIT_SFX
	_hit_player.max_polyphony = 6
	add_child(_hit_player)

	_build_hud()
	Conductor.finished.connect(_finish)
	Conductor.play(_chart)


func _exit_tree() -> void:
	Conductor.stop()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_pause()


# ---------------------------------------------------------------------------
# Boucle de jeu
# ---------------------------------------------------------------------------
func _process(_delta: float) -> void:
	if _ended or Conductor.is_paused():
		return
	_t = Conductor.visual_time()

	for _i in _judge.collect_misses(_t):
		_popup("Raté", Color("ffb3a1"))
		_sad_until = _t + 0.6

	while _lead_idx < _lead_hits.size() and _lead_hits[_lead_idx] <= _t:
		_lead_idx += 1

	_update_phase()
	queue_redraw()

	if _t > _chart.length_sec() + 0.3:
		_finish()


func _input(event: InputEvent) -> void:
	if _ended or Conductor.is_paused() or not UI.is_tap(event):
		return
	get_viewport().set_input_as_handled()
	_hit_player.play()
	var tap := Conductor.tap_time()
	_player_last = Conductor.visual_time()
	_player_side ^= 1

	var r := _judge.tap(tap)
	match r["grade"]:
		Judge.Grade.PERFECT:
			_popup("Parfait !", UI.CREAM)
			_happy_until = _player_last + 0.4
		Judge.Grade.GOOD:
			_popup("Bien", UI.OCHRE)
		Judge.Grade.OK:
			_popup("Trop tôt" if r["offset"] < 0.0 else "Trop tard", Color("ffd2b8"))
		Judge.Grade.EXTRA:
			# On ne pénalise que les frappes en trop pendant le tour du joueur.
			if _chart.section_at(tap).get("type", "") == "response":
				_judge.register_extra()
				_popup("Oups", Color("ffd2b8"))
				_oops_until = _player_last + 0.3


func _update_phase() -> void:
	var sec := _chart.section_at(_t)
	var type: String = sec.get("type", "intro")
	var phrase := int(sec.get("phrase", 0))
	var text := "Prêt ?"
	var hint := ""
	var yours := false
	match type:
		"count":
			var n := 0
			for c in _count_cues:
				if c["time"] <= _t:
					n = int(c["value"])
			text = str(n) if n > 0 else "Prêt ?"
			hint = "Écoute le maître…"
		"call":
			text = "Écoute…"
			if phrase < 2:
				hint = "Retiens bien son rythme"
		"response":
			text = "À toi !"
			yours = true
			if phrase < 2:
				hint = "Tape le même rythme, au même moment"
		"outro":
			text = "Bravo !"
	_phase_label.text = text
	_phase_label.add_theme_color_override("font_color", UI.GREEN.lightened(0.35) if yours else UI.CREAM)
	_hint_label.text = hint


# ---------------------------------------------------------------------------
# Dessin (placeholders)
# ---------------------------------------------------------------------------
func _draw() -> void:
	var vp := get_viewport_rect().size
	_draw_background(vp)

	var ground := vp.y * 0.74
	var cx := vp.x / 2.0
	_ellipse(Vector2(cx, ground + 4), 330, 40, Color(0.11, 0.07, 0.19, 0.35))

	var spb := _chart.sec_per_beat()
	var ph := fposmod(_t / spb, 1.0) if _t >= 0.0 else 0.0
	var bob := -5.0 * sin(PI * ph)

	# Maître : bras qui anticipent la frappe suivante
	var last := _lead_hits[_lead_idx - 1] if _lead_idx > 0 else -INF
	var next := _lead_hits[_lead_idx] if _lead_idx < _lead_hits.size() else INF
	var lead_arms := [IDLE_ANGLE, IDLE_ANGLE]
	for k in 2:
		if k == _lead_idx % 2 and next - _t < 0.12:
			lead_arms[k] = IDLE_ANGLE * (next - _t) / 0.12
		elif _lead_idx > 0 and k == (_lead_idx - 1) % 2 and _t - last < 0.2:
			lead_arms[k] = IDLE_ANGLE * (_t - last) / 0.2
	var lead_sad := _t < _sad_until
	_draw_drummer(Vector2(cx - 170, ground - 264 * S), bob, lead_arms, LEAD_SKIN,
		UI.INDIGO.lightened(0.15), true, Mouth.SAD if lead_sad else Mouth.SMILE, lead_sad, _t - last)

	# Joueur : réagit à ses propres frappes
	var dp := _t - _player_last
	var player_arms := [IDLE_ANGLE, IDLE_ANGLE]
	if dp < 0.18:
		player_arms[_player_side] = IDLE_ANGLE * dp / 0.18
	var mouth := Mouth.SMILE
	if _t < _oops_until or _t < _sad_until:
		mouth = Mouth.OOPS
	elif _t < _happy_until:
		mouth = Mouth.BIG
	_draw_drummer(Vector2(cx + 170, ground - 264 * S), bob * 0.9, player_arms, PLAYER_SKIN,
		UI.GREEN, false, mouth, false, dp)

	# Points de temps
	var sec_type: String = _chart.section_at(_t).get("type", "")
	var beat := int(floor(fposmod(_t, spb * 4) / spb)) if _t >= 0.0 else -1
	for k in 4:
		var on := k == beat and sec_type != "outro"
		draw_circle(Vector2(cx - 60 + k * 40, 230), 10.0 if on else 7.0,
			UI.CREAM if on else Color(UI.CREAM, 0.25))

	# Progression
	var p := clampf(_t / _chart.length_sec(), 0.0, 1.0)
	draw_rect(Rect2(vp.x * 0.1, vp.y - 70, vp.x * 0.8, 10), Color(UI.CREAM, 0.2))
	draw_rect(Rect2(vp.x * 0.1, vp.y - 70, vp.x * 0.8 * p, 10), UI.CREAM)


func _draw_background(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), UI.INDIGO)
	var colors := [Color("6d2748"), Color("b8452f"), Color("e07a35"), Color("f6c063")]
	var center := Vector2(vp.x / 2.0, vp.y * 1.1)
	var r := vp.y * 0.85
	for i in colors.size():
		draw_circle(center, r * (1.0 - i * 0.2), colors[i])


func _draw_drummer(origin: Vector2, bob: float, arms: Array, skin: Color, body: Color,
		is_lead: bool, mouth: int, sad_brows: bool, since_hit: float) -> void:
	var P := func(x: float, y: float, moves: bool = true) -> Vector2:
		return origin + Vector2(x, y + (bob if moves else 0.0)) * S

	# Corps
	var sb := StyleBoxFlat.new()
	sb.bg_color = body
	sb.set_corner_radius_all(int(28 * S))
	draw_style_box(sb, Rect2(P.call(-36, 122), Vector2(72, 96) * S))
	for row in 3:
		for col in 3:
			draw_circle(P.call(-20 + col * 20, 140 + row * 22), 5 * S, UI.OCHRE if is_lead else UI.CREAM)

	# Tête
	draw_rect(Rect2(P.call(-8, 112), Vector2(16, 14) * S), skin)
	draw_circle(P.call(0, 94), 30 * S, skin)
	if is_lead:
		var kufi := PackedVector2Array()
		for i in 13:
			var a := PI + PI * i / 12.0
			kufi.append(P.call(27 * cos(a), 82 + 24 * sin(a)))
		draw_colored_polygon(kufi, UI.TERRA)
		draw_line(P.call(-27, 82), P.call(27, 82), UI.OCHRE, 4 * S)
	else:
		draw_rect(Rect2(P.call(-30, 72), Vector2(60, 9) * S), UI.OCHRE)
		draw_circle(P.call(30, 76), 6 * S, UI.OCHRE)

	# Yeux, sourcils, bouche
	for s in [-1, 1]:
		draw_circle(P.call(10 * s, 94), 5 * S, Color.WHITE)
		draw_circle(P.call(10 * s, 95), 2.6 * S, UI.INK)
		var inner_y := 85.0 if sad_brows else 84.0
		var outer_y := 81.0 if sad_brows else 84.0
		draw_line(P.call(6 * s, inner_y), P.call(16 * s, outer_y), UI.INK, 3 * S)
	match mouth:
		Mouth.SMILE:
			draw_polyline(_bezier(P.call(-9, 106), P.call(0, 114), P.call(9, 106)), UI.INK, 3 * S)
		Mouth.SAD:
			draw_polyline(_bezier(P.call(-9, 112), P.call(0, 104), P.call(9, 112)), UI.INK, 3 * S)
		Mouth.BIG:
			draw_colored_polygon(_bezier(P.call(-11, 105), P.call(0, 122), P.call(11, 105)), UI.INK)
		Mouth.OOPS:
			draw_arc(P.call(0, 109), 4 * S, 0, TAU, 16, UI.INK, 3 * S)

	# Bras (index 0 = gauche, 1 = droit)
	for k in 2:
		var s := -1 if k == 0 else 1
		var shoulder := Vector2(28 * s, 138)
		var hand := shoulder + (Vector2(16 * s, 186) - shoulder).rotated(deg_to_rad(arms[k] * -s))
		draw_line(P.call(shoulder.x, shoulder.y), P.call(hand.x, hand.y), skin, 13 * S)
		draw_circle(P.call(hand.x, hand.y), 8 * S, skin)

	# Djembé (ne bouge pas avec le balancement)
	var drum := PackedVector2Array()
	for v in [Vector2(-40, 192), Vector2(-38, 205), Vector2(-30, 218), Vector2(-15, 230), Vector2(-20, 264),
			Vector2(20, 264), Vector2(15, 230), Vector2(30, 218), Vector2(38, 205), Vector2(40, 192)]:
		drum.append(P.call(v.x, v.y, false))
	draw_colored_polygon(drum, DRUM_WOOD)
	for x in [-24, -8, 8, 24]:
		draw_line(P.call(x * 1.3, 198, false), P.call(x * 0.5, 230, false), Color(DRUM_SKIN, 0.7), 2 * S)
	draw_rect(Rect2(P.call(-21, 238, false), Vector2(42, 6) * S), DRUM_WOOD.darkened(0.35))
	var head_c: Vector2 = P.call(0, 192, false)
	_ellipse(head_c, 41 * S, 10 * S, DRUM_SKIN)
	if since_hit >= 0.0 and since_hit < 0.12:
		var grow := since_hit * 80.0
		_ellipse_outline(head_c, (41 + grow) * S, (10 + grow / 4.0) * S, Color(UI.CREAM, 1.0 - since_hit / 0.12), 3 * S)


func _ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, ry / rx))
	draw_circle(Vector2.ZERO, rx, color)
	draw_set_transform(Vector2.ZERO)


func _ellipse_outline(center: Vector2, rx: float, ry: float, color: Color, width: float) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, ry / rx))
	draw_arc(Vector2.ZERO, rx, 0.0, TAU, 48, color, width)
	draw_set_transform(Vector2.ZERO)


func _bezier(a: Vector2, c: Vector2, b: Vector2, n: int = 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		pts.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	return pts


# ---------------------------------------------------------------------------
# Interface
# ---------------------------------------------------------------------------
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud)

	_phase_label = UI.label("Prêt ?", 76)
	_phase_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_phase_label.offset_top = 90
	_phase_label.offset_bottom = 190
	_hud.add_child(_phase_label)

	_hint_label = UI.label("", 30)
	_hint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hint_label.offset_top = 260
	_hint_label.offset_bottom = 320
	_hud.add_child(_hint_label)

	_pause_overlay = ColorRect.new()
	_pause_overlay.color = Color(0.11, 0.07, 0.19, 0.8)
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.visible = false
	_hud.add_child(_pause_overlay)
	var col := UI.centered_column(_pause_overlay)
	col.add_child(UI.label("Pause", 88))
	var resume := UI.button("Reprendre")
	resume.pressed.connect(_resume)
	var cc := CenterContainer.new()
	cc.add_child(resume)
	col.add_child(cc)


func _popup(text: String, color: Color) -> void:
	var vp := get_viewport_rect().size
	var l := UI.label(text, 52, color)
	l.size = Vector2(360, 80)
	l.position = Vector2(vp.x / 2.0 + 170 - 180, vp.y * 0.74 - 560)
	_hud.add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 90, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.55).set_delay(0.15)
	tw.chain().tween_callback(l.queue_free)


func _pause() -> void:
	if not is_node_ready() or _ended or Conductor.is_paused():
		return
	Conductor.set_paused(true)
	_pause_overlay.visible = true


func _resume() -> void:
	_pause_overlay.visible = false
	Conductor.set_paused(false)


func _finish() -> void:
	if _ended:
		return
	_ended = true
	Conductor.stop()

	var ranks := {
		"perfect": ["Parfait !", "Le cercle entier s'est levé pour toi.", UI.GREEN.lightened(0.3)],
		"superb": ["Superbe !", "Le maître hoche la tête, impressionné.", UI.GREEN.lightened(0.3)],
		"ok": ["OK", "Pas mal, mais quelques contretemps t'ont échappé.", UI.OCHRE],
		"try_again": ["Essaie encore", "Le groove était là… toi un peu moins.", Color("ffb3a1")],
	}
	var r: Array = ranks[_judge.rank()]
	var c := _judge.counts

	var overlay := ColorRect.new()
	overlay.color = Color(0.11, 0.07, 0.19, 0.88)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(overlay)
	var col := UI.centered_column(overlay, 22)
	col.add_child(UI.label("Djembé Duo", 34, UI.OCHRE))
	col.add_child(UI.label(r[0], 96, r[2]))
	col.add_child(UI.label(r[1], 30))
	col.add_child(UI.label("Parfait %d · Bien %d · Juste %d · Raté %d" % [
		c[Judge.Grade.PERFECT], c[Judge.Grade.GOOD], c[Judge.Grade.OK], c[Judge.Grade.MISS]], 30))
	var acc_text := "Précision : %d %%" % roundi(_judge.accuracy() * 100)
	if c[Judge.Grade.EXTRA] > 0:
		acc_text += " · %d frappe(s) en trop" % c[Judge.Grade.EXTRA]
	col.add_child(UI.label(acc_text, 34))

	# Diagnostic de latence : si le joueur est systématiquement décalé
	var mean_ms := _judge.mean_offset() * 1000.0
	if _judge.offsets.size() >= 5 and absf(mean_ms) >= 15.0:
		var info := UI.label("En moyenne, tu tapes %d ms %s." % [
			roundi(absf(mean_ms)), "en retard" if mean_ms > 0 else "en avance"], 26)
		col.add_child(info)
		var fix := UI.button("Corriger la latence", 30)
		fix.pressed.connect(func() -> void:
			Settings.set_latency_ms(Settings.latency_ms + mean_ms)
			info.text = "Latence corrigée : %d ms" % Settings.latency_ms
			fix.visible = false)
		col.add_child(_center(fix))

	var retry := UI.button("Rejouer")
	retry.pressed.connect(func() -> void: get_tree().reload_current_scene())
	col.add_child(_center(retry))
	var menu := UI.button("Menu", 32)
	menu.pressed.connect(func() -> void: get_tree().change_scene_to_file(MENU))
	col.add_child(_center(menu))


func _center(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.add_child(c)
	return cc
