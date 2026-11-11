class_name Arena
extends Node2D
## Draws the background: sky, the arena wall with a crowd, and the sand.
## It is only decoration; the fighters do not collide with anything here.

## Height (y) of the sand surface. The fighters stand on this line.
const FLOOR_Y := 600.0
const WIDTH := 1280.0
const HEIGHT := 720.0


func _draw() -> void:
	# Sky
	draw_rect(Rect2(0, 0, WIDTH, 300), Color(0.45, 0.62, 0.82))
	# Stands of the amphitheatre with a crowd (dots in a fixed random pattern)
	draw_rect(Rect2(0, 200, WIDTH, 300), Color(0.62, 0.5, 0.38))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7  # same seed = same crowd every time
	var crowd_colors := [Color(0.75, 0.3, 0.25), Color(0.9, 0.85, 0.7),
		Color(0.35, 0.45, 0.7), Color(0.55, 0.4, 0.25), Color(0.85, 0.7, 0.3)]
	for row in 5:
		for i in 60:
			var x := i * 22.0 + rng.randf_range(0.0, 12.0)
			var y := 225.0 + row * 34.0 + rng.randf_range(-4.0, 4.0)
			var color: Color = crowd_colors[rng.randi() % crowd_colors.size()]
			if x > WIDTH - 7.0:
				continue  # stay inside the picture (on phones the edge is visible)
			draw_circle(Vector2(x, y), 7.0, color)
	# Stone wall (podium) around the arena floor, with a few block lines
	draw_rect(Rect2(0, 400, WIDTH, FLOOR_Y - 400), Color(0.78, 0.72, 0.62))
	for x in range(0, int(WIDTH), 120):
		draw_line(Vector2(x, 400), Vector2(x, FLOOR_Y), Color(0.65, 0.6, 0.5), 2.0)
	draw_line(Vector2(0, 470), Vector2(WIDTH, 470), Color(0.65, 0.6, 0.5), 2.0)
	draw_rect(Rect2(0, 395, WIDTH, 10), Color(0.6, 0.18, 0.15))  # red trim
	# Sand floor (harena) with some darker grains
	draw_rect(Rect2(0, FLOOR_Y, WIDTH, HEIGHT - FLOOR_Y), Color(0.89, 0.78, 0.55))
	for i in 220:
		var grain := Vector2(rng.randf_range(0, WIDTH), rng.randf_range(FLOOR_Y + 4, HEIGHT))
		draw_circle(grain, rng.randf_range(1.0, 2.5), Color(0.78, 0.66, 0.44))
