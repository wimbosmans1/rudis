extends Node
## Turns the player's key presses (or touch buttons) into fighter actions.
##
## The actions (move_left, attack_high, ...) are defined in
## Project > Project Settings > Input Map. The touch buttons press the very
## same actions, so this script works for keyboard and touch alike.

## How long a button press is remembered while the fighter is still busy.
## This makes the controls feel less strict: press attack slightly early
## and it still happens when the previous move ends.
const BUFFER_TIME := 0.2

## The fighter this controller steers. Set by main.gd.
var fighter: Fighter
## main.gd turns this off on the title screen and after the round.
var enabled := false

var _buffered_action := ""
var _buffer_timer := 0.0


func _physics_process(delta: float) -> void:
	if fighter == null:
		return
	if not enabled:
		fighter.move_input = 0.0
		fighter.wants_block = false
		return

	fighter.move_input = Input.get_axis("move_left", "move_right")
	fighter.wants_block = Input.is_action_pressed("block")

	# Remember the newest button press for a short moment.
	for action in ["attack_high", "attack_low", "dodge"]:
		if Input.is_action_just_pressed(action):
			_buffered_action = action
			_buffer_timer = BUFFER_TIME

	if _buffered_action != "":
		if _perform(_buffered_action):
			_buffered_action = ""
		else:
			_buffer_timer -= delta
			if _buffer_timer <= 0.0:
				_buffered_action = ""


## Tries the action. Returns true if the fighter actually did it.
func _perform(action: String) -> bool:
	match action:
		"attack_high":
			return fighter.try_attack(Fighter.AttackKind.HIGH)
		"attack_low":
			return fighter.try_attack(Fighter.AttackKind.LOW)
		"dodge":
			return fighter.try_dodge(fighter.move_input)
	return false
