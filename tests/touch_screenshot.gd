extends SceneTree
## Makes a picture of the phone layout, to check it without a phone.
## The window size plays the screen size in points. For an iPhone 14 held
## sideways in Safari (844 x 340 points), from the project folder:
##
##   SHOT=/tmp/phone.png godot --path . --resolution 844x340 --script res://tests/touch_screenshot.gd

func _initialize():
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	_go.call_deferred(m)

func _go(m):
	m.touch_controls.force_touch = true
	m.use_touch_layout()
	m.start_round()
	m.touch_controls.visible = true
	for i in 30: await process_frame
	m.apply_layout()
	for i in 10: await process_frame
	var b = m.touch_controls.buttons["attack_high"]
	b.get_child(0).set_pressed(true)
	for i in 5: await process_frame
	root.get_texture().get_image().save_png(OS.get_environment("SHOT"))
	quit()
