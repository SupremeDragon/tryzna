class_name SolidWorld
extends RefCounted
## Перешкоди локації в логічному просторі.
##
## Кожна перешкода — коробка: слід на землі (x, глибина) плюс висота.
## Розвʼязується вона по-різному залежно від світу, і це прямо випливає
## з того, яку вісь цей світ убиває:
##
##   ПЛИНЬ / ВИСІ (глибина жива) → зіткнення у площині (x, глибина).
##                                 Висота не важить: через хату не переступиш.
##   НИЦЬ (глибина мертва)       → зіткнення у площині (x, висота).
##                                 Глибина не важить: обійти нічого не можна,
##                                 на уступ можна тільки застрибнути.
##
## Тобто це та сама коробка, прочитана двома різними парами осей.

class Solid extends RefCounted:
	var foot: Rect2  # слід на землі: x та глибина
	var height: float

	func _init(p_foot: Rect2, p_height: float) -> void:
		foot = p_foot
		height = p_height

var _solids: Array[Solid] = []


func clear() -> void:
	_solids.clear()


## `center` — центр основи, `size` — (ширина по x, глибина по y).
func add_box(center: Vector3, size: Vector2, height: float) -> void:
	_solids.append(Solid.new(
		Rect2(center.x - size.x * 0.5, center.y - size.y * 0.5, size.x, size.y),
		height
	))


func count() -> int:
	return _solids.size()


func solids() -> Array[Solid]:
	return _solids


# --- Топ-даун: площина (x, глибина) ------------------------------------------

## Виштовхує слід гравця з перешкод уздовж однієї осі.
## `axis`: 0 — x, 1 — глибина. Повертає скориговану координату центра.
func resolve_ground(foot: Rect2, axis: int, moving_positive: bool) -> float:
	var result: Rect2 = foot
	for solid: Solid in _solids:
		if not result.intersects(solid.foot):
			continue
		if axis == 0:
			result.position.x = (
				solid.foot.position.x - result.size.x if moving_positive
				else solid.foot.end.x
			)
		else:
			result.position.y = (
				solid.foot.position.y - result.size.y if moving_positive
				else solid.foot.end.y
			)
	return result.get_center().x if axis == 0 else result.get_center().y


func overlaps_ground(foot: Rect2) -> bool:
	for solid: Solid in _solids:
		if foot.intersects(solid.foot):
			return true
	return false


# --- Профіль: площина (x, висота) --------------------------------------------

## Чи перетинає відрізок [x_min, x_max] × [z_min, z_max] якусь перешкоду.
func overlaps_side(x_min: float, x_max: float, z_min: float, z_max: float) -> bool:
	for solid: Solid in _solids:
		if x_max > solid.foot.position.x and x_min < solid.foot.end.x \
				and z_min < solid.height and z_max > 0.0:
			return true
	return false


## Виштовхує гравця по горизонталі. Повертає скориговане x центра.
func resolve_side_x(
	x_center: float, half_width: float, z_min: float, z_max: float, moving_right: bool
) -> float:
	var result: float = x_center
	for solid: Solid in _solids:
		if z_min >= solid.height or z_max <= 0.0:
			continue
		if result + half_width > solid.foot.position.x \
				and result - half_width < solid.foot.end.x:
			result = (
				solid.foot.position.x - half_width if moving_right
				else solid.foot.end.x + half_width
			)
	return result


## Найвища опора під ногами при падінні з `z_from` до `z_to`.
## Повертає висоту опори або -1.0, якщо ставати нема на що.
func landing_height(x_center: float, half_width: float, z_from: float, z_to: float) -> float:
	var best: float = -1.0
	for solid: Solid in _solids:
		if x_center + half_width <= solid.foot.position.x \
				or x_center - half_width >= solid.foot.end.x:
			continue
		# Опора рахується, тільки якщо ми були над нею й опустилися нижче.
		if z_from >= solid.height - 0.5 and z_to <= solid.height and solid.height > best:
			best = solid.height
	return best


## Чи впирається голова в стелю під час підйому.
func ceiling_below(x_center: float, half_width: float, z_head: float) -> bool:
	for solid: Solid in _solids:
		if x_center + half_width <= solid.foot.position.x \
				or x_center - half_width >= solid.foot.end.x:
			continue
		if z_head > 0.0 and z_head < solid.height:
			return true
	return false
