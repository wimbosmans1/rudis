extends Node
## A simple computer opponent.
##
## A few times per second it looks at the situation and picks one thing:
## defend (block or dodge) when the enemy swings, back off when tired,
## attack when close enough, otherwise walk closer.
## The numbers below make it easier or harder.

## Seconds between decisions. Bigger = slower reactions = easier.
@export var reaction_time := 0.28
## Chance (0 to 1) to block when the enemy attacks.
@export_range(0.0, 1.0) var block_chance := 0.4
## Chance (0 to 1) to dodge instead when the enemy attacks.
@export_range(0.0, 1.0) var dodge_chance := 0.12
## Chance (0 to 1) to attack when in range.
@export_range(0.0, 1.0) var aggression := 0.6
## Below this stamina the AI steps back to recover.
@export var tired_stamina := 30.0

## The fighter the AI steers, and the one it fights. Set by main.gd.
var fighter: Fighter
var target: Fighter
## main.gd turns this off on the title screen and after the round.
var enabled := false

var _think_timer := 0.0
var _block_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _physics_process(delta: float) -> void:
	if fighter == null or target == null:
		return
	if not enabled or fighter.is_dead() or target.is_dead():
		fighter.move_input = 0.0
		fighter.wants_block = false
		return

	# Keep holding the block until the timer runs out.
	if _block_timer > 0.0:
		_block_timer -= delta
		fighter.move_input = 0.0
		fighter.wants_block = _block_timer > 0.0
		return

	_think_timer -= delta
	if _think_timer > 0.0:
		return
	_think_timer = reaction_time * _rng.randf_range(0.7, 1.3)
	_decide()


func _decide() -> void:
	var distance := fighter.distance_to_fighter(target)
	var toward := signf(target.position.x - fighter.position.x)
	fighter.wants_block = false

	# 1. Defend when the enemy swings and could reach us.
	if target.is_attacking() and distance <= target.reach + 30.0:
		var roll := _rng.randf()
		if roll < block_chance:
			_block_timer = _rng.randf_range(0.35, 0.6)
			fighter.wants_block = true
			fighter.move_input = 0.0
			return
		if roll < block_chance + dodge_chance and fighter.try_dodge(0.0):
			return

	# 2. Tired: step back and let stamina refill.
	if fighter.stamina < tired_stamina:
		fighter.move_input = -toward
		return

	# 3. Close enough: maybe attack, otherwise wait or step back a little.
	if distance <= fighter.reach * 0.95:
		fighter.move_input = 0.0
		if distance < fighter.reach * 0.6 and _rng.randf() < 0.3:
			fighter.move_input = -toward  # keep some distance (long weapon)
		elif _rng.randf() < aggression:
			var kind := Fighter.AttackKind.HIGH if _rng.randf() < 0.5 else Fighter.AttackKind.LOW
			fighter.try_attack(kind)
		return

	# 4. Too far away: walk closer.
	fighter.move_input = toward
