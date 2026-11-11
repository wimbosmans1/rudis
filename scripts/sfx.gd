extends Node
## Sound effects: a "whoosh" for every swing, a "thud" when a blow lands and
## a metallic "clang" when it is blocked.
##
## The sounds are made by tools/make_sounds.py (pure maths, no recordings,
## free to use). To use other sounds, replace the files in sounds/ with your
## own .wav or .ogg files of the same name.
##
## Browsers (especially Safari on iPhone) only allow sound after the player
## has tapped or pressed a key. Godot switches the sound on at the first tap
## or key press by itself; unlock() is called from the Start button as well
## to make sure it is ready before the first blow.

const SOUNDS := {
	"swing": preload("res://sounds/swing.wav"),
	"hit": preload("res://sounds/hit.wav"),
	"clang": preload("res://sounds/clang.wav"),
}
## Loudness in decibels. 0 = full volume, -6 = about half as loud.
const VOLUME_DB := {"swing": -10.0, "hit": -4.0, "clang": -8.0}
## How many sounds can play at the same moment.
const VOICES := 6

## Every sound played, for the automatic test.
var played: Array[String] = []

var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


## Lets this script listen to a fighter. Called once per fighter by main.gd.
func watch(fighter: Fighter) -> void:
	fighter.attack_started.connect(func(_kind: int) -> void: play("swing"))
	fighter.got_hit.connect(func(result: String) -> void:
		play("clang" if result == "blocked" else "hit"))


## Plays one of the sounds, slightly higher or lower each time so it does
## not sound like a machine gun.
func play(sound_name: String) -> void:
	played.append(sound_name)
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = SOUNDS[sound_name]
	player.volume_db = VOLUME_DB[sound_name]
	player.pitch_scale = randf_range(0.92, 1.08)
	player.play()


## Plays a silent moment of sound from inside a tap / click, which is what
## iPhone Safari needs before it lets a web page make sound.
func unlock() -> void:
	var player := _players[_next]
	player.stream = SOUNDS["swing"]
	player.volume_db = -80.0
	player.play()
