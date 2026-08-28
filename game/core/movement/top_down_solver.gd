class_name TopDownSolver
extends MovementSolver
## Рух по площині землі: 8 напрямків, z завжди 0.
##
## Один і той самий розвʼязувач обслуговує ПЛИНЬ і ВИСІ — різниця лише в константах.
## Плинь: є інерція, тіло має вагу. Висі: інерції немає, рух божественно рівний.
##
## Зіткнення тут — у площині (x, глибина). Висота перешкоди не важить:
## через хату не переступиш, хоч би яка низька вона була.

var use_inertia: bool = true
var name_label: String = "ПЛИНЬ"


func _init(p_speed: float = 320.0, p_inertia: bool = true) -> void:
	speed = p_speed
	use_inertia = p_inertia


func step(state: MovementSolver.MoverState, input: Vector2, _jump_pressed: bool, dt: float) -> void:
	# Ривок перебиває звичайний рух: поки він триває, ввід не має значення.
	if dash_left > 0.0:
		dash_left = maxf(dash_left - dt, 0.0)
		state.velocity.x = dash_dir.x * dash_speed
		state.velocity.y = dash_dir.y * dash_speed
		state.velocity.z = 0.0
		_move_axis(state, 0, state.velocity.x * dt)
		_move_axis(state, 1, state.velocity.y * dt)
		state.position.z = approach(state.position.z, 0.0, 900.0, dt)
		state.on_ground = is_zero_approx(state.position.z)
		return

	var wish: Vector2 = input.limit_length(1.0) * speed

	if use_inertia:
		state.velocity.x = approach(state.velocity.x, wish.x, accel if wish.x != 0.0 else friction, dt)
		state.velocity.y = approach(state.velocity.y, wish.y, accel if wish.y != 0.0 else friction, dt)
	else:
		state.velocity.x = wish.x
		state.velocity.y = wish.y

	state.velocity.z = 0.0

	# Рухаємось і розвʼязуємо по одній осі за раз — інакше тіло чіпляється
	# за кути й зупиняється там, де мало б ковзнути вздовж стіни.
	_move_axis(state, 0, state.velocity.x * dt)
	_move_axis(state, 1, state.velocity.y * dt)

	# Плавно опускаємо на землю, якщо прийшли з режиму зі стрибками.
	state.position.z = approach(state.position.z, 0.0, 900.0, dt)
	state.on_ground = is_zero_approx(state.position.z)

	if not is_zero_approx(input.x):
		state.facing = signf(input.x)
	if input.length_squared() > 0.001:
		state.facing_dir = input.normalized()


func _move_axis(state: MovementSolver.MoverState, axis: int, delta: float) -> void:
	if is_zero_approx(delta):
		return

	if axis == 0:
		state.position.x += delta
	else:
		state.position.y += delta

	if world == null:
		return

	var foot: Rect2 = foot_of(state.position)
	if not world.overlaps_ground(foot):
		return

	var corrected: float = world.resolve_ground(foot, axis, delta > 0.0)
	if axis == 0:
		state.position.x = corrected
		state.velocity.x = 0.0
	else:
		state.position.y = corrected
		state.velocity.y = 0.0


func label() -> String:
	return name_label
