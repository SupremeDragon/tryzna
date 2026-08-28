class_name EnemyBrain
extends RefCounted
## Найпростіший ворог, який усе одно чесний до гравця.
##
## Правило одне: перед ударом завжди є видимий замах, і його вистачає, щоб
## відскочити. Ворог має 1 атаку. Читабельність важливіша за глибину —
## див. docs/03-геймплей.md, §3.

enum State { IDLE, CHASE, WINDUP, STRIKE, RECOVER }

var aggro_radius: float = 560.0
var strike_radius: float = 104.0
var leash_radius: float = 900.0
var speed: float = 185.0

var windup_time: float = 0.55
var strike_time: float = 0.14
var recover_time: float = 0.70

var state: State = State.IDLE
var timer: float = 0.0
var facing: Vector2 = Vector2.RIGHT

var _struck_this_swing: bool = false


## Повертає бажану швидкість. Стан оновлюється всередині.
func tick(dt: float, self_pos: Vector2, target_pos: Vector2, staggered: bool) -> Vector2:
	if staggered:
		state = State.IDLE
		timer = 0.0
		return Vector2.ZERO

	var to_target: Vector2 = target_pos - self_pos
	var distance: float = to_target.length()
	if distance > 0.001:
		facing = to_target / distance

	timer += dt

	match state:
		State.IDLE:
			if distance <= aggro_radius:
				_enter(State.CHASE)
			return Vector2.ZERO

		State.CHASE:
			if distance > leash_radius:
				_enter(State.IDLE)
				return Vector2.ZERO
			if distance <= strike_radius:
				_enter(State.WINDUP)
				return Vector2.ZERO
			return facing * speed

		State.WINDUP:
			if timer >= windup_time:
				_enter(State.STRIKE)
				_struck_this_swing = false
			return Vector2.ZERO

		State.STRIKE:
			if timer >= strike_time:
				_enter(State.RECOVER)
			return Vector2.ZERO

		State.RECOVER:
			if timer >= recover_time:
				_enter(State.CHASE if distance <= aggro_radius else State.IDLE)
			return Vector2.ZERO

	return Vector2.ZERO


## Наскільки визрів замах, 0..1. Це те, що гравець мусить бачити.
func windup_ratio() -> float:
	if state == State.WINDUP:
		return clampf(timer / maxf(windup_time, 0.0001), 0.0, 1.0)
	return 1.0 if state == State.STRIKE else 0.0


func is_striking() -> bool:
	return state == State.STRIKE


## Удар зараховується один раз за замах.
func consume_strike() -> bool:
	if state != State.STRIKE or _struck_this_swing:
		return false
	_struck_this_swing = true
	return true


func interrupt() -> void:
	_enter(State.RECOVER)


func _enter(next: State) -> void:
	state = next
	timer = 0.0
