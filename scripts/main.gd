extends Node2D
## The "director" of the game. It connects all parts of the scene and runs
## the flow: title screen -> fight -> Victory / Defeat -> restart.

## Where the fighters start, in pixels from the left of the screen.
const PLAYER_START_X := 400.0
const OPPONENT_START_X := 880.0
## Wait this long after a knock-out before showing the result.
const RESULT_DELAY := 1.2

## Sent when a round ends. player_won is true for a Victory.
signal round_finished(player_won: bool)

@onready var player: Fighter = $Player
@onready var opponent: Fighter = $Opponent
@onready var player_controller: Node = $PlayerController
@onready var ai_controller: Node = $AIController
@onready var hud: CanvasLayer = $HUD
@onready var touch_controls: CanvasLayer = $TouchControls
@onready var menu: CanvasLayer = $Menu

var round_active := false


func _ready() -> void:
	# Tell every part who it works with.
	player.opponent = opponent
	opponent.opponent = player
	for fighter in [player, opponent]:
		fighter.position.y = Arena.FLOOR_Y
		fighter.died.connect(_on_fighter_died)
	player_controller.fighter = player
	ai_controller.fighter = opponent
	ai_controller.target = player
	hud.setup(player, opponent)

	menu.start_pressed.connect(start_round)
	menu.restart_pressed.connect(start_round)

	# Show the fighters standing in the arena behind the title screen.
	_reset_fighters()
	_set_controls_enabled(false)
	menu.show_title()


## Starts a new duel from full health.
func start_round() -> void:
	_reset_fighters()
	menu.hide_all()
	round_active = true
	_set_controls_enabled(true)


func _reset_fighters() -> void:
	player.reset(PLAYER_START_X, 1)
	opponent.reset(OPPONENT_START_X, -1)


func _set_controls_enabled(on: bool) -> void:
	player_controller.enabled = on
	ai_controller.enabled = on
	touch_controls.visible = on and touch_controls.is_wanted()


func _on_fighter_died(fighter: Fighter) -> void:
	if not round_active:
		return
	round_active = false
	_set_controls_enabled(false)
	var player_won := fighter != player
	# A short pause so you can see the final blow, then the result.
	await get_tree().create_timer(RESULT_DELAY).timeout
	menu.show_result(player_won)
	round_finished.emit(player_won)
