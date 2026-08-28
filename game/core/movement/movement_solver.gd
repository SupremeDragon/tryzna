class_name MovementSolver
extends RefCounted
## Базовий розвʼязувач руху.
##
## Гравець у грі ОДИН. Змінюється не контролер, а підключений розвʼязувач.
## Це те, що дозволяє нам мати три світи з різною фізикою без потрійного коду.

var speed: float = 320.0
var accel: float = 2400.0
var friction: float = 3000.0

## Перешкоди поточної локації. null — рух нічим не обмежений.
var world: SolidWorld = null

## Габарити тіла в логічному просторі.
var half_width: float = 26.0
var half_depth: float = 22.0
var body_height: float = 118.0


## Стан рухомого тіла в логічних координатах.
class MoverState extends RefCounted:
	var position: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var on_ground: bool = true
	var facing: float = 1.0
	## Куди дивиться тіло в площині землі. Потрібно, щоб знати, куди б\'є.
	var facing_dir: Vector2 = Vector2.RIGHT


## Один крок симуляції. Реалізація мутує `state`.
func step(_state: MoverState, _input: Vector2, _jump_pressed: bool, _dt: float) -> void:
	pass


## Людська назва режиму для HUD.
func label() -> String:
	return "—"


## --- Ривок ---------------------------------------------------------------
## Ухилення — це рух, а не бойова дія, тому живе тут, а не в бою.

var dash_left: float = 0.0
var dash_dir: Vector2 = Vector2.RIGHT
var dash_speed: float = 880.0


func start_dash(direction: Vector2, duration: float) -> void:
	dash_dir = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	dash_left = duration


func is_dashing() -> bool:
	return dash_left > 0.0


## Слід тіла на землі — те, чим воно впирається в перешкоди зверху.
func foot_of(position: Vector3) -> Rect2:
	return Rect2(
		position.x - half_width, position.y - half_depth,
		half_width * 2.0, half_depth * 2.0
	)


static func approach(current: float, target: float, rate: float, dt: float) -> float:
	return move_toward(current, target, rate * dt)
