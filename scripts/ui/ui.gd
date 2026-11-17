class_name UI
extends RefCounted
## Petites fabriques d'interface en attendant la vraie DA.
## (Les scènes construisent leur UI en code pour rester lisibles sans l'éditeur.)

const CREAM := Color("fff4dc")
const INK := Color("1d1330")
const TERRA := Color("d4572a")
const OCHRE := Color("f0a93a")
const GREEN := Color("2f9a6e")
const INDIGO := Color("26286a")


static func label(text: String, size: int, color: Color = CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, size: int = 40) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(420, 96)
	b.add_theme_font_size_override("font_size", size)
	var normal := StyleBoxFlat.new()
	normal.bg_color = TERRA
	normal.set_corner_radius_all(48)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = TERRA.darkened(0.25)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("focus", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_pressed_color", CREAM)
	b.add_theme_color_override("font_hover_color", CREAM)
	return b


## Colonne centrée qui remplit l'écran.
static func centered_column(parent: Control, separation: int = 28) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.custom_minimum_size = Vector2(600, 0)
	col.add_theme_constant_override("separation", separation)
	center.add_child(col)
	return col


## Vrai si l'événement est une frappe du joueur (doigt posé, ou Espace au clavier).
static func is_tap(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventKey:
		var k := event as InputEventKey
		return k.pressed and not k.echo and k.keycode == KEY_SPACE
	return false
