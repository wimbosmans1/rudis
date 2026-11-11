extends CanvasLayer
## Round on-screen buttons for phones and tablets (for example an iPhone).
##
## They only appear on devices with a touch screen. Each button "presses" the
## same input action as the keyboard (see the Input Map), so the player
## controller does not need to know whether you use keys or a finger.
## TouchScreenButton supports several fingers at once, so you can walk and
## attack at the same time.

const RADIUS := 58.0

## Each button: the input action, the text on it, and where it sits
## on the 1280 x 720 screen.
const BUTTONS := [
	{"action": "move_left", "text": "<", "position": Vector2(95, 630)},
	{"action": "move_right", "text": ">", "position": Vector2(240, 630)},
	{"action": "attack_high", "text": "HIGH", "position": Vector2(1045, 510)},
	{"action": "attack_low", "text": "LOW", "position": Vector2(1185, 510)},
	{"action": "block", "text": "BLOCK", "position": Vector2(1045, 640)},
	{"action": "dodge", "text": "ROLL", "position": Vector2(1185, 640)},
]


func _ready() -> void:
	layer = 5
	for info in BUTTONS:
		_add_button(info["action"], info["text"], info["position"])
	visible = false  # main.gd shows the buttons during a fight


## True on phones / tablets, false on a normal PC.
func is_wanted() -> bool:
	return DisplayServer.is_touchscreen_available()


func _add_button(action: String, text: String, at: Vector2) -> void:
	var button := TouchScreenButton.new()
	button.position = at
	button.action = action
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	button.shape = circle
	# Lets a finger slide from one button onto another (handy for walking).
	button.passby_press = action == "move_left" or action == "move_right"
	add_child(button)

	# The visible part: a see-through circle with a label in the middle.
	var disc := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 32:
		var angle := TAU * i / 32.0
		points.append(Vector2(cos(angle), sin(angle)) * RADIUS)
	disc.polygon = points
	disc.color = Color(1, 1, 1, 0.22)
	button.add_child(disc)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	label.position = Vector2(-RADIUS, -RADIUS)
	button.add_child(label)

	# Brighter while a finger is on the button.
	button.pressed.connect(func() -> void: disc.color = Color(1, 1, 1, 0.5))
	button.released.connect(func() -> void: disc.color = Color(1, 1, 1, 0.22))
