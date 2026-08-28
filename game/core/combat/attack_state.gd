class_name AttackState
extends RefCounted
## Один замах: замах → удар → віддих.
##
## Три фази, а не анімаційні події, бо бій мусить бути читабельним:
## гравець має встигнути побачити замах і зреагувати. Це стосується і
## ворогів, і самої Ости.

enum Phase { READY, WINDUP, ACTIVE, RECOVER }

var windup: float = 0.12
var active: float = 0.15
var recover: float = 0.25

## Наскільки далеко від центра тіла лягає зона удару.
var reach: float = 78.0
var half_size: Vector2 = Vector2(48.0, 42.0)

var phase: Phase = Phase.READY
var _t: float = 0.0
var _spent: bool = false


func _init(p_windup: float = 0.12, p_active: float = 0.15, p_recover: float = 0.25) -> void:
	windup = p_windup
	active = p_active
	recover = p_recover


func is_busy() -> bool:
	return phase != Phase.READY


func is_active() -> bool:
	return phase == Phase.ACTIVE


## Наскільки визрів замах, 0..1. Для «телеграфа» на екрані.
func windup_ratio() -> float:
	if phase != Phase.WINDUP:
		return 1.0 if phase == Phase.ACTIVE else 0.0
	return clampf(_t / maxf(windup, 0.0001), 0.0, 1.0)


## Почати замах. Повертає false, якщо тіло ще зайняте попереднім.
func press() -> bool:
	if is_busy():
		return false
	phase = Phase.WINDUP
	_t = 0.0
	_spent = false
	return true


## Один замах б\'є один раз, скільки б кадрів не тривала активна фаза.
func consume() -> bool:
	if not is_active() or _spent:
		return false
	_spent = true
	return true


func cancel() -> void:
	phase = Phase.READY
	_t = 0.0
	_spent = false


func tick(dt: float) -> void:
	if phase == Phase.READY:
		return
	_t += dt
	match phase:
		Phase.WINDUP:
			if _t >= windup:
				_t -= windup
				phase = Phase.ACTIVE
		Phase.ACTIVE:
			if _t >= active:
				_t -= active
				phase = Phase.RECOVER
		Phase.RECOVER:
			if _t >= recover:
				phase = Phase.READY
				_t = 0.0
				_spent = false


## Зона удару в логічній площині землі.
func box(origin: Vector2, direction: Vector2) -> Rect2:
	var dir: Vector2 = direction if direction.length_squared() > 0.001 else Vector2.RIGHT
	var center: Vector2 = origin + dir.normalized() * reach
	return Rect2(center - half_size, half_size * 2.0)
