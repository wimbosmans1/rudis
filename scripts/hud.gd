extends CanvasLayer
## The bars at the top of the screen: name, health and stamina per fighter.
## The bars are built in code so the whole layout is visible in one place.

const BAR_WIDTH := 460.0
const HEALTH_COLOR := Color(0.85, 0.2, 0.18)
const STAMINA_COLOR := Color(0.95, 0.78, 0.25)

var _player: Fighter
var _opponent: Fighter
var _player_bars: Dictionary
var _opponent_bars: Dictionary


## Connects the HUD to the two fighters. Called once by main.gd.
func setup(player: Fighter, opponent: Fighter) -> void:
	_player = player
	_opponent = opponent
	_player_bars = _make_panel(player.display_name, Vector2(30, 20), false)
	_opponent_bars = _make_panel(opponent.display_name, Vector2(1280 - 30 - BAR_WIDTH, 20), true)


func _process(_delta: float) -> void:
	# Copy the current numbers into the bars every frame.
	if _player == null:
		return
	_update_bars(_player_bars, _player)
	_update_bars(_opponent_bars, _opponent)


func _update_bars(bars: Dictionary, fighter: Fighter) -> void:
	var health_bar: ProgressBar = bars["health"]
	var stamina_bar: ProgressBar = bars["stamina"]
	health_bar.max_value = fighter.max_health
	health_bar.value = fighter.health
	stamina_bar.max_value = fighter.max_stamina
	stamina_bar.value = fighter.stamina
	# Stamina bar turns grey when the fighter is exhausted.
	stamina_bar.modulate = Color(0.6, 0.6, 0.6) if fighter.is_exhausted() else Color.WHITE


## Builds a name label, a health bar and a stamina bar at a screen position.
## right_side = true makes the bars empty towards the middle of the screen.
func _make_panel(title: String, at: Vector2, right_side: bool) -> Dictionary:
	var box := VBoxContainer.new()
	box.position = at
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	if right_side:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(label)

	var health := _make_bar(HEALTH_COLOR, 22.0, right_side)
	var stamina := _make_bar(STAMINA_COLOR, 12.0, right_side)
	box.add_child(health)
	box.add_child(stamina)
	return {"health": health, "stamina": stamina}


func _make_bar(fill_color: Color, height: float, right_side: bool) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(BAR_WIDTH, height)
	if right_side:
		bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0, 0, 0, 0.55)
	background.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	return bar
