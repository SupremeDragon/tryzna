extends Node
## Проєктор — серце візуального концепту «Тризни».
##
## Увесь світ зберігається в ЛОГІЧНИХ координатах Vector3:
##   x — горизонталь (вліво/вправо)
##   y — глибина (від камери вглиб сцени)
##   z — висота над землею
##
## На екран це переводять ДВА множники, і кожен потойбічний світ убиває свій:
##
##            глибина   висота    що бачиш
##   ВИСІ      0.92      0.00     карту: вежі осіли у власні основи
##   ПЛИНЬ     0.55      1.00     повний світ — єдиний, де живі обидві осі
##   НИЦЬ      0.00      1.00     силует: розташування зникло, лишився зріст
##
## Смерть забирає глибину. Піднесення забирає висоту. Обидва переходи — це
## анімація одного числа до нуля, тільки різного. Ніякого 3D у грі немає.

signal depth_scale_changed(value: float)
signal height_scale_changed(value: float)

var _depth_scale: float = WorldSpace.DEPTH_PLYN
var _height_scale: float = WorldSpace.HEIGHT_PLYN

## Наскільки глибина зсуває обʼєкт по вертикалі екрана.
var depth_scale: float:
	get:
		return _depth_scale
	set(value):
		var clamped: float = clampf(value, 0.0, 1.0)
		if is_equal_approx(clamped, _depth_scale):
			return
		_depth_scale = clamped
		depth_scale_changed.emit(_depth_scale)

## Наскільки висота підіймає обʼєкт над його власною основою.
var height_scale: float:
	get:
		return _height_scale
	set(value):
		var clamped: float = clampf(value, 0.0, 1.0)
		if is_equal_approx(clamped, _height_scale):
			return
		_height_scale = clamped
		height_scale_changed.emit(_height_scale)


## Логічна точка → екранна.
func project(p: Vector3) -> Vector2:
	return Vector2(p.x, p.y * _depth_scale - p.z * _height_scale)


## Ключ сортування по глибині (хто кого затуляє).
func sort_key(p: Vector3) -> float:
	return p.y


## Наскільки світ сплющений у силует: 0 — обʼємний, 1 — Ниць.
func flatness() -> float:
	return clampf(1.0 - inverse_lerp(WorldSpace.DEPTH_NYTS, WorldSpace.DEPTH_PLYN, _depth_scale), 0.0, 1.0)


## Наскільки світ став картою: 0 — обʼємний, 1 — Висі.
func mapness() -> float:
	return clampf(1.0 - _height_scale, 0.0, 1.0)
