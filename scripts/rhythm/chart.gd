class_name Chart
extends RefCounted
## Partition d'un mini-jeu, chargée depuis un fichier JSON de data/charts/.
##
## Tout est exprimé en « steps » (doubles-croches par défaut) depuis le temps 0
## du morceau. Format :
##  - sections : [{step, type, ...}]  découpage du morceau (intro, call, response…)
##  - cues     : [{step, type, ...}]  événements visuels/sonores déjà dans la musique
##  - notes    : [{step, type}]       frappes que le joueur doit faire

var id: String
var title: String
var genre: String
var bpm: float
var steps_per_beat: int = 4
var beats_per_bar: int = 4
var first_beat_offset: float = 0.0
var length_steps: int
var stream: AudioStream
var sections: Array = []
var cues: Array = []
var notes: Array = []


static func load_from(path: String) -> Chart:
	var data: Variant = null
	var res: Resource = load(path)
	if res is JSON:
		data = (res as JSON).data
	else:
		data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Partition illisible : %s" % path)
		return null

	var c := Chart.new()
	c.id = data.get("id", "")
	c.title = data.get("title", "")
	c.genre = data.get("genre", "")
	c.bpm = float(data["bpm"])
	c.steps_per_beat = int(data.get("steps_per_beat", 4))
	c.beats_per_bar = int(data.get("beats_per_bar", 4))
	c.first_beat_offset = float(data.get("first_beat_offset", 0.0))
	c.length_steps = int(data["length_steps"])
	c.stream = load(data["audio"])
	c.sections = data.get("sections", [])
	c.cues = data.get("cues", [])
	c.notes = data.get("notes", [])
	return c


func sec_per_step() -> float:
	return 60.0 / bpm / steps_per_beat


func sec_per_beat() -> float:
	return 60.0 / bpm


func steps_per_bar() -> int:
	return steps_per_beat * beats_per_bar


func step_to_time(step: float) -> float:
	return step * sec_per_step()


func time_to_step(t: float) -> float:
	return t / sec_per_step()


func length_sec() -> float:
	return step_to_time(length_steps)


## Section active à un instant donné (dictionnaire vide avant le début).
func section_at(t: float) -> Dictionary:
	var step := time_to_step(t)
	var current: Dictionary = {}
	for s in sections:
		if float(s["step"]) <= step:
			current = s
		else:
			break
	return current


## Instants (en secondes) des notes que le joueur doit frapper.
func note_times() -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for n in notes:
		out.append(step_to_time(float(n["step"])))
	return out


## Cues d'un type donné, avec leur instant en secondes ajouté sous la clé "time".
func cues_of(type: String) -> Array:
	var out: Array = []
	for cue in cues:
		if cue["type"] == type:
			var c: Dictionary = cue.duplicate()
			c["time"] = step_to_time(float(cue["step"]))
			out.append(c)
	return out
