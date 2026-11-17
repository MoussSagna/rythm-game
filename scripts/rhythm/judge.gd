class_name Judge
extends RefCounted
## Juge les frappes du joueur par rapport aux notes attendues.
##
## Usage :
##   var judge := Judge.new(chart.note_times())
##   var r := judge.tap(Conductor.tap_time())   # à chaque frappe
##   for i in judge.collect_misses(Conductor.visual_time()): ...   # à chaque frame

enum Grade { PERFECT, GOOD, OK, MISS, EXTRA }

## Fenêtres de jugement (écart absolu max, en secondes).
const PERFECT_WINDOW := 0.05
const GOOD_WINDOW := 0.10
const OK_WINDOW := 0.15

## Poids de chaque note dans la précision finale.
const WEIGHTS := {Grade.PERFECT: 1.0, Grade.GOOD: 0.75, Grade.OK: 0.4, Grade.MISS: 0.0}
## Pénalité par frappe en trop.
const EXTRA_PENALTY := 0.03

var counts := {Grade.PERFECT: 0, Grade.GOOD: 0, Grade.OK: 0, Grade.MISS: 0, Grade.EXTRA: 0}
## Écarts (secondes, négatif = en avance) des notes touchées : sert au diagnostic de latence.
var offsets: Array[float] = []

var _times: PackedFloat64Array
var _done: PackedByteArray


func _init(note_times: PackedFloat64Array) -> void:
	_times = note_times
	_done = PackedByteArray()
	_done.resize(_times.size())
	_done.fill(0)


func total() -> int:
	return _times.size()


## Juge une frappe. Retourne {grade, offset, index}. Une frappe qui ne
## correspond à aucune note renvoie Grade.EXTRA sans la compter : l'appelant
## décide via register_extra() si elle doit être pénalisée.
func tap(t: float) -> Dictionary:
	var best := -1
	var best_d := INF
	for i in _times.size():
		if _done[i]:
			continue
		var d := t - _times[i]
		if absf(d) < absf(best_d):
			best_d = d
			best = i
		if _times[i] > t + OK_WINDOW:
			break
	if best == -1 or absf(best_d) > OK_WINDOW:
		return {"grade": Grade.EXTRA, "offset": 0.0, "index": -1}

	_done[best] = 1
	offsets.append(best_d)
	var a := absf(best_d)
	var g: int = Grade.PERFECT if a <= PERFECT_WINDOW else (Grade.GOOD if a <= GOOD_WINDOW else Grade.OK)
	counts[g] += 1
	return {"grade": g, "offset": best_d, "index": best}


func register_extra() -> void:
	counts[Grade.EXTRA] += 1


## Marque comme ratées les notes dont la fenêtre est dépassée. Retourne leurs index.
func collect_misses(now: float) -> Array[int]:
	var missed: Array[int] = []
	for i in _times.size():
		if _times[i] > now:
			break
		if not _done[i] and now > _times[i] + OK_WINDOW:
			_done[i] = 1
			counts[Grade.MISS] += 1
			missed.append(i)
	return missed


func accuracy() -> float:
	if total() == 0:
		return 0.0
	var score := 0.0
	for g in WEIGHTS:
		score += counts[g] * WEIGHTS[g]
	score = score / total() - counts[Grade.EXTRA] * EXTRA_PENALTY
	return clampf(score, 0.0, 1.0)


## Rang façon Rhythm Paradise : "perfect", "superb", "ok" ou "try_again".
func rank() -> String:
	var acc := accuracy()
	if acc >= 0.95 and counts[Grade.MISS] == 0:
		return "perfect"
	if acc >= 0.85:
		return "superb"
	if acc >= 0.6:
		return "ok"
	return "try_again"


## Écart moyen des frappes réussies (secondes). > 0 : le joueur tape en retard.
func mean_offset() -> float:
	if offsets.is_empty():
		return 0.0
	var s := 0.0
	for o in offsets:
		s += o
	return s / offsets.size()
