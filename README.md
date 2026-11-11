# Rudis: From Slave to Legend

**Rudis** is a 2D gladiator game set in ancient Rome, made with the free game
engine [Godot](https://godotengine.org). The name comes from the *rudis*, the
wooden sword a gladiator received when he won his freedom.

The full game will be a roguelite: you live one life as a gladiator, fight
real-time duels in the arena, manage your school between fights, and the way
you lived decides your next life.

This repository is **Phase 0**: one playable duel. It exists to answer one
question: *is the fighting fun?* Everything is drawn with simple shapes on
purpose; pixel art comes later.

## What is in this prototype

- A side-view arena with a sandy floor and a crowd.
- **You**: a red **murmillo** (big helmet with crest, large shield, short sword).
  Strong block, shorter reach.
- **Opponent**: a blue **retiarius** (no helmet, trident and net), controlled by
  the computer. Faster and longer reach, but weaker block and less health.
- Health bar (red) and stamina bar (yellow) for each fighter.
  - Attacks and dodge rolls cost stamina. Stamina refills when you rest.
  - Blocking stops most of the damage but costs stamina. If a block empties
    your stamina, your guard breaks and you stagger.
  - With no stamina you move slowly and block badly.
- A short white flash and a small spark when a blow lands. No blood
  (family-friendly).
- Title screen ("RUDIS" + Start), and "Victory" or "Defeat" with a Restart
  button at the end of the round.
- On-screen touch buttons that appear automatically on phones and tablets.

## Controls

| Action              | Keyboard              | Touch screen   |
|---------------------|-----------------------|----------------|
| Walk left / right   | A / D or Left / Right | `<` and `>`    |
| High attack         | J or Up               | HIGH           |
| Low attack          | K or Down             | LOW            |
| Block (hold)        | L or Shift            | BLOCK (hold)   |
| Dodge roll          | Space                 | ROLL           |

Tip: a high attack hits harder but is slower to start; a low attack is quick.
Watch the opponent pull back the trident, then block or roll away.
Holding a direction while rolling rolls that way; otherwise you roll backwards.

## Play it in a browser

The web version is in the `docs/` folder. When GitHub Pages is switched on
for this repository it can be played from a link, on a PC or in Safari on an
iPhone (turn the phone sideways). Nothing needs to be installed.

## Open the project in Godot (later, when you want to tinker)

1. Download **Godot 4.7** (the normal version, not ".NET") from
   <https://godotengine.org/download>. It is free and needs no account.
2. Download this repository (green **Code** button > **Download ZIP**, or
   `git clone`), and unzip it.
3. Start Godot, click **Import**, and pick the `project.godot` file in the folder.
4. Press **F5** (or the play button at the top right) to play.

Good places to start reading or changing things:

- `scripts/fighter.gd`: the rules of fighting (damage, stamina costs, timings
  at the top of the file in the `ATTACKS` table and the constants below it).
- `scenes/main.tscn` > select **Player** or **Opponent**: change health, speed,
  reach or block strength in the Inspector on the right.
- `scripts/ai_controller.gd`: make the opponent easier or harder.

## How the web build is made

The web build is made with Godot's **Web** export (the settings are saved in
`export_presets.cfg`):

- **Thread support is OFF** (single-threaded). This matters: the threaded
  version needs special server settings that GitHub Pages and iPhone Safari do
  not give, the single-threaded one runs everywhere.
- The renderer is **Compatibility** (WebGL 2), which works in all modern
  browsers, including Safari on iPhone.

In the Godot editor: **Project > Export... > Web > Export Project**, and save
it as `docs/index.html`. (The first time, Godot asks you to download the
"export templates"; click the button and it does it for you.)

From the command line (this is how it is done now):

```
godot --headless --path . --export-release "Web" docs/index.html
```

## Automatic check

`tests/smoke_test.gd` starts the game without a window and checks the rules:
attacks hit, blocks reduce damage, dodges avoid hits, stamina is spent and
refills, a full computer-vs-computer fight ends with Victory/Defeat, and
Restart works.

```
godot --headless --path . --import
godot --headless --path . --fixed-fps 60 --script res://tests/smoke_test.gd
```

It prints `PASS` / `FAIL` per check and `ALL PASSED` at the end.

## Folder structure

```
rudis/
├── project.godot         Godot project settings, including the key bindings (Input Map)
├── export_presets.cfg    Settings for the Web export
├── icon.svg              Project icon (the wooden sword)
├── scenes/
│   └── main.tscn         The one scene: arena, two fighters, controllers, HUD, menus
├── scripts/
│   ├── main.gd           Game flow: title -> fight -> Victory/Defeat -> restart
│   ├── fighter.gd        One gladiator: moving, attacking, blocking, rolling, drawing
│   ├── player_controller.gd  Keyboard / touch input -> fighter actions
│   ├── ai_controller.gd  The computer opponent's decisions
│   ├── arena.gd          Draws the background (sky, crowd, wall, sand)
│   ├── hud.gd            Health and stamina bars
│   ├── menu.gd           Title screen and result screen
│   └── touch_controls.gd On-screen buttons for phones
├── tests/
│   └── smoke_test.gd     Automatic check (see above)
└── docs/                 The exported web version (what the browser loads)
```

Files ending in `.uid` and `.import` are made by Godot itself; leave them in
place. The hidden `.godot/` folder is Godot's cache and is not stored in Git.

## Next steps (ideas)

- High and low blocks that must match the attack height.
- Signature moves: the retiarius net throw, the murmillo shield charge.
- Pixel-art gladiators and simple sounds.
- A violence setting (family / light / realistic); this prototype is family mode.
