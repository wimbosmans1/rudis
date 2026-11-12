extends SceneTree
## Automatic check that the game starts and the duel rules work.
## It runs without a window. From the project folder, run:
##
##   godot --headless --fixed-fps 60 --script res://tests/smoke_test.gd
##
## It prints PASS / FAIL for every check and ends with exit code 0 if all passed.

var _main: Node2D
var _failures := 0


func _initialize() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


## Starts a round with both controllers switched off, fighters close together.
func _setup_duel() -> void:
	_main.start_round()
	# Pause the controllers completely, so the test alone decides what happens.
	_main.player_controller.set_physics_process(false)
	_main.ai_controller.set_physics_process(false)
	_main.player.position.x = 600.0
	_main.opponent.position.x = 700.0
	await _wait(2)


func _touch(finger: int, at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = at
	event.pressed = down
	root.push_input(event, true)  # position is already in game pixels


## Tries the layout maths on a few real phone screens (sizes in game pixels,
## as the game sees them with the "expand" setting) and checks the rules.
func _check_touch_layouts() -> void:
	var script: Script = load("res://scripts/touch_controls.gd")
	# name: [screen in game pixels, game pixels per point, expected layout]
	var screens := {
		"iPhone 14 landscape": [Vector2(1787, 720), 1787.0 / 844.0, "side"],
		"iPhone 14 landscape, full screen": [Vector2(1558, 720), 1558.0 / 844.0, "side"],
		"iPhone SE landscape": [Vector2(1720, 720), 1720.0 / 667.0, "side"],
		"iPhone 14 Pro Max landscape": [Vector2(1813, 720), 1813.0 / 932.0, "side"],
		"iPhone 14 portrait": [Vector2(1280, 2400), 1280.0 / 390.0, "strip"],
		"iPad landscape": [Vector2(1280, 960), 1280.0 / 1024.0, "strip"],
	}
	for screen_name in screens:
		var view: Vector2 = screens[screen_name][0]
		var px_per_pt: float = screens[screen_name][1]
		var expected_mode: String = screens[screen_name][2]
		var layout: Dictionary = script.compute_layout(view, px_per_pt)
		var arena: Rect2 = layout["arena"]
		var rects: Array = layout["buttons"].values()
		var ok := arena.size.x > 0.0 and Rect2(Vector2.ZERO, view).encloses(arena)
		ok = ok and rects.size() == 6 and layout["mode"] == expected_mode
		var smallest := INF
		for i in rects.size():
			var r: Rect2 = rects[i]
			smallest = minf(smallest, minf(r.size.x, r.size.y) / px_per_pt)
			ok = ok and not r.intersects(arena) and Rect2(Vector2.ZERO, view).encloses(r)
			for j in range(i + 1, rects.size()):
				ok = ok and not r.intersects(rects[j])
		ok = ok and smallest >= 60.0
		# Sideways, the arena should use (almost) the whole screen height.
		if expected_mode == "side":
			ok = ok and arena.size.y >= 0.9 * view.y
		_check(ok, "%s: %s layout, smallest button %.0f pt, arena %.0f x %.0f pt (%.0f%% of height)" % [
			screen_name, layout["mode"], smallest, arena.size.x / px_per_pt, arena.size.y / px_per_pt,
			100.0 * arena.size.y / view.y])
	# iPhone 14 sideways in Safari: the arena must be clearly bigger than the
	# old layout with the strip below it (about 402 x 226 points).
	var iphone: Dictionary = script.compute_layout(Vector2(1787, 720), 1787.0 / 844.0)
	var arena_pt: Vector2 = iphone["arena"].size / (1787.0 / 844.0)
	_check(arena_pt.x >= 560.0 and arena_pt.y >= 315.0,
		"iPhone 14 landscape arena is bigger than before (%.0f x %.0f pt, was 402 x 226)" % [arena_pt.x, arena_pt.y])
	# Left thumb gets < and > (left edge), right thumb the four actions.
	var b: Dictionary = iphone["buttons"]
	var mid := 1787.0 / 2.0
	_check(b["move_left"].end.x < mid and b["move_right"].end.x < mid
		and b["move_left"].end.y <= b["move_right"].position.y
		and b["attack_high"].position.x > mid and b["dodge"].position.x > mid,
		"iPhone 14 landscape: < > stacked on the left, HIGH LOW BLOCK ROLL on the right")


func _run() -> void:
	await _wait(2)
	var player: Fighter = _main.player
	var opponent: Fighter = _main.opponent

	# 1. Input actions exist and have keys.
	for action in ["move_left", "move_right", "attack_high", "attack_low", "block", "dodge"]:
		_check(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(),
			"input action '%s' has keys" % action)
	var left_keys := InputMap.action_get_events("move_left").map(
		func(e: InputEvent) -> int: return (e as InputEventKey).physical_keycode)
	_check(KEY_A in left_keys and KEY_LEFT in left_keys, "move_left uses A and the Left arrow")

	# 2. Title screen is showing.
	_check(_main.menu.is_title_visible(), "title screen visible at start")

	# 3. A clean high attack hits and costs stamina.
	await _setup_duel()
	_check(not _main.menu.is_title_visible(), "Start hides the title screen")
	_check(player.try_attack(Fighter.AttackKind.HIGH), "player can start a high attack")
	_check(player.stamina < player.max_stamina, "attacking costs stamina")
	await _wait(40)
	var clean_damage := opponent.max_health - opponent.health
	_check(clean_damage > 0.0, "high attack hits (damage %.1f)" % clean_damage)
	_check(_main.sfx.played.has("swing") and _main.sfx.played.has("hit"),
		"swing and hit sounds play (%s)" % [_main.sfx.played])

	# 4. Blocking reduces damage.
	await _setup_duel()
	opponent.wants_block = true
	await _wait(2)
	player.try_attack(Fighter.AttackKind.HIGH)
	await _wait(40)
	var blocked_damage := opponent.max_health - opponent.health
	_check(blocked_damage > 0.0 and blocked_damage < clean_damage,
		"block reduces damage (%.1f instead of %.1f)" % [blocked_damage, clean_damage])
	_check(opponent.stamina < opponent.max_stamina, "blocking costs stamina")
	_check(_main.sfx.played.has("clang"), "blocked attack plays the clang sound")
	opponent.wants_block = false

	# 5. Dodging avoids the hit.
	await _setup_duel()
	player.try_attack(Fighter.AttackKind.HIGH)
	await _wait(6)
	_check(opponent.try_dodge(0.0), "opponent can dodge")
	await _wait(40)
	_check(is_equal_approx(opponent.health, opponent.max_health), "dodge avoids the damage")

	# 6. Not enough stamina = no attack.
	await _setup_duel()
	player.stamina = 5.0
	_check(not player.try_attack(Fighter.AttackKind.HIGH), "no attack without stamina")

	# 7. Stamina refills when resting.
	player.stamina = 10.0
	await _wait(120)
	_check(player.stamina > 10.0, "stamina regenerates (%.1f)" % player.stamina)

	# 8. A whole fight, computer against computer, ends with a result screen.
	_main.player_controller.set_physics_process(true)
	_main.ai_controller.set_physics_process(true)
	_main.start_round()
	var second_ai: Node = load("res://scripts/ai_controller.gd").new()
	_main.add_child(second_ai)
	_main.move_child(second_ai, 0)  # think before the fighters move
	second_ai.fighter = player
	second_ai.target = opponent
	_main.player_controller.enabled = false
	second_ai.enabled = true
	var frames := 0
	while not _main.menu.is_result_visible() and frames < 60 * 300:
		await physics_frame
		frames += 1
		if not _main.round_active:
			second_ai.enabled = false
	_check(_main.menu.is_result_visible(),
		"AI vs AI fight ends after %.1f s with '%s'" % [frames / 60.0, _main.menu.get_result_text()])
	_check(player.is_dead() != opponent.is_dead(), "exactly one fighter is knocked out")

	# 9. Restart gives both fighters full health again.
	_main.start_round()
	await _wait(2)
	_check(player.health == player.max_health and opponent.health == opponent.max_health,
		"restart resets health")
	_check(not _main.menu.is_result_visible(), "restart hides the result screen")

	# 10. Phone layout: big buttons, never on top of the arena.
	_check_touch_layouts()
	var touch: CanvasLayer = _main.touch_controls
	touch.force_touch = true
	_main.apply_layout()
	touch.visible = true
	var area: Rect2 = touch.arena_rect
	var overlap := false
	for action in touch.buttons:
		var button: TouchScreenButton = touch.buttons[action]
		var size: Vector2 = (button.shape as RectangleShape2D).size
		if Rect2(button.position - size / 2.0, size).intersects(area):
			overlap = true
	_check(not overlap and _main.scale.x < 1.0,
		"touch layout shrinks the arena (x%.2f) and keeps buttons off it" % _main.scale.x)
	# A finger on the HIGH button presses the high attack, and a second finger
	# on > walks at the same time.
	var high: TouchScreenButton = touch.buttons["attack_high"]
	var right: TouchScreenButton = touch.buttons["move_right"]
	_touch(0, high.position, true)
	_touch(1, right.position, true)
	await _wait(1)
	_check(Input.is_action_pressed("attack_high") and Input.is_action_pressed("move_right"),
		"two fingers press HIGH and > together")
	_touch(0, high.position, false)
	_touch(1, right.position, false)
	touch.force_touch = false
	touch.visible = false
	_main.apply_layout()

	print("\n%s: %d check(s) failed" % ["FAILED" if _failures > 0 else "ALL PASSED", _failures])
	quit(1 if _failures > 0 else 0)
