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

	print("\n%s: %d check(s) failed" % ["FAILED" if _failures > 0 else "ALL PASSED", _failures])
	quit(1 if _failures > 0 else 0)
