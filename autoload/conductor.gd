extends Node
## Chef d'orchestre (autoload « Conductor ») : l'horloge musicale du jeu.
##
## Règle d'or d'un jeu de rythme : le temps de référence est la POSITION DE
## LECTURE AUDIO, jamais le temps écoulé entre les frames. Sinon le jeu et la
## musique dérivent l'un par rapport à l'autre.
##
## Trois « temps » sont exposés, tous en secondes depuis le temps 0 du morceau :
##  - song_time      : position audio estimée, compensée de la latence de sortie
##                     annoncée par le moteur. Mise à jour une fois par frame.
##  - visual_time()  : temps à utiliser pour l'affichage (aligné sur le son entendu).
##  - tap_time()     : temps à utiliser pour juger une frappe du joueur
##                     (mesuré à l'instant de l'appel, latence calibrée retirée).

signal finished

## Part de la latence calibrée appliquée aux visuels. La latence calibrée
## contient aussi le délai tactile, qui ne concerne pas l'affichage : baisser
## cette valeur (ex. 0.7) si les animations semblent en retard sur le son.
const VISUAL_LATENCY_FACTOR := 1.0

var chart: Chart
var song_time: float = 0.0
var playing: bool = false

var _player: AudioStreamPlayer
var _last_raw: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.finished.connect(_on_player_finished)


## Lance la musique d'une partition depuis le début.
func play(c: Chart) -> void:
	chart = c
	_player.stream = c.stream
	_last_raw = 0.0
	song_time = -c.first_beat_offset
	playing = true
	_player.play()


func stop() -> void:
	playing = false
	_player.stop()


func set_paused(paused: bool) -> void:
	_player.stream_paused = paused


func is_paused() -> bool:
	return _player.stream_paused


func _process(_delta: float) -> void:
	if not playing or _player.stream_paused:
		return
	var raw := _raw_position()
	# La position audio avance par paquets : on interdit les petits retours
	# en arrière pour garder un temps monotone (animations fluides).
	if raw < _last_raw and _last_raw - raw < 0.1:
		raw = _last_raw
	_last_raw = raw
	song_time = raw - chart.first_beat_offset


## Position audio « entendue » en secondes dans le fichier, recalculée à l'instant.
func _raw_position() -> float:
	return (_player.get_playback_position()
		+ AudioServer.get_time_since_last_mix()
		- AudioServer.get_output_latency())


## Temps musical à l'instant présent, sans latence calibrée (utilisé par le calibrage).
func sample_time() -> float:
	if chart == null:
		return 0.0
	return maxf(_raw_position(), _last_raw) - chart.first_beat_offset


## Temps d'une frappe du joueur, latence calibrée retirée : à comparer aux notes.
func tap_time() -> float:
	return sample_time() - Settings.latency_sec()


## Temps à utiliser pour tout ce qui s'affiche.
func visual_time() -> float:
	return song_time - Settings.latency_sec() * VISUAL_LATENCY_FACTOR


func _on_player_finished() -> void:
	playing = false
	finished.emit()
