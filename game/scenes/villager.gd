extends "res://scenes/walker.gd"
## Селянин: той, хто ходить сам.
##
## Розум тут навмисно короткий: постояв — вибрав куди — дійшов — постояв. Ніякої
## навігації по карті: селянин намічає точку неподалік і йде до неї навпростець,
## а якщо впирається, кидає цю точку й вибирає іншу. Село від цього виглядає
## живим, а коду тут на екран, і він не бреше про свої вміння.
##
## Далеко від дому селянин не відходить: людина, що безцільно бреде через усе
## поле, читається не як мешканець, а як загублена.

## Наскільки далеко від дому селянин ходить, у клітинках.
var roam: int = 5
## Скільки стоїть між прогулянками.
var rest_min: float = 1.2
var rest_max: float = 4.0

var _home := Vector2.ZERO
var _target := Vector2.ZERO
var _rest: float = 0.0
var _going: bool = false
var _patience: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	speed = 90.0
	super._ready()
	_rng.randomize()
	_home = position
	_rest = _rng.randf_range(0.0, rest_max)


func _process(delta: float) -> void:
	if _ground == null:
		return

	if not _going:
		_rest -= delta
		stand()
		if _rest <= 0.0:
			_aim()
		return

	var step: Vector2 = _target - position
	# «Дійшов» міряємо великодушно: селянин цілиться в центр клітинки, а
	# ковзання по осях лишає його трохи збоку, і суворий поріг тримав би його
	# на місці, доки не скінчиться терпіння.
	if step.length() < 12.0:
		_settle()
		return

	var before: Vector2 = position
	walk(step.normalized(), delta)

	# Уперся. Це нормально: шляху селянин не шукає, тож просто передумує.
	_patience -= delta
	if _patience <= 0.0 or position.distance_to(before) < 0.1:
		_settle()


func _aim() -> void:
	var home_cell: Vector2i = cell_at(_home)
	for tries: int in range(8):
		var cell: Vector2i = home_cell + Vector2i(
			_rng.randi_range(-roam, roam), _rng.randi_range(-roam, roam)
		)
		var spot: Vector2 = center_of(cell)
		if blocked(spot):
			continue
		_target = spot
		_going = true
		_patience = 6.0
		return
	_rest = _rng.randf_range(rest_min, rest_max)


func _settle() -> void:
	_going = false
	_rest = _rng.randf_range(rest_min, rest_max)
	stand()
