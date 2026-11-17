# Consignes pour Claude Code

Jeu de rythme mobile en **Godot 4.5 / GDScript**, inspiré de Rhythm Paradise (un mini-jeu par genre musical). Lire `README.md` pour l'architecture.

## Règles de timing (non négociables)

- Le temps de jeu vient **toujours** de `Conductor` (position de lecture audio), jamais de `delta` ni de `Time.get_ticks_msec()`.
- Juger une frappe : `Conductor.tap_time()`. Afficher / animer / détecter les ratés : `Conductor.visual_time()`.
- Toute la logique de jugement passe par `Judge` ; un mini-jeu ne réimplémente pas de fenêtres de timing.
- Un mini-jeu est décrit par ses données (`data/charts/*.json`) : pas de timings codés en dur dans les scènes.

## Conventions

- GDScript typé (`:=`, types explicites). Les avertissements « inféré depuis un Variant » sont traités comme des erreurs : typer explicitement le résultat d'un `Callable.call()` ou d'un accès à un dictionnaire.
- Commentaires et textes du jeu en français.
- Indentation par tabulations (style Godot).
- Pour l'instant, l'UI des scènes est construite en code (`scripts/ui/ui.gd`) et les visuels sont dessinés dans `_draw()` : ce sont des placeholders en attendant la DA.

## Vérifier son travail

```bash
godot --headless --import                       # après ajout d'assets
godot --headless -s res://tests/run_tests.gd     # tests de la logique de rythme
godot --headless --quit-after 240 res://scenes/minigames/djembe_duo/djembe_duo.tscn   # erreurs de script
```

Ajouter un test dans `tests/run_tests.gd` pour toute nouvelle logique de rythme.
