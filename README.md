# Rythm Game

Jeu de rythme mobile inspiré de *Rhythm Paradise* : une suite de mini-jeux courts, joués à l'oreille avec une seule action (taper l'écran). Chaque monde est consacré à un genre musical : Afrobeat, Amapiano, House, Techno, Drum & Bass, Reggaeton…

Moteur : **Godot 4.5** (rendu *Compatibility*, format portrait 720×1280).

## Démarrer

1. Installer [Godot 4.5](https://godotengine.org/download) (version standard, pas .NET).
2. Ouvrir `project.godot` depuis le gestionnaire de projets.
3. Lancer avec **F5**. Au premier lancement, le jeu demande un calibrage de latence.
4. Sur ordinateur, le clic souris et la barre **Espace** servent de « tap ».

Pour tester sur téléphone : *Projet → Exporter* (Android : installer le template d'export et le SDK, voir la doc Godot), ou *Déploiement en un clic* avec le téléphone branché en USB.

## Ce qui existe

| Élément | Fichier | Rôle |
|---|---|---|
| Horloge musicale | `autoload/conductor.gd` | Source de vérité du timing : la position de lecture audio |
| Réglages | `autoload/settings.gd` | Latence calibrée, sauvegardée dans `user://settings.cfg` |
| Partition | `scripts/rhythm/chart.gd` | Charge un mini-jeu décrit en JSON (`data/charts/`) |
| Juge | `scripts/rhythm/judge.gd` | Parfait / Bien / Juste / Raté, précision, rang |
| Calibrage | `scenes/calibration/` | 16 bips, médiane des écarts → latence du joueur |
| Mini-jeu 1 | `scenes/minigames/djembe_duo/` | Djembé Duo : appel-réponse Afrobeat à 108 BPM |
| Menu | `scenes/menu/` | Lancer le jeu, calibrer, ajuster la latence à ±10 ms |
| Tests | `tests/run_tests.gd` | Logique de rythme testée sans affichage |

Les graphismes sont des formes simples dessinées en code, en attendant la DA.

## Comment marche la synchro

Un jeu de rythme ne doit **jamais** se baser sur le temps écoulé entre les images : il dérive par rapport à la musique. Ici :

1. **`Conductor.song_time`** = position de lecture audio + temps depuis le dernier mixage − latence de sortie annoncée par le moteur (méthode recommandée par la doc Godot, *Sync the gameplay with audio and music*).
2. **Le calibrage** mesure ce qui reste : la vraie latence du casque ou des haut-parleurs (Bluetooth compris) et le délai de l'écran tactile. Le joueur tape sur des bips, et la médiane de ses écarts devient `Settings.latency_ms`.
3. **Les frappes** sont jugées avec `Conductor.tap_time()` (temps mesuré à l'instant du tap, latence retirée) et **l'affichage** utilise `Conductor.visual_time()`.
4. L'écran de résultats détecte un décalage systématique et propose de le corriger.

Réglages utiles dans `project.godot` : `audio/driver/output_latency=15` et `input_devices/buffering/agile_event_flushing=true` (taps plus précis sur Android).

## Ajouter un mini-jeu

Un mini-jeu = **une musique + une partition JSON + une scène**.

La partition (`data/charts/*.json`) décrit tout en *steps* (doubles-croches) depuis le temps 0 :

```json
{
  "bpm": 108, "steps_per_beat": 4, "beats_per_bar": 4,
  "audio": "res://audio/music/mon_jeu.ogg",
  "first_beat_offset": 0.5,
  "length_steps": 368,
  "sections": [{"step": 0, "type": "intro"}, {"step": 32, "type": "call", "phrase": 0}],
  "cues":     [{"step": 32, "type": "lead_hit"}],
  "notes":    [{"step": 48, "type": "tap"}]
}
```

- `first_beat_offset` : secondes de silence avant le premier temps dans le fichier audio.
- `sections` : découpage du morceau, que la scène utilise pour savoir dans quelle phase on est.
- `cues` : événements déjà présents dans la musique, pour animer (le maître qui frappe, un décompte…).
- `notes` : ce que le joueur doit taper. C'est la seule chose que le `Judge` regarde.

La scène charge la partition avec `Chart.load_from()`, crée un `Judge`, lance `Conductor.play()` et anime selon `Conductor.visual_time()`. Prendre `djembe_duo.gd` comme modèle.

## Audio et partitions générés

`tools/build_djembe_duo.py` synthétise la musique placeholder de Djembé Duo et du calibrage, **et** écrit les partitions correspondantes, à partir de la même liste de patterns. Musique et partition restent donc toujours alignées.

```bash
pip install numpy scipy   # + ffmpeg avec libvorbis
python3 tools/build_djembe_duo.py
```

Quand la vraie musique arrivera, il faudra écrire la partition à la main, ou avec un petit outil d'édition, en relevant les steps de chaque frappe.

## Tests

```bash
godot --headless -s res://tests/run_tests.gd
```

## Feuille de route

- [ ] Valider la synchro sur un vrai téléphone (Android + iPhone, haut-parleur + Bluetooth)
- [ ] Mini-jeu 2 : House (vérifier que le système est réutilisable tel quel)
- [ ] Direction artistique, puis remplacement des placeholders par des sprites
- [ ] Musiques originales par genre
- [ ] Sélection des mondes, sauvegarde des rangs, remix de fin de monde
