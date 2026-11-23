# Sinking Ship - first playtest

Back to basics: two rooms, a door, a player, some enemies and props. Nothing else yet.

## Run it

Open `project.godot` in Godot 4.7 and press **F5**.

## Controls

| Key | What it does |
|---|---|
| WASD / arrows | Move |
| Space / left click | Attack (sword swing) |
| E | Open / close the door (stand next to it) |
| R | Restart |

## Files (that's all of them)

| File | What's in it |
|---|---|
| `scenes/main.tscn` | Empty scene that just runs `main.gd` |
| `scripts/main.gd` | The level: rooms, door, props (barrel, cannon, table), camera, controls, text on screen |
| `scripts/player.gd` | Player: movement and sword attack |
| `scripts/enemy.gd` | Enemy: sees you, walks to you, hits you |

The old full prototype (water, decks, boss, etc.) is backed up in
`../sinking_ship_full_prototype_backup`.
