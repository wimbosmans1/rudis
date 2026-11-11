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
@onready var sfx: Node = $Sfx

## Colour around the arena on phones (behind the touch buttons).
const STRIP_COLOR := Color(0.13, 0.09, 0.07)

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
	sfx.watch(player)
	sfx.watch(opponent)

	menu.start_pressed.connect(_on_start_button)
	menu.restart_pressed.connect(_on_start_button)

	# On phones the screen is used edge to edge: the arena on top and a strip
	# with big buttons below it. On a PC the picture stays exactly as it was.
	if touch_controls.is_wanted():
		use_touch_layout()
	get_tree().root.size_changed.connect(apply_layout)

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


## Switches to the phone layout (arena above, buttons below).
func use_touch_layout() -> void:
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	RenderingServer.set_default_clear_color(STRIP_COLOR)
	apply_layout()


## Shrinks and moves the arena (and the health bars with it) into the space
## the touch controls leave free. Runs again when the phone is turned.
func apply_layout() -> void:
	var area: Rect2 = touch_controls.update_layout()
	var zoom := area.size.x / Arena.WIDTH
	position = area.position
	scale = Vector2(zoom, zoom)
	hud.offset = area.position
	hud.scale = Vector2(zoom, zoom)


func _on_start_button() -> void:
	sfx.unlock()  # iPhone: sound may only start from inside a tap
	start_round()


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
