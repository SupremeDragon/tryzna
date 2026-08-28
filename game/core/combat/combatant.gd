class_name Combatant
extends RefCounted
## Той, кого можна вдарити. Нічого не знає ні про сцену, ні про малювання.

signal died()
signal hurt(amount: int)

var max_hp: int = 3
var hp: int = 3

## Невразливість після удару — щоб один замах не з\'їдав усе життя.
var invuln_left: float = 0.0
var invuln_on_hit: float = 0.45

## Приголомшення: поки триває, тіло не діє.
var stagger_left: float = 0.0


func _init(p_max_hp: int = 3) -> void:
	max_hp = p_max_hp
	hp = p_max_hp


func is_alive() -> bool:
	return hp > 0


func is_staggered() -> bool:
	return stagger_left > 0.0


func can_be_hit() -> bool:
	return is_alive() and invuln_left <= 0.0


## Повертає true, якщо удар справді зайшов.
func take_hit(amount: int = 1, stagger: float = 0.3) -> bool:
	if not can_be_hit():
		return false
	hp = maxi(hp - amount, 0)
	invuln_left = invuln_on_hit
	stagger_left = maxf(stagger_left, stagger)
	hurt.emit(amount)
	if hp == 0:
		died.emit()
	return true


func revive() -> void:
	hp = max_hp
	invuln_left = invuln_on_hit
	stagger_left = 0.0


func tick(dt: float) -> void:
	invuln_left = maxf(invuln_left - dt, 0.0)
	stagger_left = maxf(stagger_left - dt, 0.0)
