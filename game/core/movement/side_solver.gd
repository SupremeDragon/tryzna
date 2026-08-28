class_name SideSolver
extends MovementSolver
## Рух у світі мертвих: тільки вліво/вправо + стрибок.
##
## Глибина (y) не просто ігнорується — вона ПРИТЯГУЄТЬСЯ до нуля.
## Це і є механічне вираження теми: у Ниці ти більше не обираєш, куди йти.
## Вимір, який у тебе був за життя, забирають.
##
## Зіткнення тут — у площині (x, висота). Глибина не важить: обійти нічого
## не можна, на уступ можна тільки застрибнути.

const GRAVITY: float = 2600.0
const JUMP_VELOCITY: float = 980.0
const DEPTH_COLLAPSE_RATE: float = 420.0

var coyote_time: float = 0.10
var _coyote_left: float = 0.0


func _init(p_speed: float = 300.0) -> void:
	speed = p_speed
	accel = 2200.0
	friction = 2600.0


func step(state: MovementSolver.MoverState, input: Vector2, jump_pressed: bool, dt: float) -> void:
	var wish_x: float = clampf(input.x, -1.0, 1.0) * speed
	state.velocity.x = approach(
		state.velocity.x, wish_x, accel if not is_zero_approx(wish_x) else friction, dt
	)

	# Глибина схлопується. Вертикальний ввід у Ниці не робить нічого.
	state.velocity.y = 0.0
	state.position.y = approach(state.position.y, 0.0, DEPTH_COLLAPSE_RATE, dt)

	_move_horizontal(state, state.velocity.x * dt)
	_move_vertical(state, dt)

	if jump_pressed and _coyote_left > 0.0:
		state.velocity.z = JUMP_VELOCITY
		state.on_ground = false
		_coyote_left = 0.0

	if not is_zero_approx(input.x):
		state.facing = signf(input.x)
		state.facing_dir = Vector2(signf(input.x), 0.0)


func _move_horizontal(state: MovementSolver.MoverState, delta: float) -> void:
	if is_zero_approx(delta):
		return
	state.position.x += delta
	if world == null:
		return

	var corrected: float = world.resolve_side_x(
		state.position.x, half_width,
		state.position.z, state.position.z + body_height,
		delta > 0.0
	)
	if not is_equal_approx(corrected, state.position.x):
		state.position.x = corrected
		state.velocity.x = 0.0


func _move_vertical(state: MovementSolver.MoverState, dt: float) -> void:
	# z росте вгору, тому гравітація віднімає.
	state.velocity.z -= GRAVITY * dt
	var previous_z: float = state.position.z
	state.position.z += state.velocity.z * dt

	if state.velocity.z > 0.0:
		# Підйом: перевіряємо стелю.
		if world != null and world.ceiling_below(
			state.position.x, half_width, state.position.z + body_height
		):
			state.position.z = previous_z
			state.velocity.z = 0.0
		state.on_ground = false
		_coyote_left = maxf(_coyote_left - dt, 0.0)
		return

	# Падіння: шукаємо опору. Земля завжди на нулі, уступи — вище.
	var ground: float = 0.0
	if world != null:
		var landing: float = world.landing_height(
			state.position.x, half_width, previous_z, state.position.z
		)
		if landing > ground:
			ground = landing

	if state.position.z <= ground:
		state.position.z = ground
		state.velocity.z = 0.0
		state.on_ground = true
		_coyote_left = coyote_time
	else:
		state.on_ground = false
		_coyote_left = maxf(_coyote_left - dt, 0.0)


func label() -> String:
	return "НИЦЬ"
