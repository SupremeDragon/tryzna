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

## ІЗОМЕТРІЯ.
##
## Досі горизонталь на екрані дорівнювала горизонталі у світі: екран_x = x.
## Цього досить для виду в три чверті, але ізометрію так не намалювати — у ній
## глибина зсуває предмет І ВБІК ТЕЖ, а віддаль уперед підіймає його по екрану.
## Тому множників тепер чотири, а не два.
##
## Концепт від цього не ламається, а гострішає. Було: смерть забирає глибину,
## і світ із трьох чвертей стає силуетом. Стало: смерть СПЛЮЩУЄ РОМБ У ЛІНІЮ,
## бо в нуль ідуть усі три множники глибини одразу.
##
## За замовчуванням нові множники нульові — тобто без явного ввімкнення
## проєктор поводиться точно так, як поводився досі.

signal depth_scale_changed(value: float)
signal height_scale_changed(value: float)

var _depth_scale: float = WorldSpace.DEPTH_PLYN
var _height_scale: float = WorldSpace.HEIGHT_PLYN
var _skew: float = 0.0
var _rise: float = 0.0

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


## Наскільки глибина зсуває обʼєкт УБІК. Нуль — прямий вид, одиниця — повна
## ізометрія: крок углиб зсуває рівно настільки ж, наскільки крок убік.
var skew: float:
	get:
		return _skew
	set(value):
		_skew = clampf(value, 0.0, 1.0)

## Наскільки крок УБІК опускає обʼєкт по екрану. У прямому виді нуль: пішов
## праворуч — лишився на тій самій висоті. В ізометрії — рівно стільки ж,
## скільки дає крок углиб, і саме з цього виходить ромб.
var rise: float:
	get:
		return _rise
	set(value):
		_rise = clampf(value, 0.0, 1.0)


## Логічна точка → екранна.
func project(p: Vector3) -> Vector2:
	return Vector2(
		p.x - p.y * _skew,
		p.x * _rise + p.y * _depth_scale - p.z * _height_scale
	)


## Ключ сортування по глибині (хто кого затуляє).
##
## Це НЕ p.y: в ізометрії ближчим є той, у кого більша сума екранної глибини,
## а вона складається і з x, і з y. Поки rise нульовий, вираз вироджується в
## колишній p.y * depth_scale, тобто старий порядок зберігається.
func sort_key(p: Vector3) -> float:
	return p.x * _rise + p.y * _depth_scale


## Наскільки світ сплющений у силует: 0 — обʼємний, 1 — Ниць.
func flatness() -> float:
	return clampf(1.0 - inverse_lerp(WorldSpace.DEPTH_NYTS, WorldSpace.DEPTH_PLYN, _depth_scale), 0.0, 1.0)


## Наскільки світ став картою: 0 — обʼємний, 1 — Висі.
func mapness() -> float:
	return clampf(1.0 - _height_scale, 0.0, 1.0)
