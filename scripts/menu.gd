extends CanvasLayer
## The title screen ("RUDIS" + Start) and the end-of-round screen
## ("Victory" / "Defeat" + Restart). Both are built in code below.

signal start_pressed
signal restart_pressed

var _title_screen: Control
var _result_screen: Control
var _result_label: Label
var _start_button: Button
var _restart_button: Button


func _ready() -> void:
	layer = 10  # draw above the game and the HUD
	_title_screen = _build_title_screen()
	_result_screen = _build_result_screen()
	show_title()


func show_title() -> void:
	_title_screen.visible = true
	_result_screen.visible = false
	_start_button.grab_focus()  # so Enter / Space also presses Start


## won = true shows "Victory", false shows "Defeat".
func show_result(won: bool) -> void:
	_result_label.text = "Victory" if won else "Defeat"
	_result_label.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.35) if won else Color(0.85, 0.85, 0.9))
	_title_screen.visible = false
	_result_screen.visible = true
	_restart_button.grab_focus()


func hide_all() -> void:
	_title_screen.visible = false
	_result_screen.visible = false


func is_title_visible() -> bool:
	return _title_screen.visible


func is_result_visible() -> bool:
	return _result_screen.visible


func get_result_text() -> String:
	return _result_label.text


# ---------------------------------------------------------------------------
# Building the screens
# ---------------------------------------------------------------------------

func _build_title_screen() -> Control:
	var screen := _make_screen()
	var column := _make_column(screen)
	column.add_child(_make_label("RUDIS", 140, Color(0.95, 0.8, 0.4)))
	var logo := RudisLogo.new()
	logo.custom_minimum_size = Vector2(360, 40)
	column.add_child(logo)
	column.add_child(_make_label("From Slave to Legend", 30, Color.WHITE))
	_start_button = _make_button("Start")
	_start_button.pressed.connect(func() -> void: start_pressed.emit())
	column.add_child(_start_button)
	column.add_child(_make_label(
		"Move: A / D or arrows    High attack: J or Up    Low attack: K or Down\n" +
		"Block (hold): L or Shift    Dodge roll: Space", 20, Color(0.9, 0.9, 0.9)))
	return screen


func _build_result_screen() -> Control:
	var screen := _make_screen()
	var column := _make_column(screen)
	_result_label = _make_label("Victory", 110, Color.WHITE)
	column.add_child(_result_label)
	_restart_button = _make_button("Restart")
	_restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	column.add_child(_restart_button)
	return screen


## A see-through dark layer covering the whole screen.
func _make_screen() -> Control:
	var screen := ColorRect.new()
	screen.color = Color(0, 0, 0, 0.55)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	return screen


## A column centred on the screen that stacks its children vertically.
func _make_column(screen: Control) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)
	return column


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.25, 0.08, 0.05))
	label.add_theme_constant_override("outline_size", int(font_size / 8.0))
	return label


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 72)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 36)
	return button


## The logo idea: a wooden training sword (the rudis) lying under the title.
class RudisLogo extends Control:
	func _draw() -> void:
		var mid := size.y / 2.0
		var wood := Color(0.78, 0.59, 0.31)
		var dark_wood := Color(0.36, 0.23, 0.09)
		# Blade
		var blade := Rect2(size.x * 0.32, mid - 7, size.x * 0.62, 14)
		draw_rect(blade, dark_wood)
		draw_rect(blade.grow(-2), wood)
		draw_colored_polygon(PackedVector2Array([
			Vector2(size.x * 0.94, mid - 7), Vector2(size.x, mid), Vector2(size.x * 0.94, mid + 7)]), wood)
		# Cross guard, grip and pommel
		draw_rect(Rect2(size.x * 0.29, mid - 18, 12, 36), dark_wood)
		draw_rect(Rect2(size.x * 0.12, mid - 5, size.x * 0.17, 10), Color(0.55, 0.36, 0.17))
		draw_circle(Vector2(size.x * 0.1, mid), 9, dark_wood)
