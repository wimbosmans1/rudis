class_name Fighter
extends Node2D
## One gladiator standing in the arena.
##
## A Fighter does not decide what to do by itself. A "controller" tells it:
## - PlayerController reads the keyboard / touch buttons,
## - AIController makes the decisions for the computer opponent.
## The controller sets [member move_input] and [member wants_block] every frame
## and calls [method try_attack] or [method try_dodge]. The Fighter then checks
## the rules (enough stamina? not busy?) and moves, attacks and draws itself.
##
## The node's position is the point between the fighter's feet, on the sand.

## Sent when this fighter's health reaches zero.
signal died(fighter: Fighter)
## Sent when this fighter starts a swing (used for the "whoosh" sound).
signal attack_started(kind: AttackKind)
## Sent when a blow reaches this fighter. result is "hit" or "blocked".
signal got_hit(result: String)

## The two gladiator types in this prototype. More will follow later.
enum GladiatorClass { MURMILLO, RETIARIUS }

## What the fighter is doing right now. Only one state at a time.
enum State { IDLE, WALK, ATTACK, BLOCK, DODGE, HURT, DEAD }

## Which height an attack aims at.
enum AttackKind { HIGH, LOW }

# ---------------------------------------------------------------------------
# Settings you can change per fighter in the Inspector (see scenes/main.tscn)
# ---------------------------------------------------------------------------

@export var display_name := "Gladiator"
@export var gladiator_class: GladiatorClass = GladiatorClass.MURMILLO
## Main colour of the fighter (tunic, crest, shield).
@export var body_color := Color(0.78, 0.16, 0.14)
@export var max_health := 100.0
@export var max_stamina := 100.0
## Walking speed in pixels per second.
@export var move_speed := 220.0
## How far an attack reaches, measured from this fighter's centre to the
## opponent's centre, in pixels.
@export var reach := 120.0
## Multiplies all damage this fighter deals. 1.0 = normal.
@export var damage_multiplier := 1.0
## Part of the damage a block stops: 0.8 means 80 % is stopped.
@export_range(0.0, 1.0) var block_strength := 0.75

# ---------------------------------------------------------------------------
# Game rules (the same for every fighter)
# ---------------------------------------------------------------------------

## Data for each attack. Times are in seconds.
## windup   = the fighter pulls the weapon back (the opponent can react)
## active   = the moment the hit can land
## recovery = the fighter is open while bringing the weapon back
const ATTACKS := {
	AttackKind.HIGH: {"damage": 14.0, "stamina": 24.0, "windup": 0.30, "active": 0.10, "recovery": 0.30},
	AttackKind.LOW: {"damage": 9.0, "stamina": 16.0, "windup": 0.20, "active": 0.10, "recovery": 0.22},
}
const DODGE_COST := 28.0          ## Stamina spent on a dodge roll.
const DODGE_TIME := 0.40          ## How long the roll lasts (you cannot be hit).
const DODGE_SPEED := 430.0        ## Roll speed in pixels per second.
const BLOCK_STAMINA_COST := 12.0  ## Stamina lost when you block a hit.
const STAMINA_REGEN := 24.0       ## Stamina regained per second when resting.
const STAMINA_REGEN_DELAY := 0.6  ## Pause after an action before stamina refills.
const HURT_TIME := 0.32           ## How long a fighter staggers after being hit.
const GUARD_BREAK_TIME := 0.7     ## Stagger time when a block runs out of stamina.
const MIN_GAP := 70.0             ## Fighters cannot stand closer than this.
const FLASH_TIME := 0.12          ## Length of the white "hit flash".

# ---------------------------------------------------------------------------
# Values that change while playing
# ---------------------------------------------------------------------------

var health := 100.0
var stamina := 100.0
var state: State = State.IDLE
## 1 = looking right, -1 = looking left.
var facing := 1
## The other fighter. Set by main.gd.
var opponent: Fighter
## Left and right edges of the arena floor. Set by main.gd.
var arena_left := 60.0
var arena_right := 1220.0

## Filled in by the controller every frame.
## -1 = walk left, 0 = stand still, 1 = walk right.
var move_input := 0.0
## True while the controller wants to hold the block.
var wants_block := false

var _state_time := 0.0              # seconds spent in the current state
var _current_attack: AttackKind = AttackKind.HIGH
var _attack_has_hit := false        # so one swing only hits once
var _dodge_direction := -1.0
var _hurt_duration := HURT_TIME
var _knockback := 0.0               # sideways push after being hit
var _regen_delay := 0.0
var _flash := 0.0                   # >0 while the hit flash is showing
var _spark_time := 0.0              # >0 while a spark is showing
var _spark_position := Vector2.ZERO
var _spark_was_blocked := false


## Puts the fighter back to full health at a starting spot.
func reset(start_x: float, start_facing: int) -> void:
	health = max_health
	stamina = max_stamina
	position.x = start_x
	facing = start_facing
	scale.x = facing
	move_input = 0.0
	wants_block = false
	_knockback = 0.0
	_flash = 0.0
	_spark_time = 0.0
	_regen_delay = 0.0
	_enter_state(State.IDLE)


# ---------------------------------------------------------------------------
# Actions a controller can ask for
# ---------------------------------------------------------------------------

## Starts an attack if the fighter is free and has enough stamina.
## Returns true if the attack started.
func try_attack(kind: AttackKind) -> bool:
	if not _can_act():
		return false
	var cost: float = ATTACKS[kind]["stamina"]
	if stamina < cost:
		return false
	_spend_stamina(cost)
	_current_attack = kind
	_attack_has_hit = false
	_enter_state(State.ATTACK)
	attack_started.emit(kind)
	return true


## Starts a dodge roll. direction: -1 = left, 1 = right, 0 = roll backwards.
## Returns true if the roll started.
func try_dodge(direction: float) -> bool:
	if not _can_act() or stamina < DODGE_COST:
		return false
	_spend_stamina(DODGE_COST)
	_dodge_direction = signf(direction) if direction != 0.0 else -float(facing)
	_enter_state(State.DODGE)
	return true


# ---------------------------------------------------------------------------
# Questions other scripts can ask
# ---------------------------------------------------------------------------

func is_dead() -> bool:
	return state == State.DEAD


## True while winding up or swinging (used by the AI to decide when to block).
func is_attacking() -> bool:
	return state == State.ATTACK


func is_exhausted() -> bool:
	return stamina <= 0.0


func distance_to_fighter(other: Fighter) -> float:
	return absf(other.position.x - position.x)


# ---------------------------------------------------------------------------
# Main loop: runs 60 times per second
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_state_time += delta
	_flash = maxf(_flash - delta, 0.0)
	_spark_time = maxf(_spark_time - delta, 0.0)

	if state != State.DEAD:
		_update_stamina(delta)
		match state:
			State.IDLE, State.WALK:
				_update_walking(delta)
			State.BLOCK:
				if not wants_block:
					_enter_state(State.IDLE)
			State.ATTACK:
				_update_attack(delta)
			State.DODGE:
				position.x += _dodge_direction * DODGE_SPEED * delta
				if _state_time >= DODGE_TIME:
					_enter_state(State.IDLE)
			State.HURT:
				if _state_time >= _hurt_duration:
					_enter_state(State.IDLE)

		# Being pushed back by a hit slowly fades out.
		position.x += _knockback * delta
		_knockback = move_toward(_knockback, 0.0, 1400.0 * delta)

		_keep_apart_from_opponent()
		_face_opponent()

	# Never leave the arena.
	position.x = clampf(position.x, arena_left, arena_right)
	queue_redraw()  # ask Godot to call _draw() again with the new pose


func _update_walking(delta: float) -> void:
	if wants_block:
		_enter_state(State.BLOCK)
		return
	var speed := move_speed
	if is_exhausted():
		speed *= 0.6  # tired fighters move slowly
	position.x += move_input * speed * delta
	if absf(move_input) > 0.1:
		if state != State.WALK:
			_enter_state(State.WALK)
	elif state != State.IDLE:
		_enter_state(State.IDLE)


func _update_attack(delta: float) -> void:
	var data: Dictionary = ATTACKS[_current_attack]
	var active_start: float = data["windup"]
	var active_end: float = active_start + data["active"]
	var total: float = active_end + data["recovery"]

	# A small step forward while the blow lands.
	if _state_time >= active_start and _state_time < active_end:
		position.x += facing * 90.0 * delta
		if not _attack_has_hit:
			_try_hit_opponent(data["damage"] * damage_multiplier)

	if _state_time >= total:
		_enter_state(State.IDLE)


func _try_hit_opponent(damage: float) -> void:
	if opponent == null or opponent.is_dead():
		return
	var in_front := signf(opponent.position.x - position.x) == float(facing)
	if in_front and distance_to_fighter(opponent) <= reach:
		_attack_has_hit = true
		opponent.receive_hit(self, damage, _current_attack)


## Called by the other fighter when its blow reaches us.
## Returns "dodged", "blocked" or "hit" (handy for testing).
func receive_hit(attacker: Fighter, damage: float, kind: AttackKind) -> String:
	if state == State.DODGE or state == State.DEAD:
		return "dodged"  # rolling fighters cannot be hit

	var push_direction := signf(position.x - attacker.position.x)
	var hit_from_front := signf(attacker.position.x - position.x) == float(facing)
	var spark_height := -125.0 if kind == AttackKind.HIGH else -50.0
	_spark_position = Vector2(22.0, spark_height)
	_spark_time = 0.15

	if state == State.BLOCK and hit_from_front:
		# A tired fighter blocks less well.
		var strength := block_strength * (0.5 if is_exhausted() else 1.0)
		_take_damage(damage * (1.0 - strength))
		_spend_stamina(BLOCK_STAMINA_COST)
		_spark_was_blocked = true
		_knockback = push_direction * 160.0
		if is_exhausted() and not is_dead():
			_hurt_duration = GUARD_BREAK_TIME  # guard broken!
			_enter_state(State.HURT)
		got_hit.emit("blocked")
		return "blocked"

	_spark_was_blocked = false
	_flash = FLASH_TIME
	_knockback = push_direction * 280.0
	got_hit.emit("hit")
	_take_damage(damage)
	if not is_dead():
		_hurt_duration = HURT_TIME
		_enter_state(State.HURT)  # a clean hit interrupts what we were doing
	return "hit"


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

func _can_act() -> bool:
	return state == State.IDLE or state == State.WALK or state == State.BLOCK


func _enter_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0


func _take_damage(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	if health <= 0.0 and state != State.DEAD:
		_enter_state(State.DEAD)
		died.emit(self)


func _spend_stamina(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	_regen_delay = STAMINA_REGEN_DELAY


func _update_stamina(delta: float) -> void:
	# Stamina only comes back when you are not attacking or rolling.
	if state == State.ATTACK or state == State.DODGE:
		return
	if _regen_delay > 0.0:
		_regen_delay -= delta
		return
	var rate := STAMINA_REGEN
	if state == State.BLOCK:
		rate *= 0.3  # holding the shield up is tiring, so slow refill
	stamina = minf(stamina + rate * delta, max_stamina)


func _face_opponent() -> void:
	# Turn around only when free, not in the middle of a swing or roll.
	if opponent == null or not (_can_act() or state == State.HURT):
		return
	var direction := signf(opponent.position.x - position.x)
	if direction != 0.0:
		facing = int(direction)
		scale.x = facing  # flipping the scale mirrors the drawing


func _keep_apart_from_opponent() -> void:
	# Fighters may roll past each other, but otherwise they cannot overlap.
	if opponent == null or state == State.DODGE or opponent.state == State.DODGE:
		return
	if opponent.is_dead():
		return
	var gap := position.x - opponent.position.x
	if absf(gap) < MIN_GAP:
		var side := signf(gap) if gap != 0.0 else -float(facing)
		position.x += side * (MIN_GAP - absf(gap)) * 0.5


# ---------------------------------------------------------------------------
# Drawing. Everything is made of simple shapes for now; pixel art comes later.
# Coordinates: x > 0 is in front of the fighter, y < 0 is above the sand.
# ---------------------------------------------------------------------------

func _draw() -> void:
	_draw_shadow()
	if state == State.DEAD:
		# Lying on the sand: turn the whole drawing a quarter turn.
		draw_set_transform(Vector2(0, -18), -PI / 2.0, Vector2.ONE)
	elif state == State.DODGE:
		# Rolling: draw squashed and low.
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.15, 0.55))
	_draw_body()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_spark()


## Colours turn white during the hit flash and see-through while rolling.
func _tint(color: Color) -> Color:
	var c := color.lerp(Color.WHITE, _flash / FLASH_TIME)
	if state == State.DODGE:
		c.a = 0.6
	return c


func _draw_shadow() -> void:
	var points := PackedVector2Array()
	for i in 16:
		var angle := TAU * i / 16.0
		points.append(Vector2(cos(angle) * 42.0, sin(angle) * 8.0))
	draw_colored_polygon(points, Color(0, 0, 0, 0.25))


func _draw_body() -> void:
	var skin := _tint(Color(0.87, 0.69, 0.53))
	var cloth := _tint(body_color)
	var dark := _tint(body_color.darkened(0.45))

	draw_rect(Rect2(-18, -62, 14, 62), skin)  # back leg
	draw_rect(Rect2(4, -62, 14, 62), skin)    # front leg
	draw_rect(Rect2(-18, -128, 36, 52), skin) # chest
	draw_rect(Rect2(-22, -80, 44, 26), cloth) # loincloth (subligaculum)
	draw_rect(Rect2(-22, -84, 44, 8), dark)   # belt (balteus)
	draw_circle(Vector2(0, -145), 16, skin)   # head

	if gladiator_class == GladiatorClass.MURMILLO:
		_draw_murmillo(cloth, dark)
	else:
		_draw_retiarius(cloth, dark)


## Where the weapon hand is and which way the weapon points, for each pose.
func _weapon_pose() -> Dictionary:
	var hand := Vector2(22, -100)
	var direction := Vector2(0.6, -0.8)
	match state:
		State.ATTACK:
			var winding_up: bool = _state_time < ATTACKS[_current_attack]["windup"]
			if _current_attack == AttackKind.HIGH:
				hand = Vector2(-6, -142) if winding_up else Vector2(34, -128)
				direction = Vector2(-0.4, -1.0) if winding_up else Vector2(1.0, -0.08)
			else:
				hand = Vector2(-8, -90) if winding_up else Vector2(34, -70)
				direction = Vector2(-1.0, 0.3) if winding_up else Vector2(1.0, 0.35)
		State.BLOCK:
			hand = Vector2(14, -108)
			direction = Vector2(0.15, -1.0)
		State.HURT:
			hand = Vector2(2, -104)
			direction = Vector2(-0.6, -0.8)
	return {"hand": hand, "direction": direction.normalized()}


func _draw_arm_to(hand: Vector2) -> void:
	draw_line(Vector2(8, -122), hand, _tint(Color(0.87, 0.69, 0.53)), 9.0)


## Murmillo: big helmet with a fish crest, large shield, short sword.
func _draw_murmillo(cloth: Color, dark: Color) -> void:
	var metal := _tint(Color(0.72, 0.72, 0.74))
	draw_rect(Rect2(4, -40, 14, 40), metal)                       # greave on front leg
	draw_circle(Vector2(0, -147), 20, metal)                      # helmet
	draw_rect(Rect2(6, -156, 14, 16), metal.darkened(0.35))       # visor grille
	draw_colored_polygon(PackedVector2Array([                     # fish-like crest
		Vector2(-16, -162), Vector2(10, -164), Vector2(-2, -192), Vector2(-26, -180)]), cloth)

	var pose := _weapon_pose()
	var hand: Vector2 = pose["hand"]
	var blade_tip: Vector2 = hand + pose["direction"] * 48.0
	var shield := Rect2(16, -128, 16, 78)
	if state == State.BLOCK:
		shield = Rect2(30, -146, 18, 92)  # shield pushed forward and up

	var draw_sword := func() -> void:
		_draw_arm_to(hand)
		draw_line(hand, blade_tip, _tint(Color(0.85, 0.85, 0.9)), 6.0)  # gladius
		draw_line(hand - pose["direction"].orthogonal() * 8.0,
			hand + pose["direction"].orthogonal() * 8.0, dark, 4.0)     # hilt guard
	var draw_shield := func() -> void:
		draw_rect(shield, dark)                                        # scutum
		draw_rect(shield.grow(-3), cloth)
		draw_circle(shield.get_center(), 6, _tint(Color(0.9, 0.75, 0.3))) # metal boss

	# Draw the shield on top while blocking so it is clearly raised.
	if state == State.BLOCK:
		draw_sword.call()
		draw_shield.call()
	else:
		draw_shield.call()
		draw_sword.call()


## Retiarius: no helmet, shoulder guard, long trident, a net at the hip.
func _draw_retiarius(cloth: Color, dark: Color) -> void:
	var metal := _tint(Color(0.72, 0.72, 0.74))
	var hair := _tint(Color(0.3, 0.2, 0.12))
	draw_arc(Vector2(0, -147), 16, PI, TAU, 12, hair, 6.0)        # hair, no helmet
	draw_colored_polygon(PackedVector2Array([                     # galerus (shoulder guard)
		Vector2(-2, -132), Vector2(20, -130), Vector2(22, -112), Vector2(0, -118)]), metal)

	# Net bundle hanging at the back hip.
	var net_centre := Vector2(-24, -70)
	draw_circle(net_centre, 12, _tint(Color(0.85, 0.8, 0.65)))
	for offset in [-6.0, 0.0, 6.0]:
		draw_line(net_centre + Vector2(offset, -11), net_centre + Vector2(offset, 11), dark, 1.5)
		draw_line(net_centre + Vector2(-11, offset), net_centre + Vector2(11, offset), dark, 1.5)

	# Trident (fuscina): long shaft and three prongs.
	var pose := _weapon_pose()
	var hand: Vector2 = pose["hand"]
	var direction: Vector2 = pose["direction"]
	var tip := hand + direction * 105.0
	var butt := hand - direction * 35.0
	_draw_arm_to(hand)
	draw_line(butt, tip, _tint(Color(0.55, 0.38, 0.2)), 5.0)
	var side := direction.orthogonal() * 9.0
	draw_line(tip - side, tip + side, metal, 4.0)
	for prong in [-1.0, 0.0, 1.0]:
		var base: Vector2 = tip + side * prong
		draw_line(base, base + direction * 16.0, metal, 3.0)


## A little star where a blow lands. Yellow for a hit, pale blue for a block.
func _draw_spark() -> void:
	if _spark_time <= 0.0:
		return
	var color := Color(0.75, 0.9, 1.0) if _spark_was_blocked else Color(1.0, 0.95, 0.5)
	var size := 10.0 + 60.0 * (0.15 - _spark_time)
	for i in 6:
		var angle := TAU * i / 6.0 + 0.3
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(_spark_position + direction * size * 0.4,
			_spark_position + direction * size, color, 3.0)
