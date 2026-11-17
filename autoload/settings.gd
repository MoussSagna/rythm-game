extends Node
## Réglages persistants du joueur (autoload « Settings »).
##
## latency_ms = latence totale mesurée par le calibrage : sortie audio
## (haut-parleur, casque Bluetooth…) + délai de l'écran tactile.
## Elle est soustraite de l'heure de chaque frappe avant le jugement.

const PATH := "user://settings.cfg"

var latency_ms: int = 0
var calibrated: bool = false

## Scène à ouvrir une fois le calibrage terminé (vide = retour au menu).
var after_calibration_scene: String = ""


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		latency_ms = int(cfg.get_value("audio", "latency_ms", 0))
		calibrated = bool(cfg.get_value("audio", "calibrated", false))


func latency_sec() -> float:
	return latency_ms / 1000.0


func set_latency_ms(value: float) -> void:
	latency_ms = clampi(roundi(value), -100, 600)
	calibrated = true
	save()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "latency_ms", latency_ms)
	cfg.set_value("audio", "calibrated", calibrated)
	cfg.save(PATH)
