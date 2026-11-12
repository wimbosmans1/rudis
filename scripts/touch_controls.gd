extends CanvasLayer
## Big on-screen buttons for phones and tablets (for example an iPhone).
##
## They only appear on devices with a touch screen. The buttons always sit
## OUTSIDE the arena, so your thumbs never cover the fight. There are two
## layouts, and the game picks the one that leaves the bigger arena:
##
## Phone sideways (landscape): the buttons go in the dark edges left and
## right of the arena, and the arena uses (almost) the full screen height:
##
##   +-----+--------------------------+--------+
##   | [<] |                          | [HIGH] |
##   |     |      the arena (fight)   | [LOW]  |
##   | [>] |                          | [BLOCK]|
##   |     |                          | [ROLL] |
##   +-----+--------------------------+--------+
##
## Phone upright (portrait) and iPad: the buttons get a strip under the arena:
##
##   +--------------------------------------+
##   |            the arena (fight)         |
##   +--------------------------------------+
##   | [<] [>]                [HIGH] [LOW]  |
##   |                        [BLOCK][ROLL] |
##
## Each button "presses" the same input action as the keyboard (see the Input
## Map), so the player controller does not need to know whether you use keys
## or a finger. TouchScreenButton supports several fingers at once, so you
## can walk and attack at the same time.

## Button sizes in "points". A point is the unit iPhones use for sizes:
## Apple advises at least 44 points for anything you tap; these buttons are
## about twice that, so they are easy to hit with a thumb without looking.
const BUTTON_HEIGHT_PT := 84.0
const MOVE_WIDTH_PT := 104.0     ## Width of the < and > buttons.
const ACTION_WIDTH_PT := 92.0    ## Width of HIGH, LOW, BLOCK and ROLL.
const GAP_PT := 12.0             ## Space between two buttons.
const CLUSTER_GAP_PT := 28.0     ## Minimum space between the two thumb groups.
const EDGE_PT := 12.0            ## Space to the left / right / top of the strip.
const BOTTOM_PT := 18.0          ## Space at the bottom (the iPhone "home bar").
## The button strip never takes more than this part of the screen height.
const MAX_STRIP_SHARE := 0.42

## Side layout (phone sideways). Sizes in points.
const SIDE_EDGE_PT := 10.0       ## Space between a button and the screen edge.
const SIDE_INNER_PT := 8.0       ## Space between a button and the arena.
const SIDE_TOP_PT := 8.0         ## Space above the top button.
const SIDE_BOTTOM_PT := 12.0     ## Space below the bottom button (home bar).
const SIDE_GAP_PT := 12.0        ## Preferred space between two buttons...
const SIDE_MIN_GAP_PT := 6.0     ## ...made smaller (to this) on short screens.
const SIDE_MIN_WIDTH_PT := 76.0  ## The side buttons are at least this wide...
const SIDE_MAX_WIDTH_PT := 120.0 ## ...and at most this wide.
const SIDE_MAX_HEIGHT_PT := 110.0 ## HIGH / LOW / BLOCK / ROLL at most this tall.
## Buttons should be at least this big (Apple's minimum is 44 points).
const MIN_BUTTON_PT := 60.0

## The size of the arena drawing (the game's "virtual screen").
const ARENA_SIZE := Vector2(1280, 720)

const MOVE_ACTIONS := ["move_left", "move_right"]
const ACTION_BUTTONS := [
	{"action": "attack_high", "text": "HIGH"},
	{"action": "attack_low", "text": "LOW"},
	{"action": "block", "text": "BLOCK"},
	{"action": "dodge", "text": "ROLL"},
]

const IDLE_COLOR := Color(1, 1, 1, 0.16)
const PRESSED_COLOR := Color(1.0, 0.85, 0.4, 0.55)
const BORDER_COLOR := Color(1, 1, 1, 0.55)

## Tests can switch this on to get the phone layout on a PC.
var force_touch := false

## action name -> the TouchScreenButton for it
var buttons := {}
## The area of the screen the arena is drawn in (set by update_layout()).
var arena_rect := Rect2(Vector2.ZERO, ARENA_SIZE)


func _ready() -> void:
	layer = 5
	for action in MOVE_ACTIONS:
		_add_button(action, "")
	for info in ACTION_BUTTONS:
		_add_button(info["action"], info["text"])
	visible = false  # main.gd shows the buttons during a fight


## True on phones / tablets, false on a normal PC.
func is_wanted() -> bool:
	return force_touch or DisplayServer.is_touchscreen_available()


## Works out where the arena and every button go for the current screen
## size, moves the buttons there and returns the arena area.
## main.gd calls this at the start and whenever the screen turns or resizes.
func update_layout() -> Rect2:
	if not is_wanted():
		arena_rect = Rect2(Vector2.ZERO, ARENA_SIZE)
		return arena_rect
	var view := get_viewport().get_visible_rect().size
	var layout := compute_layout(view, _pixels_per_point(view))
	arena_rect = layout["arena"]
	for action in buttons:
		_place_button(buttons[action], layout["buttons"][action])
	return arena_rect


## The layout maths, separate so the automatic test can try many screens.
## view: screen size in game pixels. px_per_pt: game pixels per iPhone point.
## Tries both layouts and keeps the one with the bigger arena (as long as its
## buttons are still big enough).
## Returns {"arena": Rect2, "buttons": {action name: Rect2}, "columns": int,
## "mode": "side" or "strip"}.
static func compute_layout(view: Vector2, px_per_pt: float) -> Dictionary:
	var strip := _strip_layout(view, px_per_pt)
	var side := _side_layout(view, px_per_pt)
	if not side.is_empty() and side["arena"].get_area() > strip["arena"].get_area():
		return side
	return strip


## Phone sideways: < and > on the left, HIGH LOW BLOCK ROLL in a column on
## the right, the arena in between at (almost) full height.
## Returns {} if the buttons would get too small on this screen.
static func _side_layout(view: Vector2, px_per_pt: float) -> Dictionary:
	var u := px_per_pt
	var view_pt := view / u
	# Height of the four right-hand buttons, with smaller gaps if needed.
	var free_pt := view_pt.y - SIDE_TOP_PT - SIDE_BOTTOM_PT
	var gap_pt := SIDE_GAP_PT
	if (free_pt - 3.0 * gap_pt) / 4.0 < MIN_BUTTON_PT:
		gap_pt = maxf(SIDE_MIN_GAP_PT, (free_pt - 4.0 * MIN_BUTTON_PT) / 3.0)
	var action_h_pt := minf(SIDE_MAX_HEIGHT_PT, (free_pt - 3.0 * gap_pt) / 4.0)
	if action_h_pt < MIN_BUTTON_PT:
		return {}
	# The arena: as tall as the screen, unless the edges would then be too
	# narrow for the buttons.
	var min_gutter := (SIDE_EDGE_PT + SIDE_MIN_WIDTH_PT + SIDE_INNER_PT) * u
	var scale := minf(view.y / ARENA_SIZE.y, (view.x - 2.0 * min_gutter) / ARENA_SIZE.x)
	if scale <= 0.0:
		return {}
	var arena_size := ARENA_SIZE * scale
	var arena := Rect2((view - arena_size) / 2.0, arena_size)
	var gutter := arena.position.x
	var width := minf(SIDE_MAX_WIDTH_PT * u, gutter - (SIDE_EDGE_PT + SIDE_INNER_PT) * u)

	var rects := {}
	var gap := gap_pt * u
	var top := SIDE_TOP_PT * u
	var bottom := view.y - SIDE_BOTTOM_PT * u
	# Left edge: < on top, > below it, each half of the height. The buttons
	# hug the screen edge, where the thumb is.
	var left_x := SIDE_EDGE_PT * u
	var move_h := (bottom - top - gap) / 2.0
	rects["move_left"] = Rect2(left_x, top, width, move_h)
	rects["move_right"] = Rect2(left_x, top + move_h + gap, width, move_h)
	# Right edge: HIGH, LOW, BLOCK, ROLL from top to bottom, centred in height.
	var right_x := view.x - SIDE_EDGE_PT * u - width
	var h := action_h_pt * u
	var column_h := 4.0 * h + 3.0 * gap
	var y := top + (bottom - top - column_h) / 2.0
	for info in ACTION_BUTTONS:
		rects[info["action"]] = Rect2(right_x, y, width, h)
		y += h + gap
	return {"arena": arena, "buttons": rects, "columns": 1, "mode": "side"}


## Phone upright / iPad: a strip with all buttons under the arena.
static func _strip_layout(view: Vector2, px_per_pt: float) -> Dictionary:
	var available_pt := view.x / px_per_pt
	# Try all four action buttons in one row (made at most 15% smaller to
	# fit); if that is still too wide, use 2 x 2.
	var columns := 4
	if _row_width_pt(4) * 0.85 > available_pt:
		columns = 2
	var rows := 4 / columns
	# Shrink everything a little if it still does not fit the screen.
	var shrink := minf(1.0, available_pt / _row_width_pt(columns))
	var strip_pt := EDGE_PT + rows * BUTTON_HEIGHT_PT + (rows - 1) * GAP_PT + BOTTOM_PT
	shrink = minf(shrink, MAX_STRIP_SHARE * view.y / px_per_pt / strip_pt)
	var u := px_per_pt * shrink  # game pixels per (shrunk) point

	var strip_top := view.y - strip_pt * u
	# The arena: as big as possible above the strip, centred left-right and
	# sitting right on top of the buttons.
	var scale := minf(view.x / ARENA_SIZE.x, strip_top / ARENA_SIZE.y)
	var arena_size := ARENA_SIZE * scale
	var arena := Rect2(Vector2((view.x - arena_size.x) / 2.0, strip_top - arena_size.y), arena_size)

	var rects := {}
	var h := BUTTON_HEIGHT_PT * u
	var gap := GAP_PT * u
	var bottom := view.y - BOTTOM_PT * u
	var block_top := bottom - rows * h - (rows - 1) * gap
	# Left thumb: < and >, as tall as the whole right-hand block.
	var move_w := MOVE_WIDTH_PT * u
	var x := EDGE_PT * u
	for action in MOVE_ACTIONS:
		rects[action] = Rect2(x, block_top, move_w, bottom - block_top)
		x += move_w + gap
	# Right thumb: HIGH LOW BLOCK ROLL, in one row or in 2 x 2.
	var action_w := ACTION_WIDTH_PT * u
	var right_start := view.x - EDGE_PT * u - columns * action_w - (columns - 1) * gap
	for i in ACTION_BUTTONS.size():
		var column := i % columns
		var row := i / columns
		rects[ACTION_BUTTONS[i]["action"]] = Rect2(
			right_start + column * (action_w + gap), block_top + row * (h + gap), action_w, h)
	return {"arena": arena, "buttons": rects, "columns": columns, "mode": "strip"}


static func _row_width_pt(columns: int) -> float:
	return (2.0 * EDGE_PT + 2.0 * MOVE_WIDTH_PT + GAP_PT + CLUSTER_GAP_PT
		+ columns * ACTION_WIDTH_PT + (columns - 1) * GAP_PT)


## How many game pixels make one point on this screen.
func _pixels_per_point(view: Vector2) -> float:
	if OS.has_feature("web"):
		# In a browser, window.innerWidth is the page width in points.
		var css_width = JavaScriptBridge.eval("window.innerWidth", true)
		if (css_width is int or css_width is float) and css_width > 0:
			return view.x / float(css_width)
	var window_size := Vector2(get_window().size)
	if window_size.x <= 0.0:
		return 1.0
	return view.x / window_size.x * DisplayServer.screen_get_scale()


func _add_button(action: String, text: String) -> void:
	var button := TouchScreenButton.new()
	button.action = action
	button.shape = RectangleShape2D.new()
	# Lets a finger slide from one button onto another (handy for walking).
	button.passby_press = action in MOVE_ACTIONS
	add_child(button)

	var face := ButtonFace.new()
	face.text = text
	face.arrow = -1 if action == "move_left" else (1 if action == "move_right" else 0)
	button.add_child(face)
	# Lights up and sinks in a little while a finger is on it.
	button.pressed.connect(func() -> void: face.set_pressed(true))
	button.released.connect(func() -> void: face.set_pressed(false))
	buttons[action] = button
	_place_button(button, Rect2(0, 0, 100, 100))


func _place_button(button: TouchScreenButton, rect: Rect2) -> void:
	# The button sits at the middle of its rectangle; its shape is centred on it.
	button.position = rect.get_center()
	(button.shape as RectangleShape2D).size = rect.size
	var face: ButtonFace = button.get_child(0)
	face.button_size = rect.size
	face.queue_redraw()


## Draws one button: a rounded see-through box with a label or an arrow.
class ButtonFace extends Node2D:
	var text := ""
	var arrow := 0  # -1 = arrow left, 1 = arrow right, 0 = text
	var button_size := Vector2(100, 100)
	var is_pressed := false

	func set_pressed(on: bool) -> void:
		is_pressed = on
		scale = Vector2.ONE * (0.93 if on else 1.0)
		queue_redraw()

	func _draw() -> void:
		var box := StyleBoxFlat.new()
		box.bg_color = PRESSED_COLOR if is_pressed else IDLE_COLOR
		box.border_color = BORDER_COLOR
		box.set_border_width_all(maxi(2, int(button_size.y * 0.03)))
		box.set_corner_radius_all(int(minf(button_size.x, button_size.y) * 0.22))
		draw_style_box(box, Rect2(-button_size / 2.0, button_size))
		var ink := Color(1, 1, 1, 0.95)
		if arrow != 0:
			var r := minf(button_size.x, button_size.y) * 0.26
			draw_colored_polygon(PackedVector2Array([
				Vector2(arrow * r, 0), Vector2(-arrow * r * 0.7, -r), Vector2(-arrow * r * 0.7, r)]), ink)
			return
		var font := ThemeDB.fallback_font
		var font_size := int(button_size.y * 0.27)
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if width > button_size.x * 0.86:  # make long words fit
			font_size = int(font_size * button_size.x * 0.86 / width)
			width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var baseline := (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
		draw_string(font, Vector2(-width / 2.0, baseline), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
